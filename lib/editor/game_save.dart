
// ===== game_save.dart =====

// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animated_button/animated_button.dart';

class MyGameSave extends StatefulWidget {
  const MyGameSave({super.key});

  @override
  State<MyGameSave> createState() => _MyGameSaveState();
}

class _MyGameSaveState extends State<MyGameSave> {
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
          .doc(userId)
          .get();

      if (userDoc.exists) {
        setState(() {
          _userRole = userDoc.data()?['role'] ?? 'student';
        });
      }
    } catch (e) {
      debugPrint('Failed to get user role: $e');
    }
  }

  Future<void> _deleteGame(String gameId) async {
    final userId = _currentUserId;
    if (userId == null) return; // Safety check - user must be authenticated

    await FirebaseFirestore.instance
        .collection("users")
        .doc(userId)
        .collection("created_games")
        .doc(gameId)
        .delete();
  }

  /// Navigate back based on user role
  void _navigateBack() {
    if (_userRole == 'admin') {
      Get.offAllNamed('/admin');
    } else {
      Get.offAllNamed('/teacher_home');
    }
  }

  /// Show confirmation dialog
  Future<void> _showDeleteDialog(String gameId, String title) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2C2F33),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.redAccent),
            const SizedBox(width: 8),
            Text(
              "Confirm Deletion",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        content: Text(
          "Are you sure you want to delete \"$title\"?\nThis action cannot be undone.",
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
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteGame(gameId);
            },
            child: Text(
              "Delete",
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
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
              "Created Games",
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
                child: Text(
                  "No user logged in.",
                  style:
                      GoogleFonts.poppins(fontSize: 18, color: Colors.white70),
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
                      stream: FirebaseFirestore.instance
                          .collection("users")
                          .doc(_currentUserId)
                          .collection("created_games")
                          .orderBy("created_at", descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(color: Colors.white),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Center(
                            child: Text(
                              "No games created yet.",
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                color: Colors.white70,
                              ),
                            ),
                          );
                        }

                        final games = snapshot.data!.docs;

                        // Filter games based on search query
                        final filteredGames = games.where((game) {
                          if (_searchQuery.isEmpty) return true;
                          
                          final gameData = game.data() as Map<String, dynamic>? ?? {};
                          final title = (gameData["title"]?.toString() ?? "").toLowerCase();
                          final gameRule = (gameData["gameRule"]?.toString() ?? "").toLowerCase();
                          final query = _searchQuery.toLowerCase();
                          
                          return title.contains(query) || gameRule.contains(query);
                        }).toList();

                        if (filteredGames.isEmpty) {
                          return Center(
                            child: Text(
                              _searchQuery.isEmpty
                                  ? "No games created yet."
                                  : "No games found matching \"$_searchQuery\"",
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                color: Colors.white70,
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: filteredGames.length,
                          itemBuilder: (context, index) {
                            final game = filteredGames[index];
                            final gameData = game.data() as Map<String, dynamic>? ?? {};
                            final gameId = game.id;
                            final title = gameData["title"]?.toString() ?? "Untitled";
                            final description = gameData["description"]?.toString() ?? "";
                            final difficulty = gameData["difficulty"]?.toString() ?? "easy";
                            final prizeCoins = gameData["prizeCoins"]?.toString() ?? "0";

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: _buildGameCard(
                                gameId,
                                title,
                                description,
                                difficulty,
                                prizeCoins,
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


  /// Build game card
  Widget _buildGameCard(
    String gameId,
    String title,
    String description,
    String difficulty,
    String prizeCoins,
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

    return Container(
      key: ValueKey("normal_$gameId"),
      height: 120,
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
        child: Row(
          children: [
            // Icon/Image Container
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade100, Colors.purple.shade100],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Image.asset(
                  "assets/others/save.png",
                  width: 50,
                  height: 50,
                  fit: BoxFit.contain,
                ),
              ),
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

            // Action Buttons
            Row(
              children: [
                AnimatedButton(
                  height: 50,
                  width: 100,
                  color: Colors.blueAccent,
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
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.edit, color: Colors.white, size: 18),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedButton(
                  height: 50,
                  width: 100,
                  color: Colors.redAccent,
                  shadowDegree: ShadowDegree.light,
                  onPressed: () => _showDeleteDialog(gameId, title),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Delete",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.delete, color: Colors.white, size: 18),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

