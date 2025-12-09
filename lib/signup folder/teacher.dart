// ignore_for_file: use_build_context_synchronously, unused_catch_clause, deprecated_member_use

import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


// ---------------- Teacher Signup Page ---------------- //
class MyTeacher extends StatefulWidget {
  const MyTeacher({super.key});

  @override
  State<MyTeacher> createState() => _MyTeacherState();
}

class _MyTeacherState extends State<MyTeacher> {
  // Controllers
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  final TextEditingController mobileController = TextEditingController();
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController addressController = TextEditingController();

  bool _obscurePassword = true;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isRegistering = false;
  
  // Email verification states
  bool _isCheckingEmail = false;
  bool _isEmailVerified = false;
  String? _verificationMessage;
  Timer? _emailDebounce;
  User? _tempUser;
  
  // Email validation helper
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  // Get email provider name for user-friendly messages
  String _getEmailProvider(String email) {
    final domain = email.split('@').last.toLowerCase();
    
    if (domain.contains('gmail')) return 'Gmail';
    if (domain.contains('yahoo')) return 'Yahoo';
    if (domain.contains('outlook') || domain.contains('hotmail') || domain.contains('live')) return 'Outlook';
    if (domain.contains('edu.ph') || domain.contains('.edu')) return 'Educational Institution';
    if (domain.contains('icloud') || domain.contains('me.com')) return 'iCloud';
    if (domain.contains('protonmail') || domain.contains('proton')) return 'ProtonMail';
    
    return 'your email provider';
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
  
  // Show signup guide dialog
  void _showSignupGuide() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2C2F2C), Color(0xFF1E201E)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                },
              ),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.help_outline,
                            color: Colors.blueAccent,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            "Teacher Sign Up Guide",
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Introduction
                    Text(
                      "Follow these simple steps to create your teacher account:",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Step 1
                    _buildGuideStep(
                      number: "1",
                      icon: Icons.edit,
                      title: "Fill in Your Information",
                      description: "You can fill in the fields in any order you prefer. Enter your email, password, confirm password, mobile number, full name, and address.",
                      color: Colors.blue,
                    ),
                    
                    // Step 2
                    _buildGuideStep(
                      number: "2",
                      icon: Icons.lock,
                      title: "Create a Strong Password",
                      description: "Make sure your password is at least 6 characters long and both password fields match.",
                      color: Colors.indigo,
                    ),
                    
                    // Step 3
                    _buildGuideStep(
                      number: "3",
                      icon: Icons.email,
                      title: "Email Verification",
                      description: "Fill in ALL fields (email, password, confirm password, mobile, full name, address). After 2 seconds, the system will automatically send a verification link to your email. We support all email providers: Gmail, Yahoo, Outlook, .edu.ph, and more.",
                      color: Colors.purple,
                    ),
                    
                    // Step 4
                    _buildGuideStep(
                      number: "4",
                      icon: Icons.mark_email_read,
                      title: "Verify Your Email",
                      description: "Check your email inbox (and spam/junk folder) for the verification link. The email will be sent to your provider (Gmail, Yahoo, Outlook, etc.). Click the link to verify your email. A green checkmark ✓ will appear once verified.",
                      color: Colors.green,
                    ),
                    
                    // Step 5
                    _buildGuideStep(
                      number: "5",
                      icon: Icons.check_circle,
                      title: "Complete All Fields",
                      description: "Fill in all remaining fields: Mobile Number, Full Name, and Address. The Register button will activate only when all fields are filled and email is verified.",
                      color: Colors.orange,
                    ),
                    
                    // Step 6
                    _buildGuideStep(
                      number: "6",
                      icon: Icons.how_to_reg,
                      title: "Submit & Wait for Approval",
                      description: "Once all fields are complete and email is verified, click the Register button. Your account will be sent to admin for approval.",
                      color: Colors.teal,
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Tips section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.amber.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.lightbulb_outline,
                                color: Colors.amber,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Pro Tips",
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "• Fill in fields in any order you prefer\n• Both passwords must match to proceed\n• Email verification starts only when ALL fields are filled\n• Use a valid email you can access (Gmail, Yahoo, Outlook, .edu.ph, etc.)\n• Check spam/junk folder if you don't see the verification email\n• All email providers are supported\n• Register button activates when ALL fields are filled AND email is verified\n• You can scroll up/down by dragging the screen\n• Admin approval typically takes 24-48 hours",
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.white70,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Close button
                    SizedBox(
                      width: double.infinity,
                      height: 45,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          "Got It!",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  
  // Build guide step widget
  Widget _buildGuideStep({
    required String number,
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step number circle
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white60,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Check if all fields are filled
  bool _areAllFieldsFilled() {
    return emailController.text.trim().isNotEmpty &&
        passwordController.text.trim().isNotEmpty &&
        confirmPasswordController.text.trim().isNotEmpty &&
        mobileController.text.trim().isNotEmpty &&
        fullNameController.text.trim().isNotEmpty &&
        addressController.text.trim().isNotEmpty;
  }
  
  // Validate all required fields
  bool _validateFields() {
    if (emailController.text.trim().isEmpty ||
        passwordController.text.trim().isEmpty ||
        confirmPasswordController.text.trim().isEmpty ||
        mobileController.text.trim().isEmpty ||
        fullNameController.text.trim().isEmpty ||
        addressController.text.trim().isEmpty) {
      _showDialog(
        "Required Fields Missing",
        "Please fill in all required fields to continue with your registration.",
      );
      return false;
    }
    
    if (passwordController.text != confirmPasswordController.text) {
      _showDialog(
        "Password Mismatch",
        "The passwords you entered do not match. Please make sure both password fields are identical.",
      );
      return false;
    }
    
    if (passwordController.text.length < 6) {
      _showDialog(
        "Password Too Short",
        "Password must be at least 6 characters long.",
      );
      return false;
    }
    
    return true;
  }
  
  // Check email and send verification
  Future<void> _checkAndVerifyEmail(String email) async {
    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _isCheckingEmail = false;
        _isEmailVerified = false;
        _verificationMessage = null;
      });
      return;
    }
    
    // Validate email format
    if (!_isValidEmail(email)) {
      setState(() {
        _isCheckingEmail = false;
        _verificationMessage = "Invalid email format. Please use a valid email (Gmail, Yahoo, Outlook, .edu.ph, etc.)";
      });
      return;
    }
    
    // Don't check if already verified
    if (_isEmailVerified && _tempUser?.email == email) {
      return;
    }
    
    // Validate password is entered
    if (passwordController.text.trim().isEmpty) {
      setState(() {
        _isCheckingEmail = false;
        _verificationMessage = "Please enter a password before verifying email.";
      });
      return;
    }
    
    setState(() {
      _isCheckingEmail = true;
      _isEmailVerified = false;
      _verificationMessage = null;
    });
    
    final provider = _getEmailProvider(email);
    
    try {
      // Create account with ACTUAL password (this will fail if email exists)
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: passwordController.text.trim(),
      );
      
      _tempUser = userCredential.user;
      
      // Send verification email
      await _tempUser!.sendEmailVerification();
      
      setState(() {
        _isCheckingEmail = false;
        _verificationMessage = "Verification email sent to your $provider inbox. Please check spam folder if not found.";
      });
      
      // Start checking for email verification
      _startVerificationCheck();
      
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isCheckingEmail = false;
      });
      
      if (e.code == 'email-already-in-use') {
        setState(() {
          _verificationMessage = "Email already in use. Please use a different email.";
        });
      } else if (e.code == 'invalid-email') {
        setState(() {
          _verificationMessage = "Invalid email format. Please use a valid email from any provider.";
        });
      } else if (e.code == 'weak-password') {
        setState(() {
          _verificationMessage = "Password is too weak. Use at least 6 characters.";
        });
      } else {
        setState(() {
          _verificationMessage = "Error: ${e.message}";
        });
      }
    } catch (e) {
      setState(() {
        _isCheckingEmail = false;
        _verificationMessage = "Error checking email.";
      });
    }
  }
  
  // Start checking for email verification status
  void _startVerificationCheck() {
    Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_tempUser != null) {
        await _tempUser!.reload();
        _tempUser = FirebaseAuth.instance.currentUser;
        
        if (_tempUser?.emailVerified ?? false) {
          timer.cancel();
          setState(() {
            _isEmailVerified = true;
            _verificationMessage = "Email verified successfully!";
          });
        }
      } else {
        timer.cancel();
      }
    });
  }
  
  // Check if all fields are filled and trigger verification
  void _checkAllFieldsAndVerify() {
    if (_emailDebounce?.isActive ?? false) _emailDebounce!.cancel();
    
    _emailDebounce = Timer(const Duration(seconds: 2), () {
      final email = emailController.text.trim();
      final password = passwordController.text.trim();
      final confirmPassword = confirmPasswordController.text.trim();
      final mobile = mobileController.text.trim();
      final fullName = fullNameController.text.trim();
      final address = addressController.text.trim();
      
      // Only start verification if ALL fields are filled
      if (email.isNotEmpty && email.contains('@') &&
          password.isNotEmpty && confirmPassword.isNotEmpty &&
          mobile.isNotEmpty && fullName.isNotEmpty && address.isNotEmpty) {
        
        // Check if passwords match
        if (password != confirmPassword) {
          setState(() {
            _verificationMessage = "Passwords do not match. Please check your password fields.";
          });
          return;
        }
        
        // All fields filled and passwords match - proceed with email verification
        _checkAndVerifyEmail(email);
      }
    });
  }
  
  // Register teacher after email verification
  Future<void> _registerTeacher() async {
    if (!_isEmailVerified) {
      _showDialog(
        "Email Not Verified",
        "Please verify your email address before registering. Check your inbox for the verification link.",
      );
      return;
    }
    
    if (!_validateFields()) return;
    
    // Verify the user is still authenticated
    if (_tempUser == null || FirebaseAuth.instance.currentUser == null) {
      _showDialog(
        "Session Expired",
        "Your session has expired. Please refresh the page and try again.",
      );
      return;
    }
    
    setState(() {
      _isRegistering = true;
    });
    
    try {
      // User already exists with verified email, just save to Firestore
      final currentUser = FirebaseAuth.instance.currentUser;
      
      if (currentUser != null) {
        // Save teacher info to Firestore
        await _firestore.collection("users").doc(currentUser.uid).set({
          "email": emailController.text.trim(),
          "fullname": fullNameController.text.trim(),
          "mobileNumber": mobileController.text.trim(),
          "address": addressController.text.trim(),
          "role": "teacher",
          "verified": false,
          "createdAt": FieldValue.serverTimestamp(),
        });
        
        // Keep user signed in and navigate to waiting page
        // User will be redirected to login once verified
        if (mounted) {
          Navigator.of(context).pushReplacement(_createRoute());
        }
      } else {
        throw Exception("No authenticated user found");
      }
    } catch (e) {
      setState(() {
        _isRegistering = false;
      });
      _showDialog(
        "Registration Error",
        "An error occurred during registration: ${e.toString()}. Please try again or contact support.",
      );
    }
  }
  
  @override
  void dispose() {
    _emailDebounce?.cancel();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    mobileController.dispose();
    fullNameController.dispose();
    addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      body: Center(
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
            },
          ),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
              Text(
                "Sign Up",
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),

              // Fields
              buildEmailField(),
              buildPasswordField("Password", passwordController),
              buildPasswordField("Confirm Password", confirmPasswordController),
              buildTextField("Mobile Number", mobileController, false),
              buildTextField("Full Name", fullNameController, false),
              buildMultilineTextField("Address", addressController),

              const SizedBox(height: 25),

              // Verification message
              if (_verificationMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    _verificationMessage!,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: _isEmailVerified ? Colors.green : Colors.orange,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              
              // Register button
              SizedBox(
                width: 300,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (_isRegistering || !_isEmailVerified || !_areAllFieldsFilled()) ? Colors.grey : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: (_isRegistering || !_isEmailVerified || !_areAllFieldsFilled()) ? null : _registerTeacher,
                  child: Text(
                    _isRegistering ? "Registering..." : "Register",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 15),
              
              // Help text with guide button
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Having trouble signing up? ",
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                  TextButton(
                    onPressed: _showSignupGuide,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      "read the guide",
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueAccent,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Supported email providers info box
              Container(
                width: 300,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.verified_user, color: Colors.green, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'All Email Providers Supported',
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Gmail • Yahoo • Outlook • iCloud\nEducational (.edu.ph) • ProtonMail • and more',
                      style: GoogleFonts.poppins(
                        color: Colors.white60,
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'You will receive verification emails',
                      style: GoogleFonts.poppins(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Email field with verification indicator
  Widget buildEmailField() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        width: 300,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 50,
              child: TextField(
                controller: emailController,
                onChanged: (value) {
                  _checkAllFieldsAndVerify();
                  setState(() {}); // Refresh button state
                },
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: "Email (Gmail, Yahoo, Outlook, .edu.ph, etc.)",
                  hintStyle: const TextStyle(color: Colors.white70, fontSize: 13),
                  filled: true,
                  fillColor: const Color(0xFF1E1E1E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  suffixIcon: _isCheckingEmail
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                            ),
                          ),
                        )
                      : _isEmailVerified
                          ? const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                            )
                          : null,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "All email providers supported",
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Reusable single-line text field
  Widget buildTextField(
      String hint, TextEditingController controller, bool obscure) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        width: 300,
        height: 50,
        child: TextField(
          controller: controller,
          onChanged: (value) {
            _checkAllFieldsAndVerify();
            setState(() {}); // Refresh button state
          },
          obscureText: obscure,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white70),
            filled: true,
            fillColor: const Color(0xFF1E1E1E),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    );
  }

  // Multiline field (for Address)
  Widget buildMultilineTextField(String hint, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        width: 300,
        child: TextField(
          controller: controller,
          onChanged: (value) {
            _checkAllFieldsAndVerify();
            setState(() {}); // Refresh button state
          },
          maxLines: 3,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white70),
            filled: true,
            fillColor: const Color(0xFF1E1E1E),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    );
  }

  // Password field with toggle
  Widget buildPasswordField(String hint, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        width: 300,
        height: 50,
        child: TextField(
          controller: controller,
          onChanged: (value) {
            _checkAllFieldsAndVerify();
            setState(() {}); // Refresh button state
          },
          obscureText: _obscurePassword,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white70),
            filled: true,
            fillColor: const Color(0xFF1E1E1E),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            suffixIcon: hint == "Password"
                ? IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Colors.white70,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  )
                : null,
          ),
        ),
      ),
    );
  }

  // Slide Route
  Route _createRoute() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          const WaitingPage(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0); // Slide from right
        const end = Offset.zero;
        const curve = Curves.easeInOut;
        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
  }
}

