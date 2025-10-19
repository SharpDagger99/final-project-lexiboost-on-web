// ignore_for_file: deprecated_member_use, avoid_print

import 'dart:ui'; // needed for ImageFilter
import 'package:animated_button/animated_button.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class MyStart extends StatefulWidget {
  const MyStart({super.key});

  @override
  State<MyStart> createState() => _MyStartState();
}

class _MyStartState extends State<MyStart> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E201E),

      // 🔥 Glassy AppBar
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15), // blur effect
            child: AppBar(
              backgroundColor: Colors.white.withOpacity(0.05), // frosted tint
              elevation: 0, // no shadow, cleaner glass
              automaticallyImplyLeading: false,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Image.asset("assets/logo/LEXIBOOST.png", scale: 5),
                  const Spacer(),

                  // 🔹 Sign In Button
                  AnimatedButton(
                    width: 60,
                    color: Colors.white,
                    child: Text(
                      "Sign In",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                    onPressed: () async {
                      // ✅ Open in new tab
                      final url = Uri.parse('${Uri.base.origin}/#/register');
                      await launchUrl(
                        url,
                        mode: LaunchMode.externalApplication,
                      );
                    },
                  ),

                  const SizedBox(width: 10),

                  // 🔹 Create Account Button
                  AnimatedButton(
                    width: 60,
                    color: Colors.lightGreenAccent,
                    child: Text(
                      "Create",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                    onPressed: () async {
                      // ✅ Open in new tab
                      final url = Uri.parse('${Uri.base.origin}/#/register2');
                      await launchUrl(
                        url,
                        mode: LaunchMode.externalApplication,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),

      // 🔥 Your animated body text
      body: Center(
        child: SingleChildScrollView(
          child: SizedBox(
            width: 300,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Hello",
                  style: TextStyle(
                    fontSize: 32.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
