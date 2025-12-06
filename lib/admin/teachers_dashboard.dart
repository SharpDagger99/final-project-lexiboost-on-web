// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../models/custom_scroll_behavior.dart';

class MyTeachersDashboard extends StatefulWidget {
  const MyTeachersDashboard({super.key});

  @override
  State<MyTeachersDashboard> createState() => _MyTeachersDashboardState();
}

class _MyTeachersDashboardState extends State<MyTeachersDashboard> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allTeachers = [];
  List<Map<String, dynamic>> _filteredTeachers = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadTeachers();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _filterTeachers();
    });
  }

  void _filterTeachers() {
    if (_searchQuery.isEmpty) {
      _filteredTeachers = List.from(_allTeachers);
    } else {
      _filteredTeachers = _allTeachers.where((teacher) {
        final name = (teacher['name'] ?? '').toString().toLowerCase();
        final email = (teacher['email'] ?? '').toString().toLowerCase();
        final uid = (teacher['uid'] ?? '').toString().toLowerCase();
        return name.contains(_searchQuery) ||
            email.contains(_searchQuery) ||
            uid.contains(_searchQuery);
      }).toList();
    }
  }

  Future<void> _loadTeachers() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'teacher')
          .get();

      debugPrint('Loaded ${snapshot.docs.length} teachers from Firestore');

      _allTeachers = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'uid': doc.id,
          'name': data['fullname'] ?? data['name'] ?? 'Unknown',
          'email': data['email'] ?? 'No email',
          'fullname': data['fullname'] ?? 'Unknown',
          'createdAt': data['createdAt'] ?? data['created_at'],
          'lastActive': data['lastActive'] ?? data['last_active'],
          'profileImage': data['profileImage'] ?? data['profile_image'],
          'status': _getTeacherStatus(data['lastActive'] ?? data['last_active']),
          'banned': data['banned'] ?? false,
        };
      }).toList();

      // Sort by name
      _allTeachers.sort((a, b) => 
        (a['name'] as String).compareTo(b['name'] as String));

      _filteredTeachers = List.from(_allTeachers);
      
      debugPrint('Filtered teachers count: ${_filteredTeachers.length}');
      
      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading teachers: $e');
      setState(() => _isLoading = false);
      
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading teachers: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getTeacherStatus(dynamic lastActive) {
    if (lastActive == null) return 'Inactive';
    
    try {
      final lastActiveDate = (lastActive as Timestamp).toDate();
      final now = DateTime.now();
      final difference = now.difference(lastActiveDate);

      if (difference.inMinutes < 5) return 'Online';
      if (difference.inDays < 7) return 'Active';
      if (difference.inDays < 30) return 'Inactive';
      return 'Dormant';
    } catch (e) {
      return 'Unknown';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Online':
        return Colors.green;
      case 'Active':
        return Colors.blue;
      case 'Inactive':
        return Colors.orange;
      case 'Dormant':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A3E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            // Navigate back to admin dashboard
            Get.offAllNamed('/admin');
          },
        ),
        title: Text(
          'Teacher Dashboard',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadTeachers,
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Search Bar and Stats
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A3E),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E2E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: GoogleFonts.poppins(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search by name, email, or ID...',
                      hintStyle: GoogleFonts.poppins(
                        color: Colors.white.withOpacity(0.5),
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.blue,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear,
                                color: Colors.white54,
                              ),
                              onPressed: () {
                                _searchController.clear();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Teacher List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  )
                : _filteredTeachers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _searchQuery.isEmpty
                                  ? Icons.school_outlined
                                  : Icons.search_off,
                              size: 80,
                              color: Colors.white.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'No teachers found'
                                  : 'No results for "$_searchQuery"',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                color: Colors.white.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ScrollConfiguration(
                        behavior: CustomScrollBehavior(),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: _filteredTeachers.length,
                          itemBuilder: (context, index) {
                            final teacher = _filteredTeachers[index];
                            return _buildTeacherCard(teacher);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherCard(Map<String, dynamic> teacher) {
    final status = teacher['status'] as String;
    final statusColor = _getStatusColor(status);
    final isBanned = teacher['banned'] as bool? ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isBanned ? const Color(0xFF3A2A2E) : const Color(0xFF2A2A3E),
        borderRadius: BorderRadius.circular(16),
        border: isBanned ? Border.all(color: Colors.red.withOpacity(0.5), width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showTeacherDetails(teacher),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.blue.withOpacity(0.3),
                      backgroundImage: teacher['profileImage'] != null && (teacher['profileImage'] as String).isNotEmpty
                          ? MemoryImage(base64Decode(teacher['profileImage']))
                          : null,
                      child: teacher['profileImage'] == null || (teacher['profileImage'] as String).isEmpty
                          ? Text(
                              (teacher['name'] as String)
                                  .substring(0, 1)
                                  .toUpperCase(),
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            )
                          : null,
                    ),
                    if (!isBanned)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF2A2A3E),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                // Teacher Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              teacher['name'],
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isBanned)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.red.withOpacity(0.5),
                                ),
                              ),
                              child: Text(
                                'BANNED',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        teacher['email'],
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (!isBanned)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: statusColor.withOpacity(0.5),
                                ),
                              ),
                              child: Text(
                                status,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: statusColor,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Arrow Icon
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white.withOpacity(0.3),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTeacherDetails(Map<String, dynamic> teacher) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF2A2A3E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.blue.withOpacity(0.3),
                    backgroundImage: teacher['profileImage'] != null && (teacher['profileImage'] as String).isNotEmpty
                        ? MemoryImage(base64Decode(teacher['profileImage']))
                        : null,
                    child: teacher['profileImage'] == null || (teacher['profileImage'] as String).isEmpty
                        ? Text(
                            (teacher['name'] as String)
                                .substring(0, 1)
                                .toUpperCase(),
                            style: GoogleFonts.poppins(
                              fontSize: 32,
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
                          teacher['name'],
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(teacher['status'])
                                .withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _getStatusColor(teacher['status'])
                                  .withOpacity(0.5),
                            ),
                          ),
                          child: Text(
                            teacher['status'],
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _getStatusColor(teacher['status']),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Get.back(),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Divider(color: Colors.white.withOpacity(0.1)),
              const SizedBox(height: 16),
              // Details
              _buildDetailRow('Email', teacher['email']),
              _buildDetailRow('Full Name', teacher['fullname']),
              _buildDetailRow('User ID', teacher['uid']),
              _buildDetailRow(
                'Joined',
                _formatDate(teacher['createdAt']),
              ),
              _buildDetailRow(
                'Last Active',
                _formatDate(teacher['lastActive']),
              ),
              if (teacher['banned'] == true) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.block, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This account is banned',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              // Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Get.back(),
                  child: Text(
                    'Close',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    try {
      final date = (timestamp as Timestamp).toDate();
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Unknown';
    }
  }
}