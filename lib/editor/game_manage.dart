// ignore_for_file: deprecated_member_use, use_build_context_synchronously, avoid_print, unnecessary_null_in_if_null_operators, avoid_web_libraries_in_flutter

import 'dart:convert';
import 'dart:html' as html;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animated_button/animated_button.dart';

class MyManagement extends StatefulWidget {
  const MyManagement({super.key});

  @override
  State<MyManagement> createState() => _MyManagementState();
}

class _MyManagementState extends State<MyManagement> {
  final User? user = FirebaseAuth.instance.currentUser;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>>? completedUsers;
  List<Map<String, dynamic>>? allCompletedUsers; // Store all users
  List<String>? myStudentIds; // Store teacher's student IDs
  bool isLoading = true;
  String? gameId;
  String? title;
  String? gameSet;
  String? gameCode;
  String? gameRule; // Store game rule to check if it's score mode
  String? userId;
  String _filterType = 'all'; // 'all' or 'my_students'
  String _searchQuery = '';
  Set<String> _selectedStudentIds = {}; // Track selected students for printing

  @override
  void initState() {
    super.initState();
    // Use post frame callback to ensure URL is fully loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getArguments();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _getArguments() {
    // Try to get from Get.arguments first
    final args = Get.arguments as Map<String, dynamic>?;
    
    // If no arguments, try to parse from URL parameters
    final uri = Uri.base;
    
    debugPrint('🔍 game_manage: Checking data sources...');
    debugPrint('  Get.arguments: $args');
    debugPrint('  URL: ${uri.toString()}');
    debugPrint('  URL query params: ${uri.queryParameters}');
    
    // Update state with parsed values, treating empty strings as null
    setState(() {
      gameId = args?['gameId'] as String? ?? uri.queryParameters['gameId'];
      
      // Handle title - empty string should be treated as null
      final titleFromArgs = args?['title'] as String?;
      final titleFromUrl = uri.queryParameters['title'];
      title = (titleFromArgs != null && titleFromArgs.isNotEmpty) ? titleFromArgs : 
              (titleFromUrl != null && titleFromUrl.isNotEmpty) ? titleFromUrl : null;
      
      // Handle gameSet - empty string should be treated as null
      final gameSetFromArgs = args?['gameSet'] as String?;
      final gameSetFromUrl = uri.queryParameters['gameSet'];
      gameSet = (gameSetFromArgs != null && gameSetFromArgs.isNotEmpty) ? gameSetFromArgs : 
                (gameSetFromUrl != null && gameSetFromUrl.isNotEmpty) ? gameSetFromUrl : null;
      
      // Handle gameCode - empty string should be treated as null
      final gameCodeFromArgs = args?['gameCode'] as String?;
      final gameCodeFromUrl = uri.queryParameters['gameCode'];
      gameCode = (gameCodeFromArgs != null && gameCodeFromArgs.isNotEmpty) ? gameCodeFromArgs : 
                 (gameCodeFromUrl != null && gameCodeFromUrl.isNotEmpty) ? gameCodeFromUrl : null;
      
      userId = args?['userId'] as String? ?? uri.queryParameters['userId'] ?? user?.uid;
    });
    
    debugPrint('📥 game_manage arguments parsed:');
    debugPrint('  gameId: $gameId');
    debugPrint('  title: $title (${title == null ? "NULL - will fetch" : "OK"})');
    debugPrint('  gameSet: $gameSet (${gameSet == null ? "NULL - will fetch" : "OK"})');
    debugPrint('  gameCode: $gameCode (${gameCode == null ? "NULL - will fetch" : "OK"})');
    debugPrint('  userId: $userId');
    
    if (gameId != null && userId != null) {
      debugPrint('✅ Valid arguments, loading data...');
      _loadData();
    } else {
      debugPrint('⚠️ Missing required arguments: gameId=$gameId, userId=$userId');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadData() async {
    if (gameId == null || userId == null) {
      debugPrint('❌ Cannot load data: gameId or userId is null');
      return;
    }
    
    debugPrint('🔄 Starting data load...');
    setState(() {
      isLoading = true;
    });
    
    // ALWAYS fetch game details from Firestore to ensure we have the latest data
    debugPrint('📦 Fetching game details from Firestore...');
    await _fetchGameDetails();
    
    // Fetch completed users, teacher's students, and game rule in parallel
    debugPrint('📦 Fetching users, students, and game rule...');
    final results = await Future.wait([
      _fetchCompletedUsers(gameId!),
      _fetchMyStudentIds(),
      _fetchGameRule(),
    ]);
    
    final users = results[0] as List<Map<String, dynamic>>;
    final studentIds = results[1] as List<String>;
    final rule = results[2] as String?;
    
    debugPrint('✅ Data fetched: ${users.length} users, ${studentIds.length} students');
    
    if (mounted) {
      setState(() {
        allCompletedUsers = users;
        myStudentIds = studentIds;
        completedUsers = users; // Default to all
        gameRule = rule;
        isLoading = false;
      });
      debugPrint('✅ Data load complete and UI updated');
    }
  }
  
  /// Fetch game details from Firestore - ALWAYS updates with latest data
  Future<void> _fetchGameDetails() async {
    try {
      if (gameId == null || userId == null) {
        debugPrint('❌ Cannot fetch game details: gameId or userId is null');
        return;
      }
      
      debugPrint('🔄 Fetching game details from Firestore...');
      debugPrint('  Path: users/$userId/created_games/$gameId');
      
      final gameDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId!)
          .collection('created_games')
          .doc(gameId!)
          .get();
      
      if (gameDoc.exists) {
        final data = gameDoc.data();
        debugPrint('📄 Game document found in Firestore');
        debugPrint('  Raw data: $data');
        
        if (mounted) {
          setState(() {
            // ALWAYS update with Firestore data (source of truth)
            title = data?['title'] as String? ?? title;
            gameSet = data?['gameSet'] as String? ?? gameSet;
            gameCode = data?['gameCode'] as String? ?? gameCode;
          });
          debugPrint('✅ Game details updated from Firestore:');
          debugPrint('  title: $title');
          debugPrint('  gameSet: $gameSet');
          debugPrint('  gameCode: $gameCode');
        }
      } else {
        debugPrint('⚠️ Game document not found in Firestore!');
        debugPrint('  Checked path: users/$userId/created_games/$gameId');
      }
    } catch (e) {
      debugPrint('❌ Error fetching game details: $e');
      debugPrint('  Stack trace: ${StackTrace.current}');
    }
  }

  /// Fetch game rule to check if it's score mode
  Future<String?> _fetchGameRule() async {
    try {
      if (gameId == null || userId == null) return null;

      final gameDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId!)
          .collection('created_games')
          .doc(gameId!)
          .get();

      if (gameDoc.exists) {
        final data = gameDoc.data();
        return data?['gameRule'] as String?;
      }
      return null;
    } catch (e) {
      print('Error fetching game rule: $e');
      return null;
    }
  }

