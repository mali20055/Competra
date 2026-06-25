import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Son 10 ELO geçmişini çizgi grafik olarak gösterir.
/// Çizgi rengi: son değer başlangıçtan yüksekse yeşil, düşükse kırmızı.
class EloChart extends StatelessWidget {
  const EloChart({super.key, required this.history});

  final List<Map<String, dynamic>> history;

  static const Color _upColor = Color(0xFF2E9E5B);
  static const Color _downColor = Color(0xFFD64545);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Widget shell(Widget child) => Container(
          height: 160,
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
          ),
          child: child,
        );

    if (history.isEmpty) {
      return shell(
        Center(
          child: Text(
            'Henüz maç yok',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final entries =
        history.length > 10 ? history.sublist(history.length - 10) : history;
    final ratings = entries
        .map((e) => ((e['rating'] as num?) ?? 1000).toDouble())
        .toList();

    final firstRating = ratings.first;
    final lastRating = ratings.last;
    final lineColor = lastRating >= firstRating ? _upColor : _downColor;

    final spots = [
      for (var i = 0; i < ratings.length; i++) FlSpot(i.toDouble(), ratings[i]),
    ];

    final minY = ratings.reduce((a, b) => a < b ? a : b) - 20;
    final maxY = ratings.reduce((a, b) => a > b ? a : b) + 20;

    return shell(
      LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          titlesData: const FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: lineColor,
              barWidth: 2.5,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) =>
                    FlDotCirclePainter(
                  radius: 3.5,
                  color: lineColor,
                  strokeWidth: 1.5,
                  strokeColor: scheme.surface,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: lineColor.withValues(alpha: 0.10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
