
// ===== game_save.dart =====

// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

class MyGameSave extends StatefulWidget {
  const MyGameSave({super.key});

  @override
  State<MyGameSave> createState() => _MyGameSaveState();
}

class _MyGameSaveState extends State<MyGameSave> {
  final User? user = FirebaseAuth.instance.currentUser;

  /// Store the ID of the game being "marked for delete"
  String? deletingGameId;

  Future<void> _deleteGame(String gameId) async {
    await FirebaseFirestore.instance
        .collection("users")
        .doc(user!.uid)
        .collection("created_games")
        .doc(gameId)
        .delete();
  }

  /// Get current user's role from Firestore
  Future<String> _getUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'student';

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        return userDoc.data()?['role'] ?? 'student';
      }
      return 'student';
    } catch (e) {
      return 'student';
    }
  }

  /// Navigate back based on user role
  Future<void> _navigateBack() async {
    final role = await _getUserRole();

    if (role == 'admin') {
      Get.toNamed('/admin');
    } else if (role == 'teacher') {
      Get.toNamed('/teacher_home');
    } else {
      Navigator.of(context).pop();
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
              setState(() {
                deletingGameId = null;
              });
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
    return GestureDetector(
      // Detect taps outside to reset delete mode
      onTap: () {
        if (deletingGameId != null) {
          setState(() {
            deletingGameId = null;
          });
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
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
        body: user == null
            ? Center(
                child: Text(
                  "No user logged in.",
                  style:
                      GoogleFonts.poppins(fontSize: 18, color: Colors.white70),
                ),
              )
            : StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection("users")
                    .doc(user!.uid)
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

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      // Calculate responsive card size and columns
                      double width = constraints.maxWidth;
                      int crossAxisCount;
                      double cardWidth;

                      if (width > 1400) {
                        crossAxisCount = 5;
                        cardWidth = (width - 80) / 5;
                      } else if (width > 1100) {
                        crossAxisCount = 4;
                        cardWidth = (width - 70) / 4;
                      } else if (width > 800) {
                        crossAxisCount = 3;
                        cardWidth = (width - 60) / 3;
                      } else if (width > 500) {
                        crossAxisCount = 2;
                        cardWidth = (width - 50) / 2;
                      } else {
                        crossAxisCount = 1;
                        cardWidth = width - 40;
                      }

                      // Ensure minimum card size
                      cardWidth = cardWidth.clamp(200.0, 300.0);
                      double cardHeight =
                          cardWidth * 1.3; // Maintain aspect ratio

                      return GridView.builder(
                        padding: const EdgeInsets.all(20),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: cardWidth / cardHeight,
                        ),
                        itemCount: games.length,
                        itemBuilder: (context, index) {
                          final game = games[index];
                          final title = game["title"] ?? "Untitled";
                          final gameId = game.id;
                          final description = game["description"] ?? "";
                          final difficulty = game["difficulty"] ?? "easy";
                          final prizeCoins = game["prizeCoins"] ?? "0";

                          final isDeleting = deletingGameId == gameId;

                          return GestureDetector(
                            onTap: () {
                              if (isDeleting) {
                                setState(() {
                                  deletingGameId = null;
                                });
                              } else {
                                Get.toNamed(
                                  "/game_edit",
                                  arguments: {"gameId": gameId},
                                );
                              }
                            },
                            onLongPress: () {
                              setState(() {
                                deletingGameId = gameId;
                              });
                            },
                            onSecondaryTap: () {
                              setState(() {
                                deletingGameId = gameId;
                              });
                            },
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: isDeleting
                                  ? _buildDeleteCard(gameId, title, cardWidth)
                                  : _buildGameCard(
                                      gameId,
                                      title,
                                      description,
                                      difficulty,
                                      prizeCoins,
                                      cardWidth,
                                    ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
      ),
    );
  }

  /// Build delete confirmation card
  Widget _buildDeleteCard(String gameId, String title, double cardWidth) {
    return Container(
      key: ValueKey("delete_$gameId"),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.redAccent.withOpacity(0.9),
            Colors.red.shade700.withOpacity(0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showDeleteDialog(gameId, title),
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.delete_forever, color: Colors.white, size: 60),
                const SizedBox(height: 16),
                Text(
                  "DELETE",
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
    double cardWidth,
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Get.toNamed("/game_edit", arguments: {"gameId": gameId}),
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image section
              Expanded(
                flex: 3,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade100, Colors.purple.shade100],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Image.asset(
                        "assets/others/save.png",
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),

              // Content section
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
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

                      const SizedBox(height: 6),

                      // Description
                      if (description.isNotEmpty)
                        Expanded(
                          child: Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      
                      const Spacer(),
                      
                      // Bottom info row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                          
                          // Coins
                          Row(
                            children: [
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
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