  /// Fetch student IDs that belong to the teacher's classes
  Future<List<String>> _fetchMyStudentIds() async {
    try {
      if (userId == null) return [];
      
      List<String> studentIds = [];
      
      // Get all classes where the teacher is the owner
      QuerySnapshot classesSnapshot = await FirebaseFirestore.instance
          .collection('classes')
          .where('teacherId', isEqualTo: userId)
          .get();
      
      // Collect all student IDs from all classes
      for (var classDoc in classesSnapshot.docs) {
        final classData = classDoc.data() as Map<String, dynamic>;
        final students = List<String>.from(classData['studentIds'] ?? []);
        studentIds.addAll(students);
      }
      
      // Remove duplicates
      return studentIds.toSet().toList();
    } catch (e) {
      print('Error fetching my students: $e');
      return [];
    }
  }

  /// Filter completed users based on selected filter and search query
  void _applyFilter(String filterType) {
    if (allCompletedUsers == null) return;
    
    setState(() {
      _filterType = filterType;
      
      if (filterType == 'all') {
        completedUsers = _applySearchFilter(allCompletedUsers!);
      } else if (filterType == 'my_students' && myStudentIds != null) {
        // Filter to show only students that belong to the teacher
        // We need to match by user ID - but we only have username and profileImage
        // Let's fetch user IDs for completed users and match them
        _filterMyStudents();
      }
    });
  }

  /// Apply search filter to a list of users
  List<Map<String, dynamic>> _applySearchFilter(List<Map<String, dynamic>> users) {
    if (_searchQuery.isEmpty) return users;
    
    return users.where((userData) {
      final username = (userData['username'] as String? ?? '').toLowerCase();
      final fullname = (userData['fullname'] as String? ?? '').toLowerCase();
      final schoolId = (userData['schoolId'] as String? ?? '').toLowerCase();
      final gradeLevel = (userData['gradeLevel'] as String? ?? '').toLowerCase();
      final section = (userData['section'] as String? ?? '').toLowerCase();
      final query = _searchQuery.toLowerCase();
      
      return username.contains(query) ||
             fullname.contains(query) ||
             schoolId.contains(query) ||
             gradeLevel.contains(query) ||
             section.contains(query);
    }).toList();
  }

  /// Filter to show only teacher's students
  void _filterMyStudents() {
    if (allCompletedUsers == null || myStudentIds == null) return;
    
    // Filter using the stored userId in the data
    final filtered = allCompletedUsers!.where((userData) {
      final userId = userData['userId'] as String?;
      return userId != null && myStudentIds!.contains(userId);
    }).toList();
    
    setState(() {
      completedUsers = _applySearchFilter(filtered);
    });
  }

