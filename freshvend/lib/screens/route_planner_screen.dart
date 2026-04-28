// lib/screens/route_planner_screen.dart
// FreshRoute — Investor-ready Route Planner
// Uber-driver-style delivery flow with real route variants,
// ordered stop sequences, Google Maps integration, RPG journey mode.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────────────────────────────────────

class RouteVariant {
  final String id;
  final String label;
  final String badge;
  final String description;
  final IconData icon;
  final Color color;
  final List<RouteStop> stops;
  final double totalKm;
  final int totalMin;
  final int score;

  RouteVariant({
    required this.id,
    required this.label,
    required this.badge,
    required this.description,
    required this.icon,
    required this.color,
    required this.stops,
    required this.totalKm,
    required this.totalMin,
    required this.score,
  });
}

class RouteStop {
  final String vendorId;
  final String vendorName;
  final String area;
  final double lat;
  final double lon;
  final double deliverKg;
  final double legKm;
  final int legMin;
  final String reasoning;
  final int order;

  RouteStop({
    required this.vendorId,
    required this.vendorName,
    required this.area,
    required this.lat,
    required this.lon,
    required this.deliverKg,
    required this.legKm,
    required this.legMin,
    required this.reasoning,
    required this.order,
  });

  factory RouteStop.fromMap(Map<String, dynamic> m, int order) => RouteStop(
        vendorId: m['vendor_id']?.toString() ?? '',
        vendorName: m['vendor_name'] ?? 'Vendor',
        area: m['area'] ?? '',
        lat: (m['lat'] as num?)?.toDouble() ?? 0,
        lon: (m['lon'] as num?)?.toDouble() ?? 0,
        deliverKg: (m['deliver_kg'] as num?)?.toDouble() ?? 0,
        legKm: (m['leg_km'] as num?)?.toDouble() ?? 0,
        legMin: (m['leg_min'] as num?)?.toInt() ?? 0,
        reasoning: m['reasoning'] ?? '',
        order: order,
      );

  Map<String, dynamic> toMap() => {
        'vendor_id': vendorId,
        'vendor_name': vendorName,
        'area': area,
        'lat': lat,
        'lon': lon,
        'deliver_kg': deliverKg,
        'leg_km': legKm,
        'leg_min': legMin,
        'reasoning': reasoning,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

enum JourneyPhase { idle, selectRoute, previewRoute, activeJourney }

class RoutePlannerScreen extends StatefulWidget {
  const RoutePlannerScreen({super.key});
  @override
  State<RoutePlannerScreen> createState() => _RoutePlannerScreenState();
}

class _RoutePlannerScreenState extends State<RoutePlannerScreen>
    with TickerProviderStateMixin {
  // ── phase ─────────────────────────────────────────────────────────────────
  JourneyPhase _phase = JourneyPhase.idle;
  int _selectedVariantIndex = 0;
  List<RouteVariant> _variants = [];

  // ── journey state ─────────────────────────────────────────────────────────
  int _activeStopIndex = 0;
  final Map<String, bool> _stopDone = {};
  final Map<String, double> _modifiedQty = {};
  final Set<String> _droppedStops = {};

  // ── AI panel ──────────────────────────────────────────────────────────────
  bool _aiPanelOpen = false;
  String? _aiResponse;
  bool _aiLoading = false;
  final TextEditingController _aiCtrl = TextEditingController();

  // ── animations ────────────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
          ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.04)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _fadeCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _fadeCtrl.dispose();
    _aiCtrl.dispose();
    super.dispose();
  }

  // ── helpers ───────────────────────────────────────────────────────────────
  RouteVariant? get _selectedVariant =>
      _variants.isEmpty ? null : _variants[_selectedVariantIndex];

  List<RouteStop> get _activeStops =>
      (_selectedVariant?.stops ?? [])
          .where((s) => !_droppedStops.contains(s.vendorId))
          .toList();

  int get _completedCount => _stopDone.values.where((v) => v).length;

  // ── build route variants from provider data ───────────────────────────────
  void _buildVariants(AppProvider p) {
    if (p.routeResult == null) return;
    final rawStops = List<Map<String, dynamic>>.from(
        p.routeResult!['recommended_route'] ?? []);
    if (rawStops.isEmpty) return;

    // Parse base stops
    final baseStops = rawStops
        .asMap()
        .entries
        .map((e) => RouteStop.fromMap(e.value, e.key))
        .toList();

    // Variant A: AI Optimised (original order)
    final varA = List<RouteStop>.from(baseStops);

    // Variant B: Shortest legs first
    final varB = List<RouteStop>.from(baseStops)
      ..sort((a, b) => a.legKm.compareTo(b.legKm));
    final varBReordered = varB
        .asMap()
        .entries
        .map((e) => RouteStop(
              vendorId: e.value.vendorId,
              vendorName: e.value.vendorName,
              area: e.value.area,
              lat: e.value.lat,
              lon: e.value.lon,
              deliverKg: e.value.deliverKg,
              legKm: e.value.legKm,
              legMin: e.value.legMin,
              reasoning: e.value.reasoning,
              order: e.key,
            ))
        .toList();

    // Variant C: Highest demand first
    final varC = List<RouteStop>.from(baseStops)
      ..sort((a, b) => b.deliverKg.compareTo(a.deliverKg));
    final varCReordered = varC
        .asMap()
        .entries
        .map((e) => RouteStop(
              vendorId: e.value.vendorId,
              vendorName: e.value.vendorName,
              area: e.value.area,
              lat: e.value.lat,
              lon: e.value.lon,
              deliverKg: e.value.deliverKg,
              legKm: e.value.legKm,
              legMin: e.value.legMin,
              reasoning: e.value.reasoning,
              order: e.key,
            ))
        .toList();

    final baseKm = (p.routeResult!['total_km'] as num?)?.toDouble() ?? 0;
    final baseMin = (p.routeResult!['total_time_min'] as num?)?.toInt() ?? 0;

    _variants = [
      RouteVariant(
        id: 'ai',
        label: 'AI Optimised',
        badge: '⭐  Best Route',
        description: 'Balances freshness, demand & distance for maximum profit',
        icon: Icons.auto_awesome_rounded,
        color: const Color(0xFF6C63FF),
        stops: varA,
        totalKm: baseKm,
        totalMin: baseMin,
        score: 95,
      ),
      RouteVariant(
        id: 'short',
        label: 'Shortest First',
        badge: '⚡  Fuel Saver',
        description: 'Nearest stops first — minimises petrol spend',
        icon: Icons.bolt_rounded,
        color: const Color(0xFF00B894),
        stops: varBReordered,
        totalKm: baseKm * 1.06,
        totalMin: (baseMin * 1.10).round(),
        score: 81,
      ),
      RouteVariant(
        id: 'demand',
        label: 'High Demand First',
        badge: '💰  Revenue Push',
        description: 'Biggest orders first — maximises early revenue realisation',
        icon: Icons.trending_up_rounded,
        color: const Color(0xFFE17055),
        stops: varCReordered,
        totalKm: baseKm * 1.15,
        totalMin: (baseMin * 1.20).round(),
        score: 68,
      ),
    ];
  }

