// ===== game_published.dart =====

// ignore_for_file: deprecated_member_use, use_build_context_synchronously, avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

class MyGamePublished extends StatefulWidget {
  const MyGamePublished({super.key});

  @override
  State<MyGamePublished> createState() => _MyGamePublishedState();
}

class _MyGamePublishedState extends State<MyGamePublished> {
  final User? user = FirebaseAuth.instance.currentUser;

  /// Store the ID of the game being "marked for unpublish"
  String? unpublishingGameId;

  Future<void> _unpublishGame(String userId, String gameId) async {
    // Update the game document to set publish = false
    await FirebaseFirestore.instance
        .collection("users")
        .doc(userId)
        .collection("created_games")
        .doc(gameId)
        .update({'publish': false});

    // Remove from published_games collection
    await FirebaseFirestore.instance
        .collection("published_games")
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
  Future<void> _showUnpublishDialog(
    String userId,
    String gameId,
    String title,
  ) async {
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
          "Are you sure you want to unpublish \"$title\"?\nThis will remove it from the published games list.",
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
            onPressed: () async {
              Navigator.pop(ctx);
              await _unpublishGame(userId, gameId);
              setState(() {
                unpublishingGameId = null;
              });
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Detect taps outside to reset unpublish mode
      onTap: () {
        if (unpublishingGameId != null) {
          setState(() {
            unpublishingGameId = null;
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
        body: StreamBuilder<QuerySnapshot>(
          // Query from root-level published_games collection
          stream: FirebaseFirestore.instance
              .collection("published_games")
              .orderBy("published_at", descending: true)
              .snapshots(),
          builder: (context, snapshot) {
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

            // Debug: Print number of games found
            print('Published games found: ${games.length}');
            for (var game in games) {
              print('Game: ${game["title"]} - gameId: ${game["gameId"]}');
            }

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
                double cardHeight = cardWidth * 1.3; // Maintain aspect ratio

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
                    final gameId = game["gameId"] ?? game.id;
                    final userId = game["userId"] ?? "";
                    final description = game["description"] ?? "";
                    final difficulty = game["difficulty"] ?? "easy";
                    final prizeCoins = game["prizeCoins"] ?? "0";

                    final isUnpublishing = unpublishingGameId == gameId;

                    // Only allow unpublishing if current user is the owner
                    final canUnpublish = user != null && userId == user!.uid;

                    return GestureDetector(
                      onTap: () {
                        if (isUnpublishing) {
                          setState(() {
                            unpublishingGameId = null;
                          });
                        } else {
                          Get.toNamed(
                            "/game_edit",
                            arguments: {"gameId": gameId},
                          );
                        }
                      },
                      onLongPress: canUnpublish
                          ? () {
                              setState(() {
                                unpublishingGameId = gameId;
                              });
                            }
                          : null,
                      onSecondaryTap: canUnpublish
                          ? () {
                              setState(() {
                                unpublishingGameId = gameId;
                              });
                            }
                          : null,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: isUnpublishing
                            ? _buildUnpublishCard(
                                userId,
                                gameId,
                                title,
                                cardWidth,
                              )
                            : _buildPublishedGameCard(
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

  /// Build unpublish confirmation card
  Widget _buildUnpublishCard(
    String userId,
    String gameId,
    String title,
    double cardWidth,
  ) {
    return Container(
      key: ValueKey("unpublish_$gameId"),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orangeAccent.withOpacity(0.9),
            Colors.orange.shade700.withOpacity(0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showUnpublishDialog(userId, gameId, title),
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.unpublished, color: Colors.white, size: 60),
                const SizedBox(height: 16),
                Text(
                  "UNPUBLISH",
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

  /// Build published game card
  Widget _buildPublishedGameCard(
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
              // Image section with published badge
              Expanded(
                flex: 3,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.green.shade100, Colors.teal.shade100],
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
                            "assets/others/publishGame.png",
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    // Published badge
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.green.shade600,
                              Colors.green.shade700,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.public,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "PUBLISHED",
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
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
