import 'package:flutter/material.dart';
import 'dart:math';
import 'package:meow_lang/DB/database_helper.dart';
import 'package:meow_lang/models/cat.dart';
import 'package:meow_lang/models/historyRecord.dart';

class AnalyticsTab extends StatefulWidget {
  const AnalyticsTab({super.key});

  @override
  State<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<AnalyticsTab> {
  List<Cat> _cats = [];
  Cat? _selectedCat;
  Map<String, int> _chartData = {};
  bool _isLoading = true;
  List<HistoryRecord> _allHistory = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final cats = await DatabaseHelper.instance.getCats();
    final history = await DatabaseHelper.instance.readAllHistory();

    if (mounted) {
      setState(() {
        _cats = cats;
        _allHistory = history;
        
        if (_cats.isNotEmpty) {
          if (_selectedCat == null || !_cats.any((c) => c.catId == _selectedCat!.catId)) {
            _selectedCat = _cats.first;
          }
        } else {
          _selectedCat = null;
        }
        
        _processData();
        _isLoading = false;
      });
    }
  }

  void _processData() {
    _chartData.clear();
    if (_selectedCat == null) return;

    final catHistory = _allHistory.where((h) => h.catId == _selectedCat!.catId);
    
    for (var record in catHistory) {
      final label = record.textTranslation ?? 'Unknown';
      _chartData[label] = (_chartData[label] ?? 0) + 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_cats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No Data Available',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            const Text('Register a cat to see analytics.'),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Cat Selector
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Cat>(
                  value: _selectedCat,
                  isExpanded: true,
                  items: _cats.map((cat) {
                    return DropdownMenuItem(
                      value: cat,
                      child: Text(cat.name),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedCat = val;
                      _processData();
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 32),
            
            // Chart Area
            Expanded(
              child: _chartData.isEmpty
                  ? Center(
                      child: Text(
                        'No translation history for ${_selectedCat?.name}',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : _buildPieChart(context),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPieChart(BuildContext context) {
    final colors = List.generate(
      _chartData.length,
      (index) => Colors.primaries[index % Colors.primaries.length].withOpacity(0.8),
    );

    return Column(
      children: [
        SizedBox(
          width: 220,
          height: 220,
          child: CustomPaint(
            painter: PieChartPainter(
              data: _chartData,
              colors: colors,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            ),
            child: Center(
              child: Text(
                'Total\n${_chartData.values.fold(0, (p, c) => p + c)}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        _buildLegend(colors),
      ],
    );
  }

  Widget _buildLegend(List<Color> colors) {
    int i = 0;
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: _chartData.entries.map((entry) {
        final color = colors[i++];
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 16, height: 16, color: color),
            const SizedBox(width: 8),
            Text('${entry.key} (${entry.value})'),
          ],
        );
      }).toList(),
    );
  }
}

class PieChartPainter extends CustomPainter {
  final Map<String, int> data;
  final List<Color> colors;
  final Color backgroundColor;

  PieChartPainter({
    required this.data,
    required this.colors,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final total = data.values.reduce((a, b) => a + b);
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);
    double startAngle = -pi / 2;

    // Draw shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
    canvas.drawCircle(center.translate(4, 4), radius, shadowPaint);

    // Draw slices
    int i = 0;
    for (var entry in data.entries) {
      final sweepAngle = (entry.value / total) * 2 * pi;
      final paint = Paint()
        ..color = colors[i++]
        ..style = PaintingStyle.fill;

      canvas.drawArc(rect, startAngle, sweepAngle, true, paint);
      startAngle += sweepAngle;
    }

    // Draw donut hole
    final holePaint = Paint()..color = backgroundColor;
    canvas.drawCircle(center, radius * 0.4, holePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}