// ignore_for_file: avoid_print, use_build_context_synchronously, deprecated_member_use, sized_box_for_whitespace

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

  // Search functionality removed

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
    
    // Try to get from Get.arguments first
    final args = Get.arguments as Map<String, dynamic>?;
    
    // If no arguments, try to parse from URL parameters
    final uri = Uri.base;
    
    if (args != null) {
      debugPrint('📥 Received arguments: $args');
    } else {
      debugPrint('📥 No Get.arguments, trying URL parameters...');
      debugPrint('  URL: ${uri.toString()}');
      debugPrint('  URL query params: ${uri.queryParameters}');
    }
    
    // Update state with parsed values, treating empty strings as null
    setState(() {
      gameId = args?['gameId'] as String? ?? uri.queryParameters['gameId'];
      
      // Handle title - empty string should be treated as null
      final titleFromArgs = args?['title'] as String?;
      final titleFromUrl = uri.queryParameters['title'];
      title = (titleFromArgs != null && titleFromArgs.isNotEmpty) ? titleFromArgs : 
              (titleFromUrl != null && titleFromUrl.isNotEmpty) ? titleFromUrl : null;
      
      userId = args?['userId'] as String? ?? uri.queryParameters['userId'] ?? FirebaseAuth.instance.currentUser?.uid;
      studentUserId = args?['studentUserId'] as String? ?? uri.queryParameters['studentUserId'];
      
      // Handle studentUsername - empty string should be treated as null
      final usernameFromArgs = args?['studentUsername'] as String?;
      final usernameFromUrl = uri.queryParameters['studentUsername'];
      studentUsername = (usernameFromArgs != null && usernameFromArgs.isNotEmpty) ? usernameFromArgs : 
                        (usernameFromUrl != null && usernameFromUrl.isNotEmpty) ? usernameFromUrl : null;
    });
    
    debugPrint('📥 Parsed values:');
    debugPrint('  gameId: $gameId');
    debugPrint('  title: $title (${title == null ? "NULL - will fetch" : "OK"})');
    debugPrint('  userId: $userId');
    debugPrint('  studentUserId: $studentUserId');
    debugPrint('  studentUsername: $studentUsername (${studentUsername == null ? "NULL - will fetch" : "OK"})');

    if (gameId != null && studentUserId != null && userId != null) {
      debugPrint('✅ Arguments valid, loading submission data...');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkScreenSize();
        _loadSubmissionData();
      });
    } else {
      debugPrint(
        '⚠️ Missing required arguments: gameId=$gameId, userId=$userId, studentUserId=$studentUserId',
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Fetch missing game and student details from Firestore
  Future<void> _fetchMissingDetails() async {
    try {
      debugPrint('🔄 Fetching missing details from Firestore...');
      
      // Fetch game title if missing
      if (title == null && gameId != null && userId != null) {
        debugPrint('  Fetching game title...');
        final gameDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId!)
            .collection('created_games')
            .doc(gameId!)
            .get();
        
        if (gameDoc.exists) {
          final data = gameDoc.data();
          if (mounted) {
            setState(() {
              title = data?['title'] as String?;
            });
            debugPrint('  ✅ Game title fetched and updated: $title');
          }
        } else {
          debugPrint('  ⚠️ Game document not found');
        }
      }
      
      // Fetch student username if missing
      if (studentUsername == null && studentUserId != null) {
        debugPrint('  Fetching student username...');
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(studentUserId!)
            .get();
        
        if (userDoc.exists) {
          final data = userDoc.data();
          if (mounted) {
            setState(() {
              studentUsername = data?['username'] as String?;
            });
            debugPrint('  ✅ Student username fetched and updated: $studentUsername');
          }
        } else {
          debugPrint('  ⚠️ Student user document not found');
        }
      }
      
      debugPrint('✅ Missing details fetch completed');
    } catch (e) {
      debugPrint('❌ Error fetching missing details: $e');
    }
  }

  /// Navigate back to game_manage with proper parameters
  void _navigateBackToGameManage() {
    if (gameId != null) {
      Get.offAllNamed(
        '/game_manage?gameId=$gameId&title=${Uri.encodeComponent(title ?? '')}&userId=${userId ?? ''}',
        arguments: {
          'gameId': gameId,
          'title': title,
          'userId': userId,
        },
      );
    } else {
      Get.offAllNamed('/game_published');
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

      // Fetch missing game and student details if needed
      if (title == null || studentUsername == null) {
        await _fetchMissingDetails();
      }

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
        // Show error message to user
        Get.snackbar(
          'Error',
          'Failed to load submission data: $e',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 5),
        );
      }
    }
  }

  // Student fetching removed

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
        _checkAndUpdateTotalScore(); // Check if total score needs updating
        return; // Early return since we already updated state
      }

      // Update local state
      setState(() {
        pages[pageIndex] = pageData.copyWith(pageScore: newScore);
      });

      // Check if sum of page scores exceeds total score
      _checkAndUpdateTotalScore();

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

  /// Check if sum of page scores exceeds total score and update if needed
  void _checkAndUpdateTotalScore() {
    int sumOfPageScores = 0;
    for (var page in pages) {
      sumOfPageScores += page.pageScore;
    }

    // If sum of page scores is greater than total score, update total score
    if (sumOfPageScores > _totalScore) {
      _totalScore = sumOfPageScores;
      _totalScoreController.text = sumOfPageScores.toString();
      _updateTotalScore(sumOfPageScores);
      debugPrint('✅ Total score auto-updated to sum of page scores: $sumOfPageScores');
    }
  }

  // Search filter removed

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
                _navigateBackToGameManage();
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

  /// Build Column 1 content (Empty for now)
  Widget _buildColumn1Content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          "Student Review",
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        
        // Student info card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.blue.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Current Student:",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                studentUsername ?? 'Unknown Student',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Switch student function removed

  /// Build Column 3 content (Review Controls)
  Widget _buildColumn3Content() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
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

        // Review Progress
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
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color:
                pages.isNotEmpty
                ? (pages[currentPageIndex].currentScore > 0
                    ? Colors.green.withOpacity(0.15)
                    : (pages[currentPageIndex].currentScore == 0 && pages[currentPageIndex].scoreDocId != null
                        ? Colors.red.withOpacity(0.15)
                        : Colors.orange.withOpacity(0.15)))
                : Colors.orange.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  pages.isNotEmpty
                  ? (pages[currentPageIndex].currentScore > 0
                      ? Colors.green
                      : (pages[currentPageIndex].currentScore == 0 && pages[currentPageIndex].scoreDocId != null
                          ? Colors.red
                          : Colors.orange))
                  : Colors.orange,
              width: 2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                pages.isNotEmpty
                    ? (pages[currentPageIndex].currentScore > 0
                        ? Icons.check_circle
                        : (pages[currentPageIndex].currentScore == 0 && pages[currentPageIndex].scoreDocId != null
                            ? Icons.cancel
                            : Icons.pending))
                    : Icons.pending,
                color:
                    pages.isNotEmpty
                    ? (pages[currentPageIndex].currentScore > 0
                        ? Colors.green
                        : (pages[currentPageIndex].currentScore == 0 && pages[currentPageIndex].scoreDocId != null
                            ? Colors.red
                            : Colors.orange))
                    : Colors.orange,
                size: 24,
              ),
              const SizedBox(width: 12),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    pages.isNotEmpty
                        ? (pages[currentPageIndex].currentScore > 0
                            ? "Marked as Correct"
                            : (pages[currentPageIndex].currentScore == 0 && pages[currentPageIndex].scoreDocId != null
                                ? "Marked as Wrong"
                                : "Not Yet Reviewed"))
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

        const SizedBox(height: 40),

        const Divider(color: Colors.white24),
        const SizedBox(height: 20),

        // All control buttons in a single row at bottom
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Up button
            AnimatedButton(
              height: 50,
              width: 50,
              color: currentPageIndex > 0
                  ? Colors.blue
                  : Colors.grey.withOpacity(0.5),
              onPressed: _goToPreviousPage,
              child: Icon(
                Icons.arrow_upward_rounded,
                color: currentPageIndex > 0
                    ? Colors.white
                    : Colors.white.withOpacity(0.5),
                size: 24,
              ),
            ),
            const SizedBox(width: 8),
            // Page indicator button
            AnimatedButton(
              height: 50,
              width: 100,
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
            const SizedBox(width: 8),
            // Down button
            AnimatedButton(
              height: 50,
              width: 50,
              color: Colors.blue,
              onPressed: _goToNextPage,
              child: Icon(
                currentPageIndex < pages.length - 1
                    ? Icons.arrow_downward_rounded
                    : Icons.check,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 8),
            // Finish button
            AnimatedButton(
              height: 50,
              width: 50,
              color: Colors.green,
              shadowDegree: ShadowDegree.dark,
              onPressed: _finishReview,
              child: const Icon(
                Icons.check_circle,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 8),
            // Reset button
            AnimatedButton(
              height: 50,
              width: 50,
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
                  : const Icon(
                      Icons.refresh,
                      color: Colors.white,
                      size: 24,
                    ),
            ),
          ],
        ),
      ],
    ),
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
                onPressed: _navigateBackToGameManage,
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
        appBar: AppBar(
          backgroundColor: Colors.white.withOpacity(0.05),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _navigateBackToGameManage,
          ),
          title: Text(
            title ?? 'Game Check',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
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
              const SizedBox(height: 8),
              Text(
                "This student may not have submitted any answers yet.",
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.white54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              AnimatedButton(
                width: 120,
                height: 50,
                color: Colors.blue,
                onPressed: _navigateBackToGameManage,
                child: Text(
                  "Go Back",
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

    return Scaffold(
      backgroundColor: const Color(0xFF1E201E),
      appBar: AppBar(
        backgroundColor: Colors.white.withOpacity(0.05),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _navigateBackToGameManage,
        ),
        title: Text(
          title ?? 'Game Check',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          // Sidebar toggle buttons moved to AppBar
          if (_isMediumScreen)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
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
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
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
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Main content area (FIRST - renders behind sidebars)
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
                        // -------- Column 1 -------- (Hidden on small screens)
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

                        // -------- Column 2 --------
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

                        // -------- Column 3 -------- (Hidden on medium screens)
                        if (!_isMediumScreen)
                          Expanded(
                            child: _buildColumn3Content(),
                          ),
                      ],
                    ),
                  ),
                ),
               )             
             ),
            ),

          // Dark overlay background when Column 1 sidebar is open (ABOVE main content)
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

          // Sliding sidebar for small screens (Column 1 - Student Info) - ON TOP
          if (_isSmallScreen && _showSidebar)
            Positioned(
              top: 0,
              right: 0,
              bottom: 0,
              child: Material(
                elevation: 16,
                color: const Color(0xFF1E201E),
                shadowColor: Colors.black,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: MediaQuery.of(context).size.width.clamp(0.0, 500.0),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E201E),
                  ),
                  child: SingleChildScrollView(
                    controller: _sidebarScrollController,
                    padding: const EdgeInsets.all(20.0),
                    physics: const BouncingScrollPhysics(),
                    child: _buildColumn1Content(),
                  ),
                ),
              ),
            ),

          // Column 3 sidebar for medium screens (Review Controls) - ON TOP
          if (_isMediumScreen && _showColumn3Sidebar)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: const Color(0xFF1E201E),
                child: Material(
                  elevation: 16,
                  color: const Color(0xFF1E201E),
                  shadowColor: Colors.black,
                  child: SafeArea(
                    child: SingleChildScrollView(
                      controller: _column3ScrollController,
                      padding: const EdgeInsets.all(20.0),
                      physics: const BouncingScrollPhysics(),
                      child: _buildColumn3Content(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build review content based on game type
  Widget _buildReviewContent() {
    if (pages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.grey, size: 48),
            const SizedBox(height: 16),
            Text(
              "No pages available",
              style: GoogleFonts.poppins(color: Colors.black54, fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (currentPageIndex >= pages.length) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.grey, size: 48),
            const SizedBox(height: 16),
            Text(
              "Invalid page index",
              style: GoogleFonts.poppins(color: Colors.black54, fontSize: 16),
            ),
          ],
        ),
      );
    }

    final pageData = pages[currentPageIndex];

    if (pageData.gameType == 'Stroke') {
      return _buildStrokeReviewContent(pageData);
    }

    // For other game types (to be implemented)
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.construction, color: Colors.orange, size: 48),
          const SizedBox(height: 16),
          Text(
            "Review for ${pageData.gameType} not yet implemented",
            style: GoogleFonts.poppins(color: Colors.black87, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
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
