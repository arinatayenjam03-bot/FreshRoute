// lib/screens/dashboard_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';
import 'home_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ScrollController _scroll = ScrollController();
  Timer? _sensorTimer;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      HomeScreen.of(context)?.handleScroll(_scroll.offset);
    });
    // Refresh sensor every 8 seconds for live feel
    _sensorTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) context.read<AppProvider>().loadSensor();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _sensorTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final sensor = p.sensorData;
    final freshness = _calcFreshness(sensor);
    final urgency = _urgency(freshness);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        controller: _scroll,
        slivers: [
          // ── App bar ──
          SliverAppBar(
            pinned: true,
            backgroundColor: AppTheme.surface,
            surfaceTintColor: Colors.transparent,
            expandedHeight: 0,
            toolbarHeight: 64,
            title: Row(children: [
              // Logo
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/icon.png',
                  width: 34,
                  height: 34,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppTheme.accentLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.eco_rounded, color: AppTheme.accent, size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  RichText(
                    text: const TextSpan(children: [
                      TextSpan(
                        text: 'Fresh',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      TextSpan(
                        text: 'Route',
                        style: TextStyle(
                          color: AppTheme.accent,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ]),
                  ),
                  Text(
                    p.farmerId,
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ]),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: AppTheme.textSecondary),
                onPressed: () {},
              ),
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: CircleAvatar(
                  radius: 17,
                  backgroundColor: AppTheme.accentLight,
                  child: Text(
                    'R',
                    style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 0.5, color: AppTheme.divider),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 16),

                // ── Location card with reverse geocoding ──
                _LocationCard(lat: p.farmerLat, lon: p.farmerLon),
                const SizedBox(height: 20),

                // ── Live Sensor ──
                _SectionLabel(
                  title: 'Live Sensor',
                  trailing: TextButton(
                    onPressed: p.loadSensor,
                    child: const Text(
                      'Refresh',
                      style: TextStyle(color: AppTheme.accent, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _LiveSensorPanel(
                  sensor: sensor,
                  freshness: freshness,
                  urgency: urgency,
                  loading: p.sensorLoading,
                ),
                const SizedBox(height: 20),

                // ── This week metrics ──
                const _SectionLabel(title: 'This Week'),
                const SizedBox(height: 10),
                _WeeklyMetricsSlider(
                  avgFreshness: freshness > 0 ? freshness.round() : null,
                  revenue: p.completedOrders.fold(
                    0.0,
                    (s, o) => s + ((o['revenue'] ?? 0.0) as num).toDouble(),
                  ),
                  totalTrips: p.completedOrders.length,
                  activeBatches: p.batches.length,
                  vendorsServed: p.completedOrders.map((o) => o['vendor']).toSet().length,
                ),
                const SizedBox(height: 20),

                // ── Banner ──
                _BannerCard(),
                const SizedBox(height: 20),

                // ── Local market news ──
                _SectionLabel(
                  title: 'Local Market News',
                  trailing: TextButton(
                    onPressed: p.loadRegionNews,
                    child: const Text(
                      'Refresh',
                      style: TextStyle(color: AppTheme.accent, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _LocalNewsFeed(
                  news: p.regionNews,
                  loading: p.newsLoading,
                ),
                const SizedBox(height: 20),

                // ── AI Insights ──
                _SectionLabel(
                  title: 'AI Insights',
                  trailing: TextButton(
                    onPressed: p.loadAiInsights,
                    child: const Text(
                      'Refresh',
                      style: TextStyle(color: AppTheme.accent, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _AiInsightsCard(
                  insights: p.aiInsights,
                  loading: p.insightsLoading,
                ),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  double _calcFreshness(Map<String, dynamic> s) {
    if (s.isEmpty) return 0;
    final t = (s['temperature'] ?? 0).toDouble();
    final h = (s['humidity'] ?? 0).toDouble();
    final g = (s['mq135_ppm'] ?? 0).toDouble();
    return ((100 - (t - 10).abs() * 5).clamp(0, 100) +
            (100 - (h - 80).abs() * 2).clamp(0, 100) +
            (100 - g * 0.2).clamp(0, 100)) /
        3;
  }

  String _urgency(double f) {
    if (f > 80) return 'EXCELLENT';
    if (f > 60) return 'GOOD';
    if (f > 40) return 'MODERATE';
    if (f > 0) return 'URGENT';
    return 'NO DATA';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const _SectionLabel({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) => Row(children: [
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        if (trailing != null) trailing!,
      ]);
}

// ── Location card with reverse geocoding ──────────────────────────────────────
class _LocationCard extends StatefulWidget {
  final double lat, lon;
  const _LocationCard({required this.lat, required this.lon});

  @override
  State<_LocationCard> createState() => _LocationCardState();
}

class _LocationCardState extends State<_LocationCard> {
  String _address = 'Locating...';
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _fetchAddress();
  }

  @override
  void didUpdateWidget(_LocationCard old) {
    super.didUpdateWidget(old);
    if (old.lat != widget.lat || old.lon != widget.lon) {
      _fetchAddress();
    }
  }

  Future<void> _fetchAddress() async {
    // Skip if coordinates are the default placeholder
    if (widget.lat == 0 && widget.lon == 0) {
      setState(() => _address = 'GPS unavailable');
      return;
    }
    try {
      // Nominatim reverse geocoding — free, no API key
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=${widget.lat}&lon=${widget.lon}'
        '&format=json&zoom=16&addressdetails=1',
      );
      final r = await http.get(
        url,
        headers: {'User-Agent': 'FreshRoute/1.0'},
      ).timeout(const Duration(seconds: 8));

      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        final addr = data['address'] as Map<String, dynamic>? ?? {};

        // Build a human-readable label
        final parts = <String>[];
        final building = addr['building'] ??
            addr['amenity'] ??
            addr['tourism'] ??
            addr['leisure'] ??
            addr['office'];
        final road = addr['road'] ?? addr['pedestrian'] ?? addr['footway'];
        final suburb = addr['suburb'] ??
            addr['neighbourhood'] ??
            addr['quarter'] ??
            addr['village'];
        final city = addr['city'] ??
            addr['town'] ??
            addr['municipality'] ??
            addr['county'];
        final state = addr['state'];

        if (building != null) parts.add(building);
        if (road != null && building == null) parts.add(road);
        if (suburb != null) parts.add(suburb);
        if (city != null) parts.add(city);
        if (state != null) parts.add(state);

        final label = parts.take(3).join(', ');
        setState(() {
          _address = label.isNotEmpty ? label : data['display_name'] ?? 'Unknown location';
          _loaded = true;
        });
      } else {
        setState(() => _address = '${widget.lat.toStringAsFixed(4)}, ${widget.lon.toStringAsFixed(4)}');
      }
    } catch (_) {
      setState(() => _address = '${widget.lat.toStringAsFixed(4)}, ${widget.lon.toStringAsFixed(4)}');
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.accentLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.location_on_rounded, color: AppTheme.accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text(
                'Current Location',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
              ),
              const SizedBox(height: 2),
              _loaded
                  ? Text(
                      _address,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    )
                  : Row(children: [
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: AppTheme.accent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _address,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ]),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.accentLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppTheme.accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              const Text(
                'GPS',
                style: TextStyle(
                  color: AppTheme.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ]),
          ),
        ]),
      );
}

// ── Live sensor panel ─────────────────────────────────────────────────────────
class _LiveSensorPanel extends StatefulWidget {
  final Map<String, dynamic> sensor;
  final double freshness;
  final String urgency;
  final bool loading;
  const _LiveSensorPanel({
    required this.sensor,
    required this.freshness,
    required this.urgency,
    required this.loading,
  });

  @override
  State<_LiveSensorPanel> createState() => _LiveSensorPanelState();
}

class _LiveSensorPanelState extends State<_LiveSensorPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;

  // Previous values for animated transitions
  String _prevTemp = '--';
  String _prevHumid = '--';
  String _prevGas = '--';

  @override
  void initState() {
    super.initState();
    _pulseCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_LiveSensorPanel old) {
    super.didUpdateWidget(old);
    if (old.sensor != widget.sensor && widget.sensor.isNotEmpty) {
      _prevTemp = '${widget.sensor['temperature']}°C';
      _prevHumid = '${widget.sensor['humidity']}%';
      _prevGas = '${widget.sensor['mq135_ppm']} ppm';
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading && widget.sensor.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: AppTheme.accent),
        ),
      );
    }
    if (widget.sensor.isEmpty) return const _EmptySensorCard();

    final color = widget.urgency == 'URGENT'
        ? AppTheme.danger
        : widget.urgency == 'MODERATE'
            ? AppTheme.warning
            : AppTheme.accent;

    final temp = widget.sensor['temperature'];
    final humid = widget.sensor['humidity'];
    final gas = widget.sensor['mq135_ppm'];

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(children: [
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) => Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.4 + _pulseCtrl.value * 0.6),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'BT Sensor — Live',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            // Loading indicator when refreshing
            if (widget.loading)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: AppTheme.accent,
                ),
              ),
            if (widget.loading) const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                widget.urgency,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ]),
        ),

        // Metrics — animates value change
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            _AnimatedMetric(
              icon: Icons.thermostat_rounded,
              label: 'Temp',
              value: '$temp°C',
              color: AppTheme.danger,
            ),
            _VertDivider(),
            _AnimatedMetric(
              icon: Icons.water_drop_rounded,
              label: 'Humidity',
              value: '$humid%',
              color: AppTheme.info,
            ),
            _VertDivider(),
            _AnimatedMetric(
              icon: Icons.science_rounded,
              label: 'Ethylene',
              value: '$gas ppm',
              color: AppTheme.warning,
            ),
          ]),
        ),

        // Freshness bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text(
                'Freshness score',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              const Spacer(),
              Text(
                widget.freshness > 0 ? '${widget.freshness.round()}%' : '--',
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: widget.freshness / 100),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOut,
                builder: (_, val, __) => LinearProgressIndicator(
                  value: val,
                  backgroundColor: AppTheme.surfaceGrey,
                  valueColor: AlwaysStoppedAnimation(color),
                  minHeight: 6,
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _AnimatedMetric extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _AnimatedMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.3),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: Text(
              value,
              key: ValueKey(value),
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
          ),
        ]),
      );
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 40, color: AppTheme.divider);
}

