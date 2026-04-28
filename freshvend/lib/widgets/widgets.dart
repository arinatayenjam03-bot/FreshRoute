// lib/widgets/stat_card.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StatCard extends StatelessWidget {
  final String label, value, trend;
  final bool positive;
  const StatCard({super.key, required this.label, required this.value, required this.trend, this.positive = true});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppTheme.cardBorder),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
      const SizedBox(height: 6),
      Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
      if (trend.isNotEmpty) ...[
        const SizedBox(height: 2),
        Text(trend, style: TextStyle(color: positive ? AppTheme.success : AppTheme.danger, fontSize: 11)),
      ],
    ]),
  );
}

// lib/widgets/section_header.dart
class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionHeader({super.key, required this.title, this.action, this.onAction});

  @override
  Widget build(BuildContext context) => Row(children: [
    Text(title, style: const TextStyle(
      color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
    const Spacer(),
    if (action != null)
      TextButton(onPressed: onAction, child: Text(action!,
        style: const TextStyle(color: AppTheme.gold, fontSize: 12))),
  ]);
}

// lib/widgets/alert_banner.dart
class AlertBanner extends StatefulWidget {
  final String title, message;
  final Color color;
  const AlertBanner({super.key, required this.title, required this.message, required this.color});
  @override
  State<AlertBanner> createState() => _AlertBannerState();
}

class _AlertBannerState extends State<AlertBanner> {
  bool _dismissed = false;
  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.color.withOpacity(0.3)),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.title, style: TextStyle(color: widget.color, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(widget.message, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        ])),
        IconButton(
          icon: Icon(Icons.close, size: 16, color: widget.color),
          onPressed: () => setState(() => _dismissed = true),
        ),
      ]),
    );
  }
}