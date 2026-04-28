// lib/screens/batch_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';

class BatchScreen extends StatefulWidget {
  const BatchScreen({super.key});
  @override
  State<BatchScreen> createState() => _BatchScreenState();
}

class _BatchScreenState extends State<BatchScreen> {
  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Batches'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.divider),
        ),
      ),
      body: p.batches.isEmpty ? _EmptyState(onAdd: () => _showAddModal(context, p))
      : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Sensor status strip
          _SensorStatusStrip(sensor: p.sensorData, onRefresh: p.loadSensor),
          const SizedBox(height: 20),
          Row(children: [
            Text('${p.batches.length} Active Batch${p.batches.length != 1 ? 'es' : ''}',
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
            const Spacer(),
          ]),
          const SizedBox(height: 12),
          ...p.batches.asMap().entries.map((e) => _BatchCard(
            batch: e.value,
            index: e.key,
            freshness: _freshnessForBatch(p.sensorData, e.value),
          )),
          const SizedBox(height: 100),
        ],
      ),
      floatingActionButton: p.batches.isNotEmpty ? FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        onPressed: () => _showAddModal(context, p),
        icon: const Icon(Icons.add),
        label: const Text('Add Batch', style: TextStyle(fontWeight: FontWeight.w600)),
      ) : null,
    );
  }

  double _freshnessForBatch(Map<String, dynamic> sensor, Map<String, dynamic> batch) {
    if (sensor.isEmpty) return 0;
    final t = (sensor['temperature'] ?? 0).toDouble();
    final h = (sensor['humidity'] ?? 0).toDouble();
    final g = (sensor['mq135_ppm'] ?? 0).toDouble();
    return ((100 - (t - 10).abs() * 5).clamp(0, 100) +
        (100 - (h - 80).abs() * 2).clamp(0, 100) +
        (100 - g * 0.2).clamp(0, 100)) / 3;
  }

  void _showAddModal(BuildContext context, AppProvider p) {
    final nameCtrl    = TextEditingController();
    final qtyCtrl     = TextEditingController();
    final sensorCtrl  = TextEditingController();
    String? produceType;
    String harvestTime = 'Just now';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx, ss) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            left: 20, right: 20, top: 8,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Handle bar
            Center(child: Container(width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: AppTheme.textMuted.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2)))),

            const Text('Add New Batch', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            const SizedBox(height: 4),
            const Text('Add a crate of produce to track freshness and route',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 24),

            // Produce type chips
            const Text('Produce Type', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              'Tomatoes', 'Mangoes', 'Onions', 'Potatoes', 'Vegetables', 'Leafy Greens', 'Fruits'
            ].map((t) => GestureDetector(
              onTap: () => ss(() => produceType = t),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: produceType == t ? AppTheme.primary : AppTheme.surfaceGrey,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: produceType == t ? AppTheme.primary : Colors.transparent),
                ),
                child: Text(t, style: TextStyle(
                  color: produceType == t ? Colors.white : AppTheme.textSecondary,
                  fontSize: 13, fontWeight: FontWeight.w500)),
              ),
            )).toList()),
            const SizedBox(height: 20),

            // Batch name
            TextField(controller: nameCtrl,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
              decoration: const InputDecoration(labelText: 'Batch Name', hintText: 'e.g., Tomatoes – Batch D')),
            const SizedBox(height: 14),

            // Quantity
            TextField(controller: qtyCtrl, keyboardType: TextInputType.number,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
              decoration: const InputDecoration(
                labelText: 'Quantity (kg)',
                hintText: 'e.g., 150',
                prefixIcon: Icon(Icons.scale_outlined, color: AppTheme.textMuted),
              )),
            const SizedBox(height: 14),

            // IoT Sensor ID
            TextField(controller: sensorCtrl,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
              decoration: const InputDecoration(
                labelText: 'IoT Sensor ID (optional)',
                hintText: 'e.g., FR-SENSOR-2847-04',
                prefixIcon: Icon(Icons.sensors_outlined, color: AppTheme.textMuted),
              )),
            const SizedBox(height: 20),

            // Harvest time chips
            const Text('Harvested', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: ['Just now', '2 hours ago', '6 hours ago', 'Yesterday'].map((t) =>
              GestureDetector(
                onTap: () => ss(() => harvestTime = t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: harvestTime == t ? AppTheme.accentLight : AppTheme.surfaceGrey,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: harvestTime == t ? AppTheme.accent : Colors.transparent),
                  ),
                  child: Text(t, style: TextStyle(
                    color: harvestTime == t ? AppTheme.accent : AppTheme.textSecondary,
                    fontSize: 12, fontWeight: FontWeight.w500)),
                ),
              )).toList()),
            const SizedBox(height: 24),

            // Buttons
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                  side: const BorderSide(color: AppTheme.divider),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Cancel'))),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(
                onPressed: () {
                  if (produceType == null || qtyCtrl.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select produce type and enter quantity')));
                    return;
                  }
                  p.addBatch({
                    'produce_type': produceType,
                    'name': nameCtrl.text.isNotEmpty
                      ? nameCtrl.text : '$produceType – Batch ${p.batches.length + 1}',
                    'qty': double.tryParse(qtyCtrl.text) ?? 0,
                    'sensor_id': sensorCtrl.text,
                    'harvest_time': harvestTime,
                    'added_at': DateTime.now().toIso8601String(),
                  });
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Batch added!'),
                      backgroundColor: AppTheme.success));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Add Batch'))),
            ]),
          ]),
        );
      }),
    );
  }
}