class _EmptySensorCard extends StatelessWidget {
  const _EmptySensorCard();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.surfaceGrey,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.sensors_off_outlined, color: AppTheme.textMuted),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                'No sensor connected',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Add a batch and connect your Bluetooth sensor to see live readings.',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ]),
          ),
        ]),
      );
}

// ── Weekly metrics horizontal slider ─────────────────────────────────────────
class _WeeklyMetricsSlider extends StatelessWidget {
  final int? avgFreshness;
  final double revenue;
  final int totalTrips, activeBatches, vendorsServed;
  const _WeeklyMetricsSlider({
    this.avgFreshness,
    required this.revenue,
    required this.totalTrips,
    required this.activeBatches,
    required this.vendorsServed,
  });

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _MetricData('Freshness', avgFreshness != null ? '$avgFreshness%' : '--', Icons.eco_rounded, AppTheme.accent),
      _MetricData('Revenue', '₹${revenue.toStringAsFixed(0)}', Icons.currency_rupee_rounded, AppTheme.info),
      _MetricData('Trips', '$totalTrips', Icons.local_shipping_rounded, AppTheme.textSecondary),
      _MetricData('Batches', '$activeBatches', Icons.inventory_2_rounded, AppTheme.warning),
      _MetricData('Vendors', '$vendorsServed', Icons.storefront_rounded, AppTheme.accent),
    ];

    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: metrics.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => _MetricChip(data: metrics[i]),
      ),
    );
  }
}

