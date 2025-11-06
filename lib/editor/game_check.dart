// ignore_for_file: avoid_print, use_build_context_synchronously, deprecated_member_use

import 'package:animated_button/animated_button.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

class MyGameCheck extends StatefulWidget {
  const MyGameCheck({super.key});

  @override
  State<MyGameCheck> createState() => _MyGameCheckState();
}

class _MyGameCheckState extends State<MyGameCheck> {
  final User? user = FirebaseAuth.instance.currentUser;

  // Arguments from navigation
  String? gameId;
  String? title;
  String? userId; // Teacher's user ID
  String? studentUserId;
  String? studentUsername;

  // Loading state
  bool _isLoading = true;
  bool _isSaving = false;

  // Page data
  List<ReviewPageData> pages = [];
  int currentPageIndex = 0;

  // Responsive design state
  bool _isSmallScreen = false;
  bool _isMediumScreen = false;
  bool _showSidebar = false;
  bool _showColumn3Sidebar = false;

  // Scroll controllers
  final ScrollController _column2ScrollController = ScrollController();
  final ScrollController _sidebarScrollController = ScrollController();
  final ScrollController _column3ScrollController = ScrollController();

  // Page score controllers (map of page index to controller)
  final Map<int, TextEditingController> _pageScoreControllers = {};

  // Total score controller
  final TextEditingController _totalScoreController = TextEditingController();
  int _totalScore = 0; // Total score for the game

  @override
  void initState() {
    super.initState();
    _getArguments();
  }

  @override
  void dispose() {
    _column2ScrollController.dispose();
    _sidebarScrollController.dispose();
    _column3ScrollController.dispose();
    _totalScoreController.dispose();
    // Dispose all page score controllers
    for (var controller in _pageScoreControllers.values) {
      controller.dispose();
    }
    _pageScoreControllers.clear();
    super.dispose();
  }

  void _getArguments() {
    debugPrint('📥 MyGameCheck: Getting arguments...');
    final args = Get.arguments as Map<String, dynamic>?;
    if (args != null) {
      debugPrint('📥 Received arguments: $args');
      setState(() {
        gameId = args['gameId'] as String?;
        title = args['title'] as String?;
        userId = args['userId'] as String?;
        studentUserId = args['studentUserId'] as String?;
        studentUsername = args['studentUsername'] as String?;
      });
      debugPrint('📥 Parsed values:');
      debugPrint('  gameId: $gameId');
      debugPrint('  title: $title');
      debugPrint('  userId: $userId');
      debugPrint('  studentUserId: $studentUserId');
      debugPrint('  studentUsername: $studentUsername');

      if (gameId != null && studentUserId != null) {
        debugPrint('✅ Arguments valid, loading submission data...');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkScreenSize();
          _loadSubmissionData();
        });
      } else {
        debugPrint(
          '⚠️ Missing required arguments: gameId=$gameId, studentUserId=$studentUserId',
        );
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      debugPrint('⚠️ No arguments received!');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Check screen size and update responsive state
  void _checkScreenSize() {
    if (mounted) {
      final screenWidth = MediaQuery.of(context).size.width;
      setState(() {
        _isSmallScreen = screenWidth <= 1366;
        _isMediumScreen = screenWidth <= 1024;
        if (!_isSmallScreen) {
          _showSidebar = false;
        }
        if (!_isMediumScreen) {
          _showColumn3Sidebar = false;
        }
      });
    }
  }

  /// Load the student's submission data for review
  Future<void> _loadSubmissionData() async {
    if (gameId == null || userId == null || studentUserId == null) return;

    try {
      debugPrint(
        'Loading submission data for student: $studentUserId, game: $gameId',
      );

      // Load game rounds from teacher's created_games (ordered by page)
      final gameRoundsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId!)
          .collection('created_games')
          .doc(gameId!)
          .collection('game_rounds');

      // Try to order by 'page' field, fallback to unordered if that fails
      QuerySnapshot gameRoundsSnapshot;
      try {
        gameRoundsSnapshot = await gameRoundsRef.orderBy('page').get();
        debugPrint(
          '✅ Loaded ${gameRoundsSnapshot.docs.length} rounds (ordered by page)',
        );
      } catch (e) {
        debugPrint('⚠️ orderBy failed: $e, loading without ordering');
        gameRoundsSnapshot = await gameRoundsRef.get();
      }

      // Load student's score data
      final scoresRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId!)
          .collection('created_games')
          .doc(gameId!)
          .collection('game_score')
          .where('userId', isEqualTo: studentUserId);

      final scoresSnapshot = await scoresRef.get();

      // Create a map of page -> score
      Map<int, Map<String, dynamic>> scoresMap = {};
      for (var scoreDoc in scoresSnapshot.docs) {
        final scoreData = scoreDoc.data();
        final page = scoreData['page'] as int? ?? 0;
        scoresMap[page] = {
          'score': scoreData['score'] ?? 0, // 0/1 for correct/wrong
          'pageScore':
              scoreData['pageScore'] as int? ?? 0, // Numeric score for the page
          'docId': scoreDoc.id,
        };
      }

      // Load Stroke drawings if available
      final strokeSubmissionsDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId!)
          .collection('created_games')
          .doc(gameId!)
          .collection('stroke_submissions')
          .doc(studentUserId!)
          .get();

