// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animated_button/animated_button.dart';

class MyAddStudent extends StatefulWidget {
  const MyAddStudent({super.key});

  @override
  State<MyAddStudent> createState() => _MyAddStudentState();
}

class _MyAddStudentState extends State<MyAddStudent> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _searchController = TextEditingController();
  
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Get all students who have added this teacher and are confirmed
  Stream<List<Map<String, dynamic>>> _getConfirmedStudents() async* {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      yield [];
      return;
    }

    // Get current teacher's full name
    final teacherDoc = await _firestore.collection('users').doc(currentUser.uid).get();
    final teacherName = teacherDoc.data()?['fullname'] ?? '';

    if (teacherName.isEmpty) {
      yield [];
      return;
    }

    // Query all users to find students who have this teacher with status true
    await for (var usersSnapshot in _firestore.collection('users').where('role', isEqualTo: 'student').snapshots()) {
      List<Map<String, dynamic>> confirmedStudents = [];

      for (var userDoc in usersSnapshot.docs) {
        final teacherSubDoc = await _firestore
            .collection('users')
            .doc(userDoc.id)
            .collection('teachers')
            .doc(teacherName)
            .get();

        if (teacherSubDoc.exists) {
          final teacherData = teacherSubDoc.data();
          final status = teacherData?['status'] ?? false;

          // Only include confirmed students (status = true)
          if (status) {
            final userData = userDoc.data();
            final username = userData['username'] ?? 'Unknown';
            final fullname = userData['fullname'] ?? 'Unknown';
            final email = userData['email'] ?? '';
            final profileImage = userData['profileImage'];
            final schoolId = userData['schoolId'] ?? 'Not set';
            final gradeLevel = userData['gradeLevel'] ?? 'Not set';
            final section = userData['section'] ?? 'Not set';

            // Apply search filter - now includes fullname, schoolId, gradeLevel, and section
            if (_searchQuery.isEmpty ||
                username.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                fullname.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                schoolId.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                gradeLevel.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                section.toLowerCase().contains(_searchQuery.toLowerCase())) {
              confirmedStudents.add({
                'studentId': userDoc.id,
                'username': username,
                'fullname': fullname,
                'email': email,
                'profileImage': profileImage,
                'schoolId': schoolId,
                'gradeLevel': gradeLevel,
                'section': section,
                'acceptedAt': teacherData?['acceptedAt'],
              });
            }
          }
        }
      }

      yield confirmedStudents;
    }
  }

  // Message student dialog
  void _messageStudent(String studentId, String studentName, String studentEmail) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final TextEditingController messageController = TextEditingController();
        
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            width: 500,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: const Color(0xFF1E201E),
                      child: Text(
                        studentName.isNotEmpty ? studentName[0].toUpperCase() : 'S',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            studentName,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            studentEmail,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Message input
                Text(
                  'Send a message',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: messageController,
                  maxLines: 4,
                  style: GoogleFonts.poppins(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Type your message here...',
                    hintStyle: GoogleFonts.poppins(color: Colors.grey),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF1E201E)),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),
                const SizedBox(height: 20),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AnimatedButton(
                      width: 100,
                      height: 45,
                      color: Colors.grey[300]!,
                      shadowDegree: ShadowDegree.light,
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.poppins(
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    AnimatedButton(
                      width: 100,
                      height: 45,
                      color: const Color(0xFF1E201E),
                      shadowDegree: ShadowDegree.light,
                      onPressed: () async {
                        if (messageController.text.trim().isNotEmpty) {
                          final currentUser = _auth.currentUser;
                          if (currentUser != null) {
                            try {
                              // Get teacher's name
                              final teacherDoc = await _firestore
                                  .collection('users')
                                  .doc(currentUser.uid)
                                  .get();
                              final teacherName =
                                  teacherDoc.data()?['fullname'] ??
                                  teacherDoc.data()?['username'] ??
                                  'Teacher';

                              // Send notification to student
                              await _firestore
                                  .collection('users')
                                  .doc(studentId)
                                  .collection('notifications')
                                  .add({
                                    'title': 'Message from $teacherName',
                                    'message': messageController.text.trim(),
                                    'from': currentUser.uid,
                                    'fromName': teacherName,
                                    'timestamp': FieldValue.serverTimestamp(),
                                    'read': false,
                                    'type': 'message',
                                  });

                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Message sent to $studentName'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to send message: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        }
                      },
                      child: Text(
                        'Send',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
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

  // View detailed student information dialog
  void _viewDetailedStudentInfo(String studentId, String studentName, String studentEmail) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            width: 500,
            constraints: const BoxConstraints(maxHeight: 600),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: StreamBuilder<DocumentSnapshot>(
              stream: _firestore.collection('users').doc(studentId).snapshots(),
              builder: (context, studentSnapshot) {
                if (studentSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const SizedBox(
                    height: 400,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF1E201E),
                      ),
                    ),
                  );
                }

                if (!studentSnapshot.hasData || !studentSnapshot.data!.exists) {
                  return SizedBox(
                    height: 400,
                    child: Center(
                      child: Text(
                        'Student data not found',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  );
                }

                final studentData =
                    studentSnapshot.data!.data() as Map<String, dynamic>;
                final fullname = studentData['fullname'] ?? 'Not set';
                final email = studentData['email'] ?? studentEmail;
                final profileImageBase64 = studentData['profileImage'];
                final schoolId = studentData['schoolId'] ?? 'Not set';
                final gradeLevel = studentData['gradeLevel'] ?? 'Not set';
                final section = studentData['section'] ?? 'Not set';

                // Check if all important fields are set
                bool hasCompleteInfo = fullname != 'Not set' &&
                    schoolId != 'Not set' &&
                    gradeLevel != 'Not set' &&
                    section != 'Not set';

                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.person,
                              color: Colors.blue,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Student Details',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Profile Image
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.blue[700],
                        backgroundImage: profileImageBase64 != null
                            ? MemoryImage(base64Decode(profileImageBase64))
                            : null,
                        child: profileImageBase64 == null
                            ? Text(
                                fullname.isNotEmpty && fullname != 'Not set'
                                    ? fullname[0].toUpperCase()
                                    : 'S',
                                style: GoogleFonts.poppins(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 20),

                      // Show warning if incomplete info
                      if (!hasCompleteInfo)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange[300]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber, color: Colors.orange[700], size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Student unknown information',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange[900],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Information Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDetailRow('Full Name', fullname),
                            const SizedBox(height: 12),
                            _buildDetailRow('Email', email),
                            const SizedBox(height: 12),
                            _buildDetailRow('School ID', schoolId),
                            const SizedBox(height: 12),
                            _buildDetailRow('Grade Level', gradeLevel),
                            const SizedBox(height: 12),
                            _buildDetailRow('Section', section),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Action buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Edit button
                          AnimatedButton(
                            width: 120,
                            height: 45,
                            color: Colors.blue,
                            shadowDegree: ShadowDegree.light,
                            onPressed: () {
                              Navigator.of(context).pop();
                              _showEditStudentDialog(studentId, fullname, schoolId, gradeLevel, section, profileImageBase64);
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.edit, color: Colors.white, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  'Edit',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Close button
                          AnimatedButton(
                            width: 120,
                            height: 45,
                            color: const Color(0xFF1E201E),
                            shadowDegree: ShadowDegree.light,
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: Text(
                              'Close',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    bool isNotSet = value == 'Not set' || value.isEmpty;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: isNotSet ? Colors.grey[400] : Colors.black87,
              fontStyle: isNotSet ? FontStyle.italic : FontStyle.normal,
            ),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // Edit student information dialog for teachers
  void _showEditStudentDialog(String studentId, String currentFullname, String currentSchoolId, String currentGradeLevel, String currentSection, String? currentProfileImage) {
    final TextEditingController fullnameController = TextEditingController(text: currentFullname == "Not set" ? "" : currentFullname);
    final TextEditingController schoolIdController = TextEditingController(text: currentSchoolId == "Not set" ? "" : currentSchoolId);
    final TextEditingController gradeLevelController = TextEditingController(text: currentGradeLevel == "Not set" ? "" : currentGradeLevel);
    final TextEditingController sectionController = TextEditingController(text: currentSection == "Not set" ? "" : currentSection);
    String? newProfileImageBase64 = currentProfileImage;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                width: 500,
                constraints: const BoxConstraints(maxHeight: 650),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.edit,
                              color: Colors.blue,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Edit Student',
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  'Update student information',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Profile Image (Read-only - cannot be edited by teacher)
                      Center(
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.blue,
                          backgroundImage: newProfileImageBase64 != null
                              ? MemoryImage(base64Decode(newProfileImageBase64))
                              : null,
                          child: newProfileImageBase64 == null
                              ? const Icon(Icons.person, size: 50, color: Colors.white)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          'Profile picture cannot be edited',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Full Name
                      Text(
                        'Full Name',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: fullnameController,
                        style: GoogleFonts.poppins(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Enter full name',
                          hintStyle: GoogleFonts.poppins(color: Colors.grey),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.blue),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // School ID
                      Text(
                        'School ID',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: schoolIdController,
                        style: GoogleFonts.poppins(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Enter school ID',
                          hintStyle: GoogleFonts.poppins(color: Colors.grey),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.blue),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Grade Level
                      Text(
                        'Grade Level',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: gradeLevelController,
                        style: GoogleFonts.poppins(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Enter grade level',
                          hintStyle: GoogleFonts.poppins(color: Colors.grey),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.blue),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Section
                      Text(
                        'Section',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: sectionController,
                        style: GoogleFonts.poppins(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Enter section',
                          hintStyle: GoogleFonts.poppins(color: Colors.grey),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.blue),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Action buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          AnimatedButton(
                            width: 100,
                            height: 45,
                            color: Colors.grey[300]!,
                            shadowDegree: ShadowDegree.light,
                            onPressed: () {
                              Navigator.of(dialogContext).pop();
                            },
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.poppins(
                                color: Colors.black87,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          AnimatedButton(
                            width: 120,
                            height: 45,
                            color: Colors.blue,
                            shadowDegree: ShadowDegree.light,
                            onPressed: () async {
                              try {
                                // Update student info (excluding profile image)
                                await _firestore.collection('users').doc(studentId).update({
                                  'fullname': fullnameController.text.trim().isEmpty ? "Not set" : fullnameController.text.trim(),
                                  'schoolId': schoolIdController.text.trim().isEmpty ? "Not set" : schoolIdController.text.trim(),
                                  'gradeLevel': gradeLevelController.text.trim().isEmpty ? "Not set" : gradeLevelController.text.trim(),
                                  'section': sectionController.text.trim().isEmpty ? "Not set" : sectionController.text.trim(),
                                  // Profile image cannot be edited by teachers
                                });
                                Navigator.of(dialogContext).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Student information updated successfully',
                                      style: GoogleFonts.poppins(),
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Error updating student: $e',
                                      style: GoogleFonts.poppins(),
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.save, color: Colors.white, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  'Save',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
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
      },
    );
  }

  // View student information dialog with complete data
  void _viewStudentInfo(String studentId, String studentName, String studentEmail) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            width: 500,
            constraints: const BoxConstraints(maxHeight: 600),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: StreamBuilder<DocumentSnapshot>(
              stream: _firestore.collection('users').doc(studentId).snapshots(),
              builder: (context, studentSnapshot) {
                if (studentSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const SizedBox(
                    height: 400,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF1E201E),
                      ),
                    ),
                  );
                }

                if (!studentSnapshot.hasData || !studentSnapshot.data!.exists) {
                  return SizedBox(
                    height: 400,
                    child: Center(
                      child: Text(
                        'Student data not found',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  );
                }

                final studentData =
                    studentSnapshot.data!.data() as Map<String, dynamic>;
                final username = studentData['username'] ?? studentName;
                final email = studentData['email'] ?? studentEmail;
                final coins = studentData['coins'] ?? 0;
                final trophies = studentData['trophy'] ?? 0;
                final profileImageBase64 = studentData['profileImage'];

                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Avatar
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.amber[700],
                        backgroundImage: profileImageBase64 != null
                            ? MemoryImage(base64Decode(profileImageBase64))
                            : null,
                        child: profileImageBase64 == null
                            ? Text(
                                username.isNotEmpty
                                    ? username[0].toUpperCase()
                                    : 'S',
                                style: GoogleFonts.poppins(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 20),

                      // Student name
                      Text(
                        username,
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Student email
                      Text(
                        email,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Rank Badge
                      StreamBuilder<QuerySnapshot>(
                        stream: _firestore
                            .collection('users')
                            .orderBy('trophy', descending: true)
                            .snapshots(),
                        builder: (context, rankSnapshot) {
                          int userRank = 0;
                          if (rankSnapshot.hasData) {
                            userRank =
                                rankSnapshot.data!.docs.indexWhere(
                                  (d) => d.id == studentId,
                                ) +
                                1;
                          }

                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.amber,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.military_tech,
                                  color: Colors.amber,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  userRank > 0 ? 'Rank #$userRank' : 'Unranked',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.amber[900],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),

                      // Stats Cards
                      Row(
                        children: [
                          // Coins Card
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.amber[100]!,
                                    Colors.amber[50]!,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.amber[200]!),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.monetization_on,
                                    color: Colors.amber[700],
                                    size: 32,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Coins',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$coins',
                                    style: GoogleFonts.poppins(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber[900],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Trophies Card
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.orange[100]!,
                                    Colors.orange[50]!,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.orange[200]!),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.emoji_events,
                                    color: Colors.orange[700],
                                    size: 32,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Trophies',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$trophies',
                                    style: GoogleFonts.poppins(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange[900],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Information section
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoRow('Role', 'Student'),
                            const SizedBox(height: 12),
                            _buildInfoRow('Status', 'Active', isActive: true),
                            const SizedBox(height: 12),
                            _buildInfoRow(
                              'Student ID',
                              studentId.substring(0, 8),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Close button
                      AnimatedButton(
                        width: 120,
                        height: 45,
                        color: const Color(0xFF1E201E),
                        shadowDegree: ShadowDegree.light,
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: Text(
                          'Close',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isActive = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        isActive
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green[300]!),
                ),
                child: Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.green[700],
                  ),
                ),
              )
            : Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
      ],
    );
  }

  // Show dialog to add a student by email
  void _showAddStudentDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final TextEditingController emailController = TextEditingController();
        final TextEditingController messageController = TextEditingController();
        bool isSearching = false;
        String? errorMessage;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                width: 500,
                constraints: const BoxConstraints(maxHeight: 600),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.person_add,
                              color: Colors.green,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Add Student',
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  'Send a request to a student',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Email input
                      Text(
                        'Student Email',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: emailController,
                        style: GoogleFonts.poppins(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Enter student email address',
                          hintStyle: GoogleFonts.poppins(color: Colors.grey),
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.green),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          errorText: errorMessage,
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 20),

                      // Message input
                      Text(
                        'Message (Optional)',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: messageController,
                        maxLines: 3,
                        style: GoogleFonts.poppins(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Add a message to your request...',
                          hintStyle: GoogleFonts.poppins(color: Colors.grey),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.green),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Action buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          AnimatedButton(
                            width: 100,
                            height: 45,
                            color: Colors.grey[300]!,
                            shadowDegree: ShadowDegree.light,
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.poppins(
                                color: Colors.black87,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          AnimatedButton(
                            width: 120,
                            height: 45,
                            color: Colors.green,
                            shadowDegree: ShadowDegree.light,
                            onPressed: isSearching
                                ? () {}
                                : () {
                                    final email = emailController.text.trim();

                                    if (email.isEmpty) {
                                      setDialogState(() {
                                        errorMessage = 'Please enter an email';
                                      });
                                      return;
                                    }

                                    if (!email.contains('@')) {
                                      setDialogState(() {
                                        errorMessage =
                                            'Please enter a valid email';
                                      });
                                      return;
                                    }

                                    setDialogState(() {
                                      isSearching = true;
                                      errorMessage = null;
                                    });

                                    // Execute async operation
                                    Future.microtask(() async {
                                      try {
                                        final currentUser = _auth.currentUser;
                                        if (currentUser == null) {
                                          throw Exception('Not logged in');
                                        }

                                        // Get current teacher's data
                                        final teacherDoc = await _firestore
                                            .collection('users')
                                            .doc(currentUser.uid)
                                            .get();
                                        final teacherName =
                                            teacherDoc.data()?['fullname'] ??
                                            teacherDoc.data()?['username'] ??
                                            'Teacher';

                                        // Find student by email
                                        final studentQuery = await _firestore
                                            .collection('users')
                                            .where('email', isEqualTo: email)
                                            .where('role', isEqualTo: 'student')
                                            .limit(1)
                                            .get();

                                        if (studentQuery.docs.isEmpty) {
                                          setDialogState(() {
                                            isSearching = false;
                                            errorMessage = 'Student not found';
                                          });
                                          return;
                                        }

                                        final studentDoc =
                                            studentQuery.docs.first;
                                        final studentId = studentDoc.id;

                                        // Check if teacher already exists in student's teachers subcollection
                                        final existingTeacher = await _firestore
                                            .collection('users')
                                            .doc(studentId)
                                            .collection('teachers')
                                            .doc(teacherName)
                                            .get();

                                        if (existingTeacher.exists) {
                                          final status =
                                              existingTeacher
                                                  .data()?['status'] ??
                                              false;
                                          setDialogState(() {
                                            isSearching = false;
                                            errorMessage = status
                                                ? 'This student is already added'
                                                : 'Request already sent';
                                          });
                                          return;
                                        }

                                        // Add teacher to student's teachers subcollection with status false
                                        await _firestore
                                            .collection('users')
                                            .doc(studentId)
                                            .collection('teachers')
                                            .doc(teacherName)
                                            .set({
                                              'teacherId': currentUser.uid,
                                              'teacherName': teacherName,
                                              'status': false,
                                              'requestedAt':
                                                  FieldValue.serverTimestamp(),
                                            });

                                        // Update student's document to trigger stream listener
                                        await _firestore
                                            .collection('users')
                                            .doc(studentId)
                                            .update({
                                              'teachersUpdatedAt':
                                                  FieldValue.serverTimestamp(),
                                            });

                                        // Send notification to student
                                        final customMessage = messageController
                                            .text
                                            .trim();
                                        await _firestore
                                            .collection('users')
                                            .doc(studentId)
                                            .collection('notifications')
                                            .add({
                                              'title': 'Teacher Request',
                                              'message': customMessage.isEmpty
                                                  ? '$teacherName wants to add you as a student'
                                                  : customMessage,
                                              'from': currentUser.uid,
                                              'fromName': teacherName,
                                              'teacherEmail':
                                                  teacherDoc.data()?['email'] ??
                                                  '',
                                              'teacherName': teacherName,
                                              'teacherId': currentUser.uid,
                                              'timestamp':
                                                  FieldValue.serverTimestamp(),
                                              'read': false,
                                              'hidden': false,
                                              'type': 'teacher_request',
                                            });

                                        Navigator.of(context).pop();
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Request sent to ${studentDoc.data()['username']}',
                                            ),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      } catch (e) {
                                        setDialogState(() {
                                          isSearching = false;
                                          errorMessage =
                                              'Failed to send request: ${e.toString()}';
                                        });
                                      }
                                    });
                                  },
                            child: isSearching
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.send,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Send',
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E201E),
      body: Column(
        children: [
          // Header section
          Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My Students',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Manage and communicate with your students',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 20),

                // Search bar with Add button
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                        style: GoogleFonts.poppins(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Search students...',
                          hintStyle: GoogleFonts.poppins(color: Colors.white54),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Colors.white54,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear,
                                    color: Colors.white54,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.1),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    AnimatedButton(
                      width: 120,
                      height: 50,
                      color: Colors.green,
                      shadowDegree: ShadowDegree.light,
                      onPressed: _showAddStudentDialog,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.person_add,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Add',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Students list
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _getConfirmedStudents(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading students',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  );
                }

                final students = snapshot.data ?? [];

                if (students.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.school_outlined,
                          size: 80,
                          color: Colors.white.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No students yet'
                              : 'No students found',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isEmpty
                              ? 'Students who confirm your request will appear here'
                              : 'Try a different search term',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final student = students[index];
                    final studentId = student['studentId'];
                    final username = student['username'];
                    final email = student['email'];
                    final profileImageBase64 = student['profileImage'];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      height: 100,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D2F2D),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            // Student avatar
                            Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.amber.withOpacity(0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 35,
                                backgroundColor: Colors.amber[700],
                                backgroundImage: profileImageBase64 != null
                                    ? MemoryImage(
                                        base64Decode(profileImageBase64),
                                      )
                                    : null,
                                child: profileImageBase64 == null
                                    ? Text(
                                        username.isNotEmpty
                                            ? username[0].toUpperCase()
                                            : 'S',
                                        style: GoogleFonts.poppins(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 16),

                            // Student info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    username,
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    email,
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      color: Colors.white.withOpacity(0.7),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),

                            // Action buttons
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Student detail button
                                AnimatedButton(
                                  width: 45,
                                  height: 45,
                                  color: Colors.purple.withOpacity(0.2),
                                  shadowDegree: ShadowDegree.light,
                                  onPressed: () {
                                    _viewDetailedStudentInfo(studentId, username, email);
                                  },
                                  child: const Icon(
                                    Icons.person,
                                    color: Colors.purple,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Message button
                                AnimatedButton(
                                  width: 45,
                                  height: 45,
                                  color: Colors.white.withOpacity(0.1),
                                  shadowDegree: ShadowDegree.light,
                                  onPressed: () {
                                    _messageStudent(studentId, username, email);
                                  },
                                  child: const Icon(
                                    Icons.message_outlined,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // View info button
                                AnimatedButton(
                                  width: 45,
                                  height: 45,
                                  color: Colors.blue.withOpacity(0.2),
                                  shadowDegree: ShadowDegree.light,
                                  onPressed: () {
                                    _viewStudentInfo(studentId, username, email);
                                  },
                                  child: const Icon(
                                    Icons.info_outline,
                                    color: Colors.blue,
                                    size: 20,
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
              },
            ),
          ),
        ],
      ),
    );
  }
}