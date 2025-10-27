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

class _MyRegisterState extends State<MyRegister>
    with SingleTickerProviderStateMixin {
  bool _obscurePassword = true;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoggingIn = false;
  bool _isSendingPasswordReset = false;
  
  // Error states
  String? _emailError;
  String? _passwordError;

  // Animation controller for shake effect
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Create a shake animation that returns to 0
    _shakeAnimation =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0.0, end: 10.0), weight: 1),
          TweenSequenceItem(tween: Tween(begin: 10.0, end: -10.0), weight: 1),
          TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 1),
          TweenSequenceItem(tween: Tween(begin: 10.0, end: -10.0), weight: 1),
          TweenSequenceItem(tween: Tween(begin: -10.0, end: 0.0), weight: 1),
        ]).animate(
          CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
        );

    // Reset animation when complete
    _shakeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _shakeController.reset();
      }
    });
  }

  // Shake animation trigger
  void _triggerShake() {
    _shakeController.forward(from: 0.0);
  }

  // Clear errors
  void _clearErrors() {
    setState(() {
      _emailError = null;
      _passwordError = null;
    });
  }

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

    // Clear previous errors
    _clearErrors();

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
      print('Firebase Auth Error: ${e.code} - ${e.message}');
      
      setState(() {
        _isLoggingIn = false;
        
        // Set error states based on error code
        if (e.code == 'user-not-found' || e.code == 'invalid-email') {
          _emailError = "Invalid email";
        } else if (e.code == 'wrong-password') {
          _passwordError = "Incorrect password";
        } else if (e.code == 'invalid-credential') {
          // Invalid credential could be either email or password
          _emailError = "Invalid email";
          _passwordError = "Incorrect password";
        } else {
          // For other errors, show both
          _emailError = "Invalid email";
          _passwordError = "Incorrect password";
        }
      });
      
      // Trigger shake animation
      _triggerShake();
    } catch (e) {
      print('Unexpected Error: $e');
      setState(() {
        _isLoggingIn = false;
        _emailError = "Invalid email";
        _passwordError = "Incorrect password";
      });
      
      // Trigger shake animation
      _triggerShake();
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
    _shakeController.dispose();
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
              AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: _emailError != null
                        ? Offset(_shakeAnimation.value, 0)
                        : Offset.zero,
                    child: child,
                  );
                },
                child: SizedBox(
                  width: 300,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_emailError != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 4),
                          child: Text(
                            _emailError!,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      SizedBox(
                        height: 50,
                        child: TextField(
                          controller: _emailController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: "Email",
                            hintStyle: const TextStyle(
                              color: Colors.white54,
                              fontSize: 14,
                            ),
                            prefixIcon: Icon(
                              Icons.email,
                              color: _emailError != null
                                  ? Colors.red
                                  : Colors.white,
                              size: 18,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: _emailError != null
                                    ? Colors.red
                                    : Colors.white,
                                width: _emailError != null ? 2 : 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: _emailError != null
                                    ? Colors.red
                                    : Colors.white,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // --- PASSWORD FIELD ---
              AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: _passwordError != null
                        ? Offset(_shakeAnimation.value, 0)
                        : Offset.zero,
                    child: child,
                  );
                },
                child: SizedBox(
                  width: 300,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_passwordError != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 4),
                          child: Text(
                            _passwordError!,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      SizedBox(
                        height: 50,
                        child: TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: "Password",
                            hintStyle: const TextStyle(
                              color: Colors.white54,
                              fontSize: 14,
                            ),
                            prefixIcon: Icon(
                              Icons.password_rounded,
                              color: _passwordError != null
                                  ? Colors.red
                                  : Colors.white,
                              size: 18,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: _obscurePassword
                                    ? Colors.white54
                                    : Colors.blue,
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
                              borderSide: BorderSide(
                                color: _passwordError != null
                                    ? Colors.red
                                    : Colors.white,
                                width: _passwordError != null ? 2 : 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: _passwordError != null
                                    ? Colors.red
                                    : Colors.white,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
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
