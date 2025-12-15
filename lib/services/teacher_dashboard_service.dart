// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service class to handle teacher dashboard data operations
class TeacherDashboardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get list of teacher's students with their details
  Future<List<StudentInfo>> getTeacherStudents() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return [];

      // Get teacher's full name
      final teacherDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final teacherName = teacherDoc.data()?['fullname'] ?? '';

      if (teacherName.isEmpty) return [];

      // Get all users
      final usersSnapshot = await _firestore.collection('users').get();

      // Find students who have this teacher
      List<StudentInfo> students = [];
      for (var userDoc in usersSnapshot.docs) {
        if (userDoc.id == currentUser.uid) continue;

        final teacherSubDoc = await _firestore
            .collection('users')
            .doc(userDoc.id)
            .collection('teachers')
            .doc(teacherName)
            .get();

        if (teacherSubDoc.exists && (teacherSubDoc.data()?['status'] ?? false)) {
          final userData = userDoc.data();
          students.add(StudentInfo(
            uid: userDoc.id,
            fullname: userData['fullname'] ?? '',
            username: userData['username'] ?? '',
            email: userData['email'] ?? '',
            grade: userData['grade'] ?? '',
            section: userData['section'] ?? '',
            schoolIdNumber: userData['schoolidnumber'] ?? '',
          ));
        }
      }

      return students;
    } catch (e) {
      print('Error fetching teacher students: $e');
      return [];
    }
  }

  /// Get game type statistics for teacher's students with optional filter
  Future<List<GameTypeStats>> getStudentGameTypeStatistics({
    String? filterQuery,
    String? filterType,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return [];

      // Get teacher's full name
      final teacherDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final teacherName = teacherDoc.data()?['fullname'] ?? '';

      if (teacherName.isEmpty) return [];

      // Get all users
      final usersSnapshot = await _firestore.collection('users').get();

      // Find students who have this teacher
      List<String> studentIds = [];
      for (var userDoc in usersSnapshot.docs) {
        if (userDoc.id == currentUser.uid) continue;

        final teacherSubDoc = await _firestore
            .collection('users')
            .doc(userDoc.id)
            .collection('teachers')
            .doc(teacherName)
            .get();

        if (teacherSubDoc.exists && (teacherSubDoc.data()?['status'] ?? false)) {
          // Apply filter if provided
          if (filterQuery != null && filterQuery.isNotEmpty && filterType != null) {
            final userData = userDoc.data();
            bool matches = false;

            switch (filterType.toLowerCase()) {
              case 'grade':
                matches = (userData['grade'] ?? '').toString().toLowerCase().contains(filterQuery.toLowerCase());
                break;
              case 'section':
                matches = (userData['section'] ?? '').toString().toLowerCase().contains(filterQuery.toLowerCase());
                break;
              case 'fullname':
                matches = (userData['fullname'] ?? '').toString().toLowerCase().contains(filterQuery.toLowerCase());
                break;
              case 'username':
                matches = (userData['username'] ?? '').toString().toLowerCase().contains(filterQuery.toLowerCase());
                break;
              case 'email':
                matches = (userData['email'] ?? '').toString().toLowerCase().contains(filterQuery.toLowerCase());
                break;
              case 'schoolidnumber':
                matches = (userData['schoolidnumber'] ?? '').toString().toLowerCase().contains(filterQuery.toLowerCase());
                break;
              default:
                matches = true;
            }

            if (matches) {
              studentIds.add(userDoc.id);
            }
          } else {
            studentIds.add(userDoc.id);
          }
        }
      }

      if (studentIds.isEmpty) return [];

      // Map to aggregate game type stats
      Map<String, GameTypeStats> gameTypeMap = {};

      // For each student, get their game_type_stats
      for (var studentId in studentIds) {
        final gameTypeStatsSnapshot = await _firestore
            .collection('users')
            .doc(studentId)
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
      print('Error fetching student game type statistics: $e');
      return [];
    }
  }

  /// Get total games played by teacher's students with optional filter
  Future<int> getTotalGamesPlayed({
    String? filterQuery,
    String? filterType,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return 0;

      // Get teacher's full name
      final teacherDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final teacherName = teacherDoc.data()?['fullname'] ?? '';

      if (teacherName.isEmpty) return 0;

      // Get all users
      final usersSnapshot = await _firestore.collection('users').get();

      // Find students who have this teacher
      List<String> studentIds = [];
      for (var userDoc in usersSnapshot.docs) {
        if (userDoc.id == currentUser.uid) continue;

        final teacherSubDoc = await _firestore
            .collection('users')
            .doc(userDoc.id)
            .collection('teachers')
            .doc(teacherName)
            .get();

        if (teacherSubDoc.exists && (teacherSubDoc.data()?['status'] ?? false)) {
          // Apply filter if provided
          if (filterQuery != null && filterQuery.isNotEmpty && filterType != null) {
            final userData = userDoc.data();
            bool matches = false;

            switch (filterType.toLowerCase()) {
              case 'grade':
                matches = (userData['grade'] ?? '').toString().toLowerCase().contains(filterQuery.toLowerCase());
                break;
              case 'section':
                matches = (userData['section'] ?? '').toString().toLowerCase().contains(filterQuery.toLowerCase());
                break;
              case 'fullname':
                matches = (userData['fullname'] ?? '').toString().toLowerCase().contains(filterQuery.toLowerCase());
                break;
              case 'username':
                matches = (userData['username'] ?? '').toString().toLowerCase().contains(filterQuery.toLowerCase());
                break;
              case 'email':
                matches = (userData['email'] ?? '').toString().toLowerCase().contains(filterQuery.toLowerCase());
                break;
              case 'schoolidnumber':
                matches = (userData['schoolidnumber'] ?? '').toString().toLowerCase().contains(filterQuery.toLowerCase());
                break;
              default:
                matches = true;
            }

            if (matches) {
              studentIds.add(userDoc.id);
            }
          } else {
            studentIds.add(userDoc.id);
          }
        }
      }

      if (studentIds.isEmpty) return 0;

      int totalGamesPlayed = 0;

      // For each student, count their completed games
      for (var studentId in studentIds) {
        final completedGamesSnapshot = await _firestore
            .collection('users')
            .doc(studentId)
            .collection('completed_games')
            .get();
        
        totalGamesPlayed += completedGamesSnapshot.docs.length;
      }

      return totalGamesPlayed;
    } catch (e) {
      print('Error fetching total games played: $e');
      return 0;
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

/// Model class for student information
class StudentInfo {
  final String uid;
  final String fullname;
  final String username;
  final String email;
  final String grade;
  final String section;
  final String schoolIdNumber;

  StudentInfo({
    required this.uid,
    required this.fullname,
    required this.username,
    required this.email,
    required this.grade,
    required this.section,
    required this.schoolIdNumber,
  });

  String getDisplayText(String filterType) {
    switch (filterType.toLowerCase()) {
      case 'grade':
        return 'Grade $grade';
      case 'section':
        return 'Section $section';
      case 'fullname':
        return fullname;
      case 'username':
        return username;
      case 'email':
        return email;
      case 'schoolidnumber':
        return 'ID: $schoolIdNumber';
      default:
        return fullname;
    }
  }
}
