// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lexi_on_web/admin/dashboard.dart';
import 'package:lexi_on_web/admin/game_create.dart';
import 'package:lexi_on_web/admin/report.dart';
import 'package:lexi_on_web/teacher/student_request.dart';
import 'package:lexi_on_web/admin/settings_admin.dart';
import 'package:lexi_on_web/start.dart';

// Import all your pages


class MyTeacherHome extends StatefulWidget {
  const MyTeacherHome({super.key});

  @override 
  State<MyTeacherHome> createState() => _MyTeacherHomeState();
}

class _MyTeacherHomeState extends State<MyTeacherHome> {
  int selectedIndex = 0;

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
    {"icon": Icons.dashboard, "title": "Dashboard"},
    {"icon": Icons.request_page, "title": "Request"},
    {"icon": Icons.videogame_asset, "title": "Game Create"},
    {"icon": Icons.receipt_long, "title": "Report"},
    {"icon": Icons.settings, "title": "Settings"},
    {"icon": Icons.logout, "title": "Log Out"},
  ];

  // Pages for each sidebar option
  final List<Widget> pages = const [
    MyDashBoard(),
    MyStudentRequest(),
    MyGameCreate(),
    MyReport(),
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

          return Column(
            children: [
              // AppBar always full width
              Container(
                height: 60,
                width: double.infinity,
                color: Colors.white.withOpacity(0.05),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Image.asset("assets/logo/LEXIBOOST.png", scale: 5),
                    const Spacer(),
                  ],
                ),
              ),

              // Main content row (Sidebar + Content)
              Expanded(
                child: Row(
                  children: [
                    // Sidebar
                    Container(
                      width: sidebarWidth,
                      color: const Color(0xFF2C2F2C),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSidebarItem(
                              icon: Icons.dashboard, title: "Dashboard", index: 0),
                          _buildSidebarItem(
                              icon: Icons.request_page, title: "Request", index: 1),
                          _buildSidebarItem(
                              icon: Icons.videogame_asset,
                              title: "Game Create",
                              index: 2),
                          _buildSidebarItem(
                              icon: Icons.receipt_long, title: "Report", index: 3),

                          const Spacer(),

                          _buildSidebarItem(
                              icon: Icons.settings, title: "Settings", index: 4),
                          _buildSidebarItem(
                              icon: Icons.logout, title: "Log Out", index: 5),
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
          );
        },
      ),
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required String title,
    required int index,
  }) {
    bool isSelected = selectedIndex == index;

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Colors.blue : Colors.white70,
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
        if (index == 5) { // Logout button index
          _showLogoutDialog();
        } else {
          setState(() {
            selectedIndex = index;
          });
        }
      },
    );
  }
}