class _MetricData {
  final String label, value;
  final IconData icon;
  final Color color;
  const _MetricData(this.label, this.value, this.icon, this.color);
}

class _MetricChip extends StatelessWidget {
  final _MetricData data;
  const _MetricChip({required this.data});

  @override
  Widget build(BuildContext context) => Container(
        width: 110,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(data.icon, color: data.color, size: 18),
          const Spacer(),
          Text(
            data.value,
            style: TextStyle(
              color: data.color,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            data.label,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ]),
      );
}

// ── Banner ────────────────────────────────────────────────────────────────────
class _BannerCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            color: AppTheme.accentLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
          ),
          // Replace with:
          // Image.asset('assets/images/hero_banner.jpg', fit: BoxFit.cover)
          child: const Row(children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'FreshRoute',
                      style: TextStyle(
                        color: AppTheme.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Helping you ship love one shipment at a time',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(18),
              child: Icon(Icons.agriculture_rounded, color: AppTheme.accent, size: 48),
            ),
          ]),
        ),
      );
}

// ── Local news feed ───────────────────────────────────────────────────────────
class _LocalNewsFeed extends StatelessWidget {
  final List<Map<String, dynamic>> news;
  final bool loading;
  const _LocalNewsFeed({required this.news, required this.loading});

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.divider),
        ),
        child: const Row(children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
          ),
          SizedBox(width: 12),
          Text(
            'Loading local news…',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ]),
      );
    }
    if (news.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.divider),
        ),
        child: const Text(
          'No local news available. Pull to refresh.',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
        ),
      );
    }
    return Column(
      children: news.take(4).map((n) => _NewsCard(item: n)).toList(),
    );
  }
}

