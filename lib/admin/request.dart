// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animated_button/animated_button.dart';

class MyRequest extends StatefulWidget {
  const MyRequest({super.key});

  @override
  State<MyRequest> createState() => _MyRequestState();
}

class _MyRequestState extends State<MyRequest> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Method to update verification
  Future<void> _verifyTeacher(String docId) async {
    await _firestore.collection("users").doc(docId).update({
      "verified": true,
    });
  }

  void _showTeacherDialog(
      BuildContext context, Map<String, dynamic> data, String docId) {
    showDialog(
      context: context,
      builder: (context) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 600, // max dialog width
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2F2C),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Teacher Information",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),

                  _buildReadOnlyField("Fullname", data['fullname']),
                  _buildReadOnlyField("Email", data['email']),
                  _buildReadOnlyField(
                      "Mobile Number", data['mobileNumber'].toString()),

                  // Address TextField with 4-line height
                  _buildReadOnlyField(
                    "Address",
                    data['address'],
                    maxLines: 4,
                  ),

                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      AnimatedButton(
                        width: 110,
                        height: 45,
                        color: Colors.red,
                        shadowDegree: ShadowDegree.light,
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: const Text(
                          "Ignore",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      AnimatedButton(
                        width: 110,
                        height: 45,
                        color: Colors.white,
                        shadowDegree: ShadowDegree.light,
                        onPressed: () async {
                          await _verifyTeacher(docId);
                          if (context.mounted) Navigator.pop(context);
                        },
                        child: const Text(
                          "Accept",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReadOnlyField(String label, String value, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextField(
        readOnly: true,
        controller: TextEditingController(text: value),
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: const Color(0xFF3A3D3A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E201E),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection("users")
              .where("role", isEqualTo: "teacher")
              .where("verified", isEqualTo: false)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: Colors.white));
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Text(
                  "No request today",
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              );
            }

            final teachers = snapshot.data!.docs;

            return ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: teachers.length,
              itemBuilder: (context, index) {
                final teacher = teachers[index].data() as Map<String, dynamic>;
                final docId = teachers[index].id;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Center(
                    child: AnimatedButton(
                      width: 300,
                      height: 100,
                      color: Colors.white,
                      shadowDegree: ShadowDegree.light,
                      onPressed: () {
                        _showTeacherDialog(context, teacher, docId);
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            teacher['fullname'] ?? "No Name",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            teacher['email'] ?? "No Email",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