  /// Fetch users who completed a specific game
  Future<List<Map<String, dynamic>>> _fetchCompletedUsers(String gameId) async {
    try {
      List<Map<String, dynamic>> completedUsers = [];

      QuerySnapshot usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      for (var userDoc in usersSnapshot.docs) {
        DocumentSnapshot completedGame = await FirebaseFirestore.instance
            .collection('users')
            .doc(userDoc.id)
            .collection('completed_games')
            .doc(gameId)
            .get();

        if (completedGame.exists) {
          Map<String, dynamic> userData =
              userDoc.data() as Map<String, dynamic>;
          Map<String, dynamic>? completedData =
              completedGame.data() as Map<String, dynamic>?;
          
          String userId = userDoc.id;

          // Fetch scores from game_score subcollection if Score mode
          List<Map<String, dynamic>> roundScoresFromGameScore = [];
          int totalScoreFromGameScore = 0;

          try {
            // Try to get scores from teacher's created_games first (where scores are actually stored)
            if (this.userId != null) {
              QuerySnapshot teacherGameScoreSnapshot;
              try {
                teacherGameScoreSnapshot = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(this.userId!)
                    .collection('created_games')
                    .doc(gameId)
                    .collection('game_score')
                    .where('userId', isEqualTo: userId)
                    .orderBy('page')
                    .get();
              } catch (e) {
                // If orderBy fails (no index), try without orderBy
                teacherGameScoreSnapshot = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(this.userId!)
                    .collection('created_games')
                    .doc(gameId)
                    .collection('game_score')
                    .where('userId', isEqualTo: userId)
                    .get();
              }

              if (teacherGameScoreSnapshot.docs.isNotEmpty) {
                // Convert to list and sort by page manually
                List<QueryDocumentSnapshot> sortedDocs = List.from(
                  teacherGameScoreSnapshot.docs,
                );
                sortedDocs.sort((a, b) {
                  final pageA = (a.data() as Map)['page'] as int? ?? 0;
                  final pageB = (b.data() as Map)['page'] as int? ?? 0;
                  return pageA.compareTo(pageB);
                });

                for (var scoreDoc in sortedDocs) {
                  final scoreData = scoreDoc.data() as Map<String, dynamic>;
                  final page = scoreData['page'] as int? ?? 0;
                  final score = scoreData['score'] as int? ?? 0; // 0/1 for correct/wrong
                  final pageScore = scoreData['pageScore'] as int? ?? 0; // Numeric score for the page

                  roundScoresFromGameScore.add({
                    'round': page,
                    'score': pageScore, // Use pageScore instead of score
                    'correct': score > 0,
                  });
                  totalScoreFromGameScore += pageScore; // Sum pageScore instead of score
                }
              }
            }

            // If not found, try user's created_games (fallback)
            if (roundScoresFromGameScore.isEmpty) {
              QuerySnapshot gameScoreSnapshot;
              try {
                gameScoreSnapshot = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .collection('created_games')
                    .doc(gameId)
                    .collection('game_score')
                    .where('userId', isEqualTo: userId)
                    .orderBy('page')
                    .get();
              } catch (e) {
                // If orderBy fails (no index), try without orderBy
                gameScoreSnapshot = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .collection('created_games')
                    .doc(gameId)
                    .collection('game_score')
                    .where('userId', isEqualTo: userId)
                    .get();
              }

              if (gameScoreSnapshot.docs.isNotEmpty) {
                // Convert to list and sort by page manually
                List<QueryDocumentSnapshot> sortedDocs = List.from(
                  gameScoreSnapshot.docs,
                );
                sortedDocs.sort((a, b) {
                  final pageA = (a.data() as Map)['page'] as int? ?? 0;
                  final pageB = (b.data() as Map)['page'] as int? ?? 0;
                  return pageA.compareTo(pageB);
                });

                for (var scoreDoc in sortedDocs) {
                  final scoreData = scoreDoc.data() as Map<String, dynamic>;
                  final page = scoreData['page'] as int? ?? 0;
                  final score = scoreData['score'] as int? ?? 0; // 0/1 for correct/wrong
                  final pageScore = scoreData['pageScore'] as int? ?? 0; // Numeric score for the page

                  roundScoresFromGameScore.add({
                    'round': page,
                    'score': pageScore, // Use pageScore instead of score
                    'correct': score > 0,
                  });
                  totalScoreFromGameScore += pageScore; // Sum pageScore instead of score
                }
              }
            }
          } catch (e) {
            print('Error fetching game_score: $e');
          }

          // Use game_score data if available, otherwise use completed_games data
          List<Map<String, dynamic>>? finalRoundScores =
              roundScoresFromGameScore.isNotEmpty
              ? roundScoresFromGameScore
              : (completedData?['roundScores'] as List<dynamic>?)
                    ?.map((e) => e as Map<String, dynamic>)
                    .toList();

          // Calculate total score: totalScore from completed_games is the maximum possible total score (set by teacher)
          // Use totalScore from completed_games (set by teacher in game_check) as the maximum possible score
          int finalTotalScore = completedData?['totalScore'] as int? ?? 0;
          
          // If totalScore is not set, fallback to sum of pageScore values or calculate from roundScores
          if (finalTotalScore == 0) {
            if (roundScoresFromGameScore.isNotEmpty) {
              // Use sum of pageScore from game_score as fallback
              finalTotalScore = totalScoreFromGameScore;
            } else if (finalRoundScores != null) {
              // Fallback: calculate from roundScores if available
              for (var roundScore in finalRoundScores) {
                finalTotalScore += (roundScore['score'] as int? ?? 0);
              }
            }
          }
          
          completedUsers.add({
            'userId': userId, // Store user ID for filtering
            'username': userData['username'] ?? 'Unknown User',
            'email': userData['email'] ?? '', // Add email for printing
            'profileImage': userData['profileImage'] ?? '',
            'fullname': userData['fullname'] ?? 'Not set',
            'schoolId': userData['schoolId'] ?? 'Not set',
            'gradeLevel': userData['gradeLevel'] ?? 'Not set',
            'section': userData['section'] ?? 'Not set',
            'completedAt': completedData?['completedAt'] ?? null,
            'startedAt': completedData?['startedAt'] ?? null,
            'totalScore': finalTotalScore,
            'roundScores': finalRoundScores,
            'gameRule': completedData?['gameRule'] ?? gameRule,
            'pendingReview': completedData?['pendingReview'] ?? false,
            'reviewStatus': completedData?['reviewStatus'] ?? 'completed',
          });
        }
      }

      return completedUsers;
    } catch (e) {
      print('Error fetching completed users: $e');
      return [];
    }
  }

