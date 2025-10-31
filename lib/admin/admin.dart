// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lexi_on_web/start.dart';

// Import all your pages
import 'dashboard.dart' as admin_dashboard;
import 'request.dart';
import 'game_create.dart';
import 'report.dart';
import 'settings_admin.dart';

class MyAdmin extends StatefulWidget { 
  const MyAdmin({super.key});

  @override
  State<MyAdmin> createState() => _MyAdminState();
}

class _MyAdminState extends State<MyAdmin> {
  int selectedIndex = 0;
  bool isSidebarOpen = false;

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
    admin_dashboard.MyDashBoard(),
    MyRequest(),
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
                                    icon: Icons.dashboard, title: "Dashboard", index: 0),
                                _buildSidebarItem(
                                    icon: Icons.request_page, title: "Request", index: 1),
                                _buildSidebarItem(
                                    icon: Icons.videogame_asset,
                                    title: "Game Create",
                                    index: 2),
                                _buildSidebarItemWithBadge(
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
                            icon: Icons.dashboard, title: "Dashboard", index: 0),
                        _buildSidebarItem(
                            icon: Icons.request_page, title: "Request", index: 1),
                        _buildSidebarItem(
                            icon: Icons.videogame_asset,
                            title: "Game Create",
                            index: 2),
                        _buildSidebarItemWithBadge(
                            icon: Icons.receipt_long, title: "Report", index: 3),

                        const Spacer(),

                        _buildSidebarItem(
                            icon: Icons.settings, title: "Settings", index: 4),
                        _buildSidebarItem(
                            icon: Icons.logout, title: "Log Out", index: 5),
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
            isSidebarOpen = false; // Close sidebar on selection
          });
        }
      },
    );
  }

  Widget _buildSidebarItemWithBadge({
    required IconData icon,
    required String title,
    required int index,
  }) {
    bool isSelected = selectedIndex == index;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reports')
          .snapshots(),
      builder: (context, snapshot) {
        int badgeCount = 0;
        
        if (snapshot.hasData) {
          // Count pending reports (status: pending or null)
          badgeCount = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] as String?;
            return status == null || status == 'pending';
          }).length;
        }

        return ListTile(
          leading: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.blue : Colors.white70,
              ),
              if (badgeCount > 0)
                Positioned(
                  right: -8,
                  top: -8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF2C2F2C), width: 2),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
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
            setState(() {
              selectedIndex = index;
              isSidebarOpen = false; // Close sidebar on selection
            });
          },
        );
      },
    );
  }
}
