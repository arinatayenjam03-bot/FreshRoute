// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';
import 'dashboard_screen.dart';
import 'batch_screen.dart';
import 'marketplace_screen.dart';
import 'route_planner_screen.dart';
import 'profit_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => HomeScreenState();

  static HomeScreenState? of(BuildContext context) =>
      context.findAncestorStateOfType<HomeScreenState>();
}

class HomeScreenState extends State<HomeScreen> {
  int _idx = 0;
  bool _navVisible = true;
  double _lastOffset = 0;

  void switchTab(int idx) => setState(() => _idx = idx);

  void handleScroll(double offset) {
    if ((offset - _lastOffset).abs() < 10) return;
    final goingDown = offset > _lastOffset;
    if (goingDown && _navVisible) setState(() => _navVisible = false);
    if (!goingDown && !_navVisible) setState(() => _navVisible = true);
    _lastOffset = offset;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<AppProvider>();
      p.initGps();
      p.loadSensor();
      p.loadVendors();
      p.loadRegionNews();
      p.loadAiInsights();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      const DashboardScreen(),
      const BatchScreen(),
      const MarketplaceScreen(),
      const RoutePlannerScreen(),
      const ProfitScreen(),
    ];

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: IndexedStack(index: _idx, children: screens),
      bottomNavigationBar: AnimatedSlide(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        offset: _navVisible ? Offset.zero : const Offset(0, 1),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: _navVisible ? 1 : 0,
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              border: const Border(
                top: BorderSide(color: AppTheme.divider, width: 0.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 60,
                child: Row(
                  children: [
                    _NavItem(icon: Icons.home_rounded, label: 'Home', idx: 0, current: _idx, onTap: switchTab),
                    _NavItem(icon: Icons.inventory_2_rounded, label: 'Batches', idx: 1, current: _idx, onTap: switchTab),
                    _NavItem(icon: Icons.storefront_rounded, label: 'Market', idx: 2, current: _idx, onTap: switchTab),
                    _NavItem(icon: Icons.route_rounded, label: 'Routes', idx: 3, current: _idx, onTap: switchTab),
                    _NavItem(icon: Icons.bar_chart_rounded, label: 'Profit', idx: 4, current: _idx, onTap: switchTab),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int idx, current;
  final void Function(int) onTap;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.idx,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = idx == current;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(idx),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected ? AppTheme.accent : AppTheme.navUnselected,
              size: selected ? 26 : 23,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppTheme.accent : AppTheme.navUnselected,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
            const SizedBox(height: 3),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: selected ? AppTheme.accent : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}