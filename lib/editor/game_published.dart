// ===== game_published.dart =====

// ignore_for_file: deprecated_member_use, use_build_context_synchronously, avoid_print, unnecessary_null_in_if_null_operators, dead_code

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animated_button/animated_button.dart';
import 'package:lexi_on_web/teacher/game_rate.dart';

class MyGamePublished extends StatefulWidget {
  const MyGamePublished({super.key});

  @override
  State<MyGamePublished> createState() => _MyGamePublishedState();
}

class _MyGamePublishedState extends State<MyGamePublished> {
  final User? user = FirebaseAuth.instance.currentUser;
  final TextEditingController _searchController = TextEditingController();
  String _userRole = 'student'; // Default role
  String _searchQuery = '';

  /// Get current user ID - returns null if user is not authenticated
  String? get _currentUserId => user?.uid;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Get current user's role from Firestore
  Future<void> _loadUserRole() async {
    final userId = _currentUserId;
    if (userId == null) {
      setState(() {
        _userRole = 'student';
      });
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(userId) // Explicitly use current user's ID
          .get();

      if (userDoc.exists) {
        setState(() {
          _userRole = userDoc.data()?['role'] ?? 'student';
        });
      } else {
        setState(() {
          _userRole = 'student';
        });
      }
    } catch (e) {
      debugPrint('Failed to get user role: $e');
      setState(() {
        _userRole = 'student';
      });
    }
  }