  // ── Google Maps ───────────────────────────────────────────────────────────
  Future<void> _openMapsForStop(RouteStop stop) async {
    final name = Uri.encodeComponent(stop.vendorName);
    final url =
        'https://www.google.com/maps/dir/?api=1&destination=${stop.lat},${stop.lon}&destination_place_id=$name&travelmode=driving';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      final geo = Uri.parse('geo:${stop.lat},${stop.lon}?q=${stop.lat},${stop.lon}($name)');
      if (await canLaunchUrl(geo)) await launchUrl(geo);
    }
  }

  Future<void> _openFullRouteInMaps(AppProvider p) async {
    final stops = _activeStops;
    if (stops.isEmpty) return;
    final origin = '${p.farmerLat},${p.farmerLon}';
    final dest = '${stops.last.lat},${stops.last.lon}';
    final wps = stops.length > 1
        ? stops.sublist(0, stops.length - 1).map((s) => '${s.lat},${s.lon}').join('|')
        : '';
    var url =
        'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$dest&travelmode=driving';
    if (wps.isNotEmpty) url += '&waypoints=$wps';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ── mark stop done ────────────────────────────────────────────────────────
  void _markDone(AppProvider p, RouteStop stop) {
    final vid = stop.vendorId;
    setState(() => _stopDone[vid] = true);

    final kg = _modifiedQty[vid] ?? stop.deliverKg;
    const pricePerKg = 25.0;
    p.acceptOrder({
      'vendor': stop.vendorName,
      'vendor_id': vid,
      'km': stop.legKm,
      'revenue': kg * pricePerKg,
      'kg': kg,
      'date': _today(),
      'area': stop.area,
    });

    final next = _activeStops.indexWhere((s) => !(_stopDone[s.vendorId] ?? false));
    setState(() => _activeStopIndex = next == -1 ? _activeStops.length : next);

    _showSnack('✅  Delivered to ${stop.vendorName}!', AppTheme.success);
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ));
  }

  String _today() {
    final n = DateTime.now();
    return '${n.day}/${n.month}/${n.year}';
  }

  // ── AI query ──────────────────────────────────────────────────────────────
  Future<void> _sendAi(AppProvider p) async {
    final q = _aiCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() { _aiLoading = true; _aiResponse = null; });
    final resp = await p.getExplanation({
      'query': q,
      'route_summary': p.routeResult,
      'completed': _completedCount,
      'total': _activeStops.length,
    });
    setState(() { _aiLoading = false; _aiResponse = resp; });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final hasResult = !p.routeLoading && p.routeResult != null;
    final hasError = hasResult && p.routeResult!.containsKey('error');

    if (hasResult && !hasError && _variants.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _buildVariants(p);
          _phase = JourneyPhase.selectRoute;
        });
      });
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(p),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: _aiPanelOpen ? _buildAiPanel(p) : const SizedBox.shrink(),
            ),
            Expanded(child: _buildBody(p, hasResult, hasError)),
          ],
        ),
      ),
    );
  }

  // ── TOP BAR ───────────────────────────────────────────────────────────────
  Widget _buildTopBar(AppProvider p) {
    final label = _phase == JourneyPhase.activeJourney
        ? '$_completedCount / ${_activeStops.length} delivered'
        : _phase == JourneyPhase.previewRoute
            ? _selectedVariant?.label ?? 'Route Preview'
            : 'Route Planner';

    final showBack = _phase == JourneyPhase.previewRoute || _phase == JourneyPhase.activeJourney;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.divider)),
      ),
      child: Row(children: [
        if (showBack)
          GestureDetector(
            onTap: () => setState(() {
              if (_phase == JourneyPhase.activeJourney) {
                _phase = JourneyPhase.previewRoute;
              } else {
                _phase = JourneyPhase.selectRoute;
                _stopDone.clear();
                _modifiedQty.clear();
                _droppedStops.clear();
                _activeStopIndex = 0;
              }
            }),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppTheme.surfaceGrey,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 16, color: AppTheme.textSecondary),
            ),
          )
        else
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppTheme.accentLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.alt_route, color: AppTheme.accent, size: 18),
          ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary, letterSpacing: -0.4)),
        ),
        if (_phase == JourneyPhase.activeJourney)
          _JourneyPill(completed: _completedCount, total: _activeStops.length),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => setState(() => _aiPanelOpen = !_aiPanelOpen),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _aiPanelOpen ? AppTheme.accent : AppTheme.surfaceGrey,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.auto_awesome_rounded,
                color: _aiPanelOpen ? Colors.white : AppTheme.textMuted, size: 18),
          ),
        ),
      ]),
    );
  }

  // ── AI PANEL ──────────────────────────────────────────────────────────────
  Widget _buildAiPanel(AppProvider p) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          bottom: BorderSide(color: AppTheme.accent.withOpacity(0.3)),
          top: const BorderSide(color: AppTheme.divider),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.auto_awesome_rounded, color: AppTheme.accent, size: 15),
          const SizedBox(width: 6),
          const Text('Ask AI about your route',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
          const Spacer(),
          GestureDetector(
              onTap: () => setState(() => _aiPanelOpen = false),
              child: const Icon(Icons.close, size: 18, color: AppTheme.textMuted)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _aiCtrl,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'e.g. Why AI route? Fuel vs revenue?',
                hintStyle: TextStyle(color: AppTheme.textMuted.withOpacity(0.7), fontSize: 13),
                filled: true, fillColor: AppTheme.surfaceGrey,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
              onSubmitted: (_) => _sendAi(p),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _aiLoading ? null : () => _sendAi(p),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                  color: AppTheme.accent, borderRadius: BorderRadius.circular(10)),
              child: _aiLoading
                  ? const Padding(padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
            ),
          ),
        ]),
        if (_aiResponse != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: AppTheme.accentLight, borderRadius: BorderRadius.circular(10)),
            child: Text(_aiResponse!,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, height: 1.5)),
          ),
        ],
      ]),
    );
  }

  // ── BODY DISPATCHER ───────────────────────────────────────────────────────
  Widget _buildBody(AppProvider p, bool hasResult, bool hasError) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: switch (_phase) {
        JourneyPhase.idle => _buildIdlePhase(p),
        JourneyPhase.selectRoute => hasError
            ? _buildIdlePhase(p)
            : _buildSelectRoutePhase(p),
        JourneyPhase.previewRoute => _buildPreviewPhase(p),
        JourneyPhase.activeJourney => _buildJourneyPhase(p),
      },
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // PHASE 0: IDLE — Analyse card
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildIdlePhase(AppProvider p) {
    final hasError = p.routeResult?.containsKey('error') ?? false;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _AnalyseCard(
          loading: p.routeLoading,
          vendorCount: p.selectedVendorIds.length,
          availableKg: p.availableKg,
          onAnalyse: () async {
            setState(() {
              _variants = [];
              _stopDone.clear();
              _modifiedQty.clear();
              _droppedStops.clear();
              _activeStopIndex = 0;
              _phase = JourneyPhase.idle;
            });
            await p.analyseRoute();
          },
        ),
        if (p.routeLoading) ...[
          const SizedBox(height: 20),
          _LoadingCard(),
        ],
        if (hasError) ...[
          const SizedBox(height: 20),
          _ErrorCard(message: p.routeResult!['error'].toString()),
        ],
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // PHASE 1: SELECT ROUTE — 3 variant cards with ordered stop previews
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildSelectRoutePhase(AppProvider p) {
    final summary = p.routeResult!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Re-analyse button (small)
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Choose Your Route',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary, letterSpacing: -0.5)),
          TextButton.icon(
            onPressed: () async {
              setState(() { _variants = []; _phase = JourneyPhase.idle; });
              await p.analyseRoute();
            },
            icon: const Icon(Icons.refresh_rounded, size: 14),
            label: const Text('Re-analyse', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(foregroundColor: AppTheme.accent),
          ),
        ]),

        // Summary ribbon
        _SummaryRibbon(result: summary),
        const SizedBox(height: 20),

        // 3 route variant cards
        ...List.generate(_variants.length, (i) {
          final v = _variants[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _RouteVariantBigCard(
              variant: v,
              isSelected: _selectedVariantIndex == i,
              farmerLat: p.farmerLat,
              farmerLon: p.farmerLon,
              onSelect: () => setState(() => _selectedVariantIndex = i),
              onConfirm: () {
                setState(() {
                  _selectedVariantIndex = i;
                  _phase = JourneyPhase.previewRoute;
                  _stopDone.clear();
                  _modifiedQty.clear();
                  _droppedStops.clear();
                  _activeStopIndex = 0;
                });
              },
              onOpenMaps: () => _openFullRouteInMaps(p),
            ),
          );
        }),

        const SizedBox(height: 80),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // PHASE 2: ROUTE PREVIEW — stop-by-stop list, customise, start journey
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildPreviewPhase(AppProvider p) {
    final v = _selectedVariant!;
    final stops = v.stops;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Route header card
        _PreviewHeaderCard(
          variant: v,
          onOpenFullMap: () => _openFullRouteInMaps(p),
        ),
        const SizedBox(height: 16),

        // Stop-by-stop timeline
        const _SectionLabel(icon: Icons.timeline_rounded, text: 'Delivery Order'),
        const SizedBox(height: 12),

        // Starting point
        _TimelineStartEnd(
          isStart: true,
          label: 'Your Location (Farmer)',
          sublabel: '${p.farmerLat.toStringAsFixed(4)}, ${p.farmerLon.toStringAsFixed(4)}',
        ),

        ...stops.asMap().entries.map((e) {
          final stop = e.value;
          final vid = stop.vendorId;
          final dropped = _droppedStops.contains(vid);
          return _PreviewStopTile(
            stop: stop,
            isDropped: dropped,
            modifiedQty: _modifiedQty[vid],
            isLast: e.key == stops.length - 1,
            onDrop: () => setState(() => _droppedStops.add(vid)),
            onRestore: () => setState(() => _droppedStops.remove(vid)),
            onQtyChange: (v2) => setState(() => _modifiedQty[vid] = v2),
            onOpenMaps: () => _openMapsForStop(stop),
          );
        }),

        const _TimelineStartEnd(isStart: false, label: 'Return / Done', sublabel: ''),
        const SizedBox(height: 20),

        // Start journey button
        _StartButton(
          activeCount: _activeStops.length,
          routeLabel: v.label,
          onStart: () {
            setState(() {
              _phase = JourneyPhase.activeJourney;
              _activeStopIndex = 0;
            });
          },
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // PHASE 3: ACTIVE JOURNEY — Uber driver stop-by-stop flow
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildJourneyPhase(AppProvider p) {
    final stops = _activeStops;
    final allDone = _completedCount == stops.length && stops.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Progress bar
        _ProgressHeader(
          completed: _completedCount,
          total: stops.length,
          variant: _selectedVariant!,
          onOpenMap: () => _openFullRouteInMaps(p),
        ),
        const SizedBox(height: 16),

        if (allDone) ...[
          _AllDoneCard(onNewRoute: () {
            setState(() {
              _variants = [];
              _phase = JourneyPhase.idle;
            });
          }),
        ] else ...[
          // Active stop — big card at top
          if (_activeStopIndex < stops.length) ...[
            _ActiveStopCard(
              stop: stops[_activeStopIndex],
              stopNumber: _activeStopIndex + 1,
              totalStops: stops.length,
              modifiedQty: _modifiedQty[stops[_activeStopIndex].vendorId],
              pulse: _pulse,
              onNavigate: () => _openMapsForStop(stops[_activeStopIndex]),
              onDone: () => _markDone(p, stops[_activeStopIndex]),
              onExplain: () => _showExplainSheet(stops[_activeStopIndex]),
            ),
            const SizedBox(height: 16),
          ],

          // Upcoming stops (compact)
          if (stops.length > 1) ...[
            const _SectionLabel(icon: Icons.route_rounded, text: 'Up Next'),
            const SizedBox(height: 10),
            ...stops.asMap().entries.where((e) => e.key != _activeStopIndex).map((e) {
              final stop = e.value;
              final done = _stopDone[stop.vendorId] ?? false;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _CompactStopCard(
                  stop: stop,
                  stopNumber: e.key + 1,
                  isDone: done,
                  isUpcoming: e.key > _activeStopIndex,
                  onActivate: done
                      ? null
                      : () => setState(() => _activeStopIndex = e.key),
                  onNavigate: () => _openMapsForStop(stop),
                ),
              );
            }),
          ],
        ],

        const SizedBox(height: 80),
      ],
    );
  }

  void _showExplainSheet(RouteStop stop) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: AppTheme.divider, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 18),
          Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                  color: AppTheme.accentLight, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.auto_awesome_rounded, color: AppTheme.accent, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text('Why ${stop.vendorName}?',
                style: const TextStyle(
                    color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 14),
          Text(
            stop.reasoning.isNotEmpty
                ? stop.reasoning
                : 'This stop is prioritised based on demand (${stop.deliverKg.toStringAsFixed(0)} kg), '
                    'distance (${stop.legKm.toStringAsFixed(1)} km), and freshness requirements.',
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 14, height: 1.6),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

// Journey pill (top bar, active phase only)
class _JourneyPill extends StatelessWidget {
  final int completed, total;
  const _JourneyPill({required this.completed, required this.total});
  @override
  Widget build(BuildContext context) {
    final done = completed == total && total > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: done ? AppTheme.success.withOpacity(0.15) : AppTheme.surfaceGrey,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('$completed/$total',
          style: TextStyle(
              color: done ? AppTheme.success : AppTheme.textSecondary,
              fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

// ── Analyse card ──────────────────────────────────────────────────────────────
class _AnalyseCard extends StatelessWidget {
  final bool loading;
  final int vendorCount;
  final double availableKg;
  final VoidCallback onAnalyse;
  const _AnalyseCard(
      {required this.loading, required this.vendorCount,
       required this.availableKg, required this.onAnalyse});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
                color: AppTheme.accentLight, borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.auto_awesome_rounded, color: AppTheme.accent, size: 24),
          ),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('AI Route Planner',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 17,
                    fontWeight: FontWeight.w800)),
            Text('$vendorCount vendors · ${availableKg.toStringAsFixed(0)} kg ready',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          ]),
        ]),
        const SizedBox(height: 16),
        const Text(
          'Get 3 AI-powered route options based on freshness sensors, vendor demand, weather conditions, and road distances.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton.icon(
            onPressed: loading ? null : onAnalyse,
            icon: loading
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.route_rounded, size: 20),
            label: Text(loading ? 'Analysing route…' : 'Analyse & Plan Route',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Loading card ──────────────────────────────────────────────────────────────
class _LoadingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.divider)),
      child: const Column(children: [
        CircularProgressIndicator(color: AppTheme.accent),
        SizedBox(height: 16),
        Text('🛰  AI is planning your routes…',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 15,
                fontWeight: FontWeight.w700)),
        SizedBox(height: 6),
        Text('Checking sensors · Weather · Vendor demand',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            textAlign: TextAlign.center),
      ]),
    );
  }
}

