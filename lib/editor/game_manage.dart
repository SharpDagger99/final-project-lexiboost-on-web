// ignore_for_file: deprecated_member_use, use_build_context_synchronously, avoid_print, unnecessary_null_in_if_null_operators

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animated_button/animated_button.dart';

class MyManagement extends StatefulWidget {
  const MyManagement({super.key});

  @override
  State<MyManagement> createState() => _MyManagementState();
}

class _MyManagementState extends State<MyManagement> {
  final User? user = FirebaseAuth.instance.currentUser;
  List<Map<String, dynamic>>? completedUsers;
  List<Map<String, dynamic>>? allCompletedUsers; // Store all users
  List<String>? myStudentIds; // Store teacher's student IDs
  bool isLoading = true;
  String? gameId;
  String? title;
  String? gameSet;
  String? gameCode;
  String? userId;
  String _filterType = 'all'; // 'all' or 'my_students'

  @override
  void initState() {
    super.initState();
    _getArguments();
  }

  void _getArguments() {
    final args = Get.arguments as Map<String, dynamic>?;
    if (args != null) {
      setState(() {
        gameId = args['gameId'] as String?;
        title = args['title'] as String?;
        gameSet = args['gameSet'] as String?;
        gameCode = args['gameCode'] as String?;
        userId = args['userId'] as String? ?? user?.uid;
      });
      if (gameId != null) {
        _loadData();
      }
    }
  }

  Future<void> _loadData() async {
    if (gameId == null || userId == null) return;
    
    // Fetch completed users and teacher's students in parallel
    final results = await Future.wait([
      _fetchCompletedUsers(gameId!),
      _fetchMyStudentIds(),
    ]);
    
    final users = results[0] as List<Map<String, dynamic>>;
    final studentIds = results[1] as List<String>;
    
    if (mounted) {
      setState(() {
        allCompletedUsers = users;
        myStudentIds = studentIds;
        completedUsers = users; // Default to all
        isLoading = false;
      });
    }
  }

  /// Fetch student IDs that belong to the teacher's classes
  Future<List<String>> _fetchMyStudentIds() async {
    try {
      if (userId == null) return [];
      
      List<String> studentIds = [];
      
      // Get all classes where the teacher is the owner
      QuerySnapshot classesSnapshot = await FirebaseFirestore.instance
          .collection('classes')
          .where('teacherId', isEqualTo: userId)
          .get();
      
      // Collect all student IDs from all classes
      for (var classDoc in classesSnapshot.docs) {
        final classData = classDoc.data() as Map<String, dynamic>;
        final students = List<String>.from(classData['studentIds'] ?? []);
        studentIds.addAll(students);
      }
      
      // Remove duplicates
      return studentIds.toSet().toList();
    } catch (e) {
      print('Error fetching my students: $e');
      return [];
    }
  }

  /// Filter completed users based on selected filter
  void _applyFilter(String filterType) {
    if (allCompletedUsers == null) return;
    
    setState(() {
      _filterType = filterType;
      
      if (filterType == 'all') {
        completedUsers = allCompletedUsers;
      } else if (filterType == 'my_students' && myStudentIds != null) {
        // Filter to show only students that belong to the teacher
        // We need to match by user ID - but we only have username and profileImage
        // Let's fetch user IDs for completed users and match them
        _filterMyStudents();
      }
    });
  }

  /// Filter to show only teacher's students
  void _filterMyStudents() {
    if (allCompletedUsers == null || myStudentIds == null) return;
    
    // Filter using the stored userId in the data
    final filtered = allCompletedUsers!.where((userData) {
      final userId = userData['userId'] as String?;
      return userId != null && myStudentIds!.contains(userId);
    }).toList();
    
    setState(() {
      completedUsers = filtered;
    });
  }

