// ignore_for_file: use_build_context_synchronously, prefer_final_fields, deprecated_member_use

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animated_button/animated_button.dart';

// Add Students Dialog
class AddStudentsDialog extends StatefulWidget {
  final Map<String, dynamic> classData;

  const AddStudentsDialog({super.key, required this.classData});

  @override
  State<AddStudentsDialog> createState() => _AddStudentsDialogState();
}

class _AddStudentsDialogState extends State<AddStudentsDialog> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _studentSearchController = TextEditingController();
  
  List<String> _selectedStudentIds = [];
  String _studentSearchQuery = '';
  bool _isAdding = false;

  @override
  void dispose() {
    _studentSearchController.dispose();
    super.dispose();
  }

  // Get teacher's confirmed students excluding already added ones
  Stream<List<Map<String, dynamic>>> _getAvailableStudents() async* {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      yield [];
      return;
    }

    final teacherDoc = await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .get();
    final teacherName = teacherDoc.data()?['fullname'] ?? '';

    if (teacherName.isEmpty) {
      yield [];
      return;
    }

    final existingStudentIds = List<String>.from(
      widget.classData['studentIds'] ?? [],
    );

    await for (var usersSnapshot in _firestore
        .collection('users')
        .where('role', isEqualTo: 'student')
        .snapshots()) {
      List<Map<String, dynamic>> students = [];

      for (var userDoc in usersSnapshot.docs) {
        // Skip if already in class
        if (existingStudentIds.contains(userDoc.id)) continue;

        final teacherSubDoc = await _firestore
            .collection('users')
            .doc(userDoc.id)
            .collection('teachers')
            .doc(teacherName)
            .get();

        if (teacherSubDoc.exists && (teacherSubDoc.data()?['status'] ?? false)) {
          final userData = userDoc.data();
          final username = userData['username'] ?? 'Unknown';
          final fullname = userData['fullname'] ?? 'Unknown';
          final email = userData['email'] ?? '';
          final schoolId = userData['schoolId'] ?? 'Not set';
          final gradeLevel = userData['gradeLevel'] ?? 'Not set';
          final section = userData['section'] ?? 'Not set';

          // Enhanced search filter - includes fullname, schoolId, gradeLevel, and section
          if (_studentSearchQuery.isEmpty ||
              username.toLowerCase().contains(_studentSearchQuery.toLowerCase()) ||
              fullname.toLowerCase().contains(_studentSearchQuery.toLowerCase()) ||
              email.toLowerCase().contains(_studentSearchQuery.toLowerCase()) ||
              schoolId.toLowerCase().contains(_studentSearchQuery.toLowerCase()) ||
              gradeLevel.toLowerCase().contains(_studentSearchQuery.toLowerCase()) ||
              section.toLowerCase().contains(_studentSearchQuery.toLowerCase())) {
            students.add({
              'studentId': userDoc.id,
              'username': username,
              'fullname': fullname,
              'email': email,
              'profileImage': userData['profileImage'],
              'schoolId': schoolId,
              'gradeLevel': gradeLevel,
              'section': section,
            });
          }
        }
      }

      yield students;
    }
  }

  Future<void> _addStudents() async {
    if (_selectedStudentIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one student'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isAdding = true;
    });

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final classId = widget.classData['classId'];
      final className = widget.classData['className'] ?? 'Unknown Class';
      
      // Get teacher info
      final teacherDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final teacherName = teacherDoc.data()?['fullname'] ?? 'Teacher';

      // Get existing student IDs
      final existingStudentIds = List<String>.from(
        widget.classData['studentIds'] ?? [],
      );

      // Add new students to existing list
      final updatedStudentIds = [...existingStudentIds, ..._selectedStudentIds];

      // Update the class
      await _firestore.collection('classes').doc(classId).update({
        'studentIds': updatedStudentIds,
      });

      // Send notification to each new student
      for (String studentId in _selectedStudentIds) {
        await _firestore
            .collection('users')
            .doc(studentId)
            .collection('notifications')
            .add({
              'title': 'Added to Class',
              'message': 'You have been added to "$className" by $teacherName',
              'from': currentUser.uid,
              'fromName': teacherName,
              'timestamp': FieldValue.serverTimestamp(),
              'read': false,
              'pinned': false,
              'type': 'class_added',
              'classId': classId,
              'className': className,
            });
      }

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_selectedStudentIds.length} student(s) added successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding students: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isAdding = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
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
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.person_add,
                    color: Colors.blue,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Add Students',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Selected count
            if (_selectedStudentIds.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_selectedStudentIds.length} student(s) selected',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Student search
            TextField(
              controller: _studentSearchController,
              onChanged: (value) {
                setState(() {
                  _studentSearchQuery = value;
                });
              },
              style: GoogleFonts.poppins(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search students...',
                hintStyle: GoogleFonts.poppins(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey[50],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Students list
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _getAvailableStudents(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final students = snapshot.data ?? [];

                  if (students.isEmpty) {
                    return Center(
                      child: Text(
                        _studentSearchQuery.isEmpty
                            ? 'No available students'
                            : 'No students found',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    );
                  }

                  return Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListView.builder(
                      itemCount: students.length,
                      itemBuilder: (context, index) {
                        final student = students[index];
                        final studentId = student['studentId'];
                        final username = student['username'];
                        final email = student['email'];
                        final profileImageBase64 = student['profileImage'];
                        final isSelected = _selectedStudentIds.contains(studentId);

                        return ListTile(
                          leading: CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.blue,
                            backgroundImage: profileImageBase64 != null
                                ? MemoryImage(base64Decode(profileImageBase64))
                                : null,
                            child: profileImageBase64 == null
                                ? Text(
                                    username.isNotEmpty
                                        ? username[0].toUpperCase()
                                        : 'S',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          title: Text(
                            username,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            email,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          trailing: Checkbox(
                            value: isSelected,
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true) {
                                  _selectedStudentIds.add(studentId);
                                } else {
                                  _selectedStudentIds.remove(studentId);
                                }
                              });
                            },
                            activeColor: Colors.blue,
                          ),
                        );
                      },
                    ),
                  );
                },
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
                  color: Colors.blue,
                  shadowDegree: ShadowDegree.light,
                  onPressed: _isAdding ? () {} : _addStudents,
                  child: _isAdding
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Add Students',
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
  }
}

