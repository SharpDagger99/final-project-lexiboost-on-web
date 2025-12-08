// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/custom_scroll_behavior.dart';

/// Model class for game type statistics
class GameTypeStats {
  final String gameType;
  final int totalCorrect;
  final int totalWrong;
  final int totalPlayed;

  GameTypeStats({
    required this.gameType,
    required this.totalCorrect,
    required this.totalWrong,
    required this.totalPlayed,
  });

  double get winRate {
    if (totalCorrect == 0 && totalWrong == 0) return 0.0;
    // Using the scoring system: correct = +25%, wrong = -50%
    final correctPoints = totalCorrect * 25.0;
    final wrongPoints = totalWrong * 50.0;
    return (correctPoints - wrongPoints).clamp(0.0, 100.0);
  }
}

class MyGameDashboard extends StatefulWidget {
  const MyGameDashboard({super.key});

  @override
  State<MyGameDashboard> createState() => _MyGameDashboardState();
}

class _MyGameDashboardState extends State<MyGameDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<GameTypeStats> _gameTypeStats = [];
  bool _isLoading = true;
  int _totalGamesPlayed = 0;
  int _totalCorrect = 0;
  int _totalWrong = 0;

  @override
  void initState() {
    super.initState();
    debugPrint('🎮 Game Dashboard initialized');
    _loadGameTypeStatistics();
  }

  Future<void> _loadGameTypeStatistics() async {
    debugPrint('📊 Loading game type statistics...');
    setState(() => _isLoading = true);
    try {
      // Get all students
      final studentsSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'student')
          .get();

      // Map to aggregate game type stats
      Map<String, GameTypeStats> gameTypeMap = {};

      // For each student, get their game_type_stats
      for (var studentDoc in studentsSnapshot.docs) {
        final gameTypeStatsSnapshot = await _firestore
            .collection('users')
            .doc(studentDoc.id)
            .collection('game_type_stats')
            .get();

        for (var statDoc in gameTypeStatsSnapshot.docs) {
          final data = statDoc.data();
          final gameType = data['gameType'] as String? ?? 'Unknown';
          final totalCorrect = data['totalCorrect'] as int? ?? 0;
          final totalWrong = data['totalWrong'] as int? ?? 0;
          final totalPlayed = data['totalPlayed'] as int? ?? 0;

          if (gameTypeMap.containsKey(gameType)) {
            // Aggregate existing stats
            final existing = gameTypeMap[gameType]!;
            gameTypeMap[gameType] = GameTypeStats(
              gameType: gameType,
              totalCorrect: existing.totalCorrect + totalCorrect,
              totalWrong: existing.totalWrong + totalWrong,
              totalPlayed: existing.totalPlayed + totalPlayed,
            );
          } else {
            // Create new entry
            gameTypeMap[gameType] = GameTypeStats(
              gameType: gameType,
              totalCorrect: totalCorrect,
              totalWrong: totalWrong,
              totalPlayed: totalPlayed,
            );
          }
        }
      }

      // Convert to list and sort by total played (descending)
      final statsList = gameTypeMap.values.toList();
      statsList.sort((a, b) => b.totalPlayed.compareTo(a.totalPlayed));

      debugPrint('✅ Loaded ${statsList.length} game types');
      
      // Calculate totals
      int totalGames = 0;
      int totalCorrect = 0;
      int totalWrong = 0;
      
      for (var stat in statsList) {
        totalGames += stat.totalPlayed;
        totalCorrect += stat.totalCorrect;
        totalWrong += stat.totalWrong;
      }
      
      debugPrint('📊 Totals: $totalGames games, $totalCorrect correct, $totalWrong wrong');
      
      setState(() {
        _gameTypeStats = statsList;
        _totalGamesPlayed = totalGames;
        _totalCorrect = totalCorrect;
        _totalWrong = totalWrong;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading game type statistics: $e');
      debugPrint('Stack trace: $stackTrace');
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Game Type Statistics',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadGameTypeStatistics,
            tooltip: 'Refresh Data',
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadGameTypeStatistics,
              child: ScrollConfiguration(
                behavior: CustomScrollBehavior(),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Summary Cards
                      Text(
                        'Overview',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildSummaryCards(),
                      
                      const SizedBox(height: 32),
                      
                      // Game Type Statistics
                      Text(
                        'Game Types by Popularity',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      if (_gameTypeStats.isEmpty)
                        _buildEmptyState()
                      else
                        ..._gameTypeStats.asMap().entries.map((entry) {
                          final index = entry.key;
                          final stat = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _buildGameTypeCard(stat, index + 1),
                          );
                        }),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;
        
        if (isWide) {
          return Row(
            children: [
              Expanded(child: _buildSummaryCard(
                'Total Games',
                _totalGamesPlayed.toString(),
                Icons.sports_esports,
                Colors.orange,
              )),
              const SizedBox(width: 16),
              Expanded(child: _buildSummaryCard(
                'Total Correct',
                _totalCorrect.toString(),
                Icons.check_circle,
                Colors.green,
              )),
              const SizedBox(width: 16),
              Expanded(child: _buildSummaryCard(
                'Total Wrong',
                _totalWrong.toString(),
                Icons.cancel,
                Colors.red,
              )),
            ],
          );
        } else {
          return Column(
            children: [
              _buildSummaryCard(
                'Total Games',
                _totalGamesPlayed.toString(),
                Icons.sports_esports,
                Colors.orange,
              ),
              const SizedBox(height: 12),
              _buildSummaryCard(
                'Total Correct',
                _totalCorrect.toString(),
                Icons.check_circle,
                Colors.green,
              ),
              const SizedBox(height: 12),
              _buildSummaryCard(
                'Total Wrong',
                _totalWrong.toString(),
                Icons.cancel,
                Colors.red,
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.8), color],
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
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
          ),
        ],
      ),
    );
  }

  Widget _buildGameTypeCard(GameTypeStats stat, int rank) {
    // Determine color based on win rate
    Color progressColor;
    if (stat.winRate >= 70) {
      progressColor = Colors.green;
    } else if (stat.winRate >= 50) {
      progressColor = Colors.orange;
    } else {
      progressColor = Colors.red;
    }

    // Medal icon for top 3
    Widget? rankIcon;
    if (rank == 1) {
      rankIcon = const Icon(Icons.emoji_events, color: Colors.amber, size: 32);
    } else if (rank == 2) {
      rankIcon = Icon(Icons.emoji_events, color: Colors.grey[400], size: 28);
    } else if (rank == 3) {
      rankIcon = Icon(Icons.emoji_events, color: Colors.brown[300], size: 24);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: rank <= 3 ? progressColor.withOpacity(0.5) : Colors.purple.withOpacity(0.3),
          width: rank <= 3 ? 2 : 1,
        ),
        boxShadow: rank <= 3
            ? [
                BoxShadow(
                  color: progressColor.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with rank and game type
          Row(
            children: [
              if (rankIcon != null) ...[
                rankIcon,
                const SizedBox(width: 12),
              ] else ...[
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '#$rank',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  stat.gameType,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Stats row
          Row(
            children: [
              Expanded(
                child: _buildStatChip(
                  'Played',
                  stat.totalPlayed.toString(),
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatChip(
                  'Correct',
                  stat.totalCorrect.toString(),
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatChip(
                  'Wrong',
                  stat.totalWrong.toString(),
                  Colors.red,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Win rate
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Win Rate',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                ),
              ),
              Text(
                '${stat.winRate.toStringAsFixed(1)}%',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: progressColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: stat.winRate / 100,
              minHeight: 12,
              backgroundColor: Colors.grey[800],
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.sports_esports_outlined,
              size: 64,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No games played yet',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Game statistics will appear here once students start playing',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white54,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}