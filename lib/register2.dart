// ignore_for_file: use_super_parameters

import 'package:animated_button/animated_button.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';

class MyRegister2 extends StatefulWidget {
  const MyRegister2({Key? key}) : super(key: key);

  @override
  State<MyRegister2> createState() => _MyRegister2State();
}

class _MyRegister2State extends State<MyRegister2> {
  String? selectedRole; // "Student", "Teacher", or null

  @override
  Widget build(BuildContext context) {
    final bool hasSelection = selectedRole != null;

    Widget roleButton({
      required String role,
      required String label,
      required String assetPath,
    }) {
      final bool isSelected = selectedRole == role;

      return AnimatedButton(
        width: 150,
        height: 200,
        // highlight if selected
        color: isSelected ? Colors.blueAccent.shade100 : Colors.white,
        onPressed: () {
          setState(() {
            if (isSelected) {
              selectedRole = null; // unselect
            } else {
              selectedRole = role; // select
            }
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 80,
                  height: 80,
                  child: Image.asset(
                    assetPath,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Text(
              "Select type of account:",
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                roleButton(
                  role: "Student",
                  label: "Student",
                  assetPath: "assets/others/student.png",
                ),
                const SizedBox(width: 10),
                roleButton(
                  role: "Teacher",
                  label: "Teacher",
                  assetPath: "assets/others/mentor.png",
                ),
              ],
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AnimatedButton(
                width: 300,
                height: 50,
                color: hasSelection ? Colors.white : Colors.grey.shade700,
                onPressed: () {
                  if (!hasSelection) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select a role first')),
                    );
                    return;
                  }

                  // Navigate based on selected role
                  if (selectedRole == "Student") {
                    Get.toNamed("/student");
                  } else if (selectedRole == "Teacher") {
                    Get.toNamed("/teacher");
                  }
                },
                child: Text(
                  "Next",
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: hasSelection ? Colors.black : Colors.white70,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 50),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Already have an account? ",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Get.toNamed("/register");
                    },
                    child: Text(
                      "log in",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
