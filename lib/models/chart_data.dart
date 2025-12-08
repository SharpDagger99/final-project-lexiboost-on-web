import 'package:flutter/material.dart';

/// Model class for chart data points (supports monthly, weekly, and weekday data)
class MonthlyChartData {
  final String month; // Can represent month, week, or weekday label
  final int count;
  final DateTime date;

  MonthlyChartData({
    required this.month,
    required this.count,
    required this.date,
  });

  factory MonthlyChartData.fromMap(Map<String, dynamic> map) {
    return MonthlyChartData(
      month: map['month'] as String,
      count: map['count'] as int,
      date: map['date'] as DateTime,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'month': month,
      'count': count,
      'date': date,
    };
  }
}

/// Alias for weekly chart data (uses same structure as monthly)
typedef WeeklyChartData = MonthlyChartData;

/// Alias for weekday chart data (uses same structure as monthly)
typedef WeekdayChartData = MonthlyChartData;

/// Model class for dashboard statistics
class DashboardStats {
  final int totalTeachers;
  final int totalStudents;
  final int totalClasses;
  final int activeVideoCalls;
  final int totalPublishedGames;
  final int totalGamesPlayed;
  final int totalUsers;
  final List<MonthlyChartData> monthlyGrowth;

  DashboardStats({
    required this.totalTeachers,
    required this.totalStudents,
    required this.totalClasses,
    required this.activeVideoCalls,
    required this.totalPublishedGames,
    required this.totalGamesPlayed,
    required this.monthlyGrowth,
  }) : totalUsers = totalTeachers + totalStudents;

  double get teacherPercentage {
    if (totalUsers == 0) return 0.0;
    return (totalTeachers / totalUsers * 100).toDouble();
  }

  double get studentPercentage {
    if (totalUsers == 0) return 0.0;
    return (totalStudents / totalUsers * 100).toDouble();
  }

  factory DashboardStats.empty() {
    return DashboardStats(
      totalTeachers: 0,
      totalStudents: 0,
      totalClasses: 0,
      activeVideoCalls: 0,
      totalPublishedGames: 0,
      totalGamesPlayed: 0,
      monthlyGrowth: [],
    );
  }

  DashboardStats copyWith({
    int? totalTeachers,
    int? totalStudents,
    int? totalClasses,
    int? activeVideoCalls,
    int? totalPublishedGames,
    int? totalGamesPlayed,
    List<MonthlyChartData>? monthlyGrowth,
  }) {
    return DashboardStats(
      totalTeachers: totalTeachers ?? this.totalTeachers,
      totalStudents: totalStudents ?? this.totalStudents,
      totalClasses: totalClasses ?? this.totalClasses,
      activeVideoCalls: activeVideoCalls ?? this.activeVideoCalls,
      totalPublishedGames: totalPublishedGames ?? this.totalPublishedGames,
      totalGamesPlayed: totalGamesPlayed ?? this.totalGamesPlayed,
      monthlyGrowth: monthlyGrowth ?? this.monthlyGrowth,
    );
  }
}

/// Model class for stat card configuration
class StatCardConfig {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final List<Color> gradient;

  const StatCardConfig({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.gradient,
  });
}

/// Model class for chart configuration
class ChartConfig {
  final List<Color> lineGradient;
  final List<Color> areaGradient;
  final Color gridLineColor;
  final Color dotColor;
  final double lineWidth;
  final double dotRadius;

  const ChartConfig({
    required this.lineGradient,
    required this.areaGradient,
    required this.gridLineColor,
    required this.dotColor,
    this.lineWidth = 3.0,
    this.dotRadius = 4.0,
  });

  factory ChartConfig.defaultConfig() {
    return ChartConfig(
      lineGradient: [
        const Color(0xFFEF5350), // Red (poor - 0%)
        const Color(0xFFFFA726), // Orange (below average)
        const Color(0xFFFFEE58), // Yellow (average)
        const Color(0xFF9CCC65), // Light green (good)
        const Color(0xFF66BB6A), // Green (excellent - 100%)
      ],
      areaGradient: [
        const Color(0x66EF5350), // Red with 40% opacity
        const Color(0x1A66BB6A), // Green with 10% opacity
      ],
      gridLineColor: const Color(0x1AFFFFFF), // White with 10% opacity
      dotColor: const Color(0xFF66BB6A), // Green dot color
    );
  }
}

/// Model class for game type weekday data
class GameTypeWeekdayData {
  final String weekday;
  final int count;
  final String gameType;

  GameTypeWeekdayData({
    required this.weekday,
    required this.count,
    required this.gameType,
  });
}

