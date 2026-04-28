import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';
import 'home_screen.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final Map<String, double> _customQty = {};

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final totalSelected = p.selectedVendorIds.length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Marketplace'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.divider),
        ),
      ),
      body: p.vendors.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.accent))
          : Column(
              children: [
                if (p.batches.isNotEmpty)
                  _StockStrip(batches: p.batches),

                Expanded(
                  child: ListView(
                    padding:
                        const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    children: [
                      Text(
                        '${p.vendors.length} vendors near you',
                        style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13),
                      ),
                      const SizedBox(height: 14),

                      ...p.vendors.map((v) {
                        final vid = v['id'].toString();
                        final selected =
                            p.selectedVendorIds.contains(vid);

                        final demand =
                            (v['demand_kg'] as num?)?.toDouble() ?? 0;

                        // ensure safe value
                        final safeDemand =
                            demand <= 0 ? 0.0 : demand;

                        final myQty =
                            _customQty[vid] ?? safeDemand;

                        return _VendorCard(
                          vendor: v,
                          selected: selected,
                          customQty: myQty,
                          maxQty: safeDemand,
                          onToggle: safeDemand <= 0
                              ? null
                              : () {
                                  setState(() {
                                    if (selected) {
                                      p.selectedVendorIds.remove(vid);
                                    } else {
                                      p.selectedVendorIds.add(vid);
                                      _customQty[vid] =
                                          safeDemand;
                                    }
                                  });
                                },
                          onQtyChanged: (val) => setState(
                              () => _customQty[vid] = val),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),

      bottomSheet: totalSelected > 0
          ? Container(
              padding:
                  const EdgeInsets.fromLTRB(16, 12, 16, 28),
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                border:
                    Border(top: BorderSide(color: AppTheme.divider)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$totalSelected vendor${totalSelected > 1 ? 's' : ''} selected',
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Total demand: ${_totalDemand(p)}kg',
                              style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        HomeScreen.of(context)?.switchTab(3);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        padding: const EdgeInsets.symmetric(
                            vertical: 16),
                      ),
                      child: const Text(
                        'Plan Route  →',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  String _totalDemand(AppProvider p) {
    double total = 0;

    for (final v in p.vendors) {
      final id = v['id'].toString();
      if (p.selectedVendorIds.contains(id)) {
        total += _customQty[id] ??
            (v['demand_kg'] as num?)?.toDouble() ??
            0;
      }
    }

    return total.toStringAsFixed(0);
  }
}

class _StockStrip extends StatelessWidget {
  final List<Map<String, dynamic>> batches;

  const _StockStrip({required this.batches});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surface,
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Stock',
            style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: batches.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final b = batches[i];
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.accentLight,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppTheme.accent.withOpacity(0.3)),
                  ),
                  child: Text(
                    '${b['produce_type']} · ${b['qty']}kg',
                    style: const TextStyle(
                        color: AppTheme.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _VendorCard extends StatelessWidget {
  final Map<String, dynamic> vendor;
  final bool selected;
  final double customQty, maxQty;
  final VoidCallback? onToggle;
  final ValueChanged<double> onQtyChanged;

  const _VendorCard({
    required this.vendor,
    required this.selected,
    required this.customQty,
    required this.maxQty,
    required this.onToggle,
    required this.onQtyChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasDemand = maxQty > 0;

    final safeMax = hasDemand ? maxQty.toDouble() : 1.0;
    final safeValue = hasDemand
    ? customQty.clamp(1, safeMax).toDouble()
    : 1.0;
    final pct = hasDemand
        ? (safeValue / safeMax * 100).round()
        : 0;

    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppTheme.accent
                : AppTheme.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppTheme.accentLight
                          : AppTheme.surfaceGrey,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        _emoji(vendor['name']),
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          vendor['name'] ?? '',
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '📍 ${vendor['area']}',
                          style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _Tag(
                                hasDemand
                                    ? 'Wants ${maxQty.round()} kg'
                                    : 'No demand',
                                hasDemand
                                    ? AppTheme.warning
                                    : AppTheme.textMuted),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (onToggle != null)
                    AnimatedContainer(
                      duration:
                          const Duration(milliseconds: 150),
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppTheme.accent
                            : Colors.transparent,
                        borderRadius:
                            BorderRadius.circular(8),
                        border: Border.all(
                          color: selected
                              ? AppTheme.accent
                              : AppTheme.textMuted
                                  .withOpacity(0.5),
                          width: 1.5,
                        ),
                      ),
                      child: selected
                          ? const Icon(Icons.check,
                              size: 16,
                              color: Colors.white)
                          : null,
                    ),
                ],
              ),
            ),

            if (selected && hasDemand) ...[
              Container(height: 1, color: AppTheme.divider),
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Text('Fulfil quantity',
                            style: TextStyle(
                                color:
                                    AppTheme.textSecondary,
                                fontSize: 12)),
                        const Spacer(),
                        Text(
                          '${safeValue.round()} kg ($pct%)',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    Slider(
                      value: safeValue,
                      min: 1,
                      max: safeMax,
                      onChanged: onQtyChanged,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _emoji(String? name) {
    if (name == null) return '🏪';
    final n = name.toLowerCase();
    if (n.contains('restaurant')) return '🍽️';
    if (n.contains('cooperative')) return '🤝';
    return '🏪';
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;

  const _Tag(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w500),
      ),
    );
  }
}