      Map<String, String> strokeDrawings = {};
      if (strokeSubmissionsDoc.exists) {
        final strokeData = strokeSubmissionsDoc.data();
        strokeDrawings = Map<String, String>.from(
          strokeData?['drawings'] ?? {},
        );
      }

      // Build pages list
      List<ReviewPageData> loadedPages = [];

      for (var roundDoc in gameRoundsSnapshot.docs) {
        final roundData = roundDoc.data() as Map<String, dynamic>?;
        if (roundData == null) continue;

        final gameType = roundData['gameType'] as String? ?? '';
        // Use the page field from Firestore, or fallback to index + 1
        final pageNumber =
            (roundData['page'] as int?) ?? (loadedPages.length + 1);

        // Load game type specific data
        final gameTypeRef = gameRoundsRef
            .doc(roundDoc.id)
            .collection('game_type');
        final gameTypeSnapshot = await gameTypeRef.get();

        if (gameTypeSnapshot.docs.isEmpty) continue;

        final gameTypeData = gameTypeSnapshot.docs.first.data();

        // Get score for this page
        final scoreData = scoresMap[pageNumber];
        final currentScore = scoreData?['score'] ?? 0;

        // Load Stroke drawing URL and image hint if it's a Stroke game type
        String? strokeImageUrl;
        String? strokeImageHintUrl;
        String sentence = '';
        if (gameType == 'Stroke') {
          strokeImageUrl = strokeDrawings['round$pageNumber'];
          // Load image hint if available (when teacher uses image mode instead of sentence)
          strokeImageHintUrl = gameTypeData['imageUrl'] as String?;
          sentence = gameTypeData['sentence'] as String? ?? '';
        } else {
          sentence = gameTypeData['sentence'] as String? ?? '';
        }

        // Get page score (separate from currentScore which is 0/1 for correct/wrong)
        final pageScore = scoreData?['pageScore'] as int? ?? 0;

        loadedPages.add(
          ReviewPageData(
            gameType: gameType,
            sentence: sentence,
            currentScore: currentScore,
            pageScore: pageScore,
            scoreDocId: scoreData?['docId'],
            strokeImageUrl: strokeImageUrl,
            strokeImageHintUrl: strokeImageHintUrl,
            roundDocId: roundDoc.id,
            pageNumber: pageNumber,
          ),
        );
      }

      debugPrint('✅ Loaded ${loadedPages.length} pages for review');

      // Load total score
      await _loadTotalScore();