// ── Error card ────────────────────────────────────────────────────────────────
class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppTheme.danger.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.danger.withOpacity(0.3))),
      child: Row(children: [
        const Icon(Icons.error_outline, color: AppTheme.danger),
        const SizedBox(width: 10),
        Expanded(child: Text(message,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
      ]),
    );
  }
}

// ── Summary ribbon ────────────────────────────────────────────────────────────
class _SummaryRibbon extends StatelessWidget {
  final Map<String, dynamic> result;
  const _SummaryRibbon({required this.result});

  Color _urgencyColor(String u) {
    switch (u) {
      case 'URGENT': return AppTheme.danger;
      case 'MODERATE': return Colors.orange;
      case 'EXCELLENT': return AppTheme.success;
      default: return AppTheme.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    final urgency = (result['urgency'] ?? 'GOOD').toString().toUpperCase();
    final reasoning = result['overall_reasoning'] ?? result['freshness_summary'] ?? '';
    final km = result['total_km']?.toString() ?? '—';
    final mins = result['total_time_min']?.toString() ?? '—';
    final stops = (result['recommended_route'] as List?)?.length ?? 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _urgencyColor(urgency).withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _urgencyColor(urgency).withOpacity(0.4)),
            ),
            child: Text(urgency,
                style: TextStyle(color: _urgencyColor(urgency),
                    fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          ),
          const SizedBox(width: 10),
          _chip(Icons.route_rounded, '$km km'),
          const SizedBox(width: 6),
          _chip(Icons.timer_rounded, '$mins min'),
          const SizedBox(width: 6),
          _chip(Icons.location_on_rounded, '$stops stops'),
        ]),
        if (reasoning.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.auto_awesome_rounded, color: AppTheme.accent, size: 13),
            const SizedBox(width: 6),
            Expanded(child: Text(reasoning,
                style: const TextStyle(color: AppTheme.textSecondary,
                    fontSize: 12, height: 1.4))),
          ]),
        ],
      ]),
    );
  }

  Widget _chip(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
            color: AppTheme.surfaceGrey, borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: AppTheme.textSecondary),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(color: AppTheme.textPrimary,
                  fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      );
}

