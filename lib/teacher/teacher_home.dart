// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:lexi_on_web/admin/game_create.dart';
import 'package:lexi_on_web/teacher/notification2.dart';
import 'package:lexi_on_web/teacher/class1.dart';
import 'package:lexi_on_web/teacher/student_request.dart';
import 'package:lexi_on_web/teacher/add_student.dart';
import 'package:lexi_on_web/admin/settings_admin.dart';
import 'package:lexi_on_web/start.dart';

class MyTeacherHome extends StatefulWidget {
  const MyTeacherHome({super.key});

  @override 
  State<MyTeacherHome> createState() => _MyTeacherHomeState();
}

class _MyTeacherHomeState extends State<MyTeacherHome> {
  int selectedIndex = 0;
  bool isSidebarOpen = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get pending student requests count
  Stream<int> _getPendingRequestsCount() async* {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      yield 0;
      return;
    }

    final teacherDoc = await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .get();
    if (!teacherDoc.exists) {
      yield 0;
      return;
    }

    final teacherData = teacherDoc.data();
    final teacherName = teacherData?['fullname'] ?? '';

    if (teacherName.isEmpty) {
      yield 0;
      return;
    }

    await for (var usersSnapshot
        in _firestore.collection('users').snapshots()) {
      int count = 0;
      for (var userDoc in usersSnapshot.docs) {
        if (userDoc.id == currentUser.uid) continue;

        final teacherSubDoc = await _firestore
            .collection('users')
            .doc(userDoc.id)
            .collection('teachers')
            .doc(teacherName)
            .get();

        if (teacherSubDoc.exists) {
          final status = teacherSubDoc.data()?['status'] ?? false;
          if (!status) count++;
        }
      }
      yield count;
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 400,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2F2C),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.logout,
                    size: 48,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Confirm Logout",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Are you sure you want to log out?",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[600],
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child: const Text(
                          "Cancel",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          // Navigate to start page
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const MyStart(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child: const Text(
                          "Logout",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  final List<Map<String, dynamic>> menuItems = [
    {"icon": Icons.message_rounded, "title": "Class"},
    {"icon": Icons.people, "title": "Students"},
    {"icon": Icons.request_page, "title": "Request"},
    {"icon": Icons.videogame_asset, "title": "Game Create"},
    {"icon": Icons.notifications, "title": "Notifications"},
    {"icon": Icons.settings, "title": "Settings"},
    {"icon": Icons.logout, "title": "Log Out"},
  ];

  // Pages for each sidebar option
  final List<Widget> pages = const [
    MyClass1(),
    MyAddStudent(),
    MyStudentRequest(),
    MyGameCreate(),
    MyNotification2(),
    MySettingsAdmin(),
    Center(child: Text("Logging Out...", style: TextStyle(color: Colors.white))),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E201E),
      body: LayoutBuilder(
        builder: (context, constraints) {
          double sidebarWidth = constraints.maxWidth < 400 ? 180 : 200;
          bool isLargeScreen = constraints.maxWidth > 1200;

          return Stack(
            children: [
              Column(
                children: [
                  // AppBar always full width
                  Container(
                    height: 60,
                    width: double.infinity,
                    color: Colors.white.withOpacity(0.05),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        // Hamburger button for small screens
                        if (!isLargeScreen)
                          IconButton(
                            icon: const Icon(Icons.menu, color: Colors.white),
                            onPressed: () {
                              setState(() {
                                isSidebarOpen = !isSidebarOpen;
                              });
                            },
                          ),
                        const Spacer(),
                      ],
                    ),
                  ),

                  // Main content row (Sidebar + Content)
                  Expanded(
                    child: Row(
                      children: [
                        // Sidebar - always visible on large screens
                        if (isLargeScreen)
                          Container(
                            width: sidebarWidth,
                            color: const Color(0xFF2C2F2C),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // LexiBoost logo at top
                                Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Image.asset(
                                    "assets/logo/LEXIBOOST.png",
                                    scale: 5,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _buildSidebarItem(
                                  icon: Icons.message_rounded,
                                  title: "Class",
                                  index: 0,
                                ),
                                StreamBuilder<int>(
                                  stream: _getPendingRequestsCount(),
                                  builder: (context, snapshot) {
                                    final badgeCount = snapshot.data ?? 0;
                                    return _buildSidebarItem(
                                      icon: Icons.people,
                                      title: "Students",
                                      index: 1,
                                      badgeCount: badgeCount,
                                    );
                                  },
                                ),
                                StreamBuilder<int>(
                                  stream: _getPendingRequestsCount(),
                                  builder: (context, snapshot) {
                                    final badgeCount = snapshot.data ?? 0;
                                    return _buildSidebarItem(
                                      icon: Icons.request_page,
                                      title: "Request",
                                      index: 2,
                                      badgeCount: badgeCount,
                                    );
                                  },
                                ),
                                _buildSidebarItem(
                                  icon: Icons.videogame_asset,
                                  title: "Game Create",
                                  index: 3,
                                ),
                                _buildSidebarItem(
                                  icon: Icons.notifications,
                                  title: "Notifications",
                                  index: 4,
                                ),

                                const Spacer(),

                                _buildSidebarItem(
                                  icon: Icons.settings,
                                  title: "Settings",
                                  index: 5,
                                ),
                                _buildSidebarItem(
                                  icon: Icons.logout,
                                  title: "Log Out",
                                  index: 6,
                                ),
                              ],
                            ),
                          ),

                        // Main content area: IndexedStack
                        Expanded(
                          child: Container(
                            color: const Color(0xFF1E201E),
                            child: IndexedStack(
                              index: selectedIndex,
                              children: pages,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Overlay sidebar for small screens
              if (!isLargeScreen && isSidebarOpen)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      isSidebarOpen = false;
                    });
                  },
                  child: Container(
                    color: Colors.black54,
                  ),
                ),

              // Sliding sidebar for small screens
              if (!isLargeScreen)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 250),
                  left: isSidebarOpen ? 0 : -sidebarWidth,
                  top: 60,
                  bottom: 0,
                  width: sidebarWidth,
                  child: Container(
                    color: const Color(0xFF2C2F2C),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // LexiBoost logo at top
                        Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Image.asset(
                            "assets/logo/LEXIBOOST.png",
                            scale: 5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildSidebarItem(
                          icon: Icons.message_rounded,
                          title: "Class",
                          index: 0,
                        ),
                        StreamBuilder<int>(
                          stream: _getPendingRequestsCount(),
                          builder: (context, snapshot) {
                            final badgeCount = snapshot.data ?? 0;
                            return _buildSidebarItem(
                              icon: Icons.people,
                              title: "Students",
                              index: 1,
                              badgeCount: badgeCount,
                            );
                          },
                        ),
                        StreamBuilder<int>(
                          stream: _getPendingRequestsCount(),
                          builder: (context, snapshot) {
                            final badgeCount = snapshot.data ?? 0;
                            return _buildSidebarItem(
                              icon: Icons.request_page,
                              title: "Request",
                              index: 2,
                              badgeCount: badgeCount,
                            );
                          },
                        ),
                        _buildSidebarItem(
                          icon: Icons.videogame_asset,
                          title: "Game Create",
                          index: 3,
                        ),
                        _buildSidebarItem(
                          icon: Icons.notifications,
                          title: "Notifications",
                          index: 4,
                        ),

                        const Spacer(),

                        _buildSidebarItem(
                          icon: Icons.settings,
                          title: "Settings",
                          index: 5,
                        ),
                        _buildSidebarItem(
                          icon: Icons.logout,
                          title: "Log Out",
                          index: 6,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required String title,
    required int index,
    int badgeCount = 0,
  }) {
    bool isSelected = selectedIndex == index;

    return ListTile(
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, color: isSelected ? Colors.blue : Colors.white70),
          if (badgeCount > 0)
            Positioned(
              right: -8,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF2C2F2C),
                    width: 1.5,
                  ),
                ),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                child: Center(
                  child: Text(
                    badgeCount > 99 ? '99+' : '$badgeCount',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          color: isSelected ? Colors.blue : Colors.white,
          fontSize: 15,
        ),
      ),
      selected: isSelected,
      selectedTileColor: Colors.white12,
      onTap: () {
        if (index == 6) {
          // Log Out button index
          _showLogoutDialog();
        } else {
          setState(() {
            selectedIndex = index;
            isSidebarOpen = false; // Close sidebar on selection
          });
        }
      },
    );
  }
}
