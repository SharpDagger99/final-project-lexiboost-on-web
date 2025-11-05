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
import 'package:lexi_on_web/editor/game_check.dart';

class MyManagement extends StatefulWidget {
  const MyManagement({super.key});

  @override
  State<MyManagement> createState() => _MyManagementState();
}

class _MyManagementState extends State<MyManagement> {
  final User? user = FirebaseAuth.instance.currentUser;
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
  Set<String> _selectedStudentIds = {}; // Track selected students for printing

  @override
  void initState() {
    super.initState();
    _getArguments();
  }

  void _getArguments() {
    final args = Get.arguments as Map<String, dynamic>?;
    if (args != null) {
      setState(() {
        gameId = args['gameId'] as String?;
        title = args['title'] as String?;
        gameSet = args['gameSet'] as String?;
        gameCode = args['gameCode'] as String?;
        userId = args['userId'] as String? ?? user?.uid;
      });
      if (gameId != null) {
        _loadData();
      }
    }
  }

  Future<void> _loadData() async {
    if (gameId == null || userId == null) return;
    
    // Fetch completed users, teacher's students, and game rule in parallel
    final results = await Future.wait([
      _fetchCompletedUsers(gameId!),
      _fetchMyStudentIds(),
      _fetchGameRule(),
    ]);
    
    final users = results[0] as List<Map<String, dynamic>>;
    final studentIds = results[1] as List<String>;
    final rule = results[2] as String?;
    
    if (mounted) {
      setState(() {
        allCompletedUsers = users;
        myStudentIds = studentIds;
        completedUsers = users; // Default to all
        gameRule = rule;
        isLoading = false;
      });
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

  /// Filter completed users based on selected filter
  void _applyFilter(String filterType) {
    if (allCompletedUsers == null) return;
    
    setState(() {
      _filterType = filterType;
      
      if (filterType == 'all') {
        completedUsers = allCompletedUsers;
      } else if (filterType == 'my_students' && myStudentIds != null) {
        // Filter to show only students that belong to the teacher
        // We need to match by user ID - but we only have username and profileImage
        // Let's fetch user IDs for completed users and match them
        _filterMyStudents();
      }
    });
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
      completedUsers = filtered;
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
                  final score = scoreData['score'] as int? ?? 0;

                  roundScoresFromGameScore.add({
                    'round': page,
                    'score': score,
                    'correct': score > 0,
                  });
                  totalScoreFromGameScore += score;
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
                  final score = scoreData['score'] as int? ?? 0;

                  roundScoresFromGameScore.add({
                    'round': page,
                    'score': score,
                    'correct': score > 0,
                  });
                  totalScoreFromGameScore += score;
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

          int finalTotalScore = roundScoresFromGameScore.isNotEmpty
              ? totalScoreFromGameScore
              : (completedData?['totalScore'] as int? ?? 0);
          
          completedUsers.add({
            'userId': userId, // Store user ID for filtering
            'username': userData['username'] ?? 'Unknown User',
            'email': userData['email'] ?? '', // Add email for printing
            'profileImage': userData['profileImage'] ?? '',
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

    Get.back();
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

  /// Show confirmation dialog before navigating to game check
  Future<void> _showReviewConfirmation(Map<String, dynamic> player) async {
    print('🔵 _showReviewConfirmation called for player: ${player['username']}');
    
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        print('🔵 Dialog builder called');
        return AlertDialog(
          backgroundColor: const Color(0xFF2C2F33),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.rate_review, color: Colors.orange, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Review Submission",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            "Do you want to review ${player['username']}'s submission?\n\nYou'll be able to check their answers and mark them as correct or incorrect.",
            style: GoogleFonts.poppins(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                print('🔴 Cancel button pressed');
                Navigator.of(ctx).pop(false);
              },
              child: Text(
                "Cancel",
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                print('🟢 Continue button pressed');
                Navigator.of(ctx).pop(true);
              },
              child: Text(
                "Continue",
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
    
    print('🔵 Dialog closed. confirmed value: $confirmed');
    print('🔵 mounted state: $mounted');
    
    // Navigate after dialog closes if user confirmed
    if (confirmed == true) {
      print('📋 Navigating to game_check with:');
      print('  gameId: $gameId');
      print('  title: $title');
      print('  userId: $userId');
      print('  studentUserId: ${player['userId']}');
      print('  studentUsername: ${player['username']}');
      
      try {
        if (mounted) {
          print('📋 Calling Get.toNamed...');
          
          // Try GetX navigation
          final navigationArgs = {
            "gameId": gameId,
            "title": title,
            "userId": userId,
            "studentUserId": player['userId'],
            "studentUsername": player['username'],
          };
          
          print('📋 Calling Get.toNamed with arguments: $navigationArgs');
          
          try {
            Get.toNamed(
              "/game_check",
              arguments: navigationArgs,
            );
            print('✅ Get.toNamed called successfully');
          } catch (getError) {
            print('⚠️ Get.toNamed failed: $getError');
            print('📋 Trying Get.to() with direct page...');
            
            // Fallback: Use Get.to() directly
            try {
              Get.to(
                () => const MyGameCheck(),
                arguments: navigationArgs,
              );
              print('✅ Get.to() called successfully');
            } catch (getToError) {
              print('❌ Get.to() also failed: $getToError');
              print('📋 Last resort: Using Navigator.push with MaterialPageRoute...');
              
              // Last resort: Use Navigator directly
              if (mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MyGameCheck(),
                    settings: RouteSettings(arguments: navigationArgs),
                  ),
                );
                print('✅ Navigator.push called successfully');
              }
            }
          }
        } else {
          print('⚠️ Widget not mounted, cannot navigate');
        }
      } catch (e, stackTrace) {
        print('❌ Error navigating to game_check: $e');
        print('❌ Stack trace: $stackTrace');
      }
    } else {
      print('⚠️ Navigation cancelled (confirmed: $confirmed)');
    }
  }

  /// Show score details dialog for Score mode
  Future<void> _showScoreDetails(Map<String, dynamic> player) async {
    try {
      final roundScoresRaw = player['roundScores'];
      List<dynamic> roundScores = [];

      // Handle different data formats from Firestore
      if (roundScoresRaw != null) {
        if (roundScoresRaw is List) {
          roundScores = roundScoresRaw;
        } else if (roundScoresRaw is Map) {
          // If it's a map, convert values to list
          roundScores = roundScoresRaw.values.toList();
        } else {
          // Single value - wrap in list
          roundScores = [roundScoresRaw];
        }
      }

      final totalScore = player['totalScore'] ?? 0;
      final username = player['username'] ?? 'Unknown User';

      if (roundScores.isEmpty) {
        // Show a message if no score data available
        Get.snackbar(
          'No Score Data',
          'Score data not available for this player',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
        return;
      }

      if (!mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext ctx) => AlertDialog(
          backgroundColor: const Color(0xFF2C2F33),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.emoji_events, color: Colors.amber, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "User Score",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                username,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Round-by-round scores
                    Text(
                      'Round Details:',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // List of rounds
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: roundScores.length,
                      itemBuilder: (context, index) {
                        final roundDataRaw = roundScores[index];

                        if (roundDataRaw is! Map) {
                          return const SizedBox.shrink();
                        }

                        final roundData = Map<String, dynamic>.from(
                          roundDataRaw,
                        );
                        final round = roundData['round'] ?? (index + 1);
                        final score = roundData['score'] ?? 0;
                        final correct = roundData['correct'] ?? false;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: correct
                                ? Colors.green.withOpacity(0.2)
                                : Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: correct ? Colors.green : Colors.red,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: correct ? Colors.green : Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '$round',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Round $round',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      correct
                                          ? '✓ Correct (+$score)'
                                          : '✗ Failed (0)',
                                      style: GoogleFonts.poppins(
                                        color: correct
                                            ? Colors.green[300]
                                            : Colors.red[300],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: correct
                                      ? Colors.green
                                      : Colors.red.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '$score',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 20),

                    // Total Score Card at the bottom
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.amber[700]!, Colors.amber[500]!],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Total Score',
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$totalScore / ${roundScores.length}',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                "Close",
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      print('Error showing score details: $e');
      if (mounted) {
        Get.snackbar(
          'Error',
          'Failed to load score details: ${e.toString()}',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
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

  /// Show print dialog for My Students section
  Future<void> _showPrintDialog() async {
    // Get filtered my students
    final myStudents =
        allCompletedUsers?.where((userData) {
          final userId = userData['userId'] as String?;
          return userId != null && myStudentIds?.contains(userId) == true;
        }).toList() ??
        [];

    if (myStudents.isEmpty) {
      Get.snackbar(
        'No Students',
        'No students found to print',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    // Reset selection if needed
    if (_selectedStudentIds.isEmpty) {
      // Select all by default
      _selectedStudentIds = myStudents
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
                            _selectedStudentIds = myStudents
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
                    'Select students to print (${_selectedStudentIds.length}/${myStudents.length} selected):',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // List of students with checkboxes
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: myStudents.map((student) {
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
            onPressed: () => Get.back(),
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
          onPressed: () => Get.back(),
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
                                  width: 150,
                                  color: Colors.orange,
                                  shadowDegree: ShadowDegree.light,
                                  onPressed: _showUnpublishDialog,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      const SizedBox(width: 5),
                                      const Icon(Icons.unpublished, color: Colors.white, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        "Unpublish",
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                AnimatedButton(
                                  height: 50,
                                  width: 200, // Increased width to fit "Change Game Code" text
                                  color: Colors.blue,
                                  shadowDegree: ShadowDegree.light,
                                  onPressed: _showChangeGameCodeDialog,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      const SizedBox(width: 5),
                                      const Icon(Icons.lock, color: Colors.white, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        "Change Game Code",
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                AnimatedButton(
                                  height: 50,
                                  width: 170,
                                  color: Colors.green,
                                  shadowDegree: ShadowDegree.light,
                                  onPressed: () {
                                    Get.toNamed(
                                      "/game_edit",
                                      arguments: {"gameId": gameId},
                                    );
                                  },
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      const SizedBox(width: 5),
                                      const Icon(Icons.edit, color: Colors.white, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        "Edit Game Set",
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                    ],
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
                    height: 150,
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
                                  width: 300,
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
                                  width: 300,
                                  child: _buildStatusCard(
                                    "Game Set",
                                    gameSet ?? "None",
                                    Icons.category,
                                    Colors.blue,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 300,
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
                  Row(
                    children: [
                      Text(
                        "PLAYERS WHO COMPLETED",
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const Spacer(),
                      // Filter Buttons and Print Button
                      Row(
                        children: [
                          AnimatedButton(
                            height: 36,
                            width: 100,
                            color: _filterType == 'all' ? Colors.blue : Colors.grey.shade700,
                            shadowDegree: ShadowDegree.light,
                            onPressed: () => _applyFilter('all'),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.people_outline,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "All",
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          AnimatedButton(
                            height: 36,
                            width: 120,
                            color: _filterType == 'my_students' ? Colors.purple : Colors.grey.shade700,
                            shadowDegree: ShadowDegree.light,
                            onPressed: () => _applyFilter('my_students'),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.person_outline,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "My Students",
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Print button - only show when My Students filter is active
                          if (_filterType == 'my_students')
                            Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: AnimatedButton(
                                height: 36,
                                width: 100,
                                color: Colors.green,
                                shadowDegree: ShadowDegree.light,
                                onPressed: _showPrintDialog,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.download,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      "Download",
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
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
                                onTap: () async {
                                    // Check if pending review first (priority)
                                    final pendingReviewValue = player['pendingReview'];
                                    final bool isActuallyPending = pendingReviewValue == true || 
                                                                   (pendingReviewValue is String && pendingReviewValue.toLowerCase() == 'true');
                                    
                                    if (isActuallyPending) {
                                      await _showReviewConfirmation(player);
                                    } else if (isScoreMode) {
                                      await _showScoreDetails(player);
                                    }
                                  },
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