class _NewsCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _NewsCard({required this.item});

  Color _categoryColor(String? cat) {
    switch (cat?.toLowerCase()) {
      case 'road':
      case 'logistics':
        return AppTheme.warning;
      case 'alert':
      case 'shutdown':
        return AppTheme.danger;
      case 'weather':
        return AppTheme.info;
      default:
        return AppTheme.accent;
    }
  }

  IconData _categoryIcon(String? cat) {
    switch (cat?.toLowerCase()) {
      case 'road':
      case 'logistics':
        return Icons.traffic_rounded;
      case 'alert':
      case 'shutdown':
        return Icons.warning_amber_rounded;
      case 'weather':
        return Icons.cloud_rounded;
      default:
        return Icons.store_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cat = item['category'] as String?;
    final color = _categoryColor(cat);
    final isUrgent =
        cat?.toLowerCase() == 'alert' || cat?.toLowerCase() == 'shutdown';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isUrgent ? AppTheme.danger.withOpacity(0.4) : AppTheme.divider,
        ),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(_categoryIcon(cat), color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  (cat ?? 'News').toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                item['time'] ?? '',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
              ),
            ]),
            const SizedBox(height: 5),
            Text(
              item['title'] ?? '',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (item['summary'] != null &&
                (item['summary'] as String).isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                item['summary'],
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}

// ── AI Insights card ──────────────────────────────────────────────────────────
class _AiInsightsCard extends StatelessWidget {
  final List<String> insights;
  final bool loading;
  const _AiInsightsCard({required this.insights, required this.loading});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.accentLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: AppTheme.accent,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'AI Insights',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ]),
          const SizedBox(height: 14),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: AppTheme.accent,
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  'Generating insights for your location…',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ]),
            )
          else if (insights.isEmpty)
            const Text(
              'Tap refresh to load AI insights for your area.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
            )
          else
            ...insights.map((text) => _InsightRow(text: text)),
        ]),
      );
}

class _InsightRow extends StatelessWidget {
  final String text;
  const _InsightRow({required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            margin: const EdgeInsets.only(top: 5, right: 8),
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: AppTheme.accent,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ]),
      );
}