  /// Navigate back based on user role
  void _navigateBack() {
    if (_userRole == 'admin') {
      Get.offAllNamed('/admin');
    } else {
      Get.offAllNamed('/teacher_home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E201E),
      appBar: AppBar(
        backgroundColor: Colors.white.withOpacity(0.05),
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _navigateBack,
        ),
        title: Center(
          child: Text(
            "Published Games",
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        actions: [
          // Empty SizedBox to balance the leading icon
          const SizedBox(width: 48),
        ],
      ),
      body: _currentUserId == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_off_outlined,
                    size: 80,
                    color: Colors.white30,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Please log in to view your published games.",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Search bar - outside StreamBuilder to prevent rebuild
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    style: GoogleFonts.poppins(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search by game name or mode (heart, time, score)...',
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
                
                // Games list with StreamBuilder
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
              // Query only current user's published games from their created_games subcollection
              stream: FirebaseFirestore.instance
                  .collection("users")
                  .doc(_currentUserId) // Explicitly use current user's ID
                  .collection("created_games")
                  .where("publish", isEqualTo: true)
                  .snapshots(),
              builder: (context, snapshot) {
                // Store current user ID - we know it's not null here since we checked earlier
                final userId = _currentUserId;
                if (userId == null) {
                  return Center(
                    child: Text(
                      "Please log in to view your published games.",
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        color: Colors.white70,
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 80, color: Colors.red),
                        const SizedBox(height: 20),
                        Text(
                          "Error loading games",
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "${snapshot.error}",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.publish_outlined,
                          size: 80,
                          color: Colors.white30,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          "No published games yet.",
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Launch a game to publish it!",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final games = snapshot.data!.docs;

                // Sort games by published_at in descending order (client-side sorting)
                games.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>?;
                  final bData = b.data() as Map<String, dynamic>?;
                  final aTime = aData?["published_at"] as Timestamp?;
                  final bTime = bData?["published_at"] as Timestamp?;
                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  return bTime.compareTo(aTime); // Descending order
                });

                // Debug: Print number of games found
                print('Published games found: ${games.length}');
                for (var game in games) {
                  final gameData = game.data() as Map<String, dynamic>?;
                  print(
                    'Game: ${gameData?["title"] ?? "Untitled"} - gameId: ${game.id}',
                  );
                }

                // Filter games based on search query
                final filteredGames = games.where((game) {
                  if (_searchQuery.isEmpty) return true;
                  
                  final gameData = game.data() as Map<String, dynamic>?;
                  final title = (gameData?["title"]?.toString() ?? "").toLowerCase();
                  final gameRule = (gameData?["gameRule"]?.toString() ?? "").toLowerCase();
                  final query = _searchQuery.toLowerCase();
                  
                  return title.contains(query) || gameRule.contains(query);
                }).toList();

                if (filteredGames.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 80,
                          color: Colors.white30,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _searchQuery.isEmpty
                              ? "No published games yet."
                              : "No games found matching \"$_searchQuery\"",
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: filteredGames.length,
                  itemBuilder: (context, index) {
                    final game = filteredGames[index];
                    final gameData = game.data() as Map<String, dynamic>?;
                    final title = gameData?["title"]?.toString() ?? "Untitled";
                    final gameId = game.id; // Document ID is the gameId
                    // userId is already defined in the builder scope above
                    final description =
                        gameData?["description"]?.toString() ?? "";
                    final difficulty =
                        gameData?["difficulty"]?.toString() ?? "easy";
                    final prizeCoins =
                        gameData?["prizeCoins"]?.toString() ?? "0";
                    final gameSet = gameData?["gameSet"]?.toString();
                    final gameCode = gameData?["gameCode"]?.toString();

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: _buildPublishedGameCard(
                        gameId,
                        title,
                        description,
                        difficulty,
                        prizeCoins,
                        userId,
                        gameSet,
                        gameCode,
                      ),
                    );
                  },
                );
              },
            ),
                  ),
                ],
              ),
    );
  }

  /// Build published game card
  Widget _buildPublishedGameCard(
    String gameId,
    String title,
    String description,
    String difficulty,
    String prizeCoins,
    String userId,
    String? gameSet,
    String? gameCode,
  ) {
    // Get difficulty color
    Color getDifficultyColor() {
      switch (difficulty.toLowerCase()) {
        case 'easy':
          return Colors.green;
        case 'easy-normal':
          return Colors.lightGreen;
        case 'normal':
          return Colors.blue;
        case 'hard':
          return Colors.orange;
        case 'insane':
          return Colors.red;
        case 'brainstorm':
          return Colors.purple;
        case 'hard-brainstorm':
          return Colors.deepPurple;
        default:
          return Colors.grey;
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 600;

        return Container(
          key: ValueKey("normal_$gameId"),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: isSmallScreen
                ? _buildMobileLayout(
                    gameId,
                    title,
                    description,
                    difficulty,
                    prizeCoins,
                    userId,
                    gameSet,
                    gameCode,
                    getDifficultyColor,
                  )
                : _buildDesktopLayout(
                    gameId,
                    title,
                    description,
                    difficulty,
                    prizeCoins,
                    userId,
                    gameSet,
                    gameCode,
                    getDifficultyColor,
                  ),
          ),
        );
      },
    );
  }

  /// Build desktop/tablet layout (horizontal)
  Widget _buildDesktopLayout(
    String gameId,
    String title,
    String description,
    String difficulty,
    String prizeCoins,
    String userId,
    String? gameSet,
    String? gameCode,
    Color Function() getDifficultyColor,
  ) {
    return Row(
      children: [
        // Icon/Image Container with Published Badge
        Stack(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade100, Colors.teal.shade100],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Image.asset(
                  "assets/others/publishGame.png",
                  width: 50,
                  height: 50,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            // Published badge
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.shade600,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.public, color: Colors.white, size: 10),
                    const SizedBox(width: 2),
                    Text(
                      "PUB",
                      style: GoogleFonts.poppins(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),

        // Content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Title
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),

              // Description
              if (description.isNotEmpty)
                Text(
                  description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.black54,
                  ),
                ),

              const SizedBox(height: 8),

              // Bottom info
              Row(
                children: [
                  // Difficulty badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: getDifficultyColor().withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: getDifficultyColor(),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      difficulty.toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: getDifficultyColor(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Coins
                  Icon(
                    Icons.monetization_on,
                    color: Colors.amber.shade700,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    prizeCoins,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Animated Buttons
        Row(
          children: [
            AnimatedButton(
              height: 50,
              width: 90,
              color: Colors.green,
              shadowDegree: ShadowDegree.light,
              onPressed: () =>
                  Get.toNamed("/game_edit", arguments: {"gameId": gameId}),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Edit",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.edit, color: Colors.white, size: 16),
                ],
              ),
            ),
            // Review button - only show if user is not admin
            if (_userRole != 'admin') ...[
              const SizedBox(width: 6),
              AnimatedButton(
                height: 50,
                width: 100,
                color: Colors.orange,
                shadowDegree: ShadowDegree.light,
                onPressed: () {
                  print(
                    'Navigating to game_rate with gameId: $gameId, title: $title',
                  );
                  try {
                    Get.toNamed(
                      "/game_rate",
                      arguments: {"gameId": gameId, "title": title},
                    );
                  } catch (e) {
                    print('Navigation error: $e');
                    // Fallback to direct navigation
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const MyGameRate(),
                        settings: RouteSettings(
                          arguments: {"gameId": gameId, "title": title},
                        ),
                      ),
                    );
                  }
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Review",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.star, color: Colors.white, size: 16),
                  ],
                ),
              ),
            ],
            if (_userRole != 'admin') const SizedBox(width: 6),
            AnimatedButton(
              height: 50,
              width: 100,
              color: Colors.blueAccent,
              shadowDegree: ShadowDegree.light,
              onPressed: () {
                // Debug: Print values before navigation
                print('🔍 Navigation Debug:');
                print('  gameId: $gameId');
                print('  title: $title');
                print('  gameSet: $gameSet');
                print('  gameCode: $gameCode');
                print('  userId: $userId');
                
                // Build URL with proper null handling
                final titleParam = title.isNotEmpty ? Uri.encodeComponent(title) : '';
                final gameSetParam = gameSet != null && gameSet.isNotEmpty ? Uri.encodeComponent(gameSet) : '';
                final gameCodeParam = gameCode != null && gameCode.isNotEmpty ? Uri.encodeComponent(gameCode) : '';
                
                final url = "/game_manage?gameId=$gameId&title=$titleParam&gameSet=$gameSetParam&gameCode=$gameCodeParam&userId=$userId";
                print('  URL: $url');
                
                Get.toNamed(
                  url,
                  arguments: {
                    "gameId": gameId,
                    "title": title,
                    "gameSet": gameSet,
                    "gameCode": gameCode,
                    "userId": userId,
                  },
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Manage",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.settings, color: Colors.white, size: 16),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Build mobile layout (vertical stacking)
  Widget _buildMobileLayout(
    String gameId,
    String title,
    String description,
    String difficulty,
    String prizeCoins,
    String userId,
    String? gameSet,
    String? gameCode,
    Color Function() getDifficultyColor,
  ) {
    return Column(
      children: [
        // Top section: Icon and Content
        Row(
          children: [
            // Icon/Image Container with Published Badge
            Stack(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade100, Colors.teal.shade100],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Image.asset(
                      "assets/others/publishGame.png",
                      width: 40,
                      height: 40,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                // Published badge
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade600,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.public, color: Colors.white, size: 8),
                        const SizedBox(width: 1),
                        Text(
                          "PUB",
                          style: GoogleFonts.poppins(
                            fontSize: 7,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Bottom info
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      // Difficulty badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: getDifficultyColor().withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: getDifficultyColor(),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          difficulty.toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: getDifficultyColor(),
                          ),
                        ),
                      ),

                      // Coins
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.monetization_on,
                            color: Colors.amber.shade700,
                            size: 14,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            prizeCoins,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Action Buttons (horizontal on mobile)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: AnimatedButton(
                height: 40,
                color: Colors.green,
                shadowDegree: ShadowDegree.light,
                onPressed: () =>
                    Get.toNamed("/game_edit", arguments: {"gameId": gameId}),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.edit, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      "Edit",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Review button - only show if user is not admin
            if (_userRole != 'admin') ...[
              const SizedBox(width: 6),
              Expanded(
                child: AnimatedButton(
                  height: 40,
                  color: Colors.orange,
                  shadowDegree: ShadowDegree.light,
                  onPressed: () {
                    print(
                      'Navigating to game_rate with gameId: $gameId, title: $title',
                    );
                    try {
                      Get.toNamed(
                        "/game_rate",
                        arguments: {"gameId": gameId, "title": title},
                      );
                    } catch (e) {
                      print('Navigation error: $e');
                      // Fallback to direct navigation
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const MyGameRate(),
                          settings: RouteSettings(
                            arguments: {"gameId": gameId, "title": title},
                          ),
                        ),
                      );
                    }
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        "Review",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (_userRole != 'admin') const SizedBox(width: 6),
            Expanded(
              child: AnimatedButton(
                height: 40,
                color: Colors.blueAccent,
                shadowDegree: ShadowDegree.light,
                onPressed: () {
                  // Build URL with proper null handling
                  final titleParam = title.isNotEmpty ? Uri.encodeComponent(title) : '';
                  final gameSetParam = gameSet != null && gameSet.isNotEmpty ? Uri.encodeComponent(gameSet) : '';
                  final gameCodeParam = gameCode != null && gameCode.isNotEmpty ? Uri.encodeComponent(gameCode) : '';
                  
                  Get.toNamed(
                    "/game_manage?gameId=$gameId&title=$titleParam&gameSet=$gameSetParam&gameCode=$gameCodeParam&userId=$userId",
                    arguments: {
                      "gameId": gameId,
                      "title": title,
                      "gameSet": gameSet,
                      "gameCode": gameCode,
                      "userId": userId,
                    },
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.settings, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      "Manage",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
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
