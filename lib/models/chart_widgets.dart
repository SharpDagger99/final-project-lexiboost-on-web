// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'chart_data.dart';

/// Helper class for building chart widgets
class ChartWidgets {
  /// Build a line chart with area fill for monthly data
  static Widget buildMonthlyLineChart({
    required List<MonthlyChartData> data,
    ChartConfig? config,
    double height = 300,
  }) {
    if (data.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final chartConfig = config ?? ChartConfig.defaultConfig();
    // Note: maxValue no longer needed since Y-axis is fixed at 0-100% for percentage charts

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            horizontalInterval: 10, // Show grid lines every 10% (0%, 10%, 20%, ..., 100%)
            verticalInterval: 1,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: chartConfig.gridLineColor,
                strokeWidth: 1,
              );
            },
            getDrawingVerticalLine: (value) {
              return FlLine(
                color: chartConfig.gridLineColor,
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 1,
                getTitlesWidget: (double value, TitleMeta meta) {
                  if (value.toInt() >= 0 && value.toInt() < data.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        data[value.toInt()].month,
                        style: GoogleFonts.poppins(
                          color: Colors.white.withOpacity(0.6),
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 10, // Show every 10% (0%, 10%, 20%, etc.)
                getTitlesWidget: (double value, TitleMeta meta) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      '${value.toInt()}%',
                      style: GoogleFonts.poppins(
                        color: Colors.white.withOpacity(0.6),
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  );
                },
                reservedSize: 55, // Increased reserved space for percentage labels
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (data.length - 1).toDouble(),
          minY: 0,
          maxY: 100.0, // Percentage scale (0-100%)
          lineBarsData: [
            LineChartBarData(
              spots: data.asMap().entries.map((entry) {
                return FlSpot(
                  entry.key.toDouble(),
                  entry.value.count.toDouble(),
                );
              }).toList(),
              isCurved: true,
              gradient: LinearGradient(
                colors: chartConfig.lineGradient,
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
              barWidth: chartConfig.lineWidth,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  // Color dots based on percentage value
                  Color dotColor;
                  if (spot.y >= 80) {
                    dotColor = const Color(0xFF66BB6A); // Green (excellent)
                  } else if (spot.y >= 60) {
                    dotColor = const Color(0xFF9CCC65); // Light green (good)
                  } else if (spot.y >= 40) {
                    dotColor = const Color(0xFFFFEE58); // Yellow (average)
                  } else if (spot.y >= 20) {
                    dotColor = const Color(0xFFFFA726); // Orange (below average)
                  } else {
                    dotColor = const Color(0xFFEF5350); // Red (poor)
                  }
                  
                  return FlDotCirclePainter(
                    radius: chartConfig.dotRadius,
                    color: dotColor,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    const Color(0x66EF5350), // Red with 40% opacity at bottom
                    const Color(0x44FFEE58), // Yellow with 27% opacity in middle
                    const Color(0x1A66BB6A), // Green with 10% opacity at top
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                return touchedBarSpots.map((barSpot) {
                  final flSpot = barSpot;
                  return LineTooltipItem(
                    '${data[flSpot.x.toInt()].month}\n${flSpot.y.toInt()}%',
                    GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Build a simple bar chart
  static Widget buildBarChart({
    required Map<String, int> data,
    required Color barColor,
    double height = 300,
  }) {
    if (data.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final entries = data.entries.toList();
    final maxValue = data.values.reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (maxValue + 10).toDouble(),
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${entries[groupIndex].key}\n${rod.toY.toInt()}',
                  GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  if (value.toInt() >= 0 && value.toInt() < entries.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        entries[value.toInt()].key,
                        style: GoogleFonts.poppins(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  return Text(
                    value.toInt().toString(),
                    style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  );
                },
                reservedSize: 42,
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: entries.asMap().entries.map((entry) {
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: entry.value.value.toDouble(),
                  color: barColor,
                  width: 20,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    topRight: Radius.circular(6),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Build a pie chart
  static Widget buildPieChart({
    required Map<String, int> data,
    required List<Color> colors,
    double radius = 100,
  }) {
    if (data.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final entries = data.entries.toList();
    final total = data.values.reduce((a, b) => a + b);

    return SizedBox(
      height: radius * 2 + 50,
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: radius * 0.4,
          sections: entries.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final percentage = (item.value / total * 100).toStringAsFixed(1);
            
            return PieChartSectionData(
              color: colors[index % colors.length],
              value: item.value.toDouble(),
              title: '$percentage%',
              radius: radius,
              titleStyle: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

