// ignore_for_file: use_build_context_synchronously, unused_catch_clause

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lexi_on_web/firebase/firebase_auth.dart';


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
  final AuthService _authService = AuthService();
  
  // OTP State
  final TextEditingController otpController = TextEditingController();
  bool _isOtpSent = false;
  bool _isVerifying = false;
  String? _verificationId;

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
    
    return true;
  }
  
  // Send OTP to mobile number
  Future<void> _sendOtp() async {
    if (!_validateFields()) return;
    
    setState(() {
      _isVerifying = true;
    });
    
    try {
      // Note: For Firebase Phone Auth, prepend country code to mobile number
      // Example: +639123456789 for Philippines
      final phoneNumber = '+63${mobileController.text.trim()}'; // Adjust country code as needed
      
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification (Android only)
          setState(() {
            _isOtpSent = true;
            _isVerifying = false;
          });
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() {
            _isVerifying = false;
          });
          _showDialog(
            "Verification Failed",
            "Unable to verify your mobile number. Please check the number and try again.",
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _isOtpSent = true;
            _isVerifying = false;
          });
          _showDialog(
            "Verification Code Sent",
            "A verification code has been sent to your mobile number. Please enter it below to continue.",
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          setState(() {
            _verificationId = verificationId;
          });
        },
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      setState(() {
        _isVerifying = false;
      });
      _showDialog(
        "Error",
        "An error occurred while sending the verification code. Please try again.",
      );
    }
  }
  
  // Verify OTP and register teacher
  Future<void> _verifyOtpAndRegister() async {
    if (otpController.text.trim().isEmpty) {
      _showDialog(
        "Verification Code Required",
        "Please enter the verification code sent to your mobile number.",
      );
      return;
    }
    
    setState(() {
      _isVerifying = true;
    });
    
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otpController.text.trim(),
      );
      
      // Verify the OTP is valid
      await FirebaseAuth.instance.signInWithCredential(credential);
      
      // OTP verified, now sign out and proceed with teacher registration
      await FirebaseAuth.instance.signOut();
      
      // Register teacher
      await _authService.signUpTeacher(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
        fullName: fullNameController.text.trim(),
        mobileNumber: mobileController.text.trim(),
        address: addressController.text.trim(),
      );

      // Navigate with slide animation
      if (mounted) {
        Navigator.of(context).push(_createRoute());
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isVerifying = false;
      });
      _showDialog(
        "Invalid Code",
        "The verification code you entered is incorrect. Please check and try again.",
      );
    } catch (e) {
      setState(() {
        _isVerifying = false;
      });
      _showDialog(
        "Registration Error",
        "An error occurred during registration. Please try again or contact support if the problem persists.",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
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
              buildTextField("Email", emailController, false),
              buildPasswordField("Password", passwordController),
              buildPasswordField("Confirm Password", confirmPasswordController),
              buildTextField("Mobile Number", mobileController, false),
              buildTextField("Full Name", fullNameController, false),
              buildMultilineTextField("Address", addressController),

              const SizedBox(height: 25),

              // OTP Field (shown after OTP is sent)
              if (_isOtpSent) ...[
                buildTextField("Enter OTP", otpController, false),
                const SizedBox(height: 10),
                // Resend OTP Button
                TextButton(
                  onPressed: _sendOtp,
                  child: Text(
                    "Resend OTP",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                    ),
                  ),
                ),
                const SizedBox(height: 15),
              ],

              // Send/Verify button
              SizedBox(
                width: 300,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isVerifying ? Colors.grey : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _isVerifying
                      ? null
                      : () async {
                          if (!_isOtpSent) {
                            // Send OTP
                            await _sendOtp();
                          } else {
                            // Verify OTP and register
                            await _verifyOtpAndRegister();
                          }
                        },
                  child: Text(
                    _isVerifying
                        ? "Processing..."
                        : (_isOtpSent ? "Verify & Register" : "Send OTP"),
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
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
class WaitingPage extends StatelessWidget {
  const WaitingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Waiting GIF
                SizedBox(
                  height: 200,
                  child: Image.asset(
                    "assets/others/wait.gif",
                    fit: BoxFit.contain,
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
            ),
          ),
        ),
      ),
    );
  }
}