class _SensorStatusStrip extends StatelessWidget {
  final Map<String, dynamic> sensor;
  final VoidCallback onRefresh;
  const _SensorStatusStrip({required this.sensor, required this.onRefresh});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: sensor.isNotEmpty ? AppTheme.accentLight : AppTheme.surfaceGrey,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: sensor.isNotEmpty ? AppTheme.accent.withOpacity(0.3) : AppTheme.divider),
    ),
    child: Row(children: [
      Icon(sensor.isNotEmpty ? Icons.sensors : Icons.sensors_off_outlined,
        color: sensor.isNotEmpty ? AppTheme.accent : AppTheme.textMuted, size: 18),
      const SizedBox(width: 8),
      Text(sensor.isNotEmpty
        ? 'BT Sensor Live · ${sensor['temperature']}°C · ${sensor['humidity']}% · ${sensor['mq135_ppm']} ppm'
        : 'No Bluetooth sensor connected',
        style: TextStyle(
          color: sensor.isNotEmpty ? AppTheme.accent : AppTheme.textSecondary,
          fontSize: 12, fontWeight: FontWeight.w500)),
      const Spacer(),
      GestureDetector(onTap: onRefresh,
        child: Icon(Icons.refresh_rounded, color: sensor.isNotEmpty ? AppTheme.accent : AppTheme.textMuted, size: 18)),
    ]),
  );
}

class _BatchCard extends StatelessWidget {
  final Map<String, dynamic> batch;
  final int index;
  final double freshness;
  const _BatchCard({required this.batch, required this.index, required this.freshness});

  @override
  Widget build(BuildContext context) {
    final emoji = _emoji(batch['produce_type']);
    final fLabel = freshness > 70 ? 'Peak Fresh' : freshness > 40 ? 'Good' : freshness > 0 ? 'Moderate' : 'Unknown';
    final fColor = freshness > 70 ? AppTheme.success : freshness > 40 ? AppTheme.warning : AppTheme.textMuted;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(width: 48, height: 48,
              decoration: BoxDecoration(color: AppTheme.surfaceGrey, borderRadius: BorderRadius.circular(12)),
              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24)))),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(batch['name'] ?? batch['produce_type'] ?? 'Batch',
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text('${batch['qty']} kg  ·  ${batch['produce_type']}  ·  ${batch['harvest_time'] ?? 'Recently'}',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: fColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: Text(fLabel, style: TextStyle(color: fColor, fontSize: 11, fontWeight: FontWeight.w600))),
              if (freshness > 0) ...[
                const SizedBox(height: 4),
                Text('${freshness.round()}%', style: TextStyle(color: fColor, fontSize: 11)),
              ],
            ]),
          ]),
        ),
        if (freshness > 0) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: freshness / 100,
                backgroundColor: AppTheme.surfaceGrey,
                valueColor: AlwaysStoppedAnimation(fColor),
                minHeight: 4,
              ),
            ),
          ),
        ],
      ]),
    );
  }

  String _emoji(String? type) {
    switch (type?.toLowerCase()) {
      case 'tomatoes': return '🍅';
      case 'mangoes': return '🥭';
      case 'onions': return '🧅';
      case 'potatoes': return '🥔';
      case 'leafy greens': return '🥬';
      case 'fruits': return '🍓';
      default: return '🥦';
    }
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 80, height: 80,
        decoration: BoxDecoration(color: AppTheme.surfaceGrey, borderRadius: BorderRadius.circular(24)),
        child: const Center(child: Text('📦', style: TextStyle(fontSize: 36)))),
      const SizedBox(height: 20),
      const Text('No batches yet', style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      const Text('Add your first produce batch to start tracking freshness and planning routes.',
        style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.5), textAlign: TextAlign.center),
      const SizedBox(height: 28),
      ElevatedButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.add),
        label: const Text('Add First Batch'),
        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, minimumSize: const Size(200, 52)),
      ),
    ]),
  );
}