      if (mounted) {
        setState(() {
          pages = loadedPages;
          _isLoading = false;
        });

        if (pages.isNotEmpty) {
          // Initialize page score controllers
          for (int i = 0; i < pages.length; i++) {
            if (!_pageScoreControllers.containsKey(i)) {
              _pageScoreControllers[i] = TextEditingController(
                text: pages[i].pageScore.toString(),
              );
            }
          }
          _loadPageData(0);
        }
      }
    } catch (e) {
      debugPrint('Error loading submission data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Load a specific page
  void _loadPageData(int pageIndex) {
    if (pageIndex < 0 || pageIndex >= pages.length) return;

    setState(() {
      currentPageIndex = pageIndex;
      // Ensure page score controller exists and update it with the page's score
      if (!_pageScoreControllers.containsKey(pageIndex)) {
        _pageScoreControllers[pageIndex] = TextEditingController(
          text: pages[pageIndex].pageScore.toString(),
        );
      } else {
        // Update existing controller with current page score
        _pageScoreControllers[pageIndex]!.text = pages[pageIndex].pageScore
            .toString();
      }
    });
  }

  /// Calculate total score from all page scores
  int _calculateTotalScore() {
    int total = 0;
    for (var page in pages) {
      total += page.pageScore;
    }
    return total;
  }

  /// Load total score from Firestore
  Future<void> _loadTotalScore() async {
    if (gameId == null || userId == null || studentUserId == null) return;

    try {
      // Try to get total score from completed_games
      final completedGameDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(studentUserId!)
          .collection('completed_games')
          .doc(gameId!)
          .get();

      if (completedGameDoc.exists) {
        final data = completedGameDoc.data();
        final totalScore = data?['totalScore'] as int? ?? 0;
        setState(() {
          _totalScore = totalScore;
          _totalScoreController.text = totalScore.toString();
        });
        debugPrint('✅ Loaded total score: $totalScore');
      } else {
        // If no total score exists, default to 0
        setState(() {
          _totalScore = 0;
          _totalScoreController.text = '0';
        });
        debugPrint('⚠️ No total score found, defaulting to 0');
      }
    } catch (e) {
      debugPrint('Error loading total score: $e');
      setState(() {
        _totalScore = 0;
        _totalScoreController.text = '0';
      });
    }
  }

  /// Update total score in Firestore
  Future<void> _updateTotalScore(int newScore) async {
    if (gameId == null || studentUserId == null || userId == null) return;

    try {
      // Update total score in completed_games
      await FirebaseFirestore.instance
          .collection('users')
          .doc(studentUserId!)
          .collection('completed_games')
          .doc(gameId!)
          .update({
            'totalScore': newScore,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      setState(() {
        _totalScore = newScore;
      });

      debugPrint('✅ Total score updated: $newScore');
    } catch (e) {
      debugPrint('Error updating total score: $e');
      Get.snackbar(
        'Error',
        'Failed to update total score: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// Update page score for a specific page
  Future<void> _updatePageScore(int pageIndex, int newScore) async {
    if (gameId == null || userId == null || studentUserId == null) return;
    if (pageIndex < 0 || pageIndex >= pages.length) return;

    final pageData = pages[pageIndex];

    try {
      final scoresRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId!)
          .collection('created_games')
          .doc(gameId!)
          .collection('game_score');

      if (pageData.scoreDocId != null) {
        // Update existing score
        await scoresRef.doc(pageData.scoreDocId!).update({
          'pageScore': newScore,
        });
      } else {
        // Create new score entry
        final docRef = await scoresRef.add({
          'userId': studentUserId!,
          'page': pageData.pageNumber,
          'score': pageData.currentScore, // Keep correct/wrong score
          'pageScore': newScore,
        });
        // Update local state with new docId
        setState(() {
          pages[pageIndex] = pageData.copyWith(
            scoreDocId: docRef.id,
            pageScore: newScore,
          );
        });
        return; // Early return since we already updated state
      }

      // Update local state
      setState(() {
        pages[pageIndex] = pageData.copyWith(pageScore: newScore);
      });

      debugPrint(
        '✅ Page score updated: page ${pageData.pageNumber}, score: $newScore',
      );
    } catch (e) {
      debugPrint('Error updating page score: $e');
      Get.snackbar(
        'Error',
        'Failed to update page score: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// Mark answer as correct
  Future<void> _markAsCorrect() async {
    if (currentPageIndex >= pages.length || _isSaving) return;

    setState(() {
      _isSaving = true;
    });

    // Update score to 1 (correct)
    await _updateScore(1);

    setState(() {
      _isSaving = false;
    });

    // Show success message
    Get.snackbar(
      'Marked as Correct  ✓',
      'Score updated successfully',
      backgroundColor: Colors.green,
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );
  }

  /// Mark answer as wrong
  Future<void> _markAsWrong() async {
    if (currentPageIndex >= pages.length || _isSaving) return;

    setState(() {
      _isSaving = true;
    });

    // Update score to 0 (wrong)
    await _updateScore(0);

    setState(() {
      _isSaving = false;
    });

    // Show info message
    Get.snackbar(
      'Marked as Wrong  ✗',
      'Score updated successfully',
      backgroundColor: Colors.orange,
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );
  }

  /// Update the score in Firestore
  Future<void> _updateScore(int newScore) async {
    if (gameId == null || userId == null || studentUserId == null) return;
    if (currentPageIndex >= pages.length) return;

    final pageData = pages[currentPageIndex];

    try {
      final scoresRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId!)
          .collection('created_games')
          .doc(gameId!)
          .collection('game_score');

      if (pageData.scoreDocId != null) {
        // Update existing score
        await scoresRef.doc(pageData.scoreDocId!).update({'score': newScore});
      } else {
        // Create new score entry
        await scoresRef.add({
          'userId': studentUserId!,
          'page': pageData.pageNumber,
          'score': newScore,
        });
      }

      // Update local state
      setState(() {
        pages[currentPageIndex] = pageData.copyWith(currentScore: newScore);
      });

      debugPrint(
        '✅ Score updated: page ${pageData.pageNumber}, score: $newScore',
      );
    } catch (e) {
      debugPrint('Error updating score: $e');
      Get.snackbar(
        'Error',
        'Failed to update score: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// Finish review and update review status
  Future<void> _finishReview() async {
    if (gameId == null || studentUserId == null || userId == null) return;

    try {
      // Calculate awarded score from page scores (sum of pageScore values)
      int awardedScore = _calculateTotalScore();

      // Get maximum total score (from _totalScore which is set by teacher)
      int maxTotalScore = _totalScore > 0 ? _totalScore : awardedScore;

      // Update completed_games to mark as reviewed
      await FirebaseFirestore.instance
          .collection('users')
          .doc(studentUserId!)
          .collection('completed_games')
          .doc(gameId!)
          .update({
            'pendingReview': false,
            'reviewStatus': 'completed',
            'totalScore': maxTotalScore, // Save maximum total score
            'reviewedAt': FieldValue.serverTimestamp(),
            'reviewedBy': user?.uid,
          });

      debugPrint(
        '✅ Review completed. Awarded score: $awardedScore, Max total score: $maxTotalScore',
      );

      // Show success dialog
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF2C2F33),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Review Complete",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "You've finished reviewing $studentUsername's submission.",
                style: GoogleFonts.poppins(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green, width: 2),
                ),
                child: Column(
                  children: [
                    Text(
                      "Final Score",
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "$awardedScore / $maxTotalScore",
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
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Get.back(); // Go back to game_manage
              },
              child: Text(
                "Done",
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Error finishing review: $e');
      Get.snackbar(
        'Error',
        'Failed to save review: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _goToPreviousPage() {
    if (currentPageIndex > 0) {
      _loadPageData(currentPageIndex - 1);
    }
  }

  void _goToNextPage() {
    if (currentPageIndex < pages.length - 1) {
      _loadPageData(currentPageIndex + 1);
    }
  }

  /// Reset all checking scores to allow rechecking
  Future<void> _resetChecking() async {
    if (gameId == null || userId == null || studentUserId == null) return;
    if (_isSaving) return;

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2C2F33),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.orange, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Reset Checking",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          "Are you sure you want to reset all checking scores? This will clear all marked correct/wrong answers.",
          style: GoogleFonts.poppins(color: Colors.white70),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
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
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              "Reset",
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final scoresRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId!)
          .collection('created_games')
          .doc(gameId!)
          .collection('game_score');

      // Reset all scores to 0 (unmarked) - both currentScore and pageScore
      for (var page in pages) {
        if (page.scoreDocId != null) {
          await scoresRef.doc(page.scoreDocId!).update({
            'score': 0,
            'pageScore': 0,
          });
        }
      }

      // Update local state
      setState(() {
        for (int i = 0; i < pages.length; i++) {
          pages[i] = pages[i].copyWith(currentScore: 0, pageScore: 0);
          // Update page score controller
          if (_pageScoreControllers.containsKey(i)) {
            _pageScoreControllers[i]!.text = '0';
          }
        }
        _isSaving = false;
      });

      Get.snackbar(
        'Reset Complete',
        'All checking scores have been reset',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );

      debugPrint('✅ All checking scores reset');
    } catch (e) {
      debugPrint('Error resetting checking: $e');
      setState(() {
        _isSaving = false;
      });
      Get.snackbar(
        'Error',
        'Failed to reset checking: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// Build Column 1 content (Student Info & Navigation)
  Widget _buildColumn1Content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Student Info Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.blue.withOpacity(0.2),
                Colors.purple.withOpacity(0.2),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.blue,
                    child: Text(
                      studentUsername?.substring(0, 1).toUpperCase() ?? 'S',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          studentUsername ?? 'Unknown',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          title ?? '',
                          style: GoogleFonts.poppins(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(color: Colors.white24, height: 24),
              Row(
                children: [
                  const Icon(Icons.description, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    "Page ${currentPageIndex + 1} of ${pages.length}",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Progress indicator
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Review Progress",
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.white70),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: pages.isEmpty
                    ? 0
                    : (currentPageIndex + 1) / pages.length,
                backgroundColor: Colors.white.withOpacity(0.1),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
                minHeight: 8,
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),
        const Divider(color: Colors.white24),
        const SizedBox(height: 20),

        // Total Score Display
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.green.withOpacity(0.2),
                Colors.blue.withOpacity(0.2),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.withOpacity(0.3), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Total Score",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "${_calculateTotalScore()}",
                style: GoogleFonts.poppins(
                  fontSize: 32,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        const Divider(color: Colors.white24),
        const SizedBox(height: 20),

        // Finish Review and Reset Checking buttons
        Row(
          children: [
            AnimatedButton(
              height: 50,
              width: 150,
              color: Colors.green,
              shadowDegree: ShadowDegree.dark,
              onPressed: _finishReview,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        "Finish",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            AnimatedButton(
              height: 50,
              width: 200,
              color: Colors.orange,
              shadowDegree: ShadowDegree.dark,
              onPressed: _isSaving ? () {} : _resetChecking,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.refresh,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              "Reset Checking",
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ],
    );
  }

  /// Build Column 3 content (Review Controls)
  Widget _buildColumn3Content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Review Controls",
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        const Divider(color: Colors.white24),
        const SizedBox(height: 20),

        // Correct/Wrong buttons in Row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Correct button
            AnimatedButton(
              height: 50,
              width: 150,
              color: Colors.green,
              shadowDegree: ShadowDegree.dark,
              onPressed: _isSaving ? () {} : _markAsCorrect,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.white,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              "Correct",
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),

            const SizedBox(width: 16),

            // Wrong button
            AnimatedButton(
              height: 50,
              width: 150,
              color: Colors.red,
              shadowDegree: ShadowDegree.dark,
              onPressed: _isSaving ? () {} : _markAsWrong,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cancel, color: Colors.white, size: 28),
                        const SizedBox(width: 12),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              "Wrong",
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),

        const SizedBox(height: 24),
        const Divider(color: Colors.white24),
        const SizedBox(height: 24),

        // Page Score TextField
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Page Score:",
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.3),
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                controller: _pageScoreControllers.containsKey(currentPageIndex)
                    ? _pageScoreControllers[currentPageIndex]!
                    : TextEditingController(text: '0'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: "Enter page score",
                  hintStyle: GoogleFonts.poppins(
                    color: Colors.black54,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                ),
                textAlign: TextAlign.center,
                onChanged: (value) {
                  // Debounce the update to avoid too many Firestore calls
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (value.isNotEmpty) {
                      final score = int.tryParse(value) ?? 0;
                      if (pages.isNotEmpty &&
                          pages[currentPageIndex].pageScore != score) {
                        _updatePageScore(currentPageIndex, score);
                      }
                    }
                  });
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Total Score TextField
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Total Score:",
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.purple.withOpacity(0.3),
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                controller: _totalScoreController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: "Enter total score",
                  hintStyle: GoogleFonts.poppins(
                    color: Colors.black54,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                ),
                textAlign: TextAlign.center,
                onChanged: (value) {
                  // Debounce the update to avoid too many Firestore calls
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (value.isNotEmpty) {
                      final score = int.tryParse(value) ?? 0;
                      if (score != _totalScore) {
                        _updateTotalScore(score);
                      }
                    }
                  });
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Current score indicator
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color:
                        pages.isNotEmpty &&
                            pages[currentPageIndex].currentScore > 0
                        ? Colors.green.withOpacity(0.15)
                        : Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          pages.isNotEmpty &&
                              pages[currentPageIndex].currentScore > 0
                          ? Colors.green
                          : Colors.orange,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        pages.isNotEmpty &&
                                pages[currentPageIndex].currentScore > 0
                            ? Icons.check_circle
                            : Icons.pending,
                        color:
                            pages.isNotEmpty &&
                                pages[currentPageIndex].currentScore > 0
                            ? Colors.green
                            : Colors.orange,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            pages.isNotEmpty &&
                                    pages[currentPageIndex].currentScore > 0
                                ? "Marked as Correct"
                                : "Not Yet Reviewed",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),
        const Divider(color: Colors.white24),
        const SizedBox(height: 20),

        // Page navigation
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Flexible(
              child: AnimatedButton(
                height: 50,
                color: currentPageIndex > 0
                    ? Colors.blue
                    : Colors.grey.withOpacity(0.5),
                onPressed: _goToPreviousPage,
                child: Icon(
                  Icons.arrow_upward_rounded,
                  color: currentPageIndex > 0
                      ? Colors.white
                      : Colors.white.withOpacity(0.5),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              flex: 2,
              child: AnimatedButton(
                height: 50,
                color: Colors.green,
                onPressed: () {
                  // Show page selector dialog (similar to game_edit)
                },
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    "${currentPageIndex + 1} of ${pages.length}",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: AnimatedButton(
                height: 50,
                color: Colors.blue,
                onPressed: _goToNextPage,
                child: Icon(
                  currentPageIndex < pages.length - 1
                      ? Icons.arrow_downward_rounded
                      : Icons.check,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Check screen size immediately for responsiveness
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth <= 1366;
    final isMediumScreen = screenWidth <= 1024;

    // Update state if screen size changed
    if (isSmallScreen != _isSmallScreen || isMediumScreen != _isMediumScreen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isSmallScreen = isSmallScreen;
            _isMediumScreen = isMediumScreen;
            if (!_isSmallScreen) {
              _showSidebar = false;
            }
            if (!_isMediumScreen) {
              _showColumn3Sidebar = false;
            }
          });
        }
      });
    }

    if (gameId == null || userId == null || studentUserId == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF1E201E),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 60),
              const SizedBox(height: 16),
              Text(
                "Invalid submission data",
                style: GoogleFonts.poppins(fontSize: 18, color: Colors.white70),
              ),
              const SizedBox(height: 20),
              AnimatedButton(
                width: 100,
                height: 50,
                color: Colors.blue,
                onPressed: () => Get.back(),
                child: Text(
                  "Back",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Show loading indicator while initializing
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF1E201E),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
              ),
              const SizedBox(height: 20),
              Text(
                'Loading submission data...',
                style: GoogleFonts.poppins(fontSize: 18, color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    if (pages.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF1E201E),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.inbox, color: Colors.white30, size: 60),
              const SizedBox(height: 16),
              Text(
                "No submission data found",
                style: GoogleFonts.poppins(fontSize: 18, color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1E201E),
      body: Stack(
        children: [
          // Dark overlay background when Column 1 sidebar is open
          if (_isSmallScreen && _showSidebar)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _showSidebar = false;
                  });
                },
                child: Container(color: Colors.black.withOpacity(0.5)),
              ),
            ),

          // Dark overlay background when Column 3 sidebar is open
          if (_isMediumScreen && _showColumn3Sidebar)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _showColumn3Sidebar = false;
                  });
                },
                child: Container(color: Colors.black.withOpacity(0.5)),
              ),
            ),

          // Sliding sidebar for small screens (Column 1 - Student Info)
          if (_isSmallScreen && _showSidebar)
            Positioned(
              top: 0,
              right: 0,
              bottom: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: MediaQuery.of(context).size.width.clamp(0.0, 500.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E201E),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: GestureDetector(
                  onPanUpdate: (details) {
                    if (details.delta.dy != 0) {
                      final newOffset =
                          _sidebarScrollController.offset -
                          (details.delta.dy * 2);
                      final maxScroll =
                          _sidebarScrollController.position.maxScrollExtent;
                      final clampedOffset = newOffset.clamp(0.0, maxScroll);
                      _sidebarScrollController.jumpTo(clampedOffset);
                    }
                  },
                  child: SingleChildScrollView(
                    controller: _sidebarScrollController,
                    padding: const EdgeInsets.all(20.0),
                    physics: const BouncingScrollPhysics(),
                    child: _buildColumn1Content(),
                  ),
                ),
              ),
            ),

          // Column 3 sidebar for medium screens (Review Controls)
          if (_isMediumScreen && _showColumn3Sidebar)
            Positioned(
              top: 0,
              right: 0,
              bottom: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: MediaQuery.of(context).size.width.clamp(0.0, 500.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E201E),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: GestureDetector(
                  onPanUpdate: (details) {
                    if (details.delta.dy != 0) {
                      final newOffset =
                          _column3ScrollController.offset -
                          (details.delta.dy * 2);
                      final maxScroll =
                          _column3ScrollController.position.maxScrollExtent;
                      final clampedOffset = newOffset.clamp(0.0, maxScroll);
                      _column3ScrollController.jumpTo(clampedOffset);
                    }
                  },
                  child: SingleChildScrollView(
                    controller: _column3ScrollController,
                    padding: const EdgeInsets.all(20.0),
                    physics: const BouncingScrollPhysics(),
                    child: _buildColumn3Content(),
                  ),
                ),
              ),
            ),

          // Top-right tool and hamburger buttons
          if (_isSmallScreen || _isMediumScreen)
            Positioned(
              top: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black,
                  border: Border.all(color: Colors.white),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (_isMediumScreen)
                      Padding(
                        padding: const EdgeInsets.all(5.0),
                        child: AnimatedButton(
                          onPressed: () {
                            setState(() {
                              _showColumn3Sidebar = !_showColumn3Sidebar;
                              if (_showColumn3Sidebar && _showSidebar) {
                                _showSidebar = false;
                              }
                            });
                          },
                          width: 50,
                          height: 50,
                          color: Colors.blue,
                          child: Icon(
                            _showColumn3Sidebar ? Icons.close : Icons.build,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    if (_isSmallScreen)
                      Padding(
                        padding: const EdgeInsets.all(5.0),
                        child: AnimatedButton(
                          onPressed: () {
                            setState(() {
                              _showSidebar = !_showSidebar;
                              if (_showSidebar && _showColumn3Sidebar) {
                                _showColumn3Sidebar = false;
                              }
                            });
                          },
                          width: 50,
                          height: 50,
                          color: Colors.orange,
                          child: Icon(
                            _showSidebar ? Icons.close : Icons.menu,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

          // Main content area
          ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: (MediaQuery.of(context).size.width * 0.6).clamp(
                    0,
                    400,
                  ),
                ),
                child: SizedBox(
                  width: MediaQuery.of(context).size.width,
                  child: Padding(
                    padding: EdgeInsets.all(_isSmallScreen ? 10.0 : 30.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // -------- Column 1 -------- (Student Info & Navigation)
                        if (!_isSmallScreen)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: SingleChildScrollView(
                                    controller: _sidebarScrollController,
                                    child: _buildColumn1Content(),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // -------- Column 2 -------- (Review Content)
                        Expanded(
                          child: Center(
                            child: Container(
                              width: 428,
                              height: MediaQuery.of(
                                context,
                              ).size.height.clamp(1200.0, 2400.0),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                              ),
                              child: GestureDetector(
                                onPanUpdate: (details) {
                                  if (details.delta.dy != 0) {
                                    final newOffset =
                                        _column2ScrollController.offset -
                                        (details.delta.dy * 2);
                                    final maxScroll = _column2ScrollController
                                        .position
                                        .maxScrollExtent;
                                    final clampedOffset = newOffset.clamp(
                                      0.0,
                                      maxScroll,
                                    );
                                    _column2ScrollController.jumpTo(
                                      clampedOffset,
                                    );
                                  }
                                },
                                child: SingleChildScrollView(
                                  controller: _column2ScrollController,
                                  physics: const BouncingScrollPhysics(),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: _buildReviewContent(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // -------- Column 3 -------- (Review Controls)
                        if (!_isMediumScreen)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: _buildColumn3Content(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build review content based on game type
  Widget _buildReviewContent() {
    if (currentPageIndex >= pages.length) {
      return const Center(child: Text("No data"));
    }

    final pageData = pages[currentPageIndex];

    if (pageData.gameType == 'Stroke') {
      return _buildStrokeReviewContent(pageData);
    }

    // For other game types (to be implemented)
    return Center(
      child: Text(
        "Review for ${pageData.gameType} not yet implemented",
        style: GoogleFonts.poppins(color: Colors.black87),
      ),
    );
  }

  /// Build Stroke game content for review
  Widget _buildStrokeReviewContent(ReviewPageData pageData) {
    // Check if image hint is available (image mode) or sentence (text mode)
    final bool hasImageHint =
        pageData.strokeImageHintUrl != null &&
        pageData.strokeImageHintUrl!.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title
        Container(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            "Review Submission - Page ${currentPageIndex + 1}",
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),

        // Original Prompt (sentence or image)
        Text(
          "Original Prompt:",
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),

        // Show image hint if available, otherwise show sentence
        if (hasImageHint)
          Container(
            width: double.infinity,
            height: 250,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.3), width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                pageData.strokeImageHintUrl!,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, color: Colors.red, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          "Failed to load image hint",
                          style: GoogleFonts.poppins(color: Colors.black54),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.3), width: 2),
            ),
            child: Text(
              pageData.sentence.isEmpty
                  ? "No prompt provided"
                  : pageData.sentence,
              style: GoogleFonts.poppins(fontSize: 16, color: Colors.black87),
            ),
          ),

        const SizedBox(height: 24),

        // Student's Drawing
        Text(
          "Student's Drawing:",
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),

        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 300, maxHeight: 500),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green, width: 2),
          ),
          child: pageData.strokeImageUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    pageData.strokeImageUrl!,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error,
                              color: Colors.red,
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "Failed to load drawing",
                              style: GoogleFonts.poppins(color: Colors.black54),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.image_not_supported,
                        color: Colors.grey,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "No drawing submitted",
                        style: GoogleFonts.poppins(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

/// Data class for page review data
class ReviewPageData {
  final String gameType;
  final String sentence;
  final int currentScore; // 0 or 1 for correct/wrong
  final int pageScore; // Numeric score for the page
  final String? scoreDocId;
  final String? strokeImageUrl;
  final String? strokeImageHintUrl; // Image hint for Stroke game type
  final String roundDocId;
  final int pageNumber;

  ReviewPageData({
    required this.gameType,
    required this.sentence,
    required this.currentScore,
    this.pageScore = 0,
    this.scoreDocId,
    this.strokeImageUrl,
    this.strokeImageHintUrl,
    required this.roundDocId,
    required this.pageNumber,
  });

  ReviewPageData copyWith({
    String? gameType,
    String? sentence,
    int? currentScore,
    int? pageScore,
    String? scoreDocId,
    String? strokeImageUrl,
    String? strokeImageHintUrl,
    String? roundDocId,
    int? pageNumber,
  }) {
    return ReviewPageData(
      gameType: gameType ?? this.gameType,
      sentence: sentence ?? this.sentence,
      currentScore: currentScore ?? this.currentScore,
      pageScore: pageScore ?? this.pageScore,
      scoreDocId: scoreDocId ?? this.scoreDocId,
      strokeImageUrl: strokeImageUrl ?? this.strokeImageUrl,
      strokeImageHintUrl: strokeImageHintUrl ?? this.strokeImageHintUrl,
      roundDocId: roundDocId ?? this.roundDocId,
      pageNumber: pageNumber ?? this.pageNumber,
    );
  }
}
