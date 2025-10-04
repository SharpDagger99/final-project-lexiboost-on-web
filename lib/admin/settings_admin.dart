import 'package:flutter/material.dart';

class MySettingsAdmin extends StatefulWidget {
  const MySettingsAdmin({super.key});

  @override
  State<MySettingsAdmin> createState() => _MySettingsAdminState();
}

class _MySettingsAdminState extends State<MySettingsAdmin> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
       backgroundColor: const Color(0xFF1E201E),
      body: Center(
        child: Text(
          "This is Settings Page", 
          style: TextStyle(
            color: Colors.white
            )
            ),
      ),
    );
  }
}