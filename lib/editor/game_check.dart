// ignore_for_file: avoid_print, use_build_context_synchronously, deprecated_member_use, sized_box_for_whitespace, unnecessary_to_list_in_spreads, unused_element, avoid_web_libraries_in_flutter

import 'dart:convert';
import 'dart:html' as html;
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
  String? gameRule; // Game rule (e.g., 'score', 'timer')
  String? studentScoreDocId; // Document ID for student's score in game_score collection

  // Loading state
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isLoadingPlayerData = false; // Loading state for player switching

  // Page data
  List<ReviewPageData> pages = [];
  int currentPageIndex = 0;

  // Player list
  List<PlayerData> players = [];
  List<PlayerData> allPlayers = []; // Store all players for filtering
  bool _isLoadingPlayers = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Responsive design state
  bool _isSmallScreen = false;
  bool _isMediumScreen = false;
  bool _showSidebar = false;
  bool _showColumn3Sidebar = false;

  // Scroll controllers
  final ScrollController _column2ScrollController = ScrollController();
  final ScrollController _sidebarScrollController = ScrollController();
  final ScrollController _column3ScrollController = ScrollController();
  final ScrollController _pageSelectorScrollController = ScrollController();

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
    // Don't fetch players here - wait for arguments to be validated
  }

  @override
  void dispose() {
    _column2ScrollController.dispose();
    _sidebarScrollController.dispose();
    _column3ScrollController.dispose();
    _pageSelectorScrollController.dispose();
    _totalScoreController.dispose();
    _searchController.dispose();
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
        _fetchPlayers(); // Fetch players after arguments are validated
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
      
      // Fetch game title and gameRule if missing
      if ((title == null || gameRule == null) && gameId != null && userId != null) {
        debugPrint('  Fetching game details...');
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
              gameRule = data?['gameRule'] as String?;
            });
            debugPrint('  ✅ Game details fetched - title: $title, gameRule: $gameRule');
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

  /// Fetch all players who played this game
  Future<void> _fetchPlayers() async {
    if (gameId == null || userId == null) {
      debugPrint('⚠️ Cannot fetch players: gameId or userId is null');
      return;
    }

    if (!mounted) return;

    setState(() {
      _isLoadingPlayers = true;
    });

    try {
      debugPrint('🔄 Fetching players for game: $gameId');

      // Get all completed games for this game
      final scoresSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId!)
          .collection('created_games')
          .doc(gameId!)
          .collection('game_score')
          .get();

      if (!mounted) return;

      // Extract unique user IDs
      final Set<String> uniqueUserIds = {};
      for (var doc in scoresSnapshot.docs) {
        try {
          final data = doc.data();
          final playerId = data['userId'] as String?;
          if (playerId != null && playerId.isNotEmpty) {
            uniqueUserIds.add(playerId);
          }
        } catch (e) {
          debugPrint('  ⚠️ Error parsing score doc: $e');
        }
      }

      debugPrint('  Found ${uniqueUserIds.length} unique players');

      if (uniqueUserIds.isEmpty) {
        if (mounted) {
          setState(() {
            players = [];
            _isLoadingPlayers = false;
          });
        }
        debugPrint('⚠️ No players found for this game');
        return;
      }

      // Fetch user details for each player
      List<PlayerData> fetchedPlayers = [];
      for (var playerId in uniqueUserIds) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(playerId)
              .get();

          if (!mounted) return;

          if (userDoc.exists) {
            final userData = userDoc.data();
            if (userData != null) {
              fetchedPlayers.add(
                PlayerData(
                  userId: playerId,
                  username: userData['username'] as String? ?? 'Unknown User',
                  email: userData['email'] as String? ?? 'No email',
                  profileImage: userData['profileImage'] as String?,
                  fullname: userData['fullname'] as String?,
                  schoolId: userData['schoolId'] as String?,
                  gradeLevel: userData['gradeLevel'] as String?,
                  section: userData['section'] as String?,
                  isSelected: playerId == studentUserId,
                ),
              );
            }
          } else {
            // Add placeholder for user that doesn't exist
            fetchedPlayers.add(
              PlayerData(
                userId: playerId,
                username: 'Unknown User',
                email: 'User not found',
                isSelected: playerId == studentUserId,
              ),
            );
          }
        } catch (e) {
          debugPrint('  ⚠️ Error fetching user $playerId: $e');
          // Add placeholder for errored user
          fetchedPlayers.add(
            PlayerData(
              userId: playerId,
              username: 'Error loading user',
              email: 'Failed to load',
              isSelected: playerId == studentUserId,
            ),
          );
        }
      }

      if (!mounted) return;

      // Sort players by username
      try {
        fetchedPlayers.sort((a, b) => a.username.compareTo(b.username));
      } catch (e) {
        debugPrint('  ⚠️ Error sorting players: $e');
      }

      if (mounted) {
        setState(() {
          allPlayers = fetchedPlayers;
          players = _applySearchFilter(fetchedPlayers);
          _isLoadingPlayers = false;
        });
      }

      debugPrint('✅ Loaded ${fetchedPlayers.length} players');
    } catch (e, stackTrace) {
      debugPrint('❌ Error fetching players: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          allPlayers = [];
          players = [];
          _isLoadingPlayers = false;
        });
      }
    }
  }

  /// Apply search filter to player list
  List<PlayerData> _applySearchFilter(List<PlayerData> playerList) {
    if (_searchQuery.isEmpty) return playerList;
    
    final query = _searchQuery.toLowerCase();
    return playerList.where((player) {
      final username = player.username.toLowerCase();
      final email = player.email.toLowerCase();
      final fullname = (player.fullname ?? '').toLowerCase();
      final schoolId = (player.schoolId ?? '').toLowerCase();
      final gradeLevel = (player.gradeLevel ?? '').toLowerCase();
      final section = (player.section ?? '').toLowerCase();
      
      return username.contains(query) ||
             email.contains(query) ||
             fullname.contains(query) ||
             schoolId.contains(query) ||
             gradeLevel.contains(query) ||
             section.contains(query);
    }).toList();
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
      if (title == null || studentUsername == null || gameRule == null) {
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

      // Load student's score data using new structure
      final gameScoreRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId!)
          .collection('created_games')
          .doc(gameId!)
          .collection('game_score');

      // Query for this student's score document
      final studentScoreQuery = await gameScoreRef
          .where('userId', isEqualTo: studentUserId)
          .limit(1)
          .get();

      Map<int, Map<String, dynamic>> scoresMap = {};
      String? studentScoreDocId;

      if (studentScoreQuery.docs.isNotEmpty) {
        // Student has a score document
        final studentScoreDoc = studentScoreQuery.docs.first;
        studentScoreDocId = studentScoreDoc.id;
        
        // Store in state variable
        this.studentScoreDocId = studentScoreDocId;
        
        debugPrint('📊 Found student score document: $studentScoreDocId');

        // Load page scores from subcollection
        final pageScoresRef = studentScoreDoc.reference.collection('page_score');
        final pageScoresSnapshot = await pageScoresRef.get();
        
        debugPrint('📊 Loading ${pageScoresSnapshot.docs.length} page score documents...');
        
        for (var pageDoc in pageScoresSnapshot.docs) {
          final pageData = pageDoc.data();
          final page = pageData['page'] as int? ?? 0;
          final pageScore = pageData['pageScore'] as int? ?? 0;
          scoresMap[page] = {
            'pageScore': pageScore, // Numeric score for the page
            'docId': pageDoc.id,
            'studentDocId': studentScoreDocId,
          };
          debugPrint('  Page $page: pageScore=$pageScore, docId=${pageDoc.id}');
        }
      } else {
        debugPrint('⚠️ No score document found for student, will create on first save');
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
        final currentScore = 0; // No longer using correct/wrong score

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
        
        debugPrint('  ✅ Page $pageNumber loaded: gameType=$gameType, pageScore=$pageScore');

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
          debugPrint('🎮 Initializing page score controllers...');
          for (int i = 0; i < pages.length; i++) {
            if (!_pageScoreControllers.containsKey(i)) {
              final scoreText = pages[i].pageScore.toString();
              _pageScoreControllers[i] = TextEditingController(text: scoreText);
              debugPrint('  Controller for page $i initialized with value: $scoreText');
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

  /// Switch to a different player (instant, no loading screen)
  Future<void> _switchToPlayer(PlayerData player) async {
    if (player.userId == studentUserId) {
      debugPrint('⚠️ Already viewing player: ${player.username}');
      return; // Already viewing this player
    }

    debugPrint('🔄 Switching to player: ${player.username} (${player.userId})');

    try {
      if (!mounted) return;

      // Update selection immediately and show loading in center/right sections only
      setState(() {
        _isLoadingPlayerData = true;
        studentUserId = player.userId;
        studentUsername = player.username;
        studentScoreDocId = null; // Clear student score doc ID
        currentPageIndex = 0;
        // Update player selection in both lists
        allPlayers = allPlayers.map((p) => p.copyWith(isSelected: p.userId == player.userId)).toList();
        players = _applySearchFilter(allPlayers);
      });

      // Clear page score controllers
      try {
        for (var controller in _pageScoreControllers.values) {
          controller.dispose();
        }
        _pageScoreControllers.clear();
      } catch (e) {
        debugPrint('⚠️ Error clearing controllers: $e');
      }

      // Reload submission data in background
      await _loadSubmissionData();

      if (mounted) {
        setState(() {
          _isLoadingPlayerData = false;
        });
      }

      debugPrint('✅ Successfully switched to player: ${player.username}');
    } catch (e, stackTrace) {
      debugPrint('❌ Error switching player: $e');
      debugPrint('Stack trace: $stackTrace');
      
      if (mounted) {
        setState(() {
          _isLoadingPlayerData = false;
        });
        
        Get.snackbar(
          'Error',
          'Failed to load player data: ${e.toString()}',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
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

  /// Update total score in Firestore using new structure
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

      // Also update in game_score document if it exists
      if (studentScoreDocId != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId!)
            .collection('created_games')
            .doc(gameId!)
            .collection('game_score')
            .doc(studentScoreDocId!)
            .update({
              'totalScore': newScore,
            });
        debugPrint('✅ Updated totalScore in game_score document');
      }

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

  /// Update page score for a specific page using new structure
  Future<void> _updatePageScore(int pageIndex, int newScore) async {
    if (gameId == null || userId == null || studentUserId == null) return;
    if (pageIndex < 0 || pageIndex >= pages.length) return;

    final pageData = pages[pageIndex];

    try {
      final gameScoreRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId!)
          .collection('created_games')
          .doc(gameId!)
          .collection('game_score');

      // Ensure student score document exists
      if (studentScoreDocId == null) {
        // Create student score document
        final studentDocRef = await gameScoreRef.add({
          'username': studentUsername ?? '',
          'email': '', // Can be fetched if needed
          'userId': studentUserId!,
          'totalScore': _totalScore,
        });
        studentScoreDocId = studentDocRef.id;
        debugPrint('✅ Created student score document: $studentScoreDocId');
      }

      // Reference to page_score subcollection
      final pageScoreRef = gameScoreRef
          .doc(studentScoreDocId!)
          .collection('page_score');

      if (pageData.scoreDocId != null) {
        // Update existing page score
        await pageScoreRef.doc(pageData.scoreDocId!).update({
          'pageScore': newScore,
        });
        debugPrint('✅ Updated page score document: ${pageData.scoreDocId}');
      } else {
        // Create new page score entry
        final pageDocRef = await pageScoreRef.add({
          'page': pageData.pageNumber,
          'pageScore': newScore,
        });
        // Update local state with new docId
        setState(() {
          pages[pageIndex] = pageData.copyWith(
            scoreDocId: pageDocRef.id,
            pageScore: newScore,
          );
        });
        debugPrint('✅ Created page score document: ${pageDocRef.id}');
        _checkAndUpdateTotalScore(); // Check if total score needs updating
        return; // Early return since we already updated state
      }

      // Update local state
      setState(() {
        pages[pageIndex] = pageData.copyWith(pageScore: newScore);
      });

      // Check if sum of page scores exceeds total score
      _checkAndUpdateTotalScore();

      // Also update the game_edit.dart compatible structure
      await _updateGameEditPageScore(pageIndex, newScore);

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

  /// Update page score in game_edit.dart compatible format
  Future<void> _updateGameEditPageScore(int pageIndex, int newScore) async {
    if (gameId == null || userId == null) return;

    try {
      final gameScoreRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId!)
          .collection('created_games')
          .doc(gameId!)
          .collection('game_score');

      // Query for existing page score document (game_edit format)
      // game_edit stores: { page: 1, score: 10 } (no userId field)
      final querySnapshot = await gameScoreRef
          .where('page', isEqualTo: pageIndex + 1) // 1-based page number
          .get();

      // Find the game_edit format document (one without userId field)
      DocumentSnapshot? gameEditDoc;
      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null && !data.containsKey('userId')) {
          gameEditDoc = doc;
          break;
        }
      }

      if (gameEditDoc != null) {
        // Update existing document
        await gameEditDoc.reference.update({
          'score': newScore,
        });
        debugPrint('✅ Updated game_edit page score: page ${pageIndex + 1}, score: $newScore');
      } else {
        // Create new document in game_edit format
        await gameScoreRef.add({
          'page': pageIndex + 1, // 1-based page number
          'score': newScore,
        });
        debugPrint('✅ Created game_edit page score: page ${pageIndex + 1}, score: $newScore');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to update game_edit page score: $e');
      // Don't show error to user as this is a background sync
    }
  }

  // Search filter removed



  /// Finish review and update review status
  Future<void> _finishReview() async {
    if (gameId == null || studentUserId == null || userId == null) return;

    try {
      debugPrint('🏁 Finishing review - saving all changes first...');
      
      // First, save all page scores and total score
      for (int i = 0; i < pages.length; i++) {
        if (_pageScoreControllers.containsKey(i)) {
          final controller = _pageScoreControllers[i]!;
          final score = int.tryParse(controller.text) ?? 0;
          
          if (pages[i].pageScore != score) {
            debugPrint('  📝 Saving page $i score: ${pages[i].pageScore} → $score');
            // Save to database (this also updates local state)
            await _updatePageScore(i, score);
          }
        }
      }

      // Save total score if changed
      final totalScore = int.tryParse(_totalScoreController.text) ?? 0;
      if (totalScore != _totalScore) {
        debugPrint('  📝 Saving total score: $_totalScore → $totalScore');
        _totalScore = totalScore;
        await _updateTotalScore(totalScore);
      }
      
      debugPrint('✅ All scores saved, marking review as complete...');

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
      // Reset all scores to 0 (unmarked) using new structure
      if (studentScoreDocId != null) {
        final pageScoreRef = FirebaseFirestore.instance
            .collection('users')
            .doc(userId!)
            .collection('created_games')
            .doc(gameId!)
            .collection('game_score')
            .doc(studentScoreDocId!)
            .collection('page_score');

        // Reset all page scores to 0
        for (var page in pages) {
          if (page.scoreDocId != null) {
            await pageScoreRef.doc(page.scoreDocId!).update({
              'pageScore': 0,
            });
          }
        }

        // Reset total score to 0
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId!)
            .collection('created_games')
            .doc(gameId!)
            .collection('game_score')
            .doc(studentScoreDocId!)
            .update({
              'totalScore': 0,
            });
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

  /// Save all changes (scores and total score)
  Future<void> _saveAllChanges() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      debugPrint('💾 Starting save all changes...');
      
      // Save all page scores
      for (int i = 0; i < pages.length; i++) {
        if (_pageScoreControllers.containsKey(i)) {
          final controller = _pageScoreControllers[i]!;
          final score = int.tryParse(controller.text) ?? 0;
          
          debugPrint('  Page $i: Current=${pages[i].pageScore}, TextField=$score');
          
          if (pages[i].pageScore != score) {
            debugPrint('  📝 Updating page $i score from ${pages[i].pageScore} to $score');
            
            // Update the score in database
            await _updatePageScore(i, score);
            
            // _updatePageScore already updates local state, but ensure controller is synced
            if (_pageScoreControllers.containsKey(i)) {
              _pageScoreControllers[i]!.text = score.toString();
            }
          }
        }
      }

      // Save total score
      final totalScore = int.tryParse(_totalScoreController.text) ?? 0;
      if (totalScore != _totalScore) {
        debugPrint('  📝 Updating total score from $_totalScore to $totalScore');
        _totalScore = totalScore;
        await _updateTotalScore(totalScore);
      }
      
      debugPrint('✅ All changes saved successfully');

      if (mounted) {
        Get.snackbar(
          'Success',
          'All changes saved successfully',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      debugPrint('❌ Error saving changes: $e');
      if (mounted) {
        Get.snackbar(
          'Error',
          'Failed to save changes: $e',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  /// Download student report as CSV
  Future<void> _downloadStudentCSV() async {
    if (studentUserId == null || studentUsername == null) return;

    try {
      // Build CSV content
      final StringBuffer csvBuffer = StringBuffer();
      final generatedDate = DateTime.now().toString().split('.')[0];

      // Add header
      csvBuffer.writeln('Game: ${_escapeCsvField(title ?? 'Unknown Game')}');
      csvBuffer.writeln('Student: ${_escapeCsvField(studentUsername!)}');
      csvBuffer.writeln('Generated on: $generatedDate');
      csvBuffer.writeln(''); // Empty line

      // Main data headers
      csvBuffer.writeln('Page,Game Type,Sentence,Page Score');

      // Add each page's data
      for (int i = 0; i < pages.length; i++) {
        final page = pages[i];
        
        csvBuffer.writeln([
          (i + 1).toString(),
          _escapeCsvField(page.gameType),
          _escapeCsvField(page.sentence),
          page.pageScore.toString(),
        ].join(','));
      }

      // Add summary
      csvBuffer.writeln(''); // Empty line
      csvBuffer.writeln('Total Score,$_totalScore');

      // Create and download CSV file
      final csvContent = csvBuffer.toString();
      final blob = html.Blob([csvContent], 'text/csv;charset=utf-8');
      final url = html.Url.createObjectUrlFromBlob(blob);
      
      // Create download link
      final fileName = 'Student_Report_${studentUsername}_${DateTime.now().millisecondsSinceEpoch}.csv';
      html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      
      // Clean up
      Future.delayed(const Duration(seconds: 1), () {
        html.Url.revokeObjectUrl(url);
      });

      Get.snackbar(
        'Success',
        'CSV file downloaded for $studentUsername',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      debugPrint('❌ Error downloading CSV: $e');
      Get.snackbar(
        'Error',
        'Failed to download CSV: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    }
  }

  /// Helper function to escape CSV fields
  String _escapeCsvField(String field) {
    // If field contains comma, quote, or newline, wrap in quotes and escape quotes
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  /// Check if sum of page scores exceeds total score and update if needed
  void _checkAndUpdateTotalScore() {
    // Calculate sum of all page scores
    int sumOfPageScores = 0;
    for (var page in pages) {
      sumOfPageScores += page.pageScore;
    }
    
    // If sum of page scores is greater than total score, update total score
    if (sumOfPageScores > _totalScore) {
      _totalScore = sumOfPageScores;
      _totalScoreController.text = _totalScore.toString();
      
      debugPrint('📊 Total score updated: $sumOfPageScores (sum of page scores exceeded previous total)');
      
      // Update total score in Firestore
      _updateTotalScore(_totalScore);
    }
    // If sum is not greater, total score remains unchanged
  }

  /// Get or create a TextEditingController for a page score
  TextEditingController _getOrCreatePageScoreController(int pageIndex) {
    if (!_pageScoreControllers.containsKey(pageIndex)) {
      final controller = TextEditingController(
        text: pageIndex < pages.length ? pages[pageIndex].pageScore.toString() : '0',
      );
      _pageScoreControllers[pageIndex] = controller;
    } else {
      // Ensure controller text is in sync with the current page score
      final currentController = _pageScoreControllers[pageIndex]!;
      if (pageIndex < pages.length) {
        final expectedText = pages[pageIndex].pageScore.toString();
        if (currentController.text != expectedText) {
          currentController.text = expectedText;
        }
      }
    }
    return _pageScoreControllers[pageIndex]!;
  }

  /// Show page selector dialog for quick navigation
  void _showPageSelector() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF2A2C2A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width.clamp(0.0, 500.0),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Select Page',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: Scrollbar(
                    controller: _pageSelectorScrollController,
                    thumbVisibility: true,
                    trackVisibility: true,
                    thickness: 8,
                    radius: const Radius.circular(10),
                    child: GestureDetector(
                      onPanUpdate: (details) {
                        // Drag to scroll functionality
                        _pageSelectorScrollController.position.moveTo(
                          _pageSelectorScrollController.offset -
                              details.delta.dy,
                        );
                      },
                      child: ListView.builder(
                        controller: _pageSelectorScrollController,
                        shrinkWrap: true,
                        itemCount: pages.length,
                        itemBuilder: (context, index) {
                          final isCurrentPage = index == currentPageIndex;
                          
                          return Container(
                            margin: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 4,
                            ),
                            child: Row(
                              children: [
                                // Page button section
                                Expanded(
                                  child: Material(
                                    color: isCurrentPage
                                        ? Colors.green.withOpacity(0.3)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    child: InkWell(
                                      onTap: () {
                                        if (!isCurrentPage) {
                                          setState(() {
                                            currentPageIndex = index;
                                          });
                                        }
                                        Navigator.of(context).pop();
                                      },
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: isCurrentPage
                                                ? Colors.green
                                                : Colors.white.withOpacity(0.3),
                                            width: isCurrentPage ? 2 : 1,
                                          ),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            Text(
                                              'Page ${index + 1}',
                                              style: GoogleFonts.poppins(
                                                fontSize: 16,
                                                color: Colors.white,
                                                fontWeight: isCurrentPage
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                              ),
                                            ),
                                            const Spacer(),
                                            if (isCurrentPage)
                                              const Icon(
                                                Icons.check_circle,
                                                color: Colors.green,
                                                size: 20,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                AnimatedButton(
                  width: 100,
                  height: 40,
                  color: Colors.grey,
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Close',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Build Column 1 content (Player List)
  Widget _buildColumn1Content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search bar
        TextField(
          controller: _searchController,
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
              players = _applySearchFilter(allPlayers);
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
                        players = _applySearchFilter(allPlayers);
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
        const SizedBox(height: 16),
        
        // Player list
        if (_isLoadingPlayers)
          const Padding(
            padding: EdgeInsets.all(32.0),
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
              ),
            ),
          )
        else if (players.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                "No players found",
                style: GoogleFonts.poppins(
                  color: Colors.white54,
                  fontSize: 14,
                ),
              ),
            ),
          )
        else
          // Player list with fixed container sizes
          ...players.map((player) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: InkWell(
                onTap: () => _switchToPlayer(player),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 100,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: player.isSelected
                        ? Colors.blue.withOpacity(0.2)
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: player.isSelected
                          ? Colors.blue
                          : Colors.white.withOpacity(0.1),
                      width: player.isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Circle Avatar with profile image
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.blue,
                        backgroundImage: player.profileImage != null && player.profileImage!.isNotEmpty
                            ? MemoryImage(base64Decode(player.profileImage!))
                            : null,
                        child: player.profileImage == null || player.profileImage!.isEmpty
                            ? Text(
                                player.username.isNotEmpty
                                    ? player.username[0].toUpperCase()
                                    : '?',
                                style: GoogleFonts.poppins(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      // Username and Email
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              player.username,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              player.email,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.white60,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Download CSV button (only show for selected player)
                      if (player.isSelected) ...[
                        AnimatedButton(
                          height: 36,
                          width: 36,
                          color: Colors.purple,
                          shadowDegree: ShadowDegree.light,
                          onPressed: _downloadStudentCSV,
                          child: const Icon(
                            Icons.download,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Save button (only show for selected player)
                        AnimatedButton(
                          height: 36,
                          width: 36,
                          color: Colors.blue,
                          shadowDegree: ShadowDegree.light,
                          onPressed: _isSaving ? () {} : _saveAllChanges,
                          child: _isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.save,
                                  color: Colors.white,
                                  size: 18,
                                ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      // View button
                      AnimatedButton(
                        height: 36,
                        width: 36,
                        color: Colors.green,
                        shadowDegree: ShadowDegree.light,
                        onPressed: () {
                          _viewStudentInfo(
                            player.userId,
                            player.username,
                            player.email,
                          );
                        },
                        child: const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Selected indicator
                      if (player.isSelected)
                        const Icon(
                          Icons.check_circle,
                          color: Colors.blue,
                          size: 24,
                        ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
      ],
    );
  }

  // Switch student function removed

  /// Build Column 3 content (Review Controls)
  Widget _buildColumn3Content() {
    if (_isLoadingPlayerData) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
            ),
            const SizedBox(height: 20),
            Text(
              'Loading player data...',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      );
    }

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

        // Reset button
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Restart button
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
                controller: _getOrCreatePageScoreController(currentPageIndex),
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
                  // Update the page score in the pages list immediately for sync
                  if (currentPageIndex < pages.length) {
                    final newScore = int.tryParse(value) ?? 0;
                    setState(() {
                      pages[currentPageIndex] = pages[currentPageIndex].copyWith(pageScore: newScore);
                      _checkAndUpdateTotalScore();
                    });
                  }
                  // Note: Changes are saved when user clicks the Save button
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

        const SizedBox(height: 20),
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
              onPressed: _showPageSelector,
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
                              child: _isLoadingPlayerData
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const CircularProgressIndicator(
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                                          ),
                                          const SizedBox(height: 20),
                                          Text(
                                            'Loading player data...',
                                            style: GoogleFonts.poppins(
                                              fontSize: 16,
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : GestureDetector(
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

/// Data class for player information
class PlayerData {
  final String userId;
  final String username;
  final String email;
  final String? profileImage; // Base64 encoded image
  final String? fullname;
  final String? schoolId;
  final String? gradeLevel;
  final String? section;
  final bool isSelected;

  PlayerData({
    required this.userId,
    required this.username,
    required this.email,
    this.profileImage,
    this.fullname,
    this.schoolId,
    this.gradeLevel,
    this.section,
    this.isSelected = false,
  });

  PlayerData copyWith({
    String? userId,
    String? username,
    String? email,
    String? profileImage,
    String? fullname,
    String? schoolId,
    String? gradeLevel,
    String? section,
    bool? isSelected,
  }) {
    return PlayerData(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      email: email ?? this.email,
      profileImage: profileImage ?? this.profileImage,
      fullname: fullname ?? this.fullname,
      schoolId: schoolId ?? this.schoolId,
      gradeLevel: gradeLevel ?? this.gradeLevel,
      section: section ?? this.section,
      isSelected: isSelected ?? this.isSelected,
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