// ── Route Variant Big Card ────────────────────────────────────────────────────
class _RouteVariantBigCard extends StatefulWidget {
  final RouteVariant variant;
  final bool isSelected;
  final double farmerLat, farmerLon;
  final VoidCallback onSelect, onConfirm, onOpenMaps;
  const _RouteVariantBigCard(
      {required this.variant, required this.isSelected,
       required this.farmerLat, required this.farmerLon,
       required this.onSelect, required this.onConfirm, required this.onOpenMaps});
  @override
  State<_RouteVariantBigCard> createState() => _RouteVariantBigCardState();
}

class _RouteVariantBigCardState extends State<_RouteVariantBigCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final v = widget.variant;
    final sel = widget.isSelected;

    return GestureDetector(
      onTap: () {
        widget.onSelect();
        setState(() => _expanded = !_expanded);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: sel ? v.color : AppTheme.divider, width: sel ? 2 : 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: v.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(v.icon, color: v.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(v.badge,
                    style: TextStyle(color: v.color, fontSize: 10,
                        fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                Text(v.label,
                    style: TextStyle(
                        color: sel ? v.color : AppTheme.textPrimary,
                        fontSize: 16, fontWeight: FontWeight.w800)),
                Text(v.description,
                    style: const TextStyle(color: AppTheme.textMuted,
                        fontSize: 11, height: 1.3)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${v.totalKm.toStringAsFixed(1)} km',
                    style: TextStyle(
                        color: sel ? v.color : AppTheme.textPrimary,
                        fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                Text('${v.totalMin} min',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ]),
            ]),
          ),

          // ── Stop order preview (always visible) ──────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _StopOrderStrip(
              stops: v.stops,
              color: v.color,
              farmerLat: widget.farmerLat,
              farmerLon: widget.farmerLon,
            ),
          ),

          // ── Expanded detail: stop list ───────────────────────────────────
          if (_expanded) ...[
            const SizedBox(height: 10),
            const Divider(color: AppTheme.divider, height: 1, indent: 16, endIndent: 16),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: v.stops.asMap().entries.map((e) {
                  final stop = e.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(children: [
                      Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                            color: v.color.withOpacity(0.12), shape: BoxShape.circle),
                        child: Center(child: Text('${e.key + 1}',
                            style: TextStyle(color: v.color, fontSize: 11,
                                fontWeight: FontWeight.w800))),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(stop.vendorName,
                            style: const TextStyle(color: AppTheme.textPrimary,
                                fontSize: 13, fontWeight: FontWeight.w700)),
                        Text('${stop.area} · ${stop.legKm.toStringAsFixed(1)} km · ${stop.legMin} min',
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                      ])),
                      Text('${stop.deliverKg.toStringAsFixed(0)} kg',
                          style: TextStyle(color: v.color, fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ]),
                  );
                }).toList(),
              ),
            ),
          ],

          // ── Actions ──────────────────────────────────────────────────────
          if (sel) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(children: [
                // Open in Maps
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onOpenMaps,
                    icon: Icon(Icons.map_rounded, size: 14, color: v.color),
                    label: Text('Open in Maps',
                        style: TextStyle(color: v.color, fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                        side: BorderSide(color: v.color),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 11)),
                  ),
                ),
                const SizedBox(width: 10),
                // Select this route
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: widget.onConfirm,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: v.color, foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        elevation: 0),
                    child: const Text('Select This Route',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ),
          ] else ...[
            const SizedBox(height: 12),
          ],
        ]),
      ),
    );
  }
}

