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
        _getMonthlyGrowthData(),
      ]);

      return DashboardStats(
        totalTeachers: results[0] as int,
        totalStudents: results[1] as int,
        totalClasses: results[2] as int,
        activeVideoCalls: results[3] as int,
        totalPublishedGames: results[4] as int,
        monthlyGrowth: results[5] as List<MonthlyChartData>,
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

  /// Get user growth data by weekday for the chart
  Future<List<MonthlyChartData>> _getMonthlyGrowthData() async {
    try {
      final now = DateTime.now();
      
      // Initialize weekday stats (Monday = 1, Sunday = 7)
      final weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final weekdayStats = <String, MonthlyChartData>{};
      
      for (var i = 0; i < 7; i++) {
        final weekdayName = weekdayNames[i];
        weekdayStats[weekdayName] = MonthlyChartData(
          month: weekdayName,
          count: 0,
          date: now.subtract(Duration(days: 6 - i)), // For sorting
        );
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

      // Count users by their creation weekday
      final allUsers = [...teachersSnapshot.docs, ...studentsSnapshot.docs];

      for (var doc in allUsers) {
        final data = doc.data();
        if (data['createdAt'] != null) {
          final createdAt = (data['createdAt'] as Timestamp).toDate();
          
          // Get weekday (1 = Monday, 7 = Sunday)
          final weekday = createdAt.weekday;
          final weekdayName = weekdayNames[weekday - 1];
          
          if (weekdayStats.containsKey(weekdayName)) {
            final existingData = weekdayStats[weekdayName]!;
            weekdayStats[weekdayName] = MonthlyChartData(
              month: weekdayName,
              count: existingData.count + 1,
              date: existingData.date,
            );
          }
        }
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
}

