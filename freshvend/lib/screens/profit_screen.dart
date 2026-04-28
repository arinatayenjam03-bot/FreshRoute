// lib/screens/profit_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

class ProfitScreen extends StatefulWidget {
  const ProfitScreen({super.key});
  @override
  State<ProfitScreen> createState() => _ProfitScreenState();
}

class _ProfitScreenState extends State<ProfitScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  Map<String, dynamic>? _calc;
  String? _aiInsight;
  bool _loading = false;
  String _period = 'Today';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _analyse(AppProvider p) async {
    setState(() { _loading = true; _aiInsight = null; });

    final revenue = p.completedOrders.fold(0.0, (s, o) => s + ((o['revenue'] ?? 0.0) as num).toDouble());
    final km = p.totalKmToday;
    final petrol = (km / AppConstants.avgFuelEfficiency) * AppConstants.avgPetrolPriceIndia;
    final profit = revenue - petrol;

    setState(() => _calc = {
      'revenue': revenue,
      'petrol': petrol,
      'profit': profit,
      'km': km,
      'orders': p.completedOrders.length,
    });

    // Qwen via Ollama (same as backend)
    try {
      final r = await http.post(
        Uri.parse('${AppConstants.baseUrl}/profit_insight/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'revenue': revenue,
          'km': km,
          'orders': p.completedOrders.length,
          'period': _period,
        }),
      ).timeout(const Duration(seconds: 60));
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        setState(() => _aiInsight = data['insight'] ?? 'No insight available.');
      } else {
        setState(() => _aiInsight = 'Could not load AI insight. Check backend.');
      }
    } catch (e) {
      setState(() => _aiInsight = 'Backend unreachable. Check your connection.');
    }

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Earnings'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppTheme.textPrimary,
          unselectedLabelColor: AppTheme.textMuted,
          indicatorColor: AppTheme.accent,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [Tab(text: 'Overview'), Tab(text: 'Trips')],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _OverviewTab(
            calc: _calc,
            aiInsight: _aiInsight,
            loading: _loading,
            period: _period,
            onPeriodChange: (v) => setState(() => _period = v),
            onAnalyse: () => _analyse(p),
            completedOrders: p.completedOrders,
          ),
          _TripsTab(orders: p.completedOrders),
        ],
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final Map<String, dynamic>? calc;
  final String? aiInsight;
  final bool loading;
  final String period;
  final ValueChanged<String> onPeriodChange;
  final VoidCallback onAnalyse;
  final List<Map<String, dynamic>> completedOrders;

  const _OverviewTab({this.calc, this.aiInsight, required this.loading,
    required this.period, required this.onPeriodChange,
    required this.onAnalyse, required this.completedOrders});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Period selector
        Row(children: ['Today', 'This Week', 'This Month'].map((p) =>
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onPeriodChange(p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: period == p ? AppTheme.primary : AppTheme.surfaceGrey,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(p, style: TextStyle(
                  color: period == p ? Colors.white : AppTheme.textSecondary,
                  fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
          )).toList()),
        const SizedBox(height: 20),

        // Big earnings number (Uber style)
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Your earnings this period',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, letterSpacing: 0.2)),
            const SizedBox(height: 8),
            Text(
              calc != null ? '₹${(calc!['profit'] as double).toStringAsFixed(2)}' : '₹ —',
              style: TextStyle(
                color: calc != null && (calc!['profit'] as double) >= 0 ? AppTheme.textPrimary : AppTheme.danger,
                fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -1.5),
            ),
            if (calc != null) ...[
              const SizedBox(height: 4),
              Text(
                (calc!['profit'] as double) >= 0 ? '↑ Profitable' : '↓ Loss today',
                style: TextStyle(
                  color: (calc!['profit'] as double) >= 0 ? AppTheme.success : AppTheme.danger,
                  fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 12),

        // Breakdown - Uber earnings style
        if (calc != null) ...[
          Container(
            decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.divider)),
            child: Column(children: [
              const Padding(padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Align(alignment: Alignment.centerLeft,
                  child: Text('DETAILS', style: TextStyle(color: AppTheme.textMuted, fontSize: 11,
                    fontWeight: FontWeight.w700, letterSpacing: 1)))),
              _EarningRow(Icons.store_rounded, 'Delivery Revenue',
                '₹${(calc!['revenue'] as double).toStringAsFixed(2)}', AppTheme.textPrimary),
              _EarningRow(Icons.local_gas_station_rounded, 'Fuel Cost',
                '- ₹${(calc!['petrol'] as double).toStringAsFixed(2)}', AppTheme.danger),
              _EarningRow(Icons.route_rounded, 'Distance Covered',
                '${(calc!['km'] as double).toStringAsFixed(1)} km', AppTheme.textSecondary),
              _EarningRow(Icons.receipt_long_rounded, 'Orders Completed',
                '${calc!['orders']}', AppTheme.textSecondary),
              Container(height: 1, color: AppTheme.divider, margin: const EdgeInsets.symmetric(horizontal: 16)),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Row(children: [
                  const Text('Net Profit', style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text('₹${(calc!['profit'] as double).toStringAsFixed(2)}',
                    style: TextStyle(
                      color: (calc!['profit'] as double) >= 0 ? AppTheme.success : AppTheme.danger,
                      fontSize: 15, fontWeight: FontWeight.w800)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 20),
        ],

        // Analyse button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: loading ? null : onAnalyse,
            icon: loading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.auto_awesome_rounded, size: 18),
            label: Text(loading ? 'Analysing…' : 'Get AI Insight'),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
          ),
        ),
        const SizedBox(height: 16),

        // AI Insight
        if (aiInsight != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 32, height: 32, decoration: BoxDecoration(
                  color: AppTheme.accentLight, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.auto_awesome_rounded, color: AppTheme.accent, size: 16)),
                const SizedBox(width: 10),
                const Text('AI Cost-Benefit Analysis', style: TextStyle(color: AppTheme.textPrimary,
                  fontSize: 14, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 12),
              Text(aiInsight!, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.7)),
            ]),
          ),
          const SizedBox(height: 20),
        ],

        if (calc == null && !loading)
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.divider)),
            child: const Column(children: [
              Text('📊', style: TextStyle(fontSize: 40)),
              SizedBox(height: 12),
              Text('No earnings yet', style: TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
              SizedBox(height: 6),
              Text('Complete deliveries via Routes tab, then tap Get AI Insight.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5), textAlign: TextAlign.center),
            ]),
          ),

        const SizedBox(height: 80),
      ],
    );
  }
}

class _EarningRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color valueColor;
  const _EarningRow(this.icon, this.label, this.value, this.valueColor);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
    child: Row(children: [
      Icon(icon, size: 16, color: AppTheme.textMuted),
      const SizedBox(width: 12),
      Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
      const Spacer(),
      Text(value, style: TextStyle(color: valueColor, fontSize: 14, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _TripsTab extends StatelessWidget {
  final List<Map<String, dynamic>> orders;
  const _TripsTab({required this.orders});
  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('🚜', style: TextStyle(fontSize: 40)),
        SizedBox(height: 12),
        Text('No trips yet', style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
      ]),
    );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final o = orders[orders.length - 1 - i]; // most recent first
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.divider)),
          child: Row(children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(
              color: AppTheme.surfaceGrey, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.local_shipping_outlined, color: AppTheme.textSecondary)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(o['vendor'] ?? 'Delivery ${orders.length - i}',
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(o['date'] ?? 'Today', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            ])),
            Text('₹${((o['revenue'] ?? 0.0) as num).toStringAsFixed(2)}',
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
          ]),
        );
      },
    );
  }
}