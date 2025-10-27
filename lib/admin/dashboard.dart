// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/chart_data.dart';
import '../models/chart_widgets.dart';
import '../models/custom_scroll_behavior.dart';
import '../services/dashboard_service.dart';

class MyDashBoard extends StatefulWidget {
  const MyDashBoard({super.key});

  @override
  State<MyDashBoard> createState() => _MyDashBoardState();
}

class _MyDashBoardState extends State<MyDashBoard> {
  final DashboardService _dashboardService = DashboardService();
  DashboardStats _stats = DashboardStats.empty();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final stats = await _dashboardService.getDashboardStats();
      setState(() {
        _stats = stats;
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

                          // User Growth Chart
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
    if (width >= 1400) return 5; // Large desktop (for 5 cards)
    if (width >= 1200) return 4; // Desktop
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
    if (width >= 1200) return 400;
    if (width >= 800) return 360;
    if (width >= 600) return 320;
    return 280;
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
          title: 'Active Calls',
          value: _stats.activeVideoCalls.toString(),
          icon: Icons.video_call,
          color: Colors.orange,
          gradient: [Colors.orange.shade400, Colors.orange.shade700],
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
  }) {
    final padding = _getResponsivePadding(context) * 0.8;
    final iconSize = _getResponsiveFontSize(context, base: 24);
    final valueSize = _getResponsiveFontSize(context, base: 32);
    final titleSize = _getResponsiveFontSize(context, base: 14);
    
    return Container(
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
                Icons.trending_up,
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
    );
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
}