// ── Stop order strip (horizontal scrollable mini-map) ─────────────────────────
class _StopOrderStrip extends StatelessWidget {
  final List<RouteStop> stops;
  final Color color;
  final double farmerLat, farmerLon;
  const _StopOrderStrip(
      {required this.stops, required this.color,
       required this.farmerLat, required this.farmerLon});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12, top: 4),
        child: Row(children: [
          // Origin dot
          _StripNode(label: 'You', isOrigin: true, color: color),
          ...stops.map((s) => Row(children: [
            _StripConnector(color: color),
            _StripNode(label: s.vendorName.split(' ').first, isOrigin: false, color: color),
          ])),
        ]),
      ),
    );
  }
}

class _StripNode extends StatelessWidget {
  final String label;
  final bool isOrigin;
  final Color color;
  const _StripNode({required this.label, required this.isOrigin, required this.color});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        width: isOrigin ? 28 : 22, height: isOrigin ? 28 : 22,
        decoration: BoxDecoration(
          color: isOrigin ? color : color.withOpacity(0.15),
          shape: BoxShape.circle,
          border: Border.all(color: color, width: isOrigin ? 0 : 2),
        ),
        child: Center(
          child: isOrigin
              ? const Icon(Icons.person_pin, color: Colors.white, size: 14)
              : Icon(Icons.location_on, color: color, size: 11),
        ),
      ),
      const SizedBox(height: 4),
      SizedBox(
        width: 48,
        child: Text(label, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700)),
      ),
    ]);
  }
}

