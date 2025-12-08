// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chart_data.dart';

/// Service class to handle all dashboard data operations
class DashboardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetch complete dashboard statistics
  Future<DashboardStats> getDashboardStats() async {
    try {
      // Fetch all data in parallel for better performance
      final results = await Future.wait([
        _getTeachersCount(),
        _getStudentsCount(),
        _getClassesCount(),
        _getActiveVideoCallsCount(),
        _getPublishedGamesCount(),
        _getTotalGamesPlayedCount(),
        _getMonthlyGrowthData(),
      ]);

      return DashboardStats(
        totalTeachers: results[0] as int,
        totalStudents: results[1] as int,
        totalClasses: results[2] as int,
        activeVideoCalls: results[3] as int,
        totalPublishedGames: results[4] as int,
        totalGamesPlayed: results[5] as int,
        monthlyGrowth: results[6] as List<MonthlyChartData>,
      );
    } catch (e) {
      print('Error fetching dashboard stats: $e');
      return DashboardStats.empty();
    }
  }

  /// Get total number of teachers
  Future<int> _getTeachersCount() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'teacher')
          .get();
      return snapshot.docs.length;
    } catch (e) {
      print('Error fetching teachers count: $e');
      return 0;
    }
  }

  /// Get total number of students
  Future<int> _getStudentsCount() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'student')
          .get();
      return snapshot.docs.length;
    } catch (e) {
      print('Error fetching students count: $e');
      return 0;
    }
  }

  /// Get total number of classes
  Future<int> _getClassesCount() async {
    try {
      final snapshot = await _firestore.collection('classes').get();
      return snapshot.docs.length;
    } catch (e) {
      print('Error fetching classes count: $e');
      return 0;
    }
  }

  /// Get number of active video calls
  Future<int> _getActiveVideoCallsCount() async {
    try {
      final snapshot = await _firestore
          .collectionGroup('messages')
          .where('type', isEqualTo: 'video_call')
          .where('status', isEqualTo: 'active')
          .get();
      return snapshot.docs.length;
    } catch (e) {
      print('Error fetching active video calls: $e');
      return 0;
    }
  }

  /// Get total number of published games
  Future<int> _getPublishedGamesCount() async {
    try {
      final snapshot = await _firestore.collection('published_games').get();
      return snapshot.docs.length;
    } catch (e) {
      print('Error fetching published games count: $e');
      return 0;
    }
  }

  /// Get total number of games played by all students
  Future<int> _getTotalGamesPlayedCount() async {
    try {
      // Get all students
      final studentsSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'student')
          .get();

      int totalGamesPlayed = 0;

      // For each student, count their completed games
      for (var studentDoc in studentsSnapshot.docs) {
        final completedGamesSnapshot = await _firestore
            .collection('users')
            .doc(studentDoc.id)
            .collection('completed_games')
            .get();
        
        totalGamesPlayed += completedGamesSnapshot.docs.length;
      }

      return totalGamesPlayed;
    } catch (e) {
      print('Error fetching total games played count: $e');
      return 0;
    }
  }

  /// Get user growth data by weekday for the chart (current week only, percentage-based)
  Future<List<MonthlyChartData>> _getMonthlyGrowthData() async {
    try {
      final now = DateTime.now();
      
      // Get start of current week (Monday 00:00:00)
      final daysFromMonday = now.weekday - 1; // 0 = Monday, 6 = Sunday
      final startOfWeek = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: daysFromMonday));
      
      // Get end of current week (Sunday 23:59:59)
      final endOfWeek = startOfWeek.add(const Duration(days: 7));
      
      // Initialize weekday stats (Monday = 1, Sunday = 7)
      final weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final weekdayStats = <String, MonthlyChartData>{};
      final weekdayCounts = <String, int>{};
      
      for (var i = 0; i < 7; i++) {
        final weekdayName = weekdayNames[i];
        weekdayStats[weekdayName] = MonthlyChartData(
          month: weekdayName,
          count: 0, // Will be converted to percentage
          date: startOfWeek.add(Duration(days: i)),
        );
        weekdayCounts[weekdayName] = 0;
      }

      // Fetch all users (teachers and students)
      final teachersSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'teacher')
          .get();

      final studentsSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'student')
          .get();

      // Count users by their creation weekday (only current week)
      final allUsers = [...teachersSnapshot.docs, ...studentsSnapshot.docs];
      int totalWeekRegistrations = 0;

      for (var doc in allUsers) {
        final data = doc.data();
        if (data['createdAt'] != null) {
          final createdAt = (data['createdAt'] as Timestamp).toDate();
          
          // Only count registrations from current week
          if (createdAt.isAfter(startOfWeek.subtract(const Duration(milliseconds: 1))) &&
              createdAt.isBefore(endOfWeek)) {
            // Get weekday (1 = Monday, 7 = Sunday)
            final weekday = createdAt.weekday;
            final weekdayName = weekdayNames[weekday - 1];
            
            if (weekdayCounts.containsKey(weekdayName)) {
              weekdayCounts[weekdayName] = (weekdayCounts[weekdayName] ?? 0) + 1;
              totalWeekRegistrations++;
            }
          }
        }
      }

      // Convert counts to percentages (0-100)
      for (var i = 0; i < 7; i++) {
        final weekdayName = weekdayNames[i];
        final count = weekdayCounts[weekdayName] ?? 0;
        final percentage = totalWeekRegistrations > 0
            ? (count / totalWeekRegistrations * 100).round()
            : 0;
        
        weekdayStats[weekdayName] = MonthlyChartData(
          month: weekdayName,
          count: percentage, // Store as percentage (0-100)
          date: weekdayStats[weekdayName]!.date,
        );
      }

      // Return in weekday order (Mon to Sun)
      return weekdayNames.map((name) => weekdayStats[name]!).toList();
    } catch (e) {
      print('Error fetching weekday growth data: $e');
      return [];
    }
  }

  /// Get real-time stream of dashboard stats (for live updates)
  Stream<DashboardStats> getDashboardStatsStream() {
    // This would require more complex setup with multiple streams
    // For now, we'll use periodic updates
    return Stream.periodic(
      const Duration(seconds: 30),
      (_) => getDashboardStats(),
    ).asyncMap((future) => future);
  }

  /// Get class engagement data
  Future<Map<String, int>> getClassEngagementData() async {
    try {
      final classesSnapshot = await _firestore.collection('classes').get();
      
      int activeClasses = 0;
      int inactiveClasses = 0;

      for (var doc in classesSnapshot.docs) {
        final data = doc.data();
        final students = (data['students'] as List?)?.length ?? 0;
        
        if (students > 0) {
          activeClasses++;
        } else {
          inactiveClasses++;
        }
      }

      return {
        'active': activeClasses,
        'inactive': inactiveClasses,
      };
    } catch (e) {
      print('Error fetching class engagement: $e');
      return {'active': 0, 'inactive': 0};
    }
  }

  /// Get message statistics
  Future<Map<String, int>> getMessageStats() async {
    try {
      final messagesSnapshot = await _firestore
          .collectionGroup('messages')
          .get();

      int textMessages = 0;
      int imageMessages = 0;
      int videoMessages = 0;
      int videoCalls = 0;

      for (var doc in messagesSnapshot.docs) {
        final type = doc.data()['type'] as String?;
        switch (type) {
          case 'text':
            textMessages++;
            break;
          case 'image':
            imageMessages++;
            break;
          case 'video':
            videoMessages++;
            break;
          case 'video_call':
            videoCalls++;
            break;
        }
      }

      return {
        'text': textMessages,
        'image': imageMessages,
        'video': videoMessages,
        'videoCalls': videoCalls,
        'total': messagesSnapshot.docs.length,
      };
    } catch (e) {
      print('Error fetching message stats: $e');
      return {
        'text': 0,
        'image': 0,
        'video': 0,
        'videoCalls': 0,
        'total': 0,
      };
    }
  }

  /// Get game type statistics from all students
  Future<List<GameTypeStats>> getGameTypeStatistics() async {
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
            gameTypeMap[gameType] = gameTypeMap[gameType]!.copyWith(
              totalCorrect: gameTypeMap[gameType]!.totalCorrect + totalCorrect,
              totalWrong: gameTypeMap[gameType]!.totalWrong + totalWrong,
              totalPlayed: gameTypeMap[gameType]!.totalPlayed + totalPlayed,
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

      return statsList;
    } catch (e) {
      print('Error fetching game type statistics: $e');
      return [];
    }
  }

  /// Get game types played by weekday for the current week
  Future<Map<String, List<GameTypeWeekdayData>>> getGameTypesByWeekday() async {
    try {
      final now = DateTime.now();
      
      // Get start of current week (Monday 00:00:00)
      final daysFromMonday = now.weekday - 1;
      final startOfWeek = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: daysFromMonday));
      
      // Get end of current week (Sunday 23:59:59)
      final endOfWeek = startOfWeek.add(const Duration(days: 7));
      
      // Get all students
      final studentsSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'student')
          .get();

      // Map to store game type counts by weekday
      // Structure: {gameType: {weekday: count}}
      Map<String, Map<String, int>> gameTypeWeekdayMap = {};

      // For each student, get their completed games from current week
      for (var studentDoc in studentsSnapshot.docs) {
        final completedGamesSnapshot = await _firestore
            .collection('users')
            .doc(studentDoc.id)
            .collection('completed_games')
            .get();

        for (var gameDoc in completedGamesSnapshot.docs) {
          final data = gameDoc.data();
          
          // Check if game has completedAt timestamp
          if (data['completedAt'] != null) {
            final completedAt = (data['completedAt'] as Timestamp).toDate();
            
            // Only count games from current week
            if (completedAt.isAfter(startOfWeek.subtract(const Duration(milliseconds: 1))) &&
                completedAt.isBefore(endOfWeek)) {
              
              final gameType = data['gameType'] as String? ?? 'Unknown';
              final weekday = completedAt.weekday; // 1 = Monday, 7 = Sunday
              final weekdayName = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][weekday - 1];
              
              // Initialize maps if needed
              if (!gameTypeWeekdayMap.containsKey(gameType)) {
                gameTypeWeekdayMap[gameType] = {
                  'Mon': 0, 'Tue': 0, 'Wed': 0, 'Thu': 0, 'Fri': 0, 'Sat': 0, 'Sun': 0
                };
              }
              
              gameTypeWeekdayMap[gameType]![weekdayName] = 
                  (gameTypeWeekdayMap[gameType]![weekdayName] ?? 0) + 1;
            }
          }
        }
      }

      // Convert to result format
      Map<String, List<GameTypeWeekdayData>> result = {};
      
      for (var gameType in gameTypeWeekdayMap.keys) {
        result[gameType] = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((weekday) {
          return GameTypeWeekdayData(
            weekday: weekday,
            count: gameTypeWeekdayMap[gameType]![weekday] ?? 0,
            gameType: gameType,
          );
        }).toList();
      }

      return result;
    } catch (e) {
      print('Error fetching game types by weekday: $e');
      return {};
    }
  }
}

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

  GameTypeStats copyWith({
    String? gameType,
    int? totalCorrect,
    int? totalWrong,
    int? totalPlayed,
  }) {
    return GameTypeStats(
      gameType: gameType ?? this.gameType,
      totalCorrect: totalCorrect ?? this.totalCorrect,
      totalWrong: totalWrong ?? this.totalWrong,
      totalPlayed: totalPlayed ?? this.totalPlayed,
    );
  }
}

