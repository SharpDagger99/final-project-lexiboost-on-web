import 'package:flutter/material.dart';

class MyTeacherDashboard extends StatelessWidget {
  const MyTeacherDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E201E),
      body: Row(
        children: [
          // First box (40%)
          Expanded(
            flex: 4, // 4 out of 10 parts = 40%
            child: Container(
              color: const Color(0xFF1E201E),
              child: const Center(
                child: Text(
                  '40%',
                  style: TextStyle(color: Colors.white, fontSize: 24),
                ),
              ),
            ),
          ),

          // Second box (60%)
          Expanded(
            flex: 6, // 6 out of 10 parts = 60%
            child: Container(
              color: const Color(0xFF1E201E),
              child: const Center(
                child: Text(
                  '60%',
                  style: TextStyle(color: Colors.white, fontSize: 24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
