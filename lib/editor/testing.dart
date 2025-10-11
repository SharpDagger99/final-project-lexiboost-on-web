import 'package:flutter/material.dart';

class MyTesting extends StatefulWidget {
  const MyTesting({super.key});

  @override
  State<MyTesting> createState() => _MyTestingState();
}

class _MyTestingState extends State<MyTesting> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2C2F2C),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xFF2C2F2C),
        child: Center(
          child: Container(
            height: double.infinity,
            width: 200,
            color: Colors.white,
            child: const Center(
              child: Text(
                'Testing Page  123',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 24,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}