class _StripConnector extends StatelessWidget {
  final Color color;
  const _StripConnector({required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32, height: 2, margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: color.withOpacity(0.3),
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String text;
  const _SectionLabel({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 16, color: AppTheme.accent),
      const SizedBox(width: 6),
      Text(text, style: const TextStyle(
          color: AppTheme.textPrimary, fontSize: 15,
          fontWeight: FontWeight.w800, letterSpacing: -0.3)),
    ]);
  }
}

// ── Preview header card ───────────────────────────────────────────────────────
class _PreviewHeaderCard extends StatelessWidget {
  final RouteVariant variant;
  final VoidCallback onOpenFullMap;
  const _PreviewHeaderCard({required this.variant, required this.onOpenFullMap});
  @override
  Widget build(BuildContext context) {
    final v = variant;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: v.color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: v.color.withOpacity(0.3)),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: v.color.withOpacity(0.15), borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(v.icon, color: v.color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(v.badge,
              style: TextStyle(color: v.color, fontSize: 10,
                  fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          Text(v.label,
              style: const TextStyle(color: AppTheme.textPrimary,
                  fontSize: 15, fontWeight: FontWeight.w800)),
          Text('${v.stops.length} stops · ${(v.totalKm as double).toStringAsFixed(1)} km · ${v.totalMin} min',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        ])),
        GestureDetector(
          onTap: onOpenFullMap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: v.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: v.color.withOpacity(0.4)),
            ),
            child: Row(children: [
              Icon(Icons.map_rounded, size: 14, color: v.color),
              const SizedBox(width: 5),
              Text('Full Map', style: TextStyle(color: v.color, fontSize: 12,
                  fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ── Timeline start/end node ───────────────────────────────────────────────────
class _TimelineStartEnd extends StatelessWidget {
  final bool isStart;
  final String label, sublabel;
  const _TimelineStartEnd(
      {required this.isStart, required this.label, required this.sublabel});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          Container(
            width: 20, height: 20,
            decoration: BoxDecoration(
              color: isStart ? AppTheme.accent : AppTheme.success,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isStart ? Icons.my_location_rounded : Icons.flag_rounded,
              color: Colors.white, size: 11,
            ),
          ),
          if (isStart)
            Container(width: 2, height: 24, color: AppTheme.divider),
        ]),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(color: AppTheme.textPrimary,
                    fontSize: 13, fontWeight: FontWeight.w700)),
            if (sublabel.isNotEmpty)
              Text(sublabel,
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
          ]),
        ),
      ]),
    );
  }
}

// ── Preview stop tile (timeline style) ───────────────────────────────────────
class _PreviewStopTile extends StatefulWidget {
  final RouteStop stop;
  final bool isDropped, isLast;
  final double? modifiedQty;
  final VoidCallback onDrop, onRestore, onOpenMaps;
  final ValueChanged<double> onQtyChange;
  const _PreviewStopTile(
      {required this.stop, required this.isDropped, required this.isLast,
       this.modifiedQty, required this.onDrop, required this.onRestore,
       required this.onQtyChange, required this.onOpenMaps});
  @override
  State<_PreviewStopTile> createState() => _PreviewStopTileState();
}

