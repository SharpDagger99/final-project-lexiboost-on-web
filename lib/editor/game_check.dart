// ignore_for_file: avoid_print, use_build_context_synchronously, deprecated_member_use

import 'package:animated_button/animated_button.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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
  
  // Mobile menu state
  bool _showMobileMenu = false;
  
  // Controllers for display
  final TextEditingController strokeSentenceController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _getArguments();
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
        _loadSubmissionData();
      } else {
        debugPrint('⚠️ Missing required arguments: gameId=$gameId, studentUserId=$studentUserId');
      }
    } else {
      debugPrint('⚠️ No arguments received!');
    }
  }
  
  /// Load the student's submission data for review
  Future<void> _loadSubmissionData() async {
    if (gameId == null || userId == null || studentUserId == null) return;
    
    try {
      debugPrint('Loading submission data for student: $studentUserId, game: $gameId');
      
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
        debugPrint('✅ Loaded ${gameRoundsSnapshot.docs.length} rounds (ordered by page)');
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
          'score': scoreData['score'] ?? 0,
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
        strokeDrawings = Map<String, String>.from(strokeData?['drawings'] ?? {});
      }
      
      // Build pages list
      List<ReviewPageData> loadedPages = [];
      
      for (var roundDoc in gameRoundsSnapshot.docs) {
        final roundData = roundDoc.data() as Map<String, dynamic>?;
        if (roundData == null) continue;
        
        final gameType = roundData['gameType'] as String? ?? '';
        // Use the page field from Firestore, or fallback to index + 1
        final pageNumber = (roundData['page'] as int?) ?? (loadedPages.length + 1);
        
        // Load game type specific data
        final gameTypeRef = gameRoundsRef.doc(roundDoc.id).collection('game_type');
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
        
        loadedPages.add(ReviewPageData(
          gameType: gameType,
          sentence: sentence,
          currentScore: currentScore,
          scoreDocId: scoreData?['docId'],
          strokeImageUrl: strokeImageUrl,
          strokeImageHintUrl: strokeImageHintUrl,
          roundDocId: roundDoc.id,
          pageNumber: pageNumber,
        ));
      }
      
      debugPrint('✅ Loaded ${loadedPages.length} pages for review');
      
      if (mounted) {
        setState(() {
          pages = loadedPages;
          _isLoading = false;
        });
        
        if (pages.isNotEmpty) {
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
    
    final pageData = pages[pageIndex];
    
    setState(() {
      currentPageIndex = pageIndex;
      
      if (pageData.gameType == 'Stroke') {
        strokeSentenceController.text = pageData.sentence;
      }
    });
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
        await scoresRef.doc(pageData.scoreDocId!).update({
          'score': newScore,
        });
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
      
      debugPrint('✅ Score updated: page ${pageData.pageNumber}, score: $newScore');
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
      // Calculate total score
      int totalScore = 0;
      for (var page in pages) {
        totalScore += page.currentScore;
      }
      
      // Update completed_games to mark as reviewed
      await FirebaseFirestore.instance
          .collection('users')
          .doc(studentUserId!)
          .collection('completed_games')
          .doc(gameId!)
          .update({
            'pendingReview': false,
            'reviewStatus': 'completed',
            'totalScore': totalScore,
            'reviewedAt': FieldValue.serverTimestamp(),
            'reviewedBy': user?.uid,
          });
      
      debugPrint('✅ Review completed. Total score: $totalScore');
      
      // Show success dialog
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF2C2F33),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                      "$totalScore / ${pages.length}",
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
  
  @override
  Widget build(BuildContext context) {
    debugPrint('🎨 MyGameCheck: Building widget (gameId=$gameId, userId=$userId, studentUserId=$studentUserId)');
    
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;
    
    if (gameId == null || userId == null || studentUserId == null) {
      debugPrint('⚠️ MyGameCheck: Missing required data, showing error screen');
      return Scaffold(
        backgroundColor: const Color(0xFF1E201E),
        appBar: AppBar(
          backgroundColor: Colors.white.withOpacity(0.05),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Get.back(),
          ),
          title: Text(
            "Review Submission",
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        body: Center(
          child: Text(
            "Invalid submission data",
            style: GoogleFonts.poppins(color: Colors.white70),
          ),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: const Color(0xFF1E201E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C2F33),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Review Submission",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (!isMobile)
              Text(
                "$studentUsername - ${title ?? ''}",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.white60,
                ),
              ),
          ],
        ),
        actions: isMobile
            ? [
                IconButton(
                  icon: Icon(
                    _showMobileMenu ? Icons.close : Icons.menu,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    setState(() {
                      _showMobileMenu = !_showMobileMenu;
                    });
                  },
                ),
              ]
            : null,
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.orange),
                  const SizedBox(height: 16),
                  Text(
                    "Loading submission...",
                    style: GoogleFonts.poppins(color: Colors.white70),
                  ),
                ],
              ),
            )
          : pages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inbox, color: Colors.white30, size: 60),
                      const SizedBox(height: 16),
                      Text(
                        "No submission data found",
                        style: GoogleFonts.poppins(color: Colors.white70),
                      ),
                    ],
                  ),
                )
              : isMobile
                  ? _buildMobileLayout()
                  : _buildDesktopLayout(),
    );
  }
  
  /// Build desktop layout (side-by-side columns)
  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Left side: Game content and student answer
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _buildGameContent(),
          ),
        ),
        
        // Right side: Student info and controls
        Container(
          width: 350,
          decoration: BoxDecoration(
            color: const Color(0xFF2C2F33),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(-2, 0),
              ),
            ],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: _buildStudentInfoPanel(),
          ),
        ),
      ],
    );
  }
  
  /// Build mobile layout (stacked with hamburger menu)
  Widget _buildMobileLayout() {
    return Stack(
      children: [
        // Main content
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: _buildGameContent(),
        ),
        
        // Slide-in menu overlay
        if (_showMobileMenu)
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _showMobileMenu = false;
                });
              },
              child: Container(
                color: Colors.black.withOpacity(0.5),
              ),
            ),
          ),
        
        // Slide-in menu
        if (_showMobileMenu)
          Positioned(
            top: 0,
            right: 0,
            bottom: 0,
            child: Container(
              width: 300,
              decoration: BoxDecoration(
                color: const Color(0xFF2C2F33),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _buildStudentInfoPanel(),
              ),
            ),
          ),
      ],
    );
  }
  
  /// Build student information and control panel
  Widget _buildStudentInfoPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Student info card
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
            border: Border.all(
              color: Colors.blue.withOpacity(0.3),
              width: 1,
            ),
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
        
        const SizedBox(height: 24),
        
        // Progress indicator
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Review Progress",
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: pages.isEmpty ? 0 : (currentPageIndex + 1) / pages.length,
                backgroundColor: Colors.white.withOpacity(0.1),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
                minHeight: 8,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 24),
        const Divider(color: Colors.white24),
        const SizedBox(height: 24),
        
        // Navigation buttons
        Text(
          "Navigation",
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        
        Row(
          children: [
            Expanded(
              child: AnimatedButton(
                height: 45,
                color: currentPageIndex > 0 ? Colors.blue : Colors.grey[700]!,
                shadowDegree: ShadowDegree.light,
                onPressed: currentPageIndex > 0
                    ? () {
                        setState(() {
                          _loadPageData(currentPageIndex - 1);
                        });
                      }
                    : () {},
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.arrow_back, color: Colors.white, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      "Prev",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AnimatedButton(
                height: 45,
                color: currentPageIndex < pages.length - 1
                    ? Colors.blue
                    : Colors.grey[700]!,
                shadowDegree: ShadowDegree.light,
                onPressed: currentPageIndex < pages.length - 1
                    ? () {
                        setState(() {
                          _loadPageData(currentPageIndex + 1);
                        });
                      }
                    : () {},
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Next",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 24),
        const Divider(color: Colors.white24),
        const SizedBox(height: 24),
        
        // Finish Review button
        SizedBox(
          width: double.infinity,
          child: AnimatedButton(
            height: 50,
            color: Colors.green,
            shadowDegree: ShadowDegree.dark,
            onPressed: () {
              _finishReview();
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  "Finish Review",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  /// Build game content based on game type
  Widget _buildGameContent() {
    if (currentPageIndex >= pages.length) {
      return const Center(child: Text("No data"));
    }
    
    final pageData = pages[currentPageIndex];
    
    if (pageData.gameType == 'Stroke') {
      return _buildStrokeContent(pageData);
    }
    
    // For other game types (to be implemented)
    return Center(
      child: Text(
        "Review for ${pageData.gameType} not yet implemented",
        style: GoogleFonts.poppins(color: Colors.white70),
      ),
    );
  }
  
  /// Build Stroke game content for review
  Widget _buildStrokeContent(ReviewPageData pageData) {
    // Check if image hint is available (image mode) or sentence (text mode)
    final bool hasImageHint = pageData.strokeImageHintUrl != null && 
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
              color: Colors.white,
            ),
          ),
        ),
        
        // Original Prompt (sentence or image)
        Text(
          "Original Prompt:",
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        
        // Show image hint if available, otherwise show sentence
        if (hasImageHint)
          Container(
            width: double.infinity,
            height: 250,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
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
                        const Icon(
                          Icons.error,
                          color: Colors.red,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Failed to load image hint",
                          style: GoogleFonts.poppins(
                            color: Colors.black54,
                          ),
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
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.3), width: 2),
            ),
            child: Text(
              pageData.sentence.isEmpty
                  ? "No prompt provided"
                  : pageData.sentence,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ),
        
        const SizedBox(height: 24),
        
        // Student's Drawing
        Text(
          "Student's Drawing:",
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(
            minHeight: 300,
            maxHeight: 500,
          ),
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
                              style: GoogleFonts.poppins(
                                color: Colors.black54,
                              ),
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
                        style: GoogleFonts.poppins(
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        
        const SizedBox(height: 20),
        
        // Check and Wrong buttons
        Row(
          children: [
            Expanded(
              child: AnimatedButton(
                height: 55,
                color: Colors.green,
                shadowDegree: ShadowDegree.dark,
                onPressed: _isSaving ? () {} : _markAsCorrect,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isSaving)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    else ...[
                      const Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "Correct",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: AnimatedButton(
                height: 55,
                color: Colors.red,
                shadowDegree: ShadowDegree.dark,
                onPressed: _isSaving ? () {} : _markAsWrong,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isSaving)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    else ...[
                      const Icon(
                        Icons.cancel,
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "Wrong",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 24),
        
        // Current score indicator
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: pageData.currentScore > 0
                ? Colors.green.withOpacity(0.15)
                : Colors.orange.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: pageData.currentScore > 0 ? Colors.green : Colors.orange,
              width: 2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                pageData.currentScore > 0 ? Icons.check_circle : Icons.pending,
                color: pageData.currentScore > 0 ? Colors.green : Colors.orange,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                pageData.currentScore > 0 ? "Marked as Correct" : "Not Yet Reviewed",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  @override
  void dispose() {
    strokeSentenceController.dispose();
    super.dispose();
  }
}

/// Data class for page review data
class ReviewPageData {
  final String gameType;
  final String sentence;
  final int currentScore;
  final String? scoreDocId;
  final String? strokeImageUrl;
  final String? strokeImageHintUrl; // Image hint for Stroke game type
  final String roundDocId;
  final int pageNumber;
  
  ReviewPageData({
    required this.gameType,
    required this.sentence,
    required this.currentScore,
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
      scoreDocId: scoreDocId ?? this.scoreDocId,
      strokeImageUrl: strokeImageUrl ?? this.strokeImageUrl,
      strokeImageHintUrl: strokeImageHintUrl ?? this.strokeImageHintUrl,
      roundDocId: roundDocId ?? this.roundDocId,
      pageNumber: pageNumber ?? this.pageNumber,
    );
  }
}
