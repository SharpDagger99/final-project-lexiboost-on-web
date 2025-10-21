// ===== game_published.dart =====

// ignore_for_file: deprecated_member_use, use_build_context_synchronously, avoid_print, unnecessary_null_in_if_null_operators

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

class MyGamePublished extends StatefulWidget {
  const MyGamePublished({super.key});

  @override
  State<MyGamePublished> createState() => _MyGamePublishedState();
}

class _MyGamePublishedState extends State<MyGamePublished> {
  final User? user = FirebaseAuth.instance.currentUser;

  /// Fetch users who completed a specific game
  Future<List<Map<String, dynamic>>> _fetchCompletedUsers(String gameId) async {
    try {
      List<Map<String, dynamic>> completedUsers = [];

      // Get all users
      QuerySnapshot usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      for (var userDoc in usersSnapshot.docs) {
        // Check if this user has completed the game
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
          completedUsers.add({
            'username': userData['username'] ?? 'Unknown User',
            'profileImage': userData['profileImage'] ?? '',
            'completedAt': completedData?['completedAt'] ?? null,
          });
        }
      }

      return completedUsers;
    } catch (e) {
      print('Error fetching completed users: $e');
      return [];
    }
  }

  Future<void> _unpublishGame(String userId, String gameId) async {
    // Update the game document to set publish = false
    await FirebaseFirestore.instance
        .collection("users")
        .doc(userId)
        .collection("created_games")
        .doc(gameId)
        .update({'publish': false});

    // Also remove from root-level published_games collection if it exists
    try {
      await FirebaseFirestore.instance
          .collection("published_games")
          .doc(gameId)
          .delete();
    } catch (e) {
      // Ignore error if document doesn't exist in published_games
      print('Note: Could not delete from published_games collection: $e');
    }
  }

  /// Show dialog to change game code
  Future<void> _showChangeGameCodeDialog(
    String userId,
    String gameId,
    String? currentGameSet,
    String? currentGameCode,
  ) async {
    final TextEditingController gameCodeController = TextEditingController(
      text: currentGameCode ?? '',
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
              String newGameCode = gameCodeController.text.trim().replaceAll(
                '-',
                '',
              );
              String newGameSet = newGameCode.isEmpty ? "public" : "private";

              await FirebaseFirestore.instance
                  .collection("users")
                  .doc(userId)
                  .collection("created_games")
                  .doc(gameId)
                  .update({
                    'gameSet': newGameSet,
                    'gameCode': newGameCode.isEmpty ? null : newGameCode,
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

  /// Show game control and status dialog
  Future<void> _showGameControlDialog(
    String userId,
    String gameId,
    String title,
    String? gameSet,
    String? gameCode,
  ) async {
    // Fetch completed users
    List<Map<String, dynamic>> completedUsers = await _fetchCompletedUsers(
      gameId,
    );

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF2C2F33),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.5,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple[700]!, Colors.purple[500]!],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.settings, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Control Section
                      Text(
                        "CONTROL",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Control Buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.unpublished, size: 20),
                              label: Text(
                                "Unpublish",
                                style: GoogleFonts.poppins(fontSize: 13),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _showUnpublishDialog(userId, gameId, title);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.lock, size: 20),
                              label: Text(
                                "Game Code",
                                style: GoogleFonts.poppins(fontSize: 13),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _showChangeGameCodeDialog(
                                  userId,
                                  gameId,
                                  gameSet,
                                  gameCode,
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.edit, size: 20),
                              label: Text(
                                "Game Set",
                                style: GoogleFonts.poppins(fontSize: 13),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
                                Get.toNamed(
                                  "/game_edit",
                                  arguments: {"gameId": gameId},
                                );
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),
                      const Divider(color: Colors.white24),
                      const SizedBox(height: 24),

                      // Status Section
                      Text(
                        "STATUS",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Status Cards
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatusCard(
                              "Total Players",
                              "${completedUsers.length}",
                              Icons.people,
                              Colors.purple,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatusCard(
                              "Game Set",
                              gameSet ?? "None",
                              Icons.category,
                              Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatusCard(
                              "Game Code",
                              gameCode ?? "None",
                              Icons.lock,
                              Colors.green,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Players List
                      Text(
                        "PLAYERS WHO COMPLETED",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (completedUsers.isEmpty)
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
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: completedUsers.length,
                            separatorBuilder: (context, index) => Divider(
                              color: Colors.white.withOpacity(0.1),
                              height: 1,
                            ),
                            itemBuilder: (context, index) {
                              final player = completedUsers[index];
                              return ListTile(
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
                                subtitle: player['completedAt'] != null
                                    ? Text(
                                        "Completed: ${_formatDate(player['completedAt'])}",
                                        style: GoogleFonts.poppins(
                                          color: Colors.white54,
                                          fontSize: 12,
                                        ),
                                      )
                                    : null,
                                trailing: const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                ),
                              );
                            },
                          ),
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
        body: user == null
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
            : StreamBuilder<QuerySnapshot>(
                // Query only current user's published games from their created_games subcollection
                stream: FirebaseFirestore.instance
                    .collection("users")
                    .doc(user!.uid)
                    .collection("created_games")
                    .where("publish", isEqualTo: true)
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
                        final gameData = game.data() as Map<String, dynamic>?;
                        final title = gameData?["title"] ?? "Untitled";
                          final gameId = game.id; // Document ID is the gameId
                          final userId = user!.uid; // Current user is the owner
                        final description = gameData?["description"] ?? "";
                        final difficulty = gameData?["difficulty"] ?? "easy";
                        final prizeCoins = gameData?["prizeCoins"] ?? "0";
                        final gameSet = gameData?["gameSet"] as String?;
                        final gameCode = gameData?["gameCode"] as String?;

                        return Listener(
                          onPointerDown: (event) {
                            // Prevent browser context menu on right-click (button 2)
                            if (event.kind == PointerDeviceKind.mouse &&
                                event.buttons == 2) {
                              // Consume the event to prevent default browser menu
                              return;
                            }
                          },
                          child: GestureDetector(
                            // This behavior ensures all gestures are captured
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                          Get.toNamed(
                            "/game_edit",
                            arguments: {"gameId": gameId},
                              );
                            },
                            onLongPress: () {
                              _showGameControlDialog(
                                userId,
                                gameId,
                                title,
                                gameSet,
                                gameCode,
                              );
                            },
                            onSecondaryTapDown: (details) {
                              // Explicitly handle secondary tap to prevent default menu
                              _showGameControlDialog(
                                userId,
                                gameId,
                                title,
                                gameSet,
                                gameCode,
                              );
                            },
                            onSecondaryTap: () {
                              // Additional handler for secondary tap
                              _showGameControlDialog(
                                userId,
                                gameId,
                                title,
                                gameSet,
                                gameCode,
                              );
                            },
                            child: _buildPublishedGameCard(
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
