// ignore_for_file: deprecated_member_use, unnecessary_import, unused_local_variable

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animated_button/animated_button.dart';
import '../models/custom_scroll_behavior.dart';

class MyReport extends StatefulWidget {
  const MyReport({super.key});

  @override
  State<MyReport> createState() => _MyReportState();
}

class _MyReportState extends State<MyReport> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedTab = 'Reports'; // Reports, Ignored, Resolved, or Banned Users
  bool _showSearch = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Search users by username, fullname, or email
  Stream<QuerySnapshot> _getUsersStream() {
    if (_searchQuery.isEmpty) {
      return FirebaseFirestore.instance
          .collection('users')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots();
    }

    return FirebaseFirestore.instance
        .collection('users')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Filter users based on search query (exact start match)
  bool _matchesSearch(Map<String, dynamic> userData) {
    if (_searchQuery.isEmpty) return true;

    final query = _searchQuery.toLowerCase();
    final username = (userData['username'] ?? '').toString().toLowerCase();
    final fullname = (userData['fullname'] ?? '').toString().toLowerCase();
    final email = (userData['email'] ?? '').toString().toLowerCase();

    return username.startsWith(query) ||
        fullname.startsWith(query) ||
        email.startsWith(query);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2E),
      body: ScrollConfiguration(
        behavior: CustomScrollBehavior(),
        child: Column(
          children: [
            _buildHeader(),
            if (_showSearch) _buildSearchBar(),
            Expanded(
              child: _showSearch && _searchQuery.isNotEmpty
                  ? _buildUserSearchResults()
                  : _selectedTab == 'Reports'
                      ? _buildReportsPanel()
                      : _selectedTab == 'Resolved'
                          ? _buildResolvedReportsPanel()
                          : _selectedTab == 'Banned Users'
                              ? _buildBannedUsersPanel()
                              : _buildIgnoredReportsPanel(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E201E),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'User Reports',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              // Search user button
              IconButton(
                onPressed: () {
                  setState(() {
                    _showSearch = !_showSearch;
                    if (!_showSearch) {
                      _searchController.clear();
                      _searchQuery = '';
                    }
                  });
                },
                icon: Icon(
                  _showSearch ? Icons.close : Icons.person_search,
                  color: Colors.cyan,
                  size: 28,
                ),
                tooltip: _showSearch ? 'Close search' : 'Search users',
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Tab buttons
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildTabButton(
                      label: 'Reports',
                      icon: Icons.report,
                      isSelected: _selectedTab == 'Reports',
                      onTap: () {
                        setState(() {
                          _selectedTab = 'Reports';
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildTabButton(
                      label: 'Resolved',
                      icon: Icons.check_circle,
                      isSelected: _selectedTab == 'Resolved',
                      onTap: () {
                        setState(() {
                          _selectedTab = 'Resolved';
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildTabButton(
                      label: 'Ignored',
                      icon: Icons.visibility_off,
                      isSelected: _selectedTab == 'Ignored',
                      onTap: () {
                        setState(() {
                          _selectedTab = 'Ignored';
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildTabButton(
                      label: 'Banned Users',
                      icon: Icons.block,
                      isSelected: _selectedTab == 'Banned Users',
                      onTap: () {
                        setState(() {
                          _selectedTab = 'Banned Users';
                        });
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.cyan : Colors.grey.shade700,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.cyan.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E201E),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        style: GoogleFonts.poppins(color: Colors.black87, fontSize: 16),
        decoration: InputDecoration(
          hintText: 'Search by username, fullname, or email...',
          hintStyle: GoogleFonts.poppins(
            color: Colors.grey.shade500,
            fontSize: 16,
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: Colors.cyan,
            size: 24,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.grey.shade600),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.cyan, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildReportsPanel() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reports')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            debugPrint('Error loading reports: ${snapshot.error}');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 60, color: Colors.red.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading reports: ${snapshot.error}',
                    style: GoogleFonts.poppins(color: Colors.grey.shade400),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Note: You may need to create a Firestore index',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.cyan),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.report_off,
                    size: 80,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No reports found',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'All caught up!',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            );
          }

          // Filter reports in memory (status: pending or null/undefined)
          final pendingReports = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] as String?;
            // Include reports with status 'pending' or no status (new reports default to pending)
            return status == null || status == 'pending';
          }).toList();

          // Sort by timestamp (most recent first)
          pendingReports.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTimestamp = aData['timestamp'] as Timestamp?;
            final bTimestamp = bData['timestamp'] as Timestamp?;
            
            if (aTimestamp == null && bTimestamp == null) return 0;
            if (aTimestamp == null) return 1;
            if (bTimestamp == null) return -1;
            
            return bTimestamp.compareTo(aTimestamp);
          });

          if (pendingReports.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.report_off,
                    size: 80,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No pending reports',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'All caught up!',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: pendingReports.length,
            itemBuilder: (context, index) {
              final report = pendingReports[index];
              final data = report.data() as Map<String, dynamic>;
              return _buildReportCard(report.id, data);
            },
          );
        },
      ),
    );
  }

  Widget _buildIgnoredReportsPanel() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reports')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading ignored reports',
                style: GoogleFonts.poppins(color: Colors.grey.shade400),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.cyan),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.visibility_off,
                    size: 80,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No ignored reports',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }

          // Filter ignored reports in memory
          final ignoredReports = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] as String?;
            return status == 'ignored';
          }).toList();

          // Sort by timestamp (most recent first)
          ignoredReports.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTimestamp = aData['timestamp'] as Timestamp?;
            final bTimestamp = bData['timestamp'] as Timestamp?;
            
            if (aTimestamp == null && bTimestamp == null) return 0;
            if (aTimestamp == null) return 1;
            if (bTimestamp == null) return -1;
            
            return bTimestamp.compareTo(aTimestamp);
          });

          if (ignoredReports.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.visibility_off,
                    size: 80,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No ignored reports',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: ignoredReports.length,
            itemBuilder: (context, index) {
              final report = ignoredReports[index];
              final data = report.data() as Map<String, dynamic>;
              return _buildIgnoredReportCard(report.id, data);
            },
          );
        },
      ),
    );
  }

  Widget _buildResolvedReportsPanel() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reports')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading resolved reports',
                style: GoogleFonts.poppins(color: Colors.grey.shade400),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.cyan),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 80,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No resolved reports',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }

          // Filter resolved reports in memory
          final resolvedReports = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] as String?;
            return status == 'resolved';
          }).toList();

          // Sort by timestamp (most recent first)
          resolvedReports.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTimestamp = aData['resolvedAt'] as Timestamp? ?? aData['timestamp'] as Timestamp?;
            final bTimestamp = bData['resolvedAt'] as Timestamp? ?? bData['timestamp'] as Timestamp?;
            
            if (aTimestamp == null && bTimestamp == null) return 0;
            if (aTimestamp == null) return 1;
            if (bTimestamp == null) return -1;
            
            return bTimestamp.compareTo(aTimestamp);
          });

          if (resolvedReports.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 80,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No resolved reports',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: resolvedReports.length,
            itemBuilder: (context, index) {
              final report = resolvedReports[index];
              final data = report.data() as Map<String, dynamic>;
              return _buildResolvedReportCard(report.id, data);
            },
          );
        },
      ),
    );
  }

  Widget _buildBannedUsersPanel() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('banned', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading banned users',
                style: GoogleFonts.poppins(color: Colors.grey.shade400),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.cyan),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.block_outlined,
                    size: 80,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No banned users',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }

          final bannedUsers = snapshot.data!.docs;

          // Sort by ban timestamp (most recent first)
          bannedUsers.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTimestamp = aData['bannedAt'] as Timestamp?;
            final bTimestamp = bData['bannedAt'] as Timestamp?;
            
            if (aTimestamp == null && bTimestamp == null) return 0;
            if (aTimestamp == null) return 1;
            if (bTimestamp == null) return -1;
            
            return bTimestamp.compareTo(aTimestamp);
          });

          return ListView.builder(
            itemCount: bannedUsers.length,
            itemBuilder: (context, index) {
              final user = bannedUsers[index];
              final data = user.data() as Map<String, dynamic>;
              return _buildBannedUserCard(user.id, data);
            },
          );
        },
      ),
    );
  }

  Widget _buildUserSearchResults() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getUsersStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: Colors.white),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.cyan),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No users found',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          );
        }

        final filteredDocs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return _matchesSearch(data);
        }).toList();

        if (filteredDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 80, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No users match your search',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final userDoc = filteredDocs[index];
            final userData = userDoc.data() as Map<String, dynamic>;
            final userId = userDoc.id;

            return _buildUserCard(userId, userData);
          },
        );
      },
    );
  }

  Widget _buildReportCard(String reportId, Map<String, dynamic> data) {
    final reportEmail = data['reportEmail'] ?? 'Unknown';
    final theReporter = data['theReporter'] ?? 'Anonymous';
    final reportType = data['reportType'] ?? 'Other';
    final reportText = data['reportText'] ?? 'No description';
    final profileImage = data['profileImage'] as String?;
    final timestamp = data['timestamp'] as Timestamp?;
    final reportedUsername = data['reportedUsername'] ?? 'Unknown';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade900, Colors.red.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade300, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with reported user info
          Row(
            children: [
              // Profile Image or Placeholder
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white,
                backgroundImage: profileImage != null && profileImage.isNotEmpty
                    ? MemoryImage(base64Decode(profileImage))
                    : null,
                child: profileImage == null || profileImage.isEmpty
                    ? Text(
                        reportedUsername.substring(0, 1).toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reported: $reportedUsername',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reportEmail,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.shade700,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  reportType,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white30),
          const SizedBox(height: 12),
          
          // Report Details
          Text(
            'Report Details',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              reportText,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          // Reporter and Timestamp
          Row(
            children: [
              Icon(Icons.person, color: Colors.white70, size: 16),
              const SizedBox(width: 4),
              Text(
                'Reported by: $theReporter',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
              const Spacer(),
              if (timestamp != null)
                Text(
                  _formatTimestamp(timestamp),
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.white60,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white30),
          const SizedBox(height: 12),
          
          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AnimatedButton(
                onPressed: () => _showUserDetailsFromEmail(reportEmail),
                color: Colors.blue.shade700,
                height: 40,
                width: 100,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.person_search, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Check',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedButton(
                onPressed: () => _handleWarning(reportId, reportEmail, reportedUsername),
                color: Colors.orange.shade700,
                height: 40,
                width: 100,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.warning, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Warning',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedButton(
                onPressed: () => _handleBan(reportId, reportEmail, reportedUsername),
                color: Colors.red.shade700,
                height: 40,
                width: 100,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.block, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Ban',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedButton(
                onPressed: () => _ignoreReport(reportId),
                color: Colors.grey.shade700,
                height: 40,
                width: 100,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.visibility_off, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Ignore',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIgnoredReportCard(String reportId, Map<String, dynamic> data) {
    final reportEmail = data['reportEmail'] ?? 'Unknown';
    final theReporter = data['theReporter'] ?? 'Anonymous';
    final reportType = data['reportType'] ?? 'Other';
    final reportText = data['reportText'] ?? 'No description';
    final profileImage = data['profileImage'] as String?;
    final timestamp = data['timestamp'] as Timestamp?;
    final reportedUsername = data['reportedUsername'] ?? 'Unknown';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade600, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: Colors.grey.shade600,
                backgroundImage: profileImage != null && profileImage.isNotEmpty
                    ? MemoryImage(base64Decode(profileImage))
                    : null,
                child: profileImage == null || profileImage.isEmpty
                    ? Text(
                        reportedUsername.substring(0, 1).toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reportedUsername,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      reportEmail,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade700,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            reportType,
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: Colors.grey.shade300,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'By: $theReporter',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              AnimatedButton(
                onPressed: () => _restoreReport(reportId),
                color: Colors.green.shade700,
                height: 36,
                width: 90,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.restore, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Restore',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              reportText,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey.shade400,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (timestamp != null) ...[
            const SizedBox(height: 8),
            Text(
              'Ignored: ${_formatTimestamp(timestamp)}',
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResolvedReportCard(String reportId, Map<String, dynamic> data) {
    final reportEmail = data['reportEmail'] ?? 'Unknown';
    final theReporter = data['theReporter'] ?? 'Anonymous';
    final reportType = data['reportType'] ?? 'Other';
    final reportText = data['reportText'] ?? 'No description';
    final profileImage = data['profileImage'] as String?;
    final timestamp = data['timestamp'] as Timestamp?;
    final resolvedAt = data['resolvedAt'] as Timestamp?;
    final reportedUsername = data['reportedUsername'] ?? 'Unknown';
    final action = data['action'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: action == 'warning_sent'
              ? [Colors.green.shade800, Colors.green.shade600]
              : action == 'user_banned'
              ? [Colors.red.shade900, Colors.red.shade700]
              : [Colors.blue.shade800, Colors.blue.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: action == 'warning_sent'
              ? Colors.green.shade300
              : action == 'user_banned'
              ? Colors.red.shade300
              : Colors.blue.shade300,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (action == 'warning_sent'
                    ? Colors.green
                    : action == 'user_banned'
                    ? Colors.red
                    : Colors.blue)
                .withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with reported user info and action status
          Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: Colors.white,
                backgroundImage: profileImage != null && profileImage.isNotEmpty
                    ? MemoryImage(base64Decode(profileImage))
                    : null,
                child: profileImage == null || profileImage.isEmpty
                    ? Text(
                        reportedUsername.substring(0, 1).toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: action == 'warning_sent'
                              ? Colors.green
                              : action == 'user_banned'
                              ? Colors.red
                              : Colors.blue,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resolved: $reportedUsername',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reportEmail,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: action == 'warning_sent'
                      ? Colors.orange.shade700
                      : action == 'user_banned'
                      ? Colors.red.shade700
                      : Colors.blue.shade700,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  action == 'warning_sent'
                      ? 'WARNING SENT'
                      : action == 'user_banned'
                      ? 'USER BANNED'
                      : 'RESOLVED',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white30),
          const SizedBox(height: 12),
          
          // Report Details
          Text(
            'Report Details',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              reportText,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          // Reporter and Timestamps
          Row(
            children: [
              Icon(Icons.person, color: Colors.white70, size: 16),
              const SizedBox(width: 4),
              Text(
                'Reported by: $theReporter',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          if (resolvedAt != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white70, size: 16),
                const SizedBox(width: 4),
                Text(
                  'Resolved: ${_formatTimestamp(resolvedAt)}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Divider(color: Colors.white30),
          const SizedBox(height: 12),
          
          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Only show Cancel Warning for warning actions
              if (action == 'warning_sent') ...[
                AnimatedButton(
                  onPressed: () => _cancelWarning(reportId, reportEmail, reportedUsername),
                  color: Colors.orange.shade700,
                  height: 40,
                  width: 120,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cancel, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Cancel Warning',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],
              AnimatedButton(
                onPressed: () => _showUserDetailsFromEmail(reportEmail),
                color: Colors.blue.shade700,
                height: 40,
                width: 100,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.person_search, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Check User',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBannedUserCard(String userId, Map<String, dynamic> data) {
    final email = data['email'] ?? 'Unknown';
    final username = data['username'] ?? 'Unknown';
    final fullName = data['fullName'] ?? 'Unknown User';
    final profileImage = data['profileImage'] as String?;
    final banReason = data['banReason'] ?? 'No reason provided';
    final bannedAt = data['bannedAt'] as Timestamp?;
    final bannedBy = data['bannedBy'] ?? 'Admin';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade900, Colors.red.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.red.shade300,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with user info and ban status
          Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: Colors.white,
                backgroundImage: profileImage != null && profileImage.isNotEmpty
                    ? MemoryImage(base64Decode(profileImage))
                    : null,
                child: profileImage == null || profileImage.isEmpty
                    ? Text(
                        fullName.substring(0, 1).toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Banned: $fullName',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@$username',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                    Text(
                      email,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.shade800,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'BANNED',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white30),
          const SizedBox(height: 12),
          
          // Ban Details
          Text(
            'Ban Details',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              banReason,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          // Ban Info
          Row(
            children: [
              Icon(Icons.person, color: Colors.white70, size: 16),
              const SizedBox(width: 4),
              Text(
                'Banned by: $bannedBy',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          if (bannedAt != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.schedule, color: Colors.white70, size: 16),
                const SizedBox(width: 4),
                Text(
                  'Banned: ${_formatTimestamp(bannedAt)}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Divider(color: Colors.white30),
          const SizedBox(height: 12),
          
          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AnimatedButton(
                onPressed: () => _unbanUser(userId, fullName),
                color: Colors.green.shade700,
                height: 40,
                width: 100,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Unban',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedButton(
                onPressed: () => _showUserDetailsFromUserId(userId, data),
                color: Colors.blue.shade700,
                height: 40,
                width: 100,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.person_search, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Check User',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Widget _buildUserCard(String userId, Map<String, dynamic> userData) {
    final role = userData['role'] ?? 'user';

    // Students have username, Teachers have fullname
    final displayName = role == 'student'
        ? (userData['username'] ?? 'Unknown User')
        : (userData['fullname'] ?? 'Unknown Teacher');

    final username = userData['username'] ?? '';
    final email = userData['email'] ?? 'No email';
    final profileImage = userData['profileImage'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // User Info Container with Avatar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                // Profile Picture or Avatar
                CircleAvatar(
                  radius: 30,
                  backgroundColor: role == 'teacher'
                      ? Colors.blue.shade700
                      : Colors.purple.shade700,
                  backgroundImage: profileImage != null
                      ? MemoryImage(base64Decode(profileImage))
                      : null,
                  child: profileImage == null
                      ? Text(
                          displayName.substring(0, 1).toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),

                // User Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              displayName,
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: role == 'teacher'
                                  ? Colors.blue.withOpacity(0.3)
                                  : Colors.purple.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: role == 'teacher'
                                    ? Colors.blue
                                    : Colors.purple,
                              ),
                            ),
                            child: Text(
                              role.toUpperCase(),
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: role == 'teacher'
                                    ? Colors.blue.shade300
                                    : Colors.purple.shade300,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (username.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          '@$username',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.cyan.shade300,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey.shade300,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          Divider(color: Colors.grey.shade300),
          const SizedBox(height: 12),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Reward button only for students
              if (role == 'student') ...[
                _buildAnimatedActionButton(
                  icon: Icons.card_giftcard,
                  label: 'Reward',
                  color: Colors.white,
                  onTap: () => _showRewardDialog(userId, displayName),
                ),
                const SizedBox(width: 8),
              ],
              _buildAnimatedActionButton(
                icon: Icons.warning,
                label: 'Warning',
                color: Colors.white,
                onTap: () => _showWarningDialog(userId, displayName),
              ),
              const SizedBox(width: 8),
              _buildAnimatedActionButton(
                icon: Icons.block,
                label: 'Ban',
                color: Colors.red,
                onTap: () => _showBanDialog(userId, displayName),
              ),
              const SizedBox(width: 8),
              _buildAnimatedActionButton(
                icon: Icons.message,
                label: 'Message',
                color: Colors.white,
                onTap: () => _showMessageDialog(userId, displayName),
              ),
              const SizedBox(width: 8),
              _buildAnimatedActionButton(
                icon: Icons.check_circle,
                label: 'Check',
                color: Colors.white,
                onTap: () => _showUserDetailsDialog(userId, userData),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return AnimatedButton(
      onPressed: onTap,
      color: const Color(0xFF1E201E),
      height: 80,
      width: 80,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // Dialog functions
  void _showRewardDialog(String userId, String displayName) {
    final coinsController = TextEditingController();
    final replyController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'Reward User',
              style: GoogleFonts.poppins(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reward $displayName',
                    style: GoogleFonts.poppins(
                      color: Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Coins input
                  TextField(
                    controller: coinsController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Total Coins',
                      hintText: 'Enter amount of coins',
                      prefixIcon: const Icon(Icons.monetization_on, color: Colors.amber),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.amber, width: 2),
                      ),
                    ),
                    style: GoogleFonts.poppins(),
                  ),
                  const SizedBox(height: 16),
                  
                  // Reply message input
                  TextField(
                    controller: replyController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Reply Message',
                      hintText: 'Add a message (optional)',
                      prefixIcon: const Icon(Icons.message, color: Colors.blue),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.blue, width: 2),
                      ),
                    ),
                    style: GoogleFonts.poppins(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  coinsController.dispose();
                  replyController.dispose();
                  Navigator.pop(context);
                },
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(color: Colors.grey.shade600),
                ),
              ),
              AnimatedButton(
                onPressed: () async {
                  final coinsText = coinsController.text.trim();
                  if (coinsText.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Please enter the amount of coins',
                          style: GoogleFonts.poppins(),
                        ),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }

                  final coins = int.tryParse(coinsText);
                  if (coins == null || coins <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Please enter a valid positive number',
                          style: GoogleFonts.poppins(),
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  final replyMessage = replyController.text.trim();
                  coinsController.dispose();
                  replyController.dispose();
                  Navigator.pop(context);
                  await _sendReward(userId, displayName, coins, replyMessage);
                },
                color: Colors.green,
                height: 40,
                width: 130,
                child: Text(
                  'Send Reward',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Send reward notification to user
  Future<void> _sendReward(String userId, String displayName, int coins, String reply) async {
    try {
      // Create reward notification
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
        'title': 'Reward Received! 🎉',
        'message': reply.isNotEmpty 
            ? reply 
            : 'You have received a reward from the admin!',
        'type': 'reward',
        'coins': coins,
        'claimed': false,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      _showSuccessSnackbar('Reward sent to $displayName');
    } catch (e) {
      _showErrorSnackbar('Error sending reward: $e');
    }
  }

  void _showWarningDialog(String userId, String displayName) {
    final warningController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Send Warning',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Send a warning to $displayName',
              style: GoogleFonts.poppins(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: warningController,
              maxLines: 4,
              style: GoogleFonts.poppins(color: Colors.black87),
              decoration: InputDecoration(
                hintText: 'Enter warning message (optional)...',
                hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.orange, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              warningController.dispose();
              Navigator.pop(context);
            },
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey.shade600),
            ),
          ),
          AnimatedButton(
            onPressed: () async {
              final customMessage = warningController.text.trim();
              warningController.dispose();
              Navigator.pop(context);
              await _sendWarningToUser(userId, displayName, customMessage);
            },
            color: Colors.orange,
            height: 40,
            width: 130,
            child: Text(
              'Send Warning',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Show ban dialog for user search
  void _showBanDialog(String userId, String displayName) {
    final banReasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Ban User',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Ban $displayName permanently?\n\nThis action will prevent the user from accessing the application.',
              style: GoogleFonts.poppins(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: banReasonController,
              maxLines: 4,
              style: GoogleFonts.poppins(color: Colors.black87),
              decoration: InputDecoration(
                hintText: 'Ban reason (optional)...',
                hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.red, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              banReasonController.dispose();
              Navigator.pop(context);
            },
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey.shade600),
            ),
          ),
          AnimatedButton(
            onPressed: () async {
              final banReason = banReasonController.text.trim();
              banReasonController.dispose();
              Navigator.pop(context);
              await _banUserFromSearch(userId, displayName, banReason);
            },
            color: Colors.red,
            height: 40,
            width: 130,
            child: Text(
              'Ban User',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Ban user from search
  Future<void> _banUserFromSearch(String userId, String displayName, String banReason) async {
    try {
      // Update user status to banned
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'banned': true,
        'banReason': banReason.isNotEmpty ? banReason : 'Banned by admin',
        'bannedAt': FieldValue.serverTimestamp(),
        'bannedBy': 'Admin',
      });

      // Send ban notification to user
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
        'title': 'Account Banned',
        'message': banReason.isNotEmpty 
            ? 'Your account has been banned. Reason: $banReason' 
            : 'Your account has been banned by the admin. Please contact support for more information.',
        'type': 'ban',
        'fromName': 'Admin',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      _showSuccessSnackbar('$displayName has been banned');
    } catch (e) {
      _showErrorSnackbar('Error banning user: $e');
    }
  }

  // Send warning to user from user search
  Future<void> _sendWarningToUser(String userId, String displayName, String customMessage) async {
    try {
      // Send warning notification to user
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
        'title': 'Warning from Admin',
        'message': customMessage.isNotEmpty 
            ? customMessage 
            : 'You have received a warning from the admin. Please review our community guidelines and ensure your behavior aligns with our standards.',
        'type': 'warning',
        'fromName': 'Admin',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      _showSuccessSnackbar('Warning sent to $displayName');
    } catch (e) {
      _showErrorSnackbar('Error sending warning: $e');
    }
  }

  void _showMessageDialog(String userId, String displayName) {
    final messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Message User',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Send a message to $displayName',
              style: GoogleFonts.poppins(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: messageController,
              maxLines: 4,
              style: GoogleFonts.poppins(color: Colors.black87),
              decoration: InputDecoration(
                hintText: 'Type your message here...',
                hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey.shade600),
            ),
          ),
          AnimatedButton(
            onPressed: () {
              if (messageController.text.isNotEmpty) {
                Navigator.pop(context);
                _showSuccessSnackbar('Message sent to $displayName');
              }
            },
            color: Colors.blue,
            height: 40,
            width: 140,
            child: Text(
              'Send Message',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showUserDetailsDialog(String userId, Map<String, dynamic> userData) {
    final role = userData['role'] ?? 'user';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'User Details',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (role == 'student')
                _buildDetailRow('Username', userData['username'] ?? 'N/A'),
              if (role == 'teacher')
                _buildDetailRow('Full Name', userData['fullname'] ?? 'N/A'),
              _buildDetailRow('Email', userData['email'] ?? 'N/A'),
              _buildDetailRow('Role', userData['role'] ?? 'N/A'),
              _buildDetailRow('User ID', userId),
              if (userData['createdAt'] != null)
                _buildDetailRow(
                  'Created At',
                  (userData['createdAt'] as Timestamp)
                      .toDate()
                      .toString()
                      .substring(0, 16),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: GoogleFonts.poppins(color: Colors.cyan.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: GoogleFonts.poppins(
                color: Colors.grey.shade700,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(color: Colors.black87, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  // Show user details from email
  void _showUserDetailsFromEmail(String email) async {
    try {
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        _showErrorSnackbar('User not found');
        return;
      }

      final userData = userQuery.docs.first.data();
      final userId = userQuery.docs.first.id;
      _showUserDetailsDialog(userId, userData);
    } catch (e) {
      _showErrorSnackbar('Error loading user: $e');
    }
  }

  // Handle warning
  void _handleWarning(String reportId, String reportEmail, String reportedUsername) {
    final warningController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Send Warning',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Send a warning to $reportedUsername?\n\nNote: Multiple warnings may result in a ban.',
              style: GoogleFonts.poppins(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: warningController,
              maxLines: 3,
              style: GoogleFonts.poppins(color: Colors.black87),
              decoration: InputDecoration(
                hintText: 'Custom warning message (optional)...',
                hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.orange, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              warningController.dispose();
              Navigator.pop(context);
            },
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey.shade600),
            ),
          ),
          AnimatedButton(
            onPressed: () async {
              final customMessage = warningController.text.trim();
              warningController.dispose();
              Navigator.pop(context);
              await _sendWarning(reportId, reportEmail, reportedUsername, customMessage);
            },
            color: Colors.orange,
            height: 40,
            width: 130,
            child: Text(
              'Send Warning',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Handle ban
  void _handleBan(String reportId, String reportEmail, String reportedUsername) {
    final banReasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Ban User',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Ban $reportedUsername permanently?\n\nThis action will prevent the user from accessing the application.',
              style: GoogleFonts.poppins(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: banReasonController,
              maxLines: 3,
              style: GoogleFonts.poppins(color: Colors.black87),
              decoration: InputDecoration(
                hintText: 'Ban reason (optional)...',
                hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.red, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              banReasonController.dispose();
              Navigator.pop(context);
            },
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey.shade600),
            ),
          ),
          AnimatedButton(
            onPressed: () async {
              final banReason = banReasonController.text.trim();
              banReasonController.dispose();
              Navigator.pop(context);
              await _banUser(reportId, reportEmail, reportedUsername, banReason);
            },
            color: Colors.red,
            height: 40,
            width: 130,
            child: Text(
              'Ban User',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Ban user
  Future<void> _banUser(String reportId, String reportEmail, String reportedUsername, String banReason) async {
    try {
      // Get user ID from email
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: reportEmail)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        _showErrorSnackbar('User not found');
        return;
      }

      final userId = userQuery.docs.first.id;

      // Update user status to banned
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'banned': true,
        'banReason': banReason.isNotEmpty ? banReason : 'Banned by admin',
        'bannedAt': FieldValue.serverTimestamp(),
        'bannedBy': 'Admin',
      });

      // Send ban notification to user
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
        'title': 'Account Banned',
        'message': banReason.isNotEmpty 
            ? 'Your account has been banned. Reason: $banReason' 
            : 'Your account has been banned by the admin. Please contact support for more information.',
        'type': 'ban',
        'fromName': 'Admin',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      // Update report status
      await FirebaseFirestore.instance
          .collection('reports')
          .doc(reportId)
          .update({
        'status': 'resolved',
        'action': 'user_banned',
        'resolvedAt': FieldValue.serverTimestamp(),
      });

      _showSuccessSnackbar('$reportedUsername has been banned');
    } catch (e) {
      _showErrorSnackbar('Error banning user: $e');
    }
  }

  // Send warning to user
  Future<void> _sendWarning(String reportId, String reportEmail, String reportedUsername, [String? customMessage]) async {
    try {
      // Get user ID from email
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: reportEmail)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        _showErrorSnackbar('User not found');
        return;
      }

      final userId = userQuery.docs.first.id;

      // Send notification to user
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
        'title': 'Warning from Admin',
        'message': customMessage?.isNotEmpty == true 
            ? customMessage! 
            : 'You have received a warning from the admin. Please review our community guidelines and ensure your behavior aligns with our standards.',
        'type': 'warning',
        'fromName': 'Admin',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      // Update report status
      await FirebaseFirestore.instance
          .collection('reports')
          .doc(reportId)
          .update({
        'status': 'resolved',
        'action': 'warning_sent',
        'resolvedAt': FieldValue.serverTimestamp(),
      });

      _showSuccessSnackbar('Warning sent to $reportedUsername');
    } catch (e) {
      _showErrorSnackbar('Error sending warning: $e');
    }
  }

  // Cancel warning
  Future<void> _cancelWarning(String reportId, String reportEmail, String reportedUsername) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Cancel Warning',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Cancel the warning for $reportedUsername?\n\nThis will remove the warning notification from the user and restore the report to pending status.',
          style: GoogleFonts.poppins(color: Colors.black54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Keep Warning',
              style: GoogleFonts.poppins(color: Colors.grey.shade600),
            ),
          ),
          AnimatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performCancelWarning(reportId, reportEmail, reportedUsername);
            },
            color: Colors.orange,
            height: 40,
            width: 130,
            child: Text(
              'Cancel Warning',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Perform cancel warning
  Future<void> _performCancelWarning(String reportId, String reportEmail, String reportedUsername) async {
    try {
      // Get user ID from email
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: reportEmail)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        _showErrorSnackbar('User not found');
        return;
      }

      final userId = userQuery.docs.first.id;

      // Find and delete warning notifications related to this report
      final warningNotifications = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('type', isEqualTo: 'warning')
          .where('fromName', isEqualTo: 'Admin')
          .get();

      // Delete the most recent warning notification (assuming it's related to this report)
      if (warningNotifications.docs.isNotEmpty) {
        // Sort by timestamp and delete the most recent one
        final sortedNotifications = warningNotifications.docs;
        sortedNotifications.sort((a, b) {
          final aTimestamp = a.data()['timestamp'] as Timestamp?;
          final bTimestamp = b.data()['timestamp'] as Timestamp?;
          if (aTimestamp == null && bTimestamp == null) return 0;
          if (aTimestamp == null) return 1;
          if (bTimestamp == null) return -1;
          return bTimestamp.compareTo(aTimestamp);
        });

        await sortedNotifications.first.reference.delete();
      }

      // Send cancellation notification to user
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
        'title': 'Warning Cancelled',
        'message': 'Your previous warning has been cancelled by the admin. Thank you for your understanding.',
        'type': 'info',
        'fromName': 'Admin',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      // Update report status back to pending
      await FirebaseFirestore.instance
          .collection('reports')
          .doc(reportId)
          .update({
        'status': 'pending',
        'action': FieldValue.delete(),
        'resolvedAt': FieldValue.delete(),
        'warningCancelledAt': FieldValue.serverTimestamp(),
      });

      _showSuccessSnackbar('Warning cancelled for $reportedUsername');
    } catch (e) {
      _showErrorSnackbar('Error cancelling warning: $e');
    }
  }

  // Unban user
  Future<void> _unbanUser(String userId, String userName) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Unban User',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Restore access for $userName?\n\nThis will remove the ban and allow the user to use the application again.',
          style: GoogleFonts.poppins(color: Colors.black54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Keep Ban',
              style: GoogleFonts.poppins(color: Colors.grey.shade600),
            ),
          ),
          AnimatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performUnban(userId, userName);
            },
            color: Colors.green,
            height: 40,
            width: 130,
            child: Text(
              'Unban User',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Perform unban
  Future<void> _performUnban(String userId, String userName) async {
    try {
      // Remove ban status from user
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'banned': FieldValue.delete(),
        'banReason': FieldValue.delete(),
        'bannedAt': FieldValue.delete(),
        'bannedBy': FieldValue.delete(),
        'unbannedAt': FieldValue.serverTimestamp(),
        'unbannedBy': 'Admin',
      });

      // Send unban notification to user
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
        'title': 'Account Restored',
        'message': 'Your account has been restored by the admin. You can now use the application again. Please follow our community guidelines.',
        'type': 'info',
        'fromName': 'Admin',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      _showSuccessSnackbar('$userName has been unbanned');
    } catch (e) {
      _showErrorSnackbar('Error unbanning user: $e');
    }
  }

  // Show user details from user ID
  void _showUserDetailsFromUserId(String userId, Map<String, dynamic> userData) {
    _showUserDetailsDialog(userId, userData);
  }

  // Ignore report
  Future<void> _ignoreReport(String reportId) async {
    try {
      await FirebaseFirestore.instance
          .collection('reports')
          .doc(reportId)
          .update({
        'status': 'ignored',
        'ignoredAt': FieldValue.serverTimestamp(),
      });

      _showSuccessSnackbar('Report moved to ignored');
    } catch (e) {
      _showErrorSnackbar('Error ignoring report: $e');
    }
  }

  // Restore report
  Future<void> _restoreReport(String reportId) async {
    try {
      await FirebaseFirestore.instance
          .collection('reports')
          .doc(reportId)
          .update({
        'status': 'pending',
        'restoredAt': FieldValue.serverTimestamp(),
      });

      _showSuccessSnackbar('Report restored to pending');
    } catch (e) {
      _showErrorSnackbar('Error restoring report: $e');
    }
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