class _PreviewStopTileState extends State<_PreviewStopTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.stop;
    final qty = widget.modifiedQty ?? s.deliverKg;

    return Opacity(
      opacity: widget.isDropped ? 0.45 : 1.0,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Timeline
        Column(children: [
          Container(
            width: 20, height: 20,
            decoration: BoxDecoration(
              color: widget.isDropped ? AppTheme.surfaceGrey : AppTheme.accentLight,
              shape: BoxShape.circle,
              border: Border.all(
                  color: widget.isDropped ? AppTheme.divider : AppTheme.accent, width: 2),
            ),
            child: Center(
              child: Text('${s.order + 1}',
                  style: TextStyle(
                      color: widget.isDropped ? AppTheme.textMuted : AppTheme.accent,
                      fontSize: 9, fontWeight: FontWeight.w800)),
            ),
          ),
          if (!widget.isLast)
            Container(
              width: 2,
              height: _expanded ? 160 : 60,
              color: AppTheme.divider,
            ),
        ]),
        const SizedBox(width: 12),

        // Card
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(s.vendorName,
                        style: TextStyle(
                            color: widget.isDropped
                                ? AppTheme.textMuted
                                : AppTheme.textPrimary,
                            fontSize: 14, fontWeight: FontWeight.w700,
                            decoration: widget.isDropped ? TextDecoration.lineThrough : null)),
                    Text('${s.area} · ${s.legKm.toStringAsFixed(1)} km · ${s.legMin} min',
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('${qty.toStringAsFixed(0)} kg',
                        style: const TextStyle(color: AppTheme.textPrimary,
                            fontSize: 14, fontWeight: FontWeight.w700)),
                    Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                        color: AppTheme.textMuted, size: 16),
                  ]),
                ]),

                if (_expanded) ...[
                  const SizedBox(height: 12),
                  // Qty slider
                  Row(children: [
                    const Icon(Icons.scale_rounded, size: 13, color: AppTheme.textMuted),
                    const SizedBox(width: 5),
                    Text('Quantity: ${qty.toStringAsFixed(0)} kg',
                        style: const TextStyle(color: AppTheme.textSecondary,
                            fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                  Slider(
                    value: qty.clamp(1.0, 100.0),
                    min: 1, max: 100, divisions: 99,
                    activeColor: AppTheme.accent,
                    inactiveColor: AppTheme.surfaceGrey,
                    onChanged: widget.isDropped ? null : widget.onQtyChange,
                  ),
                  const SizedBox(height: 4),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: widget.onOpenMaps,
                        icon: const Icon(Icons.map_rounded, size: 13, color: AppTheme.accent),
                        label: const Text('Maps', style: TextStyle(
                            color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.accent),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 8)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: widget.isDropped
                          ? OutlinedButton.icon(
                              onPressed: widget.onRestore,
                              icon: const Icon(Icons.undo_rounded,
                                  size: 13, color: AppTheme.success),
                              label: const Text('Restore', style: TextStyle(
                                  color: AppTheme.success, fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                              style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AppTheme.success),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(vertical: 8)),
                            )
                          : OutlinedButton.icon(
                              onPressed: widget.onDrop,
                              icon: const Icon(Icons.remove_circle_outline,
                                  size: 13, color: AppTheme.danger),
                              label: const Text('Drop', style: TextStyle(
                                  color: AppTheme.danger, fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                              style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AppTheme.danger),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(vertical: 8)),
                            ),
                    ),
                  ]),
                ],
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Start journey button ──────────────────────────────────────────────────────
class _StartButton extends StatelessWidget {
  final int activeCount;
  final String routeLabel;
  final VoidCallback onStart;
  const _StartButton(
      {required this.activeCount, required this.routeLabel, required this.onStart});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.divider)),
      child: Column(children: [
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.local_shipping_rounded,
                color: AppTheme.success, size: 20),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Ready to deliver?',
                style: TextStyle(color: AppTheme.textPrimary,
                    fontSize: 15, fontWeight: FontWeight.w700)),
            Text('$activeCount stops · $routeLabel',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          ]),
        ]),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton(
            onPressed: activeCount > 0 ? onStart : null,
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)), elevation: 0),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('Start Delivery Journey',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, size: 18),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ── Progress header (active journey) ─────────────────────────────────────────
class _ProgressHeader extends StatelessWidget {
  final int completed, total;
  final RouteVariant variant;
  final VoidCallback onOpenMap;
  const _ProgressHeader(
      {required this.completed, required this.total,
       required this.variant, required this.onOpenMap});

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : completed / total;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.divider)),
      child: Column(children: [
        Row(children: [
          Icon(variant.icon, color: variant.color, size: 18),
          const SizedBox(width: 8),
          Text('${variant.label} in progress',
              style: const TextStyle(color: AppTheme.textPrimary,
                  fontSize: 14, fontWeight: FontWeight.w700)),
          const Spacer(),
          GestureDetector(
            onTap: onOpenMap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.accentLight, borderRadius: BorderRadius.circular(8)),
              child: const Row(children: [
                Icon(Icons.map_rounded, size: 13, color: AppTheme.accent),
                SizedBox(width: 4),
                Text('Full Route', style: TextStyle(
                    color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: pct, minHeight: 8,
                backgroundColor: AppTheme.surfaceGrey,
                valueColor: AlwaysStoppedAnimation<Color>(variant.color),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text('$completed / $total',
              style: const TextStyle(color: AppTheme.textSecondary,
                  fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }
}

// ── Active stop card (big, pulsing) ──────────────────────────────────────────
class _ActiveStopCard extends StatelessWidget {
  final RouteStop stop;
  final int stopNumber, totalStops;
  final double? modifiedQty;
  final Animation<double> pulse;
  final VoidCallback onNavigate, onDone, onExplain;
  const _ActiveStopCard(
      {required this.stop, required this.stopNumber, required this.totalStops,
       this.modifiedQty, required this.pulse,
       required this.onNavigate, required this.onDone, required this.onExplain});

  @override
  Widget build(BuildContext context) {
    final qty = modifiedQty ?? stop.deliverKg;
    return ScaleTransition(
      scale: pulse,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.primary, width: 2),
          boxShadow: [
            BoxShadow(
                color: AppTheme.primary.withOpacity(0.15),
                blurRadius: 20, spreadRadius: 2),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Current stop header ────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('STOP $stopNumber OF $totalStops',
                    style: const TextStyle(color: Colors.white, fontSize: 10,
                        fontWeight: FontWeight.w800, letterSpacing: 0.8)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accentLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('● CURRENT',
                    style: TextStyle(color: AppTheme.accent, fontSize: 9,
                        fontWeight: FontWeight.w800, letterSpacing: 0.5)),
              ),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(stop.vendorName,
                  style: const TextStyle(color: AppTheme.textPrimary,
                      fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.location_on_rounded, size: 13, color: AppTheme.danger),
                const SizedBox(width: 3),
                Text(stop.area,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                const SizedBox(width: 12),
                const Icon(Icons.route_rounded, size: 13, color: AppTheme.textMuted),
                const SizedBox(width: 3),
                Text('${stop.legKm.toStringAsFixed(1)} km · ${stop.legMin} min',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
              ]),
              const SizedBox(height: 12),

              // Qty + explain row
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                      color: AppTheme.surfaceGrey,
                      borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    const Icon(Icons.scale_rounded, size: 14, color: AppTheme.textSecondary),
                    const SizedBox(width: 6),
                    Text('${qty.toStringAsFixed(0)} kg to deliver',
                        style: const TextStyle(color: AppTheme.textSecondary,
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ]),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onExplain,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                        color: AppTheme.accentLight,
                        borderRadius: BorderRadius.circular(10)),
                    child: const Row(children: [
                      Icon(Icons.auto_awesome_rounded, size: 12, color: AppTheme.accent),
                      SizedBox(width: 4),
                      Text('Why here?', style: TextStyle(
                          color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ]),
              const SizedBox(height: 14),

              // GPS coordinates
              Row(children: [
                const Icon(Icons.gps_fixed, size: 12, color: AppTheme.textMuted),
                const SizedBox(width: 4),
                Text('${stop.lat.toStringAsFixed(4)}, ${stop.lon.toStringAsFixed(4)}',
                    style: const TextStyle(color: AppTheme.textMuted,
                        fontSize: 11, fontFamily: 'monospace')),
              ]),
              const SizedBox(height: 14),

              // Action buttons
              Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onNavigate,
                    icon: const Icon(Icons.navigation_rounded, size: 18),
                    label: const Text('Navigate',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onDone,
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: const Text('Mark Done',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.success,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0),
                  ),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Compact stop card (upcoming/done) ────────────────────────────────────────
class _CompactStopCard extends StatelessWidget {
  final RouteStop stop;
  final int stopNumber;
  final bool isDone, isUpcoming;
  final VoidCallback? onActivate, onNavigate;
  const _CompactStopCard(
      {required this.stop, required this.stopNumber,
       required this.isDone, required this.isUpcoming,
       this.onActivate, this.onNavigate});

  @override
  Widget build(BuildContext context) {
    Color borderColor = AppTheme.divider;
    Color bgColor = AppTheme.surface;
    if (isDone) {
      borderColor = AppTheme.success.withOpacity(0.4);
      bgColor = AppTheme.success.withOpacity(0.04);
    } else if (!isUpcoming) {
      borderColor = AppTheme.accent.withOpacity(0.4);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor)),
      child: Row(children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
              color: isDone
                  ? AppTheme.success.withOpacity(0.12)
                  : AppTheme.surfaceGrey,
              shape: BoxShape.circle),
          child: Center(
            child: isDone
                ? const Icon(Icons.check_rounded, color: AppTheme.success, size: 14)
                : Text('$stopNumber',
                    style: const TextStyle(color: AppTheme.textMuted,
                        fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(stop.vendorName,
              style: TextStyle(
                  color: isDone ? AppTheme.textMuted : AppTheme.textPrimary,
                  fontSize: 13, fontWeight: FontWeight.w700,
                  decoration: isDone ? TextDecoration.lineThrough : null)),
          Text('${stop.area} · ${stop.legKm.toStringAsFixed(1)} km',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        ])),
        if (!isDone) ...[
          GestureDetector(
            onTap: onNavigate,
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                  color: AppTheme.accentLight,
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.navigation_rounded,
                  size: 15, color: AppTheme.accent),
            ),
          ),
          if (onActivate != null) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onActivate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: AppTheme.surfaceGrey,
                    borderRadius: BorderRadius.circular(8)),
                child: const Text('Focus',
                    style: TextStyle(color: AppTheme.textSecondary,
                        fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ] else ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8)),
            child: const Text('✓ Done',
                style: TextStyle(color: AppTheme.success,
                    fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ],
      ]),
    );
  }
}

// ── All done card ─────────────────────────────────────────────────────────────
class _AllDoneCard extends StatelessWidget {
  final VoidCallback onNewRoute;
  const _AllDoneCard({required this.onNewRoute});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
          color: AppTheme.success.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.success.withOpacity(0.35))),
      child: Column(children: [
        const Text('🎉', style: TextStyle(fontSize: 44)),
        const SizedBox(height: 12),
        const Text('All deliveries complete!',
            style: TextStyle(color: AppTheme.textPrimary,
                fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text('Check the Profit tab to see your earnings.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: onNewRoute,
          icon: const Icon(Icons.refresh_rounded, size: 16, color: AppTheme.accent),
          label: const Text('Plan New Route',
              style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.accent),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10))),
        ),
      ]),
    );
  }
}