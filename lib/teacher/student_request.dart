// ignore_for_file: deprecated_member_use, prefer_final_fields, avoid_print, use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animated_button/animated_button.dart';
import 'package:get/get.dart';

class MyStudentRequest extends StatefulWidget {
  const MyStudentRequest({super.key});

  @override
  State<MyStudentRequest> createState() => _MyStudentRequestState();
}

class _MyStudentRequestState extends State<MyStudentRequest> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  Set<String> _processingRequests = {};

  // Accept student request
  Future<void> _acceptStudent(String studentId, String teacherName) async {
    try {
      setState(() {
        _processingRequests.add(studentId);
      });

      // Update the status to true in the student's teachers subcollection
      await _firestore
          .collection('users')
          .doc(studentId)
          .collection('teachers')
          .doc(teacherName)
          .update({
        'status': true,
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      // Update student's document to trigger stream listener
      await _firestore.collection('users').doc(studentId).update({
        'teachersUpdatedAt': FieldValue.serverTimestamp(),
      });

      // Send notification to student about acceptance
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        await _firestore
            .collection('users')
            .doc(studentId)
            .collection('notifications')
            .add({
              'title': 'Teacher Accepted!',
              'message':
                  '$teacherName has accepted your request and is now your teacher.',
              'from': currentUser.uid,
              'fromName': teacherName,
              'timestamp': FieldValue.serverTimestamp(),
              'read': false,
              'type': 'teacher_accepted',
            });
      }

      setState(() {
        _processingRequests.remove(studentId);
      });

      // Show success dialog
      _showSuccessDialog(studentId);
    } catch (e) {
      setState(() {
        _processingRequests.remove(studentId);
      });

      Get.snackbar(
        'Error',
        'Failed to accept student: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // Show success dialog after accepting
  void _showSuccessDialog(String studentId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Success icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    size: 50,
                    color: Colors.green[600],
                  ),
                ),
                const SizedBox(height: 20),

                // Success message
                Text(
                  'Student Accepted!',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'The student has been added to your list',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Close button
                AnimatedButton(
                  width: 120,
                  height: 45,
                  color: Colors.green[600]!,
                  shadowDegree: ShadowDegree.light,
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'Done',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Message student
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
                              Get.snackbar(
                                'Success',
                                'Message sent to $studentName',
                                backgroundColor: Colors.green,
                                colorText: Colors.white,
                              );
                            } catch (e) {
                              Get.snackbar(
                                'Error',
                                'Failed to send message: $e',
                                backgroundColor: Colors.red,
                                colorText: Colors.white,
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

  // Get all students who added this teacher
  Stream<List<Map<String, dynamic>>> _getStudentRequests() async* {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      yield [];
      return;
    }

    // Get current user's data (role and full name)
    final teacherDoc = await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .get();
    
    if (!teacherDoc.exists) {
      yield [];
      return;
    }

    final teacherData = teacherDoc.data();
    final userRole = teacherData?['role'] ?? '';
    final teacherName = teacherData?['fullname'] ?? '';

    // Check if user is a teacher
    if (userRole != 'teacher') {
      print('User is not a teacher. Role: $userRole');
      yield [];
      return;
    }

    // Check if teacher has a full name
    if (teacherName.isEmpty) {
      print('Teacher full name is empty');
      yield [];
      return;
    }

    print('Teacher role verified: $teacherName');

    // Query all users to find students who have this teacher with status false
    await for (var usersSnapshot
        in _firestore.collection('users').snapshots()) {
      List<Map<String, dynamic>> requests = [];

      for (var userDoc in usersSnapshot.docs) {
        // Skip if it's the current user
        if (userDoc.id == currentUser.uid) continue;

        // Check if this user has the current teacher in their subcollection
        final teacherSubDoc = await _firestore
            .collection('users')
            .doc(userDoc.id)
            .collection('teachers')
            .doc(teacherName)
            .get();

        // If the document exists with teacher's full name, this user requested this teacher
        if (teacherSubDoc.exists) {
          final teacherRequestData = teacherSubDoc.data();
          final status = teacherRequestData?['status'] ?? false;

          // Only include pending requests (status = false)
          if (!status) {
            final userData = userDoc.data();
            
            print(
              'Found pending request from user: ${userData['username']} (ID: ${userDoc.id})',
            );
            
            requests.add({
              'studentId': userDoc.id,
              'username':
                  userData['username'] ?? userData['fullname'] ?? 'Unknown',
              'email': userData['email'] ?? '',
              'profileImage': userData['profileImage'],
              'addedAt': teacherRequestData?['addedAt'],
            });
          }
        }
      }

      print('Total pending requests: ${requests.length}');
      yield requests;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E201E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Student Requests',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _getStudentRequests(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading requests',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            );
          }

          final requests = snapshot.data ?? [];

          if (requests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 80,
                    color: Colors.white.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No pending requests',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Students who add you will appear here',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            );
          }

          return FutureBuilder<DocumentSnapshot>(
            future: _firestore.collection('users').doc(_auth.currentUser?.uid).get(),
            builder: (context, teacherSnapshot) {
              final teacherName = teacherSnapshot.data?.data() != null
                  ? (teacherSnapshot.data!.data() as Map<String, dynamic>)['fullname'] ?? ''
                  : '';

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: requests.length,
                itemBuilder: (context, index) {
                  final request = requests[index];
                  final studentId = request['studentId'];
                  final username = request['username'];
                  final email = request['email'];
                  final profileImageBase64 = request['profileImage'];
                  final isProcessing = _processingRequests.contains(studentId);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D2F2D),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              // Student avatar
                              CircleAvatar(
                                radius: 30,
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
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 16),

                              // Student info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      username,
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      email,
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        color: Colors.white.withOpacity(0.7),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),

                              // Pending badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange[700],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Pending',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Action buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // Message button
                              AnimatedButton(
                                width: 110,
                                height: 42,
                                color: Colors.white.withOpacity(0.1),
                                shadowDegree: ShadowDegree.light,
                                onPressed: isProcessing
                                    ? () {}
                                    : () {
                                        _messageStudent(studentId, username, email);
                                      },
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.message_outlined,
                                      size: 18,
                                      color: isProcessing
                                          ? Colors.white.withOpacity(0.3)
                                          : Colors.white,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Message',
                                      style: GoogleFonts.poppins(
                                        color: isProcessing
                                            ? Colors.white.withOpacity(0.3)
                                            : Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Accept button
                              AnimatedButton(
                                width: 100,
                                height: 42,
                                color: Colors.green[600]!,
                                shadowDegree: ShadowDegree.light,
                                enabled: !isProcessing,
                                onPressed: () {
                                  _acceptStudent(studentId, teacherName);
                                },
                                child: isProcessing
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.check_circle_outline,
                                            size: 18,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Accept',
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
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}