  Future<void> _unpublishGame() async {
    if (userId == null || gameId == null) return;

    await FirebaseFirestore.instance
        .collection("users")
        .doc(userId!)
        .collection("created_games")
        .doc(gameId!)
        .update({'publish': false});

    try {
      await FirebaseFirestore.instance
          .collection("published_games")
          .doc(gameId!)
          .delete();
    } catch (e) {
      print('Note: Could not delete from published_games collection: $e');
    }

    Get.offAllNamed('/game_published');
    Get.snackbar(
      'Success',
      'Game unpublished successfully',
      backgroundColor: Colors.green,
      colorText: Colors.white,
    );
  }

  /// Show dialog to change game code
  Future<void> _showChangeGameCodeDialog() async {
    final TextEditingController gameCodeController = TextEditingController(
      text: gameCode ?? '',
    );

    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2C2F33),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Change Game Code",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Enter the game code for this game:",
              style: GoogleFonts.poppins(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              "Leave empty to make it public",
              style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: gameCodeController,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(8),
                GameCodeFormatter(),
              ],
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
              decoration: InputDecoration(
                hintText: "1234-5678",
                hintStyle: GoogleFonts.poppins(
                  color: Colors.white38,
                  letterSpacing: 2,
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.blue, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                prefixIcon: Icon(Icons.vpn_key, color: Colors.blue),
              ),
            ),
          ],
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
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              if (userId == null || gameId == null) return;
              
              String newGameCode = gameCodeController.text.trim().replaceAll(
                '-',
                '',
              );
              String newGameSet = newGameCode.isEmpty ? "public" : "private";

              await FirebaseFirestore.instance
                  .collection("users")
                  .doc(userId!)
                  .collection("created_games")
                  .doc(gameId!)
                  .update({
                    'gameSet': newGameSet,
                    'gameCode': newGameCode.isEmpty ? null : newGameCode,
                  });
              
              setState(() {
                gameCode = newGameCode.isEmpty ? null : newGameCode;
                gameSet = newGameSet;
              });
              
              Navigator.pop(ctx);
              Get.snackbar(
                'Success',
                'Game code updated successfully',
                backgroundColor: Colors.green,
                colorText: Colors.white,
              );
            },
            child: Text(
              "Save",
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }



  /// Show confirmation dialog for unpublishing
  Future<void> _showUnpublishDialog() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2C2F33),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.orangeAccent),
            const SizedBox(width: 8),
            Text(
              "Confirm Unpublish",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        content: Text(
          "Are you sure you want to unpublish \"${title ?? 'this game'}\"?\nThis will remove it from the published games list.",
          style: GoogleFonts.poppins(color: Colors.white70),
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
              backgroundColor: Colors.orangeAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _unpublishGame();
            },
            child: Text(
              "Unpublish",
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  /// View student information dialog (read-only)
  void _viewStudentInfo(String studentId, String studentName, String studentEmail) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            width: 500,
            constraints: const BoxConstraints(maxHeight: 600),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(studentId).snapshots(),
              builder: (context, studentSnapshot) {
                if (studentSnapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 400,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF1E201E),
                      ),
                    ),
                  );
                }

                if (!studentSnapshot.hasData || !studentSnapshot.data!.exists) {
                  return SizedBox(
                    height: 400,
                    child: Center(
                      child: Text(
                        'Student data not found',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  );
                }

                final studentData = studentSnapshot.data!.data() as Map<String, dynamic>;
                final fullname = studentData['fullname'] ?? 'Not set';
                final email = studentData['email'] ?? studentEmail;
                final profileImageBase64 = studentData['profileImage'];
                final schoolId = studentData['schoolId'] ?? 'Not set';
                final gradeLevel = studentData['gradeLevel'] ?? 'Not set';
                final section = studentData['section'] ?? 'Not set';

                // Check if all important fields are set
                bool hasCompleteInfo = fullname != 'Not set' &&
                    schoolId != 'Not set' &&
                    gradeLevel != 'Not set' &&
                    section != 'Not set';

                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.person,
                              color: Colors.blue,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Student Details',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Profile Image
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.blue[700],
                        backgroundImage: profileImageBase64 != null
                            ? MemoryImage(base64Decode(profileImageBase64))
                            : null,
                        child: profileImageBase64 == null
                            ? Text(
                                fullname.isNotEmpty && fullname != 'Not set'
                                    ? fullname[0].toUpperCase()
                                    : 'S',
                                style: GoogleFonts.poppins(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 20),

                      // Show warning if incomplete info
                      if (!hasCompleteInfo)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange[300]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber, color: Colors.orange[700], size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Student unknown information',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange[900],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Information Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDetailRow('Full Name', fullname),
                            const SizedBox(height: 12),
                            _buildDetailRow('Email', email),
                            const SizedBox(height: 12),
                            _buildDetailRow('School ID', schoolId),
                            const SizedBox(height: 12),
                            _buildDetailRow('Grade Level', gradeLevel),
                            const SizedBox(height: 12),
                            _buildDetailRow('Section', section),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Close button only (no edit)
                      AnimatedButton(
                        width: 120,
                        height: 45,
                        color: const Color(0xFF1E201E),
                        shadowDegree: ShadowDegree.light,
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: Text(
                          'Close',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    bool isNotSet = value == 'Not set' || value.isEmpty;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: isNotSet ? Colors.grey[400] : Colors.black87,
              fontStyle: isNotSet ? FontStyle.italic : FontStyle.normal,
            ),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// Format date helper
  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    try {
      DateTime date;
      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else if (timestamp is String) {
        date = DateTime.parse(timestamp);
      } else {
        return 'Unknown';
      }
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Unknown';
    }
  }

  /// Show print dialog for all players
  Future<void> _showPrintDialog() async {
    // Get currently displayed players (filtered by search)
    final players = completedUsers ?? [];

    if (players.isEmpty) {
      Get.snackbar(
        'No Players',
        'No players found to download',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    // Reset selection if needed
    if (_selectedStudentIds.isEmpty) {
      // Select all by default
      _selectedStudentIds = players
          .map((s) => s['userId'] as String?)
          .where((id) => id != null)
          .cast<String>()
          .toSet();
    }

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF2C2F33),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.download, color: Colors.blue, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Download Student Reports",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 20,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.6,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Select All / Deselect All buttons
                  Row(
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          setDialogState(() {
                            _selectedStudentIds = players
                                .map((s) => s['userId'] as String?)
                                .where((id) => id != null)
                                .cast<String>()
                                .toSet();
                          });
                        },
                        child: Text(
                          "Select All",
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          setDialogState(() {
                            _selectedStudentIds.clear();
                          });
                        },
                        child: Text(
                          "Deselect All",
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Select players to download (${_selectedStudentIds.length}/${players.length} selected):',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // List of players with checkboxes
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: players.map((student) {
                          final userId = student['userId'] as String? ?? '';
                          final username = student['username'] ?? 'Unknown';
                          final isSelected = _selectedStudentIds.contains(
                            userId,
                          );

                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (value) {
                              setDialogState(() {
                                if (value == true) {
                                  _selectedStudentIds.add(userId);
                                } else {
                                  _selectedStudentIds.remove(userId);
                                }
                              });
                            },
                            title: Text(
                              username,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                            activeColor: Colors.blue,
                            checkColor: Colors.white,
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
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
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                if (_selectedStudentIds.isEmpty) {
                  Get.snackbar(
                    'No Selection',
                    'Please select at least one student to download',
                    backgroundColor: Colors.orange,
                    colorText: Colors.white,
                  );
                  return;
                }
                _showDownloadConfirmation();
              },
              child: Text(
                "Download (${_selectedStudentIds.length})",
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Helper function to escape CSV fields
  String _escapeCsvField(String field) {
    // If field contains comma, quote, or newline, wrap in quotes and escape quotes
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  /// Show confirmation dialog before downloading student reports
  Future<void> _showDownloadConfirmation() async {
    // Get selected students
    final selectedStudents =
        allCompletedUsers?.where((userData) {
          final userId = userData['userId'] as String?;
          return userId != null && _selectedStudentIds.contains(userId);
        }).toList() ??
        [];

    if (selectedStudents.isEmpty) {
      Get.snackbar(
        'Error',
        'No students selected for export',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    if (!mounted) return;

    // Show confirmation dialog
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2C2F33),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.download, color: Colors.blue, size: 28),
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
          "Do you want to download CSV file for ${selectedStudents.length} selected student(s)?",
          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
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
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _printStudentReports();
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

  /// Export student reports as CSV/Excel
  Future<void> _printStudentReports() async {
    if (gameId == null || title == null) return;

    // Get selected students
    final selectedStudents =
        allCompletedUsers?.where((userData) {
          final userId = userData['userId'] as String?;
          return userId != null && _selectedStudentIds.contains(userId);
        }).toList() ??
        [];

    if (selectedStudents.isEmpty) {
      return;
    }

    // Build CSV content
    final StringBuffer csvBuffer = StringBuffer();
    final generatedDate = DateTime.now().toString().split('.')[0];

    // Add header
    csvBuffer.writeln('Game: ${_escapeCsvField(title!)}');
    csvBuffer.writeln('Generated on: $generatedDate');
    csvBuffer.writeln(''); // Empty line

    // Main data headers
    csvBuffer.writeln(
      'Username,Email,Completed Date,Time Taken,Total Score,Total Rounds,'
      'Round 1 Status,Round 1 Score,Round 2 Status,Round 2 Score,'
      'Round 3 Status,Round 3 Score,Round 4 Status,Round 4 Score,'
      'Round 5 Status,Round 5 Score,Round 6 Status,Round 6 Score,'
      'Round 7 Status,Round 7 Score,Round 8 Status,Round 8 Score,'
      'Round 9 Status,Round 9 Score,Round 10 Status,Round 10 Score',
    );

    // Add each student's data
    for (var student in selectedStudents) {
      final username = student['username']?.toString() ?? 'Unknown User';
      final email = student['email']?.toString() ?? 'N/A';
      final completedAt = student['completedAt'];
      final startedAt = student['startedAt'];
      final completedDate = _formatDate(completedAt);
      final duration = _formatDuration(startedAt, completedAt);
      final totalScore = student['totalScore'] ?? 0;
      final roundScoresRaw = student['roundScores'];

      // Parse round scores
      List<dynamic> roundScores = [];
      if (roundScoresRaw != null) {
        if (roundScoresRaw is List) {
          roundScores = roundScoresRaw;
        } else if (roundScoresRaw is Map) {
          roundScores = roundScoresRaw.values.toList();
        } else {
          roundScores = [roundScoresRaw];
        }
      }

      // Build CSV row
      final List<String> row = [
        _escapeCsvField(username),
        _escapeCsvField(email),
        _escapeCsvField(completedDate),
        _escapeCsvField(duration),
        totalScore.toString(),
        roundScores.isNotEmpty ? roundScores.length.toString() : '0',
      ];

      // Add round data (up to 10 rounds)
      for (int i = 1; i <= 10; i++) {
        bool found = false;
        for (var roundDataRaw in roundScores) {
          if (roundDataRaw is! Map) continue;
          final roundData = Map<String, dynamic>.from(roundDataRaw);
          final round = roundData['round'] ?? 0;
          if (round == i) {
            final score = roundData['score'] ?? 0;
            final correct = roundData['correct'] ?? false;
            row.add(correct ? 'Correct' : 'Failed');
            row.add(score.toString());
            found = true;
            break;
          }
        }
        if (!found) {
          row.add('');
          row.add('');
        }
      }

      csvBuffer.writeln(row.join(','));
    }

    // Create and download CSV file
    final csvContent = csvBuffer.toString();
    final blob = html.Blob([csvContent], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    
    // Create download link
    html.AnchorElement(href: url)
      ..setAttribute(
        'download',
        'Student_Reports_${DateTime.now().millisecondsSinceEpoch}.csv',
      )
      ..click();
    
    // Clean up
    Future.delayed(const Duration(seconds: 1), () {
      html.Url.revokeObjectUrl(url);
    });

    Get.snackbar(
      'Success',
      'CSV file downloaded for ${selectedStudents.length} student(s)',
      backgroundColor: Colors.green,
      colorText: Colors.white,
    );
  }

  /// Format duration helper (e.g., "3 minutes 20 seconds")
  String _formatDuration(dynamic startedAt, dynamic completedAt) {
    if (startedAt == null || completedAt == null) return 'N/A';

    try {
      DateTime startDate;
      DateTime endDate;

      // Parse start time
      if (startedAt is Timestamp) {
        startDate = startedAt.toDate();
      } else if (startedAt is String) {
        startDate = DateTime.parse(startedAt);
      } else {
        return 'N/A';
      }

      // Parse end time
      if (completedAt is Timestamp) {
        endDate = completedAt.toDate();
      } else if (completedAt is String) {
        endDate = DateTime.parse(completedAt);
      } else {
        return 'N/A';
      }

      // Calculate duration
      Duration duration = endDate.difference(startDate);
      int totalSeconds = duration.inSeconds;

      if (totalSeconds < 0) return 'N/A';

      int minutes = totalSeconds ~/ 60;
      int seconds = totalSeconds % 60;

      if (minutes > 0 && seconds > 0) {
        return '$minutes minute${minutes > 1 ? 's' : ''} $seconds second${seconds > 1 ? 's' : ''}';
      } else if (minutes > 0) {
        return '$minutes minute${minutes > 1 ? 's' : ''}';
      } else {
        return '$seconds second${seconds > 1 ? 's' : ''}';
      }
    } catch (e) {
      return 'N/A';
    }
  }

  /// Build status card widget
  Widget _buildStatusCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (gameId == null || title == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF1E201E),
        appBar: AppBar(
          backgroundColor: Colors.white.withOpacity(0.05),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Get.offAllNamed('/game_published'),
          ),
          title: Text(
            "Game Management",
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        body: Center(
          child: Text(
            "No game data found",
            style: GoogleFonts.poppins(color: Colors.white70),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1E201E),
      appBar: AppBar(
        backgroundColor: Colors.white.withOpacity(0.05),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.offAllNamed('/game_published'),
        ),
        title: Text(
          "Game Management",
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isSmallScreen = constraints.maxWidth < 600;
          final padding = isSmallScreen ? 16.0 : 24.0;

          return SingleChildScrollView(
            padding: EdgeInsets.all(padding),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - kToolbarHeight - padding * 2,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.purple[700]!, Colors.purple[500]!],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.settings, color: Colors.white, size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            title!,
                            style: GoogleFonts.poppins(
                              fontSize: isSmallScreen ? 18 : 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Control Section
                  Text(
                    "CONTROL",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Control Buttons - Responsive scrollable layout
                  SizedBox(
                    height: 50,
                    child: Scrollbar(
                      thumbVisibility: true,
                      child: ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context).copyWith(
                          dragDevices: {
                            PointerDeviceKind.mouse,
                            PointerDeviceKind.touch,
                          },
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                AnimatedButton(
                                  height: 50,
                                  width: 50,
                                  color: Colors.orange,
                                  shadowDegree: ShadowDegree.light,
                                  onPressed: _showUnpublishDialog,
                                  child: const Icon(Icons.unpublished, color: Colors.white, size: 20),
                                ),
                                const SizedBox(width: 12),
                                AnimatedButton(
                                  height: 50,
                                  width: 50,
                                  color: Colors.blue,
                                  shadowDegree: ShadowDegree.light,
                                  onPressed: _showChangeGameCodeDialog,
                                  child: const Icon(Icons.lock, color: Colors.white, size: 20),
                                ),
                                const SizedBox(width: 12),
                                AnimatedButton(
                                  height: 50,
                                  width: 50,
                                  color: Colors.green,
                                  shadowDegree: ShadowDegree.light,
                                  onPressed: () {
                                    Get.toNamed(
                                      "/game_edit",
                                      arguments: {"gameId": gameId},
                                    );
                                  },
                                  child: const Icon(Icons.edit, color: Colors.white, size: 20),
                                ),
                                // Check button - only visible for score mode
                                if (gameRule == 'score') ...[
                                  const SizedBox(width: 12),
                                  AnimatedButton(
                                    height: 50,
                                    width: 50,
                                    color: Colors.purple,
                                    shadowDegree: ShadowDegree.light,
                                    onPressed: () {
                                      // Navigate to first student for checking
                                      if (completedUsers != null && completedUsers!.isNotEmpty) {
                                        final firstStudent = completedUsers!.first;
                                        final studentUserId = firstStudent['userId'] as String?;
                                        final studentUsername = firstStudent['username'] as String?;
                                        if (studentUserId != null && gameId != null) {
                                          Get.toNamed(
                                            '/game_check?gameId=$gameId&title=${Uri.encodeComponent(title ?? '')}&userId=${userId ?? ''}&studentUserId=$studentUserId&studentUsername=${Uri.encodeComponent(studentUsername ?? '')}',
                                            arguments: {
                                              "gameId": gameId,
                                              "title": title,
                                              "userId": userId,
                                              "studentUserId": studentUserId,
                                              "studentUsername": studentUsername,
                                            },
                                          );
                                        }
                                      }
                                    },
                                    child: const Icon(Icons.check, color: Colors.white, size: 20),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 24),

                  // Status Section
                  Text(
                    "STATUS",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Status Cards - Scrollable row
                  SizedBox(
                    height: 140,
                    child: Scrollbar(
                      thumbVisibility: true,
                      child: ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context).copyWith(
                          dragDevices: {
                            PointerDeviceKind.mouse,
                            PointerDeviceKind.touch,
                          },
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 130,
                                  child: _buildStatusCard(
                                    "Total Players",
                                    isLoading
                                        ? "..."
                                        : "${completedUsers?.length ?? 0}",
                                    Icons.people,
                                    Colors.purple,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 130,
                                  child: _buildStatusCard(
                                    "Game Set",
                                    gameSet ?? "None",
                                    Icons.category,
                                    Colors.blue,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 130,
                                  child: _buildStatusCard(
                                    "Game Code",
                                    gameCode ?? "None",
                                    Icons.lock,
                                    Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Players List Section
                  Text(
                    "PLAYERS",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Search bar with Download button
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                              _applyFilter(_filterType);
                            });
                          },
                          style: GoogleFonts.poppins(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Search players...',
                            hintStyle: GoogleFonts.poppins(color: Colors.white54),
                            prefixIcon: const Icon(
                              Icons.search,
                              color: Colors.white54,
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.clear,
                                      color: Colors.white54,
                                    ),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                        _applyFilter(_filterType);
                                      });
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.1),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 15,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Download button
                      AnimatedButton(
                        height: 50,
                        width: 50,
                        color: Colors.green,
                        shadowDegree: ShadowDegree.light,
                        onPressed: _showPrintDialog,
                        child: const Icon(
                          Icons.download,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (isLoading)
                    Container(
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            const CircularProgressIndicator(
                              color: Colors.white,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "Loading players...",
                              style: GoogleFonts.poppins(
                                color: Colors.white54,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (completedUsers == null || completedUsers!.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.inbox,
                              size: 48,
                              color: Colors.white30,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "No players have completed this game yet",
                              style: GoogleFonts.poppins(
                                color: Colors.white54,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      constraints: BoxConstraints(
                        maxHeight: constraints.maxHeight * 0.4,
                      ),
                      child: Scrollbar(
                        thumbVisibility: true,
                        child: ScrollConfiguration(
                          behavior: ScrollConfiguration.of(context).copyWith(
                            dragDevices: {
                              PointerDeviceKind.mouse,
                              PointerDeviceKind.touch,
                            },
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: completedUsers!.length,
                            separatorBuilder: (context, index) => Divider(
                              color: Colors.white.withOpacity(0.1),
                              height: 1,
                            ),
                            itemBuilder: (context, index) {
                              final player = completedUsers![index];
                              final isScoreMode =
                                  (gameRule?.toLowerCase() == 'score' ||
                                  player['gameRule']
                                          ?.toString()
                                          .toLowerCase() ==
                                      'score');
                              
                              // Check pending review with proper boolean handling
                              final pendingReviewValue = player['pendingReview'];
                              final isPendingReview = pendingReviewValue == true || 
                                                      (pendingReviewValue is String && pendingReviewValue.toLowerCase() == 'true');
                              
                              return ListTile(
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: isSmallScreen ? 12 : 16,
                                  vertical: 8,
                                ),
                                leading: CircleAvatar(
                                  backgroundColor: Colors.purple,
                                  backgroundImage:
                                      player['profileImage'] != null &&
                                          player['profileImage']
                                              .toString()
                                              .isNotEmpty
                                      ? MemoryImage(
                                          base64Decode(player['profileImage']),
                                        )
                                      : null,
                                  child:
                                      player['profileImage'] == null ||
                                          player['profileImage']
                                              .toString()
                                              .isEmpty
                                      ? Text(
                                          player['username'][0].toUpperCase(),
                                          style: GoogleFonts.poppins(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      : null,
                                ),
                                title: Text(
                                  player['username'],
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (player['completedAt'] != null)
                                      Text(
                                        "Completed: ${_formatDate(player['completedAt'])}",
                                        style: GoogleFonts.poppins(
                                          color: Colors.white54,
                                          fontSize: 12,
                                        ),
                                      ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "Time: ${_formatDuration(player['startedAt'], player['completedAt'])}",
                                      style: GoogleFonts.poppins(
                                        color: Colors.blue.shade300,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (isScoreMode &&
                                        player['totalScore'] != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          isPendingReview
                                              ? "⏳ Pending Review"
                                              : "Total Score: ${player['totalScore']}",
                                          style: GoogleFonts.poppins(
                                            color: isPendingReview
                                                ? Colors.orange.shade300
                                                : Colors.amber.shade300,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Person info button
                                    AnimatedButton(
                                      height: 36,
                                      width: 36,
                                      color: Colors.blue,
                                      shadowDegree: ShadowDegree.light,
                                      onPressed: () {
                                        _viewStudentInfo(
                                          player['userId'] ?? '',
                                          player['username'] ?? 'Unknown',
                                          player['email'] ?? '',
                                        );
                                      },
                                      child: const Icon(
                                        Icons.person,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (isPendingReview)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: Icon(
                                          Icons.pending_actions,
                                          color: Colors.orange,
                                          size: 20,
                                        ),
                                      )
                                    else if (isScoreMode &&
                                        player['totalScore'] != null)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 8,
                                        ),
                                        child: Icon(
                                          Icons.emoji_events,
                                          color: Colors.amber,
                                          size: 20,
                                        ),
                                      ),
                                    Icon(
                                      isPendingReview ? Icons.rate_review : Icons.check_circle,
                                      color: isPendingReview ? Colors.orange : Colors.green,
                                    ),
                                  ],
                                ),
                                onTap: null,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// Custom formatter for game code: 1234-5678
class GameCodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;

    // Remove any existing dashes
    final digitsOnly = text.replaceAll('-', '');

    // If more than 8 digits, truncate
    if (digitsOnly.length > 8) {
      return oldValue;
    }

    // Format with dash after 4th digit
    String formatted = digitsOnly;
    if (digitsOnly.length > 4) {
      formatted = '${digitsOnly.substring(0, 4)}-${digitsOnly.substring(4)}';
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
