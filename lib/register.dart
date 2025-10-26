// ignore_for_file: deprecated_member_use, use_build_context_synchronously, unused_catch_clause, avoid_print

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:cloud_functions/cloud_functions.dart'; // Uncomment when using cloud functions

class MyRegister extends StatefulWidget {
  const MyRegister({super.key});

  @override
  State<MyRegister> createState() => _MyRegisterState();
}

class _MyRegisterState extends State<MyRegister> {
  bool _obscurePassword = true;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoggingIn = false;
  bool _isSendingPasswordReset = false;

  // Show dialog helper
  void _showDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            title,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: Text(message, style: GoogleFonts.poppins(fontSize: 14)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                "OK",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    // Validate email and password
    if (email.isEmpty || password.isEmpty) {
      _showDialog(
        "Missing Information",
        "Please fill in email and password",
      );
      return;
    }

    setState(() {
      _isLoggingIn = true;
    });

    try {
      // Sign in with email and password
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: email,
            password: password,
          );

      final user = userCredential.user;

      if (user != null) {
        // Check if email is verified
        if (!user.emailVerified) {
          // Send verification email
          await user.sendEmailVerification();
          await FirebaseAuth.instance.signOut();
          
          setState(() {
            _isLoggingIn = false;
          });
          
          _showDialog(
            "Email Not Verified",
            "Please verify your email address before logging in. A verification link has been sent to ${user.email}. Check your inbox and spam folder.",
          );
          return;
        }

        // Fetch user data from Firestore
        final userDoc = await FirebaseFirestore.instance
            .collection("users")
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final role = userDoc.data()?['role'] ?? 'student';
          final verified = userDoc.data()?['verified'] ?? false;

          if (role == 'admin') {
            setState(() {
              _isLoggingIn = false;
            });
            Get.offAllNamed("/admin");
          } else if (role == 'teacher') {
            // Check if teacher is verified by admin
            if (!verified) {
              await FirebaseAuth.instance.signOut();
              setState(() {
                _isLoggingIn = false;
              });
              _showDialog(
                "Account Not Verified",
                "Your teacher account is pending admin approval.",
              );
              return;
            }

            // Teacher is verified - redirect to teacher home
            setState(() {
              _isLoggingIn = false;
            });
            Get.offAllNamed("/teacher_home");
          } else {
            // Students
            setState(() {
              _isLoggingIn = false;
            });
            Get.offAllNamed("/student");
          }
        } else {
          setState(() {
            _isLoggingIn = false;
          });
          Get.offAllNamed("/student");
        }
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage =
          "Unable to log in. Please check your credentials and try again.";
      if (e.code == 'user-not-found') {
        errorMessage = "No account found with this email address.";
      } else if (e.code == 'wrong-password') {
        errorMessage = "Incorrect password. Please try again.";
      } else if (e.code == 'invalid-email') {
        errorMessage = "Invalid email address format.";
      } else if (e.code == 'invalid-credential') {
        errorMessage =
            "Invalid credentials. Please check your email and password.";
      }
      print('Firebase Auth Error: ${e.code} - ${e.message}');
      setState(() {
        _isLoggingIn = false;
      });
      _showDialog("Login Failed", errorMessage);
    } catch (e) {
      print('Unexpected Error: $e');
      setState(() {
        _isLoggingIn = false;
      });
      _showDialog("Error", "An unexpected error occurred. Please try again.");
    }
  }

  // Forgot password - send password reset email
  Future<void> forgotPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _showDialog(
        "Email Required",
        "Please enter your email address to reset your password.",
      );
      return;
    }

    if (!email.contains('@')) {
      _showDialog(
        "Invalid Email",
        "Please enter a valid email address.",
      );
      return;
    }

    setState(() {
      _isSendingPasswordReset = true;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      
      setState(() {
        _isSendingPasswordReset = false;
      });
      
      _showDialog(
        "Password Reset Email Sent",
        "A password reset link has been sent to $email. Please check your inbox and spam folder.",
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isSendingPasswordReset = false;
      });
      
      String errorMessage = "Failed to send password reset email.";
      if (e.code == 'user-not-found') {
        errorMessage = "No account found with this email address.";
      } else if (e.code == 'invalid-email') {
        errorMessage = "Invalid email address format.";
      }
      
      _showDialog("Error", errorMessage);
    } catch (e) {
      setState(() {
        _isSendingPasswordReset = false;
      });
      _showDialog("Error", "An unexpected error occurred. Please try again.");
    }
  }


  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // --- TITLE ---
              Text(
                "Sign In",
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 20),

              // --- EMAIL FIELD ---
              SizedBox(
                width: 300,
                height: 50,
                child: TextField(
                  controller: _emailController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: "Email",
                    hintStyle: const TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(
                      Icons.email,
                      color: Colors.white,
                      size: 18,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: Colors.white,
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: Colors.white,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // --- PASSWORD FIELD ---
              SizedBox(
                width: 300,
                height: 50,
                child: TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: "Password",
                    hintStyle: const TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(
                      Icons.password_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: _obscurePassword ? Colors.white54 : Colors.blue,
                        size: 18,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: Colors.white,
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: Colors.white,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),

              // --- FORGOT PASSWORD ---
              SizedBox(
                width: 300,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _isSendingPasswordReset ? null : forgotPassword,
                    child: Text(
                      _isSendingPasswordReset 
                          ? "Sending..." 
                          : "Forgot Password?",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _isSendingPasswordReset 
                            ? Colors.grey 
                            : Colors.blueAccent,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // --- LOGIN BUTTON ---
              GestureDetector(
                onTap: _isLoggingIn ? () {} : login,
                child: Container(
                  width: 300,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _isLoggingIn ? Colors.grey : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      _isLoggingIn ? "Logging in..." : "Login",
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // --- SIGN UP REDIRECT ---
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Don’t have an account? ",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Get.toNamed("/register2");
                    },
                    child: Text(
                      "Sign Up",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