// Color Picker Dialog
class ColorPickerDialog extends StatefulWidget {
  final Map<String, dynamic> classData;

  const ColorPickerDialog({super.key, required this.classData});

  @override
  State<ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<ColorPickerDialog> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Color _selectedColor;
  bool _isUpdating = false;

  final List<Color> _availableColors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.purple,
    Colors.orange,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
    Colors.amber,
    Colors.cyan,
    Colors.deepOrange,
    Colors.lime,
  ];

  @override
  void initState() {
    super.initState();
    final colorValue = widget.classData['color'] as int?;
    _selectedColor = colorValue != null ? Color(colorValue) : Colors.blue;
  }

  Future<void> _updateColor() async {
    setState(() {
      _isUpdating = true;
    });

    try {
      final classId = widget.classData['classId'];
      await _firestore.collection('classes').doc(classId).update({
        'color': _selectedColor.value,
      });

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Class color updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating color: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 400),
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
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.palette,
                    color: Colors.purple,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Choose Color',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Color preview
            Container(
              width: double.infinity,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _selectedColor.withOpacity(0.8),
                    _selectedColor.withOpacity(0.6),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  widget.classData['className'] ?? 'Class Preview',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Color grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _availableColors.length,
              itemBuilder: (context, index) {
                final color = _availableColors[index];
                final isSelected = _selectedColor.value == color.value;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedColor = color;
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.black : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.5),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 24,
                          )
                        : null,
                  ),
                );
              },
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
                  color: Colors.purple,
                  shadowDegree: ShadowDegree.light,
                  onPressed: _isUpdating ? () {} : _updateColor,
                  child: _isUpdating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Save',
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
  }
}

