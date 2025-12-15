// ignore_for_file: deprecated_member_use, unnecessary_brace_in_string_interps, avoid_types_as_parameter_names, unnecessary_to_list_in_spreads

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/teacher_dashboard_service.dart';
import '../models/custom_scroll_behavior.dart';

class MyStudentDashboards extends StatefulWidget {
  final Function(int)? onNavigate;
  
  const MyStudentDashboards({super.key, this.onNavigate});

  @override
  State<MyStudentDashboards> createState() => _MyStudentDashboardsState();
}

class _MyStudentDashboardsState extends State<MyStudentDashboards> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TeacherDashboardService _dashboardService = TeacherDashboardService();
  final TextEditingController _searchController = TextEditingController();
  
  List<GameTypeStats> _gameTypeStats = [];
  int _totalGamesPlayed = 0;
  bool _isLoadingStats = true;
  
  String? _filterQuery;
  String _filterType = 'fullname'; // Default filter type
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadGameStatistics();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadGameStatistics({String? filterQuery, String? filterType}) async {
    setState(() => _isLoadingStats = true);
    try {
      final results = await Future.wait([
        _dashboardService.getStudentGameTypeStatistics(
          filterQuery: filterQuery,
          filterType: filterType,
        ),
        _dashboardService.getTotalGamesPlayed(
          filterQuery: filterQuery,
          filterType: filterType,
        ),
      ]);
      if (mounted) {
        setState(() {
          _gameTypeStats = results[0] as List<GameTypeStats>;
          _totalGamesPlayed = results[1] as int;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading game statistics: $e');
      if (mounted) {
        setState(() => _isLoadingStats = false);
      }
    }
  }

  void _onSearchChanged(String query) {
    // Cancel previous timer
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    // Set new timer for debouncing (wait 500ms after user stops typing)
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _applyFilter(query);
    });
  }

  void _applyFilter(String query) {
    final newFilterQuery = query.isEmpty ? null : query;
    
    // Only reload if filter actually changed
    if (newFilterQuery != _filterQuery) {
      setState(() {
        _filterQuery = newFilterQuery;
      });
      _loadGameStatistics(filterQuery: _filterQuery, filterType: _filterType);
    }
  }

  void _clearFilter() {
    _searchController.clear();
    if (_filterQuery != null) {
      setState(() {
        _filterQuery = null;
      });
      _loadGameStatistics();
    }
  }

  void _onFilterTypeChanged(String? newType) {
    if (newType != null && newType != _filterType) {
      setState(() {
        _filterType = newType;
      });
      // Only reload if there's an active filter
      if (_filterQuery != null && _filterQuery!.isNotEmpty) {
        _loadGameStatistics(filterQuery: _filterQuery, filterType: _filterType);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E201E),
      body: RefreshIndicator(
        onRefresh: _loadGameStatistics,
        child: ScrollConfiguration(
          behavior: CustomScrollBehavior(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            // Welcome Header
            Text(
              'Teacher Dashboard',
              style: GoogleFonts.poppins(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Overview of your teaching activities',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 32),

            // Stats Cards (separated to prevent rebuilds)
            _TeacherStatsCards(
              firestore: _firestore,
              auth: _auth,
              onNavigate: widget.onNavigate,
            ),

            const SizedBox(height: 32),

            // Search/Filter Section
            _buildSearchSection(),

            const SizedBox(height: 32),

            // Total Games Played Card
            Text(
              'Student Game Statistics',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            if (_filterQuery != null && _filterQuery!.isNotEmpty)
              Text(
                'Filtered by ${_filterType.toUpperCase()}: "$_filterQuery"',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.cyan,
                  fontStyle: FontStyle.italic,
                ),
              ),
            const SizedBox(height: 16),
            _buildTotalGamesPlayedCard(),

            const SizedBox(height: 32),

            // Game Type Statistics
            Text(
              'Games Played by Type',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            _buildGameTypeStatistics(),
          ],
        ),
      ),
    ),
      ),
    );
  }

  Widget _buildSearchSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2F2C),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.filter_list,
                color: Colors.cyan,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Filter Student Statistics',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Filter Type Dropdown
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 600;
              
              return isWide
                  ? Row(
                      children: [
                        Expanded(flex: 2, child: _buildFilterTypeDropdown()),
                        const SizedBox(width: 12),
                        Expanded(flex: 3, child: _buildSearchField()),
                      ],
                    )
                  : Column(
                      children: [
                        _buildFilterTypeDropdown(),
                        const SizedBox(height: 12),
                        _buildSearchField(),
                      ],
                    );
            },
          ),
          
          if (_filterQuery != null && _filterQuery!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.cyan,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getFilterHintText(),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white70,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterTypeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E201E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.cyan.withOpacity(0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _filterType,
          isExpanded: true,
          dropdownColor: const Color(0xFF2C2F2C),
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.white,
          ),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.cyan),
          items: [
            DropdownMenuItem(
              value: 'fullname',
              child: Row(
                children: [
                  Icon(Icons.person, color: Colors.cyan, size: 18),
                  const SizedBox(width: 8),
                  Text('Full Name'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'username',
              child: Row(
                children: [
                  Icon(Icons.account_circle, color: Colors.cyan, size: 18),
                  const SizedBox(width: 8),
                  Text('Username'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'email',
              child: Row(
                children: [
                  Icon(Icons.email, color: Colors.cyan, size: 18),
                  const SizedBox(width: 8),
                  Text('Email'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'grade',
              child: Row(
                children: [
                  Icon(Icons.school, color: Colors.cyan, size: 18),
                  const SizedBox(width: 8),
                  Text('Grade'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'section',
              child: Row(
                children: [
                  Icon(Icons.class_, color: Colors.cyan, size: 18),
                  const SizedBox(width: 8),
                  Text('Section'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'schoolidnumber',
              child: Row(
                children: [
                  Icon(Icons.badge, color: Colors.cyan, size: 18),
                  const SizedBox(width: 8),
                  Text('School ID'),
                ],
              ),
            ),
          ],
          onChanged: _onFilterTypeChanged,
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      style: GoogleFonts.poppins(
        fontSize: 14,
        color: Colors.white,
      ),
      decoration: InputDecoration(
        hintText: 'Search by ${_filterType}...',
        hintStyle: GoogleFonts.poppins(
          fontSize: 14,
          color: Colors.white54,
        ),
        prefixIcon: const Icon(Icons.search, color: Colors.cyan),
        suffixIcon: _filterQuery != null && _filterQuery!.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, color: Colors.cyan),
                onPressed: _clearFilter,
              )
            : null,
        filled: true,
        fillColor: const Color(0xFF1E201E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.cyan.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.cyan.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.cyan, width: 2),
        ),
      ),
      onSubmitted: _applyFilter,
      onChanged: _onSearchChanged,
    );
  }

  String _getFilterHintText() {
    switch (_filterType) {
      case 'grade':
        return 'Showing statistics for all students in grade "$_filterQuery"';
      case 'section':
        return 'Showing statistics for all students in section "$_filterQuery"';
      case 'fullname':
        return 'Showing statistics for student: "$_filterQuery"';
      case 'username':
        return 'Showing statistics for username: "$_filterQuery"';
      case 'email':
        return 'Showing statistics for email: "$_filterQuery"';
      case 'schoolidnumber':
        return 'Showing statistics for school ID: "$_filterQuery"';
      default:
        return 'Filtered results';
    }
  }

  Widget _buildTotalGamesPlayedCard() {
    if (_isLoadingStats) {
      return Container(
        padding: const EdgeInsets.all(32),
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
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.sports_esports,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Overall Total Plays',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _totalGamesPlayed.toString(),
                  style: GoogleFonts.poppins(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
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
    if (_isLoadingStats) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF2C2F2C),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.cyan),
          ),
        ),
      );
    }

    if (_gameTypeStats.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF2C2F2C),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            'No game data available',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
        ),
      );
    }

    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900;

    // Calculate total games played across all types
    final totalGamesAcrossTypes = _gameTypeStats.fold<int>(
      0,
      (sum, stat) => sum + stat.totalPlayed,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2F2C),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
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
                        padding: const EdgeInsets.only(bottom: 16),
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
                const SizedBox(width: 32),
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
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildGameTypeBar(
                      gameType: _formatGameTypeName(stat.gameType),
                      totalPlayed: stat.totalPlayed,
                      percentage: percentage,
                      color: _getGameTypeColor(stat.gameType),
                    ),
                  );
                }).toList(),
                const SizedBox(height: 24),
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
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 16),
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
            fontSize: 11,
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildGameTypeBar({
    required String gameType,
    required int totalPlayed,
    required double percentage,
    required Color color,
  }) {
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
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$totalPlayed plays (${percentage.toStringAsFixed(1)}%)',
              style: GoogleFonts.poppins(
                fontSize: 14,
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
            minHeight: 12,
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
}

/// Separate widget for stats cards to prevent unnecessary rebuilds
/// when search filter changes
class _TeacherStatsCards extends StatelessWidget {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  final Function(int)? onNavigate;

  const _TeacherStatsCards({
    required this.firestore,
    required this.auth,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 1;
        if (constraints.maxWidth > 1200) {
          crossAxisCount = 4;
        } else if (constraints.maxWidth > 800) {
          crossAxisCount = 2;
        }

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.5,
          children: [
            _buildStatCard(
              context,
              'Total Classes',
              Icons.class_,
              Colors.blue,
              _getTotalClasses(),
            ),
            _buildStatCard(
              context,
              'Total Students',
              Icons.people,
              Colors.green,
              _getTotalStudents(),
            ),
            _buildStatCard(
              context,
              'Pending Requests',
              Icons.pending_actions,
              Colors.orange,
              _getPendingRequests(),
            ),
            _buildStatCard(
              context,
              'Published Games',
              Icons.gamepad,
              Colors.purple,
              _getPublishedGames(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    Stream<int> countStream,
  ) {
    return StreamBuilder<int>(
      stream: countStream,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _showNavigationConfirmation(context, title, count),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 10,
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
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: Colors.white, size: 32),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white.withOpacity(0.7),
                        size: 20,
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        snapshot.connectionState == ConnectionState.waiting
                            ? '...'
                            : count.toString(),
                        style: GoogleFonts.poppins(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showNavigationConfirmation(BuildContext context, String cardTitle, int count) {
    String destination = '';
    String message = '';
    VoidCallback? navigationAction;

    switch (cardTitle) {
      case 'Total Classes':
        destination = 'Classes';
        message = 'View and manage your $count ${count == 1 ? 'class' : 'classes'}?';
        navigationAction = () {
          Navigator.pop(context);
          if (onNavigate != null) {
            onNavigate!(1);
          }
        };
        break;
      case 'Total Students':
        destination = 'Students';
        message = 'View and manage your $count ${count == 1 ? 'student' : 'students'}?';
        navigationAction = () {
          Navigator.pop(context);
          if (onNavigate != null) {
            onNavigate!(2);
          }
        };
        break;
      case 'Pending Requests':
        destination = 'Student Requests';
        message = 'View $count pending ${count == 1 ? 'request' : 'requests'}?';
        navigationAction = () {
          Navigator.pop(context);
          if (onNavigate != null) {
            onNavigate!(3);
          }
        };
        break;
      case 'Published Games':
        destination = 'Published Games';
        message = 'View your $count published ${count == 1 ? 'game' : 'games'}?';
        navigationAction = () {
          Navigator.pop(context);
          Navigator.pushNamed(context, '/game_published');
        };
        break;
      default:
        return;
    }

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward,
                    size: 40,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Navigate to $destination?',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: navigationAction,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Go',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Stream<int> _getTotalClasses() {
    final currentUser = auth.currentUser;
    if (currentUser == null) return Stream.value(0);

    return firestore
        .collection('classes')
        .where('teacherId', isEqualTo: currentUser.uid)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Stream<int> _getTotalStudents() async* {
    final currentUser = auth.currentUser;
    if (currentUser == null) {
      yield 0;
      return;
    }

    final teacherDoc = await firestore
        .collection('users')
        .doc(currentUser.uid)
        .get();
    final teacherName = teacherDoc.data()?['fullname'] ?? '';

    if (teacherName.isEmpty) {
      yield 0;
      return;
    }

    await for (var usersSnapshot in firestore.collection('users').snapshots()) {
      int count = 0;
      for (var userDoc in usersSnapshot.docs) {
        if (userDoc.id == currentUser.uid) continue;

        final teacherSubDoc = await firestore
            .collection('users')
            .doc(userDoc.id)
            .collection('teachers')
            .doc(teacherName)
            .get();

        if (teacherSubDoc.exists && (teacherSubDoc.data()?['status'] ?? false)) {
          count++;
        }
      }
      yield count;
    }
  }

  Stream<int> _getPendingRequests() async* {
    final currentUser = auth.currentUser;
    if (currentUser == null) {
      yield 0;
      return;
    }

    final teacherDoc = await firestore
        .collection('users')
        .doc(currentUser.uid)
        .get();
    final teacherName = teacherDoc.data()?['fullname'] ?? '';

    if (teacherName.isEmpty) {
      yield 0;
      return;
    }

    await for (var usersSnapshot in firestore.collection('users').snapshots()) {
      int count = 0;
      for (var userDoc in usersSnapshot.docs) {
        if (userDoc.id == currentUser.uid) continue;

        final teacherSubDoc = await firestore
            .collection('users')
            .doc(userDoc.id)
            .collection('teachers')
            .doc(teacherName)
            .get();

        if (teacherSubDoc.exists && !(teacherSubDoc.data()?['status'] ?? false)) {
          count++;
        }
      }
      yield count;
    }
  }

  Stream<int> _getPublishedGames() {
    final currentUser = auth.currentUser;
    if (currentUser == null) return Stream.value(0);

    return firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('created_games')
        .where('publish', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}