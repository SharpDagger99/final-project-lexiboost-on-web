// ignore_for_file: deprecated_member_use, use_build_context_synchronously, unused_catch_clause, avoid_print

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MyRegister extends StatefulWidget {
  const MyRegister({super.key});

  @override
  State<MyRegister> createState() => _MyRegisterState();
}

class _MyRegisterState extends State<MyRegister> {
  bool _obscurePassword = true;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

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
          content: Text(
            message,
            style: GoogleFonts.poppins(fontSize: 14),
          ),
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

  // Show secondary authentication popup for teachers
  Future<void> _showSecondaryAuth() async {
    final TextEditingController mobileController = TextEditingController();
    final TextEditingController otpController = TextEditingController();
    String? verificationId;
    bool isOtpSent = false;
    bool isVerifying = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                "Secondary Authentication",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              content: SizedBox(
                width: 350,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Please input your mobile number to get an OTP code",
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                    const SizedBox(height: 20),
                    // Mobile Number Field
                    TextField(
                      controller: mobileController,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: "09xx xxx xx89",
                        prefixIcon: const Icon(Icons.phone, size: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Resend Code Button
                    if (isOtpSent)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: isVerifying
                              ? null
                              : () async {
                                  if (mobileController.text.trim().isEmpty) {
                                    _showDialog(
                                      "Mobile Number Required",
                                      "Please enter your mobile number.",
                                    );
                                    return;
                                  }
                                  setDialogState(() {
                                    isVerifying = true;
                                  });
                                  try {
                                    final phoneNumber =
                                        '+63${mobileController.text.trim()}';
                                    await FirebaseAuth.instance.verifyPhoneNumber(
                                      phoneNumber: phoneNumber,
                                      verificationCompleted:
                                          (PhoneAuthCredential credential) async {
                                        setDialogState(() {
                                          isOtpSent = true;
                                          isVerifying = false;
                                        });
                                      },
                                      verificationFailed:
                                          (FirebaseAuthException e) {
                                        setDialogState(() {
                                          isVerifying = false;
                                        });
                                        _showDialog(
                                          "Verification Failed",
                                          "Unable to verify your mobile number. Please check and try again.",
                                        );
                                      },
                                      codeSent: (String verId, int? resendToken) {
                                        setDialogState(() {
                                          verificationId = verId;
                                          isOtpSent = true;
                                          isVerifying = false;
                                        });
                                        _showDialog(
                                          "Code Resent",
                                          "A new verification code has been sent to your mobile number.",
                                        );
                                      },
                                      codeAutoRetrievalTimeout: (String verId) {
                                        verificationId = verId;
                                      },
                                      timeout: const Duration(seconds: 60),
                                    );
                                  } catch (e) {
                                    setDialogState(() {
                                      isVerifying = false;
                                    });
                                    _showDialog(
                                      "Error",
                                      "An error occurred. Please try again.",
                                    );
                                  }
                                },
                          child: Text(
                            "Resend Code",
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueAccent,
                            ),
                          ),
                        ),
                      ),
                    if (isOtpSent) ...[
                      const SizedBox(height: 10),
                      // OTP Field
                      TextField(
                        controller: otpController,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: "Enter OTP",
                          prefixIcon: const Icon(Icons.lock, size: 18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    FirebaseAuth.instance.signOut();
                  },
                  child: Text(
                    "Cancel",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                  ),
                  onPressed: isVerifying
                      ? null
                      : () async {
                          if (!isOtpSent) {
                            // Send OTP
                            if (mobileController.text.trim().isEmpty) {
                              _showDialog(
                                "Mobile Number Required",
                                "Please enter your mobile number.",
                              );
                              return;
                            }
                            setDialogState(() {
                              isVerifying = true;
                            });
                            try {
                              final phoneNumber =
                                  '+63${mobileController.text.trim()}';
                              await FirebaseAuth.instance.verifyPhoneNumber(
                                phoneNumber: phoneNumber,
                                verificationCompleted:
                                    (PhoneAuthCredential credential) async {
                                  setDialogState(() {
                                    isOtpSent = true;
                                    isVerifying = false;
                                  });
                                },
                                verificationFailed: (FirebaseAuthException e) {
                                  setDialogState(() {
                                    isVerifying = false;
                                  });
                                  _showDialog(
                                    "Verification Failed",
                                    "Unable to verify your mobile number. Please check and try again.",
                                  );
                                },
                                codeSent: (String verId, int? resendToken) {
                                  setDialogState(() {
                                    verificationId = verId;
                                    isOtpSent = true;
                                    isVerifying = false;
                                  });
                                  _showDialog(
                                    "Verification Code Sent",
                                    "A verification code has been sent to your mobile number.",
                                  );
                                },
                                codeAutoRetrievalTimeout: (String verId) {
                                  verificationId = verId;
                                },
                                timeout: const Duration(seconds: 60),
                              );
                            } catch (e) {
                              setDialogState(() {
                                isVerifying = false;
                              });
                              _showDialog(
                                "Error",
                                "An error occurred. Please try again.",
                              );
                            }
                          } else {
                            // Verify OTP
                            if (otpController.text.trim().isEmpty) {
                              _showDialog(
                                "OTP Required",
                                "Please enter the verification code.",
                              );
                              return;
                            }
                            setDialogState(() {
                              isVerifying = true;
                            });
                            try {
                              final credential = PhoneAuthProvider.credential(
                                verificationId: verificationId!,
                                smsCode: otpController.text.trim(),
                              );
                              await FirebaseAuth.instance
                                  .signInWithCredential(credential);
                              await FirebaseAuth.instance.signOut();
                              Navigator.of(dialogContext).pop();
                              Get.offAllNamed("/teacher_home");
                            } on FirebaseAuthException catch (e) {
                              setDialogState(() {
                                isVerifying = false;
                              });
                              _showDialog(
                                "Invalid Code",
                                "The verification code is incorrect. Please try again.",
                              );
                            }
                          }
                        },
                  child: Text(
                    isVerifying
                        ? "Processing..."
                        : (isOtpSent ? "Confirm" : "Send Code"),
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> login() async {
    try {
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = userCredential.user;

      if (user != null) {
        // 🔍 Fetch user role from Firestore
        final userDoc = await FirebaseFirestore.instance
            .collection("users")
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final role = userDoc.data()?['role'] ?? 'student';

          if (role == 'admin') {
            Get.offAllNamed("/admin");
          } else if (role == 'teacher') {
            // Show secondary authentication for teachers
            await _showSecondaryAuth();
          } else {
            Get.offAllNamed("/student");
          }
        } else {
          // If no document, default to student
          Get.offAllNamed("/student");
        }
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = "Unable to log in. Please check your credentials and try again.";
      if (e.code == 'user-not-found') {
        errorMessage = "No account found with this email address.";
      } else if (e.code == 'wrong-password') {
        errorMessage = "Incorrect password. Please try again.";
      } else if (e.code == 'invalid-email') {
        errorMessage = "Invalid email address format.";
      } else if (e.code == 'invalid-credential') {
        errorMessage = "Invalid credentials. Please check your email and password.";
      }
      // Debug: Print error details
      print('Firebase Auth Error: ${e.code} - ${e.message}');
      _showDialog("Login Failed", errorMessage);
    } catch (e) {
      // Catch any other errors
      print('Unexpected Error: $e');
      _showDialog("Error", "An unexpected error occurred. Please try again.");
    }
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
                          hintStyle: const TextStyle(color: Colors.white54, fontSize: 14),
                          prefixIcon: const Icon(Icons.email, color: Colors.white, size: 18),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Colors.white, width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Colors.white, width: 2),
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
                          hintStyle: const TextStyle(color: Colors.white54, fontSize: 14),
                          prefixIcon: const Icon(Icons.password_rounded, color: Colors.white, size: 18),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
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
                            borderSide: const BorderSide(color: Colors.white, width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ),
                
                    const SizedBox(height: 10),
                
                    // --- FORGOT PASSWORD ---
                    SizedBox(
                      width: 300,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () {
                            // Add forgot password functionality here
                          },
                          child: Text(
                            "Forgot Password?",
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueAccent,
                            ),
                          ),
                        ),
                      ),
                    ),
                
                    const SizedBox(height: 20),
                
                    // --- LOGIN BUTTON ---
                    GestureDetector(
                      onTap: login,
                      child: Container(
                        width: 300,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            "Login",
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
                          style: GoogleFonts.poppins(fontSize: 14, color: Colors.white),
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
