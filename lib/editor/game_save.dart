
// ===== game_save.dart =====

// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:animated_button/animated_button.dart';
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

                  return Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      alignment: WrapAlignment.start,
                      children: games.map((game) {
                        final title = game["title"] ?? "Untitled";
                        final gameId = game.id;

                        final isDeleting = deletingGameId == gameId;

                        return GestureDetector(
                          onTap: () {
                            if (isDeleting) {
                              // if deleting mode active -> reset instead of navigating
                              setState(() {
                                deletingGameId = null;
                              });
                            } else {
                              // normal navigation -> pass gameId to editor
                              Get.toNamed("/game_edit", arguments: {"gameId": gameId});
                            }
                          },
                          onLongPress: () {
                            // Only enter delete mode, no navigation
                            setState(() {
                              deletingGameId = gameId;
                            });
                          },
                          onSecondaryTap: () {
                            // Right click activates delete overlay
                            setState(() {
                              deletingGameId = gameId;
                            });
                          },
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: isDeleting
                                ? AnimatedButton(
                                    key: ValueKey("delete_$gameId"),
                                    width: 250,
                                    height: 250,
                                    color: Colors.redAccent.withOpacity(0.85),
                                    shadowDegree: ShadowDegree.dark,
                                    onPressed: () {
                                      _showDeleteDialog(gameId, title);
                                    },
                                    child: Center(
                                      child: Text(
                                        "DELETE",
                                        style: GoogleFonts.poppins(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  )
                                : IgnorePointer(
                                    // 👈 Prevent AnimatedButton from triggering while long-press gesture is used
                                    ignoring: isDeleting,
                                    child: AnimatedButton(
                                      key: ValueKey("normal_$gameId"),
                                      width: 250,
                                      height: 250,
                                      color: Colors.white,
                                      shadowDegree: ShadowDegree.light,
                                      onPressed: () {
                                        // Navigation is handled by parent onTap
                                        Get.toNamed("/game_edit", arguments: {"gameId": gameId});
                                      },
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Expanded(
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.all(16.0),
                                              child: Image.asset(
                                                "assets/others/save.png",
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(8.0),
                                            color:
                                                Colors.black.withOpacity(0.05),
                                            child: Text(
                                              title,
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.poppins(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black,
                                              ),
                                            ),
                                          ),

                                          

                                          
                                        ],
                                      ),
                                    ),
                                  ),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
      ),
    );
  }
}



