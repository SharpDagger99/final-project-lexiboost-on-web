import 'package:flutter/material.dart';

class MyReport extends StatefulWidget {
  const MyReport({super.key});

  @override
  State<MyReport> createState() => _MyReportState();
}

class _MyReportState extends State<MyReport> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
       backgroundColor: const Color(0xFF1E201E),
      body: Center(
        child: Text(
          "This is Report Page", 
          style: TextStyle(
            color: Colors.white
            )
            ),
      ),
    );
  }
}