  /// Fetch users who completed a specific game
  Future<List<Map<String, dynamic>>> _fetchCompletedUsers(String gameId) async {
    try {
      List<Map<String, dynamic>> completedUsers = [];

      QuerySnapshot usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      for (var userDoc in usersSnapshot.docs) {
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
            'userId': userDoc.id, // Store user ID for filtering
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

  Future<void> _unpublishGame() async {
    if (userId == null || gameId == null) return;

    await FirebaseFirestore.instance
        .collection("users")
        .doc(userId!)
        .collection("created_games")
        .doc(gameId!)
        .update({'publish': false});

    try {
      await FirebaseFirestore.instance
          .collection("published_games")
          .doc(gameId!)
          .delete();
    } catch (e) {
      print('Note: Could not delete from published_games collection: $e');
    }

    Get.back();
    Get.snackbar(
      'Success',
      'Game unpublished successfully',
      backgroundColor: Colors.green,
      colorText: Colors.white,
    );
  }

  /// Show dialog to change game code
  Future<void> _showChangeGameCodeDialog() async {
    final TextEditingController gameCodeController = TextEditingController(
      text: gameCode ?? '',
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
              if (userId == null || gameId == null) return;
              
              String newGameCode = gameCodeController.text.trim().replaceAll(
                '-',
                '',
              );
              String newGameSet = newGameCode.isEmpty ? "public" : "private";

              await FirebaseFirestore.instance
                  .collection("users")
                  .doc(userId!)
                  .collection("created_games")
                  .doc(gameId!)
                  .update({
                    'gameSet': newGameSet,
                    'gameCode': newGameCode.isEmpty ? null : newGameCode,
                  });
              
              setState(() {
                gameCode = newGameCode.isEmpty ? null : newGameCode;
                gameSet = newGameSet;
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

  /// Show confirmation dialog for unpublishing
  Future<void> _showUnpublishDialog() async {
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
          "Are you sure you want to unpublish \"${title ?? 'this game'}\"?\nThis will remove it from the published games list.",
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
            onPressed: () {
              Navigator.pop(ctx);
              _unpublishGame();
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

  @override
  Widget build(BuildContext context) {
    if (gameId == null || title == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF1E201E),
        appBar: AppBar(
          backgroundColor: Colors.white.withOpacity(0.05),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Get.back(),
          ),
          title: Text(
            "Game Management",
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        body: Center(
          child: Text(
            "No game data found",
            style: GoogleFonts.poppins(color: Colors.white70),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1E201E),
      appBar: AppBar(
        backgroundColor: Colors.white.withOpacity(0.05),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: Text(
          "Game Management",
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isSmallScreen = constraints.maxWidth < 600;
          final padding = isSmallScreen ? 16.0 : 24.0;

          return SingleChildScrollView(
            padding: EdgeInsets.all(padding),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - kToolbarHeight - padding * 2,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.purple[700]!, Colors.purple[500]!],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.settings, color: Colors.white, size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            title!,
                            style: GoogleFonts.poppins(
                              fontSize: isSmallScreen ? 18 : 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Control Section
                  Text(
                    "CONTROL",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Control Buttons - Responsive scrollable layout
                  SizedBox(
                    height: 50,
                    child: Scrollbar(
                      thumbVisibility: true,
                      child: ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context).copyWith(
                          dragDevices: {
                            PointerDeviceKind.mouse,
                            PointerDeviceKind.touch,
                          },
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                AnimatedButton(
                                  height: 50,
                                  width: 150,
                                  color: Colors.orange,
                                  shadowDegree: ShadowDegree.light,
                                  onPressed: _showUnpublishDialog,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      const SizedBox(width: 5),
                                      const Icon(Icons.unpublished, color: Colors.white, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        "Unpublish",
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                AnimatedButton(
                                  height: 50,
                                  width: 200, // Increased width to fit "Change Game Code" text
                                  color: Colors.blue,
                                  shadowDegree: ShadowDegree.light,
                                  onPressed: _showChangeGameCodeDialog,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      const SizedBox(width: 5),
                                      const Icon(Icons.lock, color: Colors.white, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        "Change Game Code",
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                AnimatedButton(
                                  height: 50,
                                  width: 170,
                                  color: Colors.green,
                                  shadowDegree: ShadowDegree.light,
                                  onPressed: () {
                                    Get.toNamed(
                                      "/game_edit",
                                      arguments: {"gameId": gameId},
                                    );
                                  },
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      const SizedBox(width: 5),
                                      const Icon(Icons.edit, color: Colors.white, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        "Edit Game Set",
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 24),

                  // Status Section
                  Text(
                    "STATUS",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Status Cards - Scrollable row
                  SizedBox(
                    height: 150,
                    child: Scrollbar(
                      thumbVisibility: true,
                      child: ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context).copyWith(
                          dragDevices: {
                            PointerDeviceKind.mouse,
                            PointerDeviceKind.touch,
                          },
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 300,
                                  child: _buildStatusCard(
                                    "Total Players",
                                    isLoading
                                        ? "..."
                                        : "${completedUsers?.length ?? 0}",
                                    Icons.people,
                                    Colors.purple,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 300,
                                  child: _buildStatusCard(
                                    "Game Set",
                                    gameSet ?? "None",
                                    Icons.category,
                                    Colors.blue,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 300,
                                  child: _buildStatusCard(
                                    "Game Code",
                                    gameCode ?? "None",
                                    Icons.lock,
                                    Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Players List Section
                  Row(
                    children: [
                      Text(
                        "PLAYERS WHO COMPLETED",
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const Spacer(),
                      // Filter Buttons
                      Row(
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
                                const Icon(
                                  Icons.people_outline,
                                  color: Colors.white,
                                  size: 16,
                                ),
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
                            width: 120,
                            color: _filterType == 'my_students' ? Colors.purple : Colors.grey.shade700,
                            shadowDegree: ShadowDegree.light,
                            onPressed: () => _applyFilter('my_students'),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.person_outline,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "My Students",
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
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (isLoading)
                    Container(
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            const CircularProgressIndicator(
                              color: Colors.white,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "Loading players...",
                              style: GoogleFonts.poppins(
                                color: Colors.white54,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (completedUsers == null || completedUsers!.isEmpty)
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
                      constraints: BoxConstraints(
                        maxHeight: constraints.maxHeight * 0.4,
                      ),
                      child: Scrollbar(
                        thumbVisibility: true,
                        child: ScrollConfiguration(
                          behavior: ScrollConfiguration.of(context).copyWith(
                            dragDevices: {
                              PointerDeviceKind.mouse,
                              PointerDeviceKind.touch,
                            },
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: completedUsers!.length,
                            separatorBuilder: (context, index) => Divider(
                              color: Colors.white.withOpacity(0.1),
                              height: 1,
                            ),
                            itemBuilder: (context, index) {
                              final player = completedUsers![index];
                              return ListTile(
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: isSmallScreen ? 12 : 16,
                                  vertical: 8,
                                ),
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
                      ),
                    ),
                ],
              ),
            ),
          );
        },
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