// ---------------- Waiting Page ---------------- //
class WaitingPage extends StatefulWidget {
  const WaitingPage({super.key});

  @override
  State<WaitingPage> createState() => _WaitingPageState();
}

class _WaitingPageState extends State<WaitingPage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;
    
    if (currentUser == null) {
      // No user logged in, redirect to register
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/register');
      });
      return const SizedBox();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: StreamBuilder<DocumentSnapshot>(
              stream: _firestore.collection('users').doc(currentUser.uid).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 100,
                      ),
                      const SizedBox(height: 30),
                      Text(
                        "Error checking verification status",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  );
                }

                if (!snapshot.hasData) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      RotationTransition(
                        turns: _animationController,
                        child: const Icon(
                          Icons.refresh,
                          color: Colors.blueAccent,
                          size: 100,
                        ),
                      ),
                      const SizedBox(height: 30),
                      Text(
                        "Loading...",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  );
                }

                final userData = snapshot.data!.data() as Map<String, dynamic>?;
                final isVerified = userData?['verified'] ?? false;

                if (isVerified) {
                  // Account is verified, redirect to login/register page
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    Navigator.of(context).pushReplacementNamed('/register');
                  });
                  
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 100,
                      ),
                      const SizedBox(height: 30),
                      Text(
                        "Account Verified!",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        "Redirecting to login...",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  );
                }

                // Still waiting for verification
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    RotationTransition(
                      turns: _animationController,
                      child: const Icon(
                        Icons.refresh,
                        color: Colors.blueAccent,
                        size: 100,
                      ),
                    ),
                    const SizedBox(height: 30),
                    Text(
                      "Please wait while your account is being verified...",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      "Our admin will review your request shortly.\nYou will be notified once approved.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
