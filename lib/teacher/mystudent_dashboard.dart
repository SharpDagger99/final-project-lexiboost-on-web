// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MyStudentDashboards extends StatefulWidget {
  final Function(int)? onNavigate;
  
  const MyStudentDashboards({super.key, this.onNavigate});

  @override
  State<MyStudentDashboards> createState() => _MyStudentDashboardsState();
}

class _MyStudentDashboardsState extends State<MyStudentDashboards> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E201E),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Header
            Text(
              'Teacher Dashboard',
              style: GoogleFonts.poppins(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Overview of your teaching activities',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 32),

            // Stats Cards
            LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount = 1;
                if (constraints.maxWidth > 1200) {
                  crossAxisCount = 4;
                } else if (constraints.maxWidth > 800) {
                  crossAxisCount = 2;
                }

                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.5,
                  children: [
                    _buildStatCard(
                      'Total Classes',
                      Icons.class_,
                      Colors.blue,
                      _getTotalClasses(),
                    ),
                    _buildStatCard(
                      'Total Students',
                      Icons.people,
                      Colors.green,
                      _getTotalStudents(),
                    ),
                    _buildStatCard(
                      'Pending Requests',
                      Icons.pending_actions,
                      Colors.orange,
                      _getPendingRequests(),
                    ),
                    _buildStatCard(
                      'Published Games',
                      Icons.gamepad,
                      Colors.purple,
                      _getPublishedGames(),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 32),

            // Recent Activity Section
            Text(
              'Recent Activity',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2F2C),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  'Activity feed coming soon...',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    IconData icon,
    Color color,
    Stream<int> countStream,
  ) {
    return StreamBuilder<int>(
      stream: countStream,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _showNavigationConfirmation(title, count),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: Colors.white, size: 32),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white.withOpacity(0.7),
                        size: 20,
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        snapshot.connectionState == ConnectionState.waiting
                            ? '...'
                            : count.toString(),
                        style: GoogleFonts.poppins(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
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

  void _showNavigationConfirmation(String cardTitle, int count) {
    String destination = '';
    String message = '';
    VoidCallback? navigationAction;

    switch (cardTitle) {
      case 'Total Classes':
        destination = 'Classes';
        message = 'View and manage your $count ${count == 1 ? 'class' : 'classes'}?';
        navigationAction = () {
          Navigator.pop(context);
          if (widget.onNavigate != null) {
            widget.onNavigate!(1); // Navigate to Classes tab (index 1)
          }
        };
        break;
      case 'Total Students':
        destination = 'Students';
        message = 'View and manage your $count ${count == 1 ? 'student' : 'students'}?';
        navigationAction = () {
          Navigator.pop(context);
          if (widget.onNavigate != null) {
            widget.onNavigate!(2); // Navigate to Students tab (index 2)
          }
        };
        break;
      case 'Pending Requests':
        destination = 'Student Requests';
        message = 'View $count pending ${count == 1 ? 'request' : 'requests'}?';
        navigationAction = () {
          Navigator.pop(context);
          if (widget.onNavigate != null) {
            widget.onNavigate!(3); // Navigate to Request tab (index 3)
          }
        };
        break;
      case 'Published Games':
        destination = 'Published Games';
        message = 'View your $count published ${count == 1 ? 'game' : 'games'}?';
        navigationAction = () {
          Navigator.pop(context);
          Navigator.pushNamed(context, '/game_published');
        };
        break;
      default:
        return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward,
                    size: 40,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Text(
                  'Navigate to $destination?',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Message
                Text(
                  message,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: navigationAction,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Go',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Stream<int> _getTotalClasses() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value(0);

    return _firestore
        .collection('classes')
        .where('teacherId', isEqualTo: currentUser.uid)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Stream<int> _getTotalStudents() async* {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      yield 0;
      return;
    }

    final teacherDoc = await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .get();
    final teacherName = teacherDoc.data()?['fullname'] ?? '';

    if (teacherName.isEmpty) {
      yield 0;
      return;
    }

    await for (var usersSnapshot in _firestore.collection('users').snapshots()) {
      int count = 0;
      for (var userDoc in usersSnapshot.docs) {
        if (userDoc.id == currentUser.uid) continue;

        final teacherSubDoc = await _firestore
            .collection('users')
            .doc(userDoc.id)
            .collection('teachers')
            .doc(teacherName)
            .get();

        if (teacherSubDoc.exists && (teacherSubDoc.data()?['status'] ?? false)) {
          count++;
        }
      }
      yield count;
    }
  }

  Stream<int> _getPendingRequests() async* {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      yield 0;
      return;
    }

    final teacherDoc = await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .get();
    final teacherName = teacherDoc.data()?['fullname'] ?? '';

    if (teacherName.isEmpty) {
      yield 0;
      return;
    }

    await for (var usersSnapshot in _firestore.collection('users').snapshots()) {
      int count = 0;
      for (var userDoc in usersSnapshot.docs) {
        if (userDoc.id == currentUser.uid) continue;

        final teacherSubDoc = await _firestore
            .collection('users')
            .doc(userDoc.id)
            .collection('teachers')
            .doc(teacherName)
            .get();

        if (teacherSubDoc.exists && !(teacherSubDoc.data()?['status'] ?? false)) {
          count++;
        }
      }
      yield count;
    }
  }

  Stream<int> _getPublishedGames() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value(0);

    return _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('created_games')
        .where('publish', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}