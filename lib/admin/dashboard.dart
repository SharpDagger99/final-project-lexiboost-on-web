// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter, unnecessary_brace_in_string_interps, unnecessary_to_list_in_spreads

import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import '../models/chart_data.dart';
import '../models/chart_widgets.dart';
import '../models/custom_scroll_behavior.dart';
import '../services/dashboard_service.dart';
import 'package:fl_chart/fl_chart.dart';

class MyDashBoard extends StatefulWidget {
  const MyDashBoard({super.key});

  @override
  State<MyDashBoard> createState() => _MyDashBoardState();
}

class _MyDashBoardState extends State<MyDashBoard> {
  final DashboardService _dashboardService = DashboardService();
  DashboardStats _stats = DashboardStats.empty();
  List<GameTypeStats> _gameTypeStats = [];
  Map<String, List<GameTypeWeekdayData>> _gameTypesByWeekday = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _dashboardService.getDashboardStats(),
        _dashboardService.getGameTypeStatistics(),
        _dashboardService.getGameTypesByWeekday(),
      ]);
      setState(() {
        _stats = results[0] as DashboardStats;
        _gameTypeStats = results[1] as List<GameTypeStats>;
        _gameTypesByWeekday = results[2] as Map<String, List<GameTypeWeekdayData>>;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A3E),
        elevation: 0,
        title: Text(
          'Admin Dashboard',
          style: GoogleFonts.poppins(
            fontSize: _getResponsiveFontSize(context, base: 24),
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            onPressed: _showDownloadConfirmation,
            tooltip: 'Download Dashboard',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadDashboardData,
            tooltip: 'Refresh Data',
          ),
          SizedBox(width: _getResponsivePadding(context)),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.cyan),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: ScrollConfiguration(
                behavior: CustomScrollBehavior(),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.all(_getResponsivePadding(context)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Stats Cards
                          Text(
                            'Overview',
                            style: GoogleFonts.poppins(
                              fontSize: _getResponsiveFontSize(
                                context,
                                base: 20,
                              ),
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: _getResponsiveSpacing(context)),
                          _buildStatsGrid(),

                          SizedBox(height: _getResponsiveSpacing(context) * 2),

                          // Total Games Played Card
                          Text(
                            'Game Statistics',
                            style: GoogleFonts.poppins(
                              fontSize: _getResponsiveFontSize(
                                context,
                                base: 20,
                              ),
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: _getResponsiveSpacing(context)),
                          _buildTotalGamesPlayedCard(),

                          SizedBox(height: _getResponsiveSpacing(context) * 2),

                          // Game Type Statistics
                          Text(
                            'Games Played by Type',
                            style: GoogleFonts.poppins(
                              fontSize: _getResponsiveFontSize(
                                context,
                                base: 20,
                              ),
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: _getResponsiveSpacing(context)),
                          _buildGameTypeStatistics(),

                          SizedBox(height: _getResponsiveSpacing(context) * 2),

                          // Game Types by Weekday Chart
                          Row(
                            children: [
                              Text(
                                'Game Types Played by Weekday',
                                style: GoogleFonts.poppins(
                                  fontSize: _getResponsiveFontSize(
                                    context,
                                    base: 20,
                                  ),
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '(${_getCurrentWeekDateRange()})',
                                style: GoogleFonts.poppins(
                                  fontSize: _getResponsiveFontSize(
                                    context,
                                    base: 14,
                                  ),
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: _getResponsiveSpacing(context)),
                          _buildGameTypeWeekdayChart(),

                          SizedBox(height: _getResponsiveSpacing(context) * 2),

                          // User Growth Chart
                          Row(
                            children: [
                              Text(
                                'User Registrations by Weekday',
                                style: GoogleFonts.poppins(
                                  fontSize: _getResponsiveFontSize(
                                    context,
                                    base: 20,
                                  ),
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '(${_getCurrentWeekDateRange()})',
                                style: GoogleFonts.poppins(
                                  fontSize: _getResponsiveFontSize(
                                    context,
                                    base: 14,
                                  ),
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: _getResponsiveSpacing(context)),
                          _buildUserGrowthChart(),

                          SizedBox(height: _getResponsiveSpacing(context) * 2),

                          // Additional Analytics
                          Text(
                            'Analytics',
                            style: GoogleFonts.poppins(
                              fontSize: _getResponsiveFontSize(
                                context,
                                base: 20,
                              ),
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: _getResponsiveSpacing(context)),
                          _buildAnalyticsSection(),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
    );
  }

  // Responsive helper methods
  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1200) return 4; // Desktop (for 4 cards)
    if (width >= 800) return 3; // Tablet landscape
    if (width >= 600) return 2; // Tablet portrait
    return 1; // Mobile
  }

  double _getResponsivePadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1200) return 24;
    if (width >= 800) return 20;
    if (width >= 600) return 16;
    return 12;
  }

  double _getResponsiveSpacing(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 800) return 16;
    return 12;
  }

  double _getResponsiveFontSize(BuildContext context, {required double base}) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1200) return base;
    if (width >= 800) return base * 0.95;
    if (width >= 600) return base * 0.9;
    return base * 0.85;
  }

  double _getChartHeight(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1200) return 450; // Increased from 400
    if (width >= 800) return 400; // Increased from 360
    if (width >= 600) return 360; // Increased from 320
    return 320; // Increased from 280
  }

  /// Get current week date range (Monday - Sunday)
  String _getCurrentWeekDateRange() {
    final now = DateTime.now();
    final daysFromMonday = now.weekday - 1;
    final startOfWeek = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: daysFromMonday));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    
    // Format: "MMM dd - MMM dd, yyyy"
    final startMonth = _getMonthAbbreviation(startOfWeek.month);
    final endMonth = _getMonthAbbreviation(endOfWeek.month);
    
    if (startOfWeek.year == endOfWeek.year) {
      if (startOfWeek.month == endOfWeek.month) {
        return '${startMonth} ${startOfWeek.day} - ${endOfWeek.day}, ${startOfWeek.year}';
      } else {
        return '${startMonth} ${startOfWeek.day} - ${endMonth} ${endOfWeek.day}, ${startOfWeek.year}';
      }
    } else {
      return '${startMonth} ${startOfWeek.day}, ${startOfWeek.year} - ${endMonth} ${endOfWeek.day}, ${endOfWeek.year}';
    }
  }

  String _getMonthAbbreviation(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  Widget _buildStatsGrid() {
    final spacing = _getResponsiveSpacing(context);
    final crossAxisCount = _getCrossAxisCount(context);
    
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: spacing,
      mainAxisSpacing: spacing,
      childAspectRatio: crossAxisCount == 1
          ? 2.5
          : (crossAxisCount == 2
                ? 1.8
                : (crossAxisCount == 3
                      ? 1.5
                      : (crossAxisCount == 4 ? 1.5 : 1.4))),
      children: [
        _buildStatCard(
          title: 'Total Teachers',
          value: _stats.totalTeachers.toString(),
          icon: Icons.school,
          color: Colors.blue,
          gradient: [Colors.blue.shade400, Colors.blue.shade700],
          isClickable: true,
        ),
        _buildStatCard(
          title: 'Total Students',
          value: _stats.totalStudents.toString(),
          icon: Icons.people,
          color: Colors.purple,
          gradient: [Colors.purple.shade400, Colors.purple.shade700],
        ),
        _buildStatCard(
          title: 'Total Classes',
          value: _stats.totalClasses.toString(),
          icon: Icons.class_,
          color: Colors.green,
          gradient: [Colors.green.shade400, Colors.green.shade700],
        ),
        _buildStatCard(
          title: 'Published Games',
          value: _stats.totalPublishedGames.toString(),
          icon: Icons.gamepad,
          color: Colors.pink,
          gradient: [Colors.pink.shade400, Colors.pink.shade700],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required List<Color> gradient,
    bool isClickable = false,
  }) {
    final padding = _getResponsivePadding(context) * 0.8;
    final iconSize = _getResponsiveFontSize(context, base: 24);
    final valueSize = _getResponsiveFontSize(context, base: 32);
    final titleSize = _getResponsiveFontSize(context, base: 14);
    
    // Check if this is a clickable card
    final isStudentsCard = title == 'Total Students';
    final isTeachersCard = title == 'Total Teachers';
    final shouldShowArrow = isStudentsCard || isTeachersCard;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: isStudentsCard 
            ? _navigateToStudentDashboard 
            : isTeachersCard 
                ? _navigateToTeacherDashboard 
                : null,
        child: Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: EdgeInsets.all(padding * 0.4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: Colors.white, size: iconSize),
                  ),
                  Icon(
                    shouldShowArrow ? Icons.arrow_forward_ios : Icons.trending_up,
                    color: Colors.white.withOpacity(0.7),
                    size: iconSize * 0.8,
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      style: GoogleFonts.poppins(
                        fontSize: valueSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: titleSize,
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Navigate to Student Dashboard
  void _navigateToStudentDashboard() {
    Get.toNamed('/StudentDashboard');
  }

  /// Navigate to Teacher Dashboard
  void _navigateToTeacherDashboard() {
    Get.toNamed('/TeacherDashboard');
  }

  Widget _buildUserGrowthChart() {
    final padding = _getResponsivePadding(context);
    final chartHeight = _getChartHeight(context);

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3E),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ChartWidgets.buildMonthlyLineChart(
        data: _stats.monthlyGrowth,
        config: ChartConfig.defaultConfig(),
        height: chartHeight - (padding * 2),
      ),
    );
  }

  Widget _buildAnalyticsSection() {
    final teacherPercentage = _stats.teacherPercentage;
    final studentPercentage = _stats.studentPercentage;
    final padding = _getResponsivePadding(context);
    final spacing = _getResponsiveSpacing(context);

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3E),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'User Distribution',
            style: GoogleFonts.poppins(
              fontSize: _getResponsiveFontSize(context, base: 18),
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          SizedBox(height: spacing * 1.5),
          _buildProgressBar(
            label: 'Teachers',
            value: _stats.totalTeachers,
            percentage: teacherPercentage,
            color: Colors.blue,
          ),
          SizedBox(height: spacing),
          _buildProgressBar(
            label: 'Students',
            value: _stats.totalStudents,
            percentage: studentPercentage,
            color: Colors.purple,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar({
    required String label,
    required int value,
    required double percentage,
    required Color color,
  }) {
    final fontSize = _getResponsiveFontSize(context, base: 14);
    final progressHeight = MediaQuery.of(context).size.width < 600 ? 8.0 : 10.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: fontSize,
                  color: Colors.white.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$value (${percentage.toStringAsFixed(1)}%)',
              style: GoogleFonts.poppins(
                fontSize: fontSize,
                color: Colors.white.withOpacity(0.8),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: percentage / 100,
            minHeight: progressHeight,
            backgroundColor: Colors.white.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildTotalGamesPlayedCard() {
    final padding = _getResponsivePadding(context);
    
    return Container(
      padding: EdgeInsets.all(padding * 1.5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B6B), Color(0xFFEE5A6F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.sports_esports,
              color: Colors.white,
              size: _getResponsiveFontSize(context, base: 40),
            ),
          ),
          SizedBox(width: padding),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Games Played',
                  style: GoogleFonts.poppins(
                    fontSize: _getResponsiveFontSize(context, base: 16),
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _stats.totalGamesPlayed.toString(),
                    style: GoogleFonts.poppins(
                      fontSize: _getResponsiveFontSize(context, base: 36),
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameTypeStatistics() {
    if (_gameTypeStats.isEmpty) {
      return Container(
        padding: EdgeInsets.all(_getResponsivePadding(context) * 2),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A3E),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            'No game data available',
            style: GoogleFonts.poppins(
              fontSize: _getResponsiveFontSize(context, base: 14),
              color: Colors.white70,
            ),
          ),
        ),
      );
    }

    final padding = _getResponsivePadding(context);
    final spacing = _getResponsiveSpacing(context);
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900;

    // Calculate total games played across all types
    final totalGamesAcrossTypes = _gameTypeStats.fold<int>(
      0,
      (sum, stat) => sum + stat.totalPlayed,
    );

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3E),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: isDesktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left side - Progress bars
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _gameTypeStats.map((stat) {
                      final percentage = totalGamesAcrossTypes > 0
                          ? (stat.totalPlayed / totalGamesAcrossTypes * 100)
                          : 0.0;
                      
                      return Padding(
                        padding: EdgeInsets.only(bottom: spacing),
                        child: _buildGameTypeBar(
                          gameType: _formatGameTypeName(stat.gameType),
                          totalPlayed: stat.totalPlayed,
                          percentage: percentage,
                          color: _getGameTypeColor(stat.gameType),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                SizedBox(width: padding * 2),
                // Right side - Pie chart
                Expanded(
                  flex: 2,
                  child: _buildGameTypePieChart(totalGamesAcrossTypes),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Progress bars
                ..._gameTypeStats.map((stat) {
                  final percentage = totalGamesAcrossTypes > 0
                      ? (stat.totalPlayed / totalGamesAcrossTypes * 100)
                      : 0.0;
                  
                  return Padding(
                    padding: EdgeInsets.only(bottom: spacing),
                    child: _buildGameTypeBar(
                      gameType: _formatGameTypeName(stat.gameType),
                      totalPlayed: stat.totalPlayed,
                      percentage: percentage,
                      color: _getGameTypeColor(stat.gameType),
                    ),
                  );
                }).toList(),
                SizedBox(height: spacing * 2),
                // Pie chart below on mobile
                _buildGameTypePieChart(totalGamesAcrossTypes),
              ],
            ),
    );
  }

  Widget _buildGameTypePieChart(int totalGamesAcrossTypes) {
    final width = MediaQuery.of(context).size.width;
    final chartSize = width >= 900 ? 280.0 : 240.0;

    return Column(
      children: [
        SizedBox(
          height: chartSize,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: chartSize * 0.25,
              sections: _gameTypeStats.map((stat) {
                final percentage = totalGamesAcrossTypes > 0
                    ? (stat.totalPlayed / totalGamesAcrossTypes * 100)
                    : 0.0;
                final color = _getGameTypeColor(stat.gameType);
                
                return PieChartSectionData(
                  color: color,
                  value: stat.totalPlayed.toDouble(),
                  title: '${percentage.toStringAsFixed(1)}%',
                  radius: chartSize * 0.18,
                  titleStyle: GoogleFonts.poppins(
                    fontSize: _getResponsiveFontSize(context, base: 12),
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  badgeWidget: null,
                );
              }).toList(),
            ),
          ),
        ),
        SizedBox(height: _getResponsiveSpacing(context)),
        // Legend
        Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: _gameTypeStats.map((stat) {
            return _buildLegendItem(
              _formatGameTypeName(stat.gameType),
              _getGameTypeColor(stat.gameType),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: _getResponsiveFontSize(context, base: 11),
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildGameTypeWeekdayChart() {
    final padding = _getResponsivePadding(context);
    final chartHeight = _getChartHeight(context);

    // Create color map for game types
    Map<String, Color> gameTypeColors = {};
    for (var gameType in _gameTypesByWeekday.keys) {
      gameTypeColors[gameType] = _getGameTypeColor(gameType);
    }

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3E),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChartWidgets.buildGameTypeWeekdayChart(
            data: _gameTypesByWeekday,
            gameTypeColors: gameTypeColors,
            height: chartHeight - (padding * 2),
          ),
          if (_gameTypesByWeekday.isNotEmpty) ...[
            SizedBox(height: _getResponsiveSpacing(context) * 2),
            // Legend
            Wrap(
              spacing: 16,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: _gameTypesByWeekday.keys.map((gameType) {
                return _buildLegendItem(
                  _formatGameTypeName(gameType),
                  _getGameTypeColor(gameType),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGameTypeBar({
    required String gameType,
    required int totalPlayed,
    required double percentage,
    required Color color,
  }) {
    final fontSize = _getResponsiveFontSize(context, base: 14);
    final progressHeight = MediaQuery.of(context).size.width < 600 ? 10.0 : 12.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                gameType,
                style: GoogleFonts.poppins(
                  fontSize: fontSize,
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$totalPlayed plays (${percentage.toStringAsFixed(1)}%)',
              style: GoogleFonts.poppins(
                fontSize: fontSize,
                color: Colors.white.withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: percentage / 100,
            minHeight: progressHeight,
            backgroundColor: Colors.white.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  String _formatGameTypeName(String gameType) {
    // Normalize the game type name (handle both spaces and underscores)
    final normalized = gameType.toLowerCase().replaceAll(' ', '_');
    
    switch (normalized) {
      case 'fill_in_the_blank':
      case 'fill_the_blank':
        return 'Fill in the Blank';
      case 'fill_in_the_blank_2':
      case 'fill_the_blank_2':
        return 'Fill in the Blank 2';
      case 'guess_the_answer':
        return 'Guess the Answer';
      case 'guess_the_answer_2':
        return 'Guess the Answer 2';
      case 'image_match':
        return 'Image Match';
      case 'listen_and_repeat':
        return 'Listen and Repeat';
      case 'math':
        return 'Math';
      case 'read_the_sentence':
        return 'Read the Sentence';
      case 'stroke':
        return 'Stroke';
      case 'what_is_it_called':
        return 'What is it Called';
      default:
        // Return original with proper capitalization
        return gameType
            .split(RegExp(r'[_\s]+'))
            .map((word) => word.isEmpty
                ? ''
                : word[0].toUpperCase() + word.substring(1).toLowerCase())
            .join(' ');
    }
  }

  Color _getGameTypeColor(String gameType) {
    // Normalize the game type name (handle both spaces and underscores)
    final normalized = gameType.toLowerCase().replaceAll(' ', '_');
    
    switch (normalized) {
      case 'fill_in_the_blank':
      case 'fill_the_blank':
        return const Color(0xFF4CAF50); // Green
      case 'fill_in_the_blank_2':
      case 'fill_the_blank_2':
        return const Color(0xFFFFEB3B); // Yellow
      case 'guess_the_answer':
        return const Color(0xFFFF9800); // Orange
      case 'guess_the_answer_2':
        return const Color(0xFF00BCD4); // Cyan
      case 'image_match':
        return const Color(0xFF8BC34A); // Light Green
      case 'listen_and_repeat':
        return const Color(0xFF9C27B0); // Violet
      case 'math':
        return const Color(0xFF9E9E9E); // Grey
      case 'read_the_sentence':
        return const Color(0xFFFFFFFF); // White
      case 'stroke':
        return const Color(0xFFE91E63); // Pink
      case 'what_is_it_called':
        return const Color(0xFFF44336); // Red
      default:
        return const Color(0xFF607D8B); // Blue Grey
    }
  }

  /// Helper function to escape CSV fields
  String _escapeCsvField(String field) {
    // If field contains comma, quote, or newline, wrap in quotes and escape quotes
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  /// Show confirmation dialog before downloading dashboard data
  Future<void> _showDownloadConfirmation() async {
    if (!mounted) return;

    // Show confirmation dialog
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A3E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            const Icon(Icons.download, color: Colors.cyan, size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "Confirm Download",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 20,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          "Do you want to download the dashboard analytics as a CSV file?",
          style: GoogleFonts.poppins(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              "Cancel",
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyan,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _printDashboardData();
            },
            child: Text(
              "Download",
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  /// Export dashboard data as CSV/Excel
  Future<void> _printDashboardData() async {
    // Build CSV content
    final StringBuffer csvBuffer = StringBuffer();
    final generatedDate = DateTime.now().toString().split('.')[0];

    // Add header information
    csvBuffer.writeln('LexiBoost Admin Dashboard Report');
    csvBuffer.writeln('Generated on: $generatedDate');
    csvBuffer.writeln(''); // Empty line

    // Overview Section
    csvBuffer.writeln('OVERVIEW STATISTICS');
    csvBuffer.writeln('Metric,Value');
    csvBuffer.writeln('Total Teachers,${_stats.totalTeachers}');
    csvBuffer.writeln('Total Students,${_stats.totalStudents}');
    csvBuffer.writeln('Total Classes,${_stats.totalClasses}');
    csvBuffer.writeln('Active Video Calls,${_stats.activeVideoCalls}');
    csvBuffer.writeln('Published Games,${_stats.totalPublishedGames}');
    csvBuffer.writeln('Total Users,${_stats.totalUsers}');
    csvBuffer.writeln(''); // Empty line

    // User Distribution Analytics
    csvBuffer.writeln('USER DISTRIBUTION');
    csvBuffer.writeln('User Type,Count,Percentage');
    csvBuffer.writeln(
      'Teachers,${_stats.totalTeachers},${_stats.teacherPercentage.toStringAsFixed(2)}%',
    );
    csvBuffer.writeln(
      'Students,${_stats.totalStudents},${_stats.studentPercentage.toStringAsFixed(2)}%',
    );
    csvBuffer.writeln(''); // Empty line

    // Game Statistics
    csvBuffer.writeln('GAME STATISTICS');
    csvBuffer.writeln('Total Games Played,${_stats.totalGamesPlayed}');
    csvBuffer.writeln(''); // Empty line

    // Game Type Statistics
    csvBuffer.writeln('GAMES PLAYED BY TYPE');
    csvBuffer.writeln('Game Type,Total Played,Total Correct,Total Wrong,Percentage');
    if (_gameTypeStats.isNotEmpty) {
      final totalGamesAcrossTypes = _gameTypeStats.fold<int>(
        0,
        (sum, stat) => sum + stat.totalPlayed,
      );
      for (var stat in _gameTypeStats) {
        final percentage = totalGamesAcrossTypes > 0
            ? (stat.totalPlayed / totalGamesAcrossTypes * 100)
            : 0.0;
        csvBuffer.writeln(
          '${_escapeCsvField(_formatGameTypeName(stat.gameType))},${stat.totalPlayed},${stat.totalCorrect},${stat.totalWrong},${percentage.toStringAsFixed(2)}%',
        );
      }
    } else {
      csvBuffer.writeln('No game data available,0,0,0,0%');
    }
    csvBuffer.writeln(''); // Empty line

    // User Registrations by Weekday (Current Week - Percentage Based)
    final weekRange = _getCurrentWeekDateRange();
    csvBuffer.writeln('USER REGISTRATIONS BY WEEKDAY ($weekRange)');
    csvBuffer.writeln('Weekday,Percentage');
    if (_stats.monthlyGrowth.isNotEmpty) {
      for (var data in _stats.monthlyGrowth) {
        csvBuffer.writeln('${_escapeCsvField(data.month)},${data.count}%');
      }
    } else {
      csvBuffer.writeln('No data available,0%');
    }

    // Create and download CSV file
    final csvContent = csvBuffer.toString();
    final blob = html.Blob([csvContent], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    
    // Create download link
    html.AnchorElement(href: url)
      ..setAttribute('download', 'Dashboard_Report_${DateTime.now().millisecondsSinceEpoch}.csv')
      ..click();
    
    // Clean up
    Future.delayed(const Duration(seconds: 1), () {
      html.Url.revokeObjectUrl(url);
    });

    // Show success message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('CSV file downloaded'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}