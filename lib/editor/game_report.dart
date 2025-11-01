// ignore_for_file: deprecated_member_use, use_build_context_synchronously, avoid_print

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import 'package:animated_button/animated_button.dart';

class MyGameReports extends StatefulWidget {
  const MyGameReports({super.key});

  @override
  State<MyGameReports> createState() => _MyGameReportsState();
}

class _MyGameReportsState extends State<MyGameReports> {
  String _filterType = 'all'; // 'all', 'active', 'hidden'
  bool _isLoading = true;
  List<Map<String, dynamic>> _allGames = [];
  List<Map<String, dynamic>> _filteredGames = [];

  @override
  void initState() {
    super.initState();
    _loadGames();
  }

  Future<void> _loadGames() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<Map<String, dynamic>> games = [];

      // Get all users with role 'teacher'
      QuerySnapshot teachersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'teacher')
          .get();

      // Fetch all games from all teachers
      for (var teacherDoc in teachersSnapshot.docs) {
        final teacherId = teacherDoc.id;
        final teacherData = teacherDoc.data() as Map<String, dynamic>;
        final teacherName = teacherData['fullname'] ?? teacherData['username'] ?? 'Unknown Teacher';

        // Get all games created by this teacher
        QuerySnapshot gamesSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(teacherId)
            .collection('created_games')
            .get();

        for (var gameDoc in gamesSnapshot.docs) {
          final gameData = gameDoc.data() as Map<String, dynamic>;
          games.add({
            'gameId': gameDoc.id,
            'teacherId': teacherId,
            'teacherName': teacherName,
            'title': gameData['title'] ?? 'Untitled',
            'createdAt': gameData['created_at'],
            'isHidden': gameData['isHidden'] ?? false,
            'isRemoved': gameData['isRemoved'] ?? false,
            'hiddenAt': gameData['hiddenAt'],
            'removedAt': gameData['removedAt'],
            'publish': gameData['publish'] ?? false,
          });
        }
      }

      // Sort by creation date (newest first)
      games.sort((a, b) {
        final dateA = a['createdAt'] as Timestamp?;
        final dateB = b['createdAt'] as Timestamp?;
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateB.compareTo(dateA);
      });

      if (mounted) {
        setState(() {
          _allGames = games;
          _applyFilter(_filterType);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading games: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        Get.snackbar(
          'Error',
          'Failed to load games: ${e.toString()}',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
  }

  void _applyFilter(String filterType) {
    setState(() {
      _filterType = filterType;
      switch (filterType) {
        case 'active':
          _filteredGames = _allGames
              .where((game) =>
                  (game['isHidden'] == false || game['isHidden'] == null) &&
                  (game['isRemoved'] == false || game['isRemoved'] == null))
              .toList();
          break;
        case 'hidden':
          _filteredGames = _allGames
              .where((game) =>
                  game['isHidden'] == true || game['isRemoved'] == true)
              .toList();
          break;
        default: // 'all'
          _filteredGames = _allGames;
      }
    });
  }

  Future<void> _hideGame(String teacherId, String gameId, bool hide, {String? reason}) async {
    try {
      // Get game title for notification
      final gameDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(teacherId)
          .collection('created_games')
          .doc(gameId)
          .get();
      final gameTitle = gameDoc.data()?['title'] ?? 'Unknown Game';

      await FirebaseFirestore.instance
          .collection('users')
          .doc(teacherId)
          .collection('created_games')
          .doc(gameId)
          .update({
        'isHidden': hide,
        'hiddenAt': hide ? FieldValue.serverTimestamp() : null,
        'hiddenReason': hide ? (reason ?? '') : null,
      });

      // Also hide from published games if published
      if (hide) {
        try {
          await FirebaseFirestore.instance
              .collection('published_games')
              .doc(gameId)
              .update({'isHidden': true});
        } catch (e) {
          // Game might not be published, ignore error
        }
      }

      // Send notification to teacher
      if (hide && reason != null && reason.isNotEmpty) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(teacherId)
              .collection('notifications')
              .add({
            'title': 'Game Hidden by Admin',
            'message': 'Your game "$gameTitle" has been hidden. Reason: $reason',
            'type': 'game_hidden',
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
            'pinned': false,
            'hidden': false,
            'fromName': 'Admin',
          });
        } catch (e) {
          print('Error sending notification: $e');
        }
      } else if (!hide) {
        // Notification when game is restored
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(teacherId)
              .collection('notifications')
              .add({
            'title': 'Game Restored',
            'message': 'Your game "$gameTitle" has been restored and is now visible to students.',
            'type': 'game_restored',
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
            'pinned': false,
            'hidden': false,
            'fromName': 'Admin',
          });
        } catch (e) {
          print('Error sending notification: $e');
        }
      }

      Get.snackbar(
        'Success',
        hide ? 'Game hidden successfully' : 'Game restored successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      _loadGames();
    } catch (e) {
      print('Error ${hide ? 'hiding' : 'restoring'} game: $e');
      Get.snackbar(
        'Error',
        'Failed to ${hide ? 'hide' : 'restore'} game',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _removeGame(String teacherId, String gameId, bool remove, {String? reason}) async {
    try {
      // Get game title for notification
      final gameDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(teacherId)
          .collection('created_games')
          .doc(gameId)
          .get();
      final gameTitle = gameDoc.data()?['title'] ?? 'Unknown Game';

      await FirebaseFirestore.instance
          .collection('users')
          .doc(teacherId)
          .collection('created_games')
          .doc(gameId)
          .update({
        'isRemoved': remove,
        'removedAt': remove ? FieldValue.serverTimestamp() : null,
        'removedReason': remove ? (reason ?? '') : null,
      });

      // Also remove from published games if published
      if (remove) {
        try {
          await FirebaseFirestore.instance
              .collection('published_games')
              .doc(gameId)
              .delete();
        } catch (e) {
          // Game might not be published, ignore error
        }
      }

      // Send notification to teacher
      if (remove && reason != null && reason.isNotEmpty) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(teacherId)
              .collection('notifications')
              .add({
            'title': 'Game Removed by Admin',
            'message': 'Your game "$gameTitle" has been removed. Reason: $reason',
            'type': 'game_removed',
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
            'pinned': false,
            'hidden': false,
            'fromName': 'Admin',
          });
        } catch (e) {
          print('Error sending notification: $e');
        }
      } else if (!remove) {
        // Notification when game is restored
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(teacherId)
              .collection('notifications')
              .add({
            'title': 'Game Restored',
            'message': 'Your game "$gameTitle" has been restored and is now available again.',
            'type': 'game_restored',
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
            'pinned': false,
            'hidden': false,
            'fromName': 'Admin',
          });
        } catch (e) {
          print('Error sending notification: $e');
        }
      }

      Get.snackbar(
        'Success',
        remove ? 'Game removed successfully' : 'Game restored successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      _loadGames();
    } catch (e) {
      print('Error ${remove ? 'removing' : 'restoring'} game: $e');
      Get.snackbar(
        'Error',
        'Failed to ${remove ? 'remove' : 'restore'} game',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _showHideConfirmDialog(
      String gameTitle, String teacherId, String gameId, bool currentlyHidden) async {
    final TextEditingController reasonController = TextEditingController();

    return showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF2C2F33),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                currentlyHidden ? Icons.visibility : Icons.visibility_off,
                color: Colors.orange,
                size: 28,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  currentlyHidden ? "Restore Game" : "Hide Game",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 20,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.6,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentlyHidden
                      ? "Do you want to restore \"$gameTitle\"? It will be visible again."
                      : "Do you want to hide \"$gameTitle\"? It will be hidden from teachers and students.",
                  style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
                ),
                if (!currentlyHidden) ...[
                  const SizedBox(height: 16),
                  Text(
                    "Reason (Required):",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: reasonController,
                    style: GoogleFonts.poppins(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Enter reason for hiding this game...",
                      hintStyle: GoogleFonts.poppins(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.orange, width: 2),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                    maxLines: 3,
                  ),
                ],
              ],
            ),
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
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                if (!currentlyHidden && reasonController.text.trim().isEmpty) {
                  Get.snackbar(
                    'Reason Required',
                    'Please provide a reason for hiding this game',
                    backgroundColor: Colors.orange,
                    colorText: Colors.white,
                  );
                  return;
                }
                Navigator.pop(ctx);
                _hideGame(
                  teacherId,
                  gameId,
                  !currentlyHidden,
                  reason: reasonController.text.trim(),
                );
              },
              child: Text(
                currentlyHidden ? "Restore" : "Hide",
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRemoveConfirmDialog(
      String gameTitle, String teacherId, String gameId, bool currentlyRemoved) async {
    final TextEditingController reasonController = TextEditingController();

    return showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF2C2F33),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                currentlyRemoved ? Icons.restore : Icons.delete,
                color: Colors.red,
                size: 28,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  currentlyRemoved ? "Restore Game" : "Remove Game",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 20,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.6,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentlyRemoved
                      ? "Do you want to restore \"$gameTitle\"? It will be available again."
                      : "Do you want to remove \"$gameTitle\"? This action can be undone later.",
                  style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
                ),
                if (!currentlyRemoved) ...[
                  const SizedBox(height: 16),
                  Text(
                    "Reason (Required):",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: reasonController,
                    style: GoogleFonts.poppins(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Enter reason for removing this game...",
                      hintStyle: GoogleFonts.poppins(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.red, width: 2),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                    maxLines: 3,
                  ),
                ],
              ],
            ),
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
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                if (!currentlyRemoved && reasonController.text.trim().isEmpty) {
                  Get.snackbar(
                    'Reason Required',
                    'Please provide a reason for removing this game',
                    backgroundColor: Colors.orange,
                    colorText: Colors.white,
                  );
                  return;
                }
                Navigator.pop(ctx);
                _removeGame(
                  teacherId,
                  gameId,
                  !currentlyRemoved,
                  reason: reasonController.text.trim(),
                );
              },
              child: Text(
                currentlyRemoved ? "Restore" : "Remove",
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E201E),
      appBar: AppBar(
        backgroundColor: Colors.white.withOpacity(0.05),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: Text(
          "Game Controller",
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadGames,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Buttons
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                AnimatedButton(
                  height: 36,
                  width: 100,
                  color: _filterType == 'all' ? Colors.blue : Colors.grey.shade700,
                  shadowDegree: ShadowDegree.light,
                  onPressed: () => _applyFilter('all'),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.list, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        "All",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedButton(
                  height: 36,
                  width: 100,
                  color: _filterType == 'active' ? Colors.green : Colors.grey.shade700,
                  shadowDegree: ShadowDegree.light,
                  onPressed: () => _applyFilter('active'),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        "Active",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedButton(
                  height: 36,
                  width: 100,
                  color: _filterType == 'hidden' ? Colors.orange : Colors.grey.shade700,
                  shadowDegree: ShadowDegree.light,
                  onPressed: () => _applyFilter('hidden'),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.visibility_off, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        "Hidden",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Games List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : _filteredGames.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.games,
                              size: 64,
                              color: Colors.white.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _filterType == 'all'
                                  ? 'No games found'
                                  : _filterType == 'active'
                                      ? 'No active games'
                                      : 'No hidden games',
                              style: GoogleFonts.poppins(
                                color: Colors.white54,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredGames.length,
                        itemBuilder: (context, index) {
                          final game = _filteredGames[index];
                          final isHidden = game['isHidden'] == true;
                          final isRemoved = game['isRemoved'] == true;
                          final isPublished = game['publish'] == true;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isRemoved
                                    ? Colors.red.withOpacity(0.5)
                                    : isHidden
                                        ? Colors.orange.withOpacity(0.5)
                                        : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: CircleAvatar(
                                backgroundColor: isRemoved
                                    ? Colors.red
                                    : isHidden
                                        ? Colors.orange
                                        : isPublished
                                            ? Colors.green
                                            : Colors.blue,
                                child: Icon(
                                  isRemoved
                                      ? Icons.delete
                                      : isHidden
                                          ? Icons.visibility_off
                                          : Icons.games,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(
                                game['title'] ?? 'Untitled',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    'Teacher: ${game['teacherName']}',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    'Created: ${_formatDate(game['createdAt'])}',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (isPublished)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Published',
                                          style: GoogleFonts.poppins(
                                            color: Colors.green[300],
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (isHidden || isRemoved)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: (isRemoved ? Colors.red : Colors.orange)
                                              .withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          isRemoved ? 'Removed' : 'Hidden',
                                          style: GoogleFonts.poppins(
                                            color: isRemoved
                                                ? Colors.red[300]
                                                : Colors.orange[300],
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Hide/Show button
                                  IconButton(
                                    icon: Icon(
                                      isHidden ? Icons.visibility : Icons.visibility_off,
                                      color: isHidden ? Colors.green : Colors.orange,
                                    ),
                                    onPressed: () => _showHideConfirmDialog(
                                      game['title'],
                                      game['teacherId'],
                                      game['gameId'],
                                      isHidden,
                                    ),
                                    tooltip: isHidden ? 'Restore' : 'Hide',
                                  ),
                                  // Remove/Restore button
                                  IconButton(
                                    icon: Icon(
                                      isRemoved ? Icons.restore : Icons.delete,
                                      color: isRemoved ? Colors.green : Colors.red,
                                    ),
                                    onPressed: () => _showRemoveConfirmDialog(
                                      game['title'],
                                      game['teacherId'],
                                      game['gameId'],
                                      isRemoved,
                                    ),
                                    tooltip: isRemoved ? 'Restore' : 'Remove',
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
