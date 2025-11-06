// ignore_for_file: deprecated_member_use, sort_child_properties_last

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animated_button/animated_button.dart';
import 'package:url_launcher/url_launcher.dart';

class MyStudent extends StatefulWidget {
  const MyStudent({super.key});

  @override
  State<MyStudent> createState() => _MyStudentState();
}

class _MyStudentState extends State<MyStudent> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }
  
  Future<void> _downloadApp() async {
    const url = 'https://drive.google.com/uc?export=download&id=1VLTunOGQHgC5qU9UqrFNdFYS1EVX-iDR';
    final uri = Uri.parse(url);
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not open download link',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    final isMediumScreen = screenWidth >= 600 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;
    
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E0E0E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Download LexiBoost',
          style: GoogleFonts.poppins(
            fontSize: isSmallScreen ? 18 : 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.mouse,
            PointerDeviceKind.touch,
            PointerDeviceKind.stylus,
            PointerDeviceKind.trackpad,
          },
        ),
        child: isDesktop
            ? _buildDesktopLayout(screenWidth)
            : Center(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.only(
                    top: 200,
                    left: isSmallScreen ? 24 : (isMediumScreen ? 40 : 60),
                    right: isSmallScreen ? 24 : (isMediumScreen ? 40 : 60),
                    bottom: isSmallScreen ? 20 : 40,
                  ),
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: isSmallScreen ? double.infinity : 600,
                    ),
                    child: _buildMobileLayout(screenWidth, isSmallScreen, isMediumScreen),
                  ),
                ),
              ),
      ),
    );
  }
  
  Widget _buildDesktopLayout(double screenWidth) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.only(top: 150, left: 80, right: 80, bottom: 60),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left side - Content
              Expanded(
                flex: 5,
                child: _buildDesktopContent(),
              ),
              const SizedBox(width: 60),
              // Right side - QR Code and Download
              Expanded(
                flex: 4,
                child: _buildDesktopQRAndButton(),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildDesktopContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Icon with gradient background
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.lightGreenAccent.withOpacity(0.2),
                Colors.blue.withOpacity(0.2),
              ],
            ),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.phone_android_rounded,
            size: 100,
            color: Colors.lightGreenAccent,
          ),
        ),
        
        const SizedBox(height: 40),
        
        // Main heading
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [
              Colors.lightGreenAccent,
              Colors.blue.shade300,
            ],
          ).createShader(bounds),
          child: Text(
            'Mobile App Required',
            style: GoogleFonts.poppins(
              fontSize: 52,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
            textAlign: TextAlign.left,
          ),
        ),
        
        const SizedBox(height: 32),
        
        // Information text
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.lightGreenAccent.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: Colors.lightGreenAccent,
                    size: 48,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Students cannot sign up or log in through the website',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Please download the LexiBoost mobile app from the QR code or download button on your phone to access your student account and start learning!',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withOpacity(0.8),
                  height: 1.7,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 40),
        
        // Additional info
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.blue.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.security_rounded,
                color: Colors.blue.shade300,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Safe & secure download',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.blue.shade300,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildDesktopQRAndButton() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // QR Code section
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: child,
            );
          },
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.lightGreenAccent.withOpacity(0.4),
                  blurRadius: 40,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Image.asset(
                    'assets/logo/qr_code.png',
                    width: 320,
                    height: 320,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Scan QR Code',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Use your phone camera to scan',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 40),
        
        // Download button
        AnimatedButton(
          width: 420,
          height: 80,
          color: Colors.lightGreenAccent,
          shadowDegree: ShadowDegree.dark,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.download_rounded,
                color: Colors.black,
                size: 36,
              ),
              const SizedBox(width: 16),
              Text(
                'Download App Now',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          onPressed: _downloadApp,
        ),
      ],
    );
  }
  
  Widget _buildMobileLayout(double screenWidth, bool isSmallScreen, bool isMediumScreen) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
                // Icon with gradient background
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.lightGreenAccent.withOpacity(0.2),
                        Colors.blue.withOpacity(0.2),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.phone_android_rounded,
                    size: isSmallScreen ? 60 : 80,
                    color: Colors.lightGreenAccent,
                  ),
                ),
                
                SizedBox(height: isSmallScreen ? 24 : 32),
                
                // Main heading
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [
                      Colors.lightGreenAccent,
                      Colors.blue.shade300,
                    ],
                  ).createShader(bounds),
                  child: Text(
                    'Mobile App Required',
                    style: GoogleFonts.poppins(
                      fontSize: isSmallScreen ? 28 : (isMediumScreen ? 36 : 42),
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                
                SizedBox(height: isSmallScreen ? 16 : 24),
                
                // Information text
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.lightGreenAccent.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: Colors.lightGreenAccent,
                        size: isSmallScreen ? 32 : 40,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Students cannot sign up or log in through the website',
                        style: GoogleFonts.poppins(
                          fontSize: isSmallScreen ? 16 : 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please download the LexiBoost mobile app to access your student account and start learning!',
                        style: GoogleFonts.poppins(
                          fontSize: isSmallScreen ? 14 : 16,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withOpacity(0.8),
                          height: 1.6,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: isSmallScreen ? 32 : 48),
                
                // QR Code section
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: child,
                    );
                  },
                  child: Container(
                    padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.lightGreenAccent.withOpacity(0.4),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Image.asset(
                            'assets/logo/qr_code.png',
                            width: isSmallScreen ? 200 : (isMediumScreen ? 250 : 280),
                            height: isSmallScreen ? 200 : (isMediumScreen ? 250 : 280),
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Scan QR Code',
                          style: GoogleFonts.poppins(
                            fontSize: isSmallScreen ? 16 : 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Use your phone camera to scan',
                          style: GoogleFonts.poppins(
                            fontSize: isSmallScreen ? 12 : 14,
                            fontWeight: FontWeight.w400,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                SizedBox(height: isSmallScreen ? 32 : 40),
                
                // Divider with text
                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: Colors.white.withOpacity(0.2),
                        thickness: 1,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'OR',
                        style: GoogleFonts.poppins(
                          fontSize: isSmallScreen ? 14 : 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.6),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: Colors.white.withOpacity(0.2),
                        thickness: 1,
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: isSmallScreen ? 32 : 40),
                
                // Download button
                AnimatedButton(
                  width: isSmallScreen ? screenWidth * 0.85 : (isMediumScreen ? 350 : 400),
                  height: isSmallScreen ? 60 : 70,
                  color: Colors.lightGreenAccent,
                  shadowDegree: ShadowDegree.dark,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.download_rounded,
                        color: Colors.black,
                        size: isSmallScreen ? 28 : 32,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Download App Now',
                        style: GoogleFonts.poppins(
                          fontSize: isSmallScreen ? 18 : 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  onPressed: _downloadApp,
                ),
                
                SizedBox(height: isSmallScreen ? 16 : 24),
                
                // Additional info
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.security_rounded,
                        color: Colors.blue.shade300,
                        size: isSmallScreen ? 18 : 20,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Safe & secure download',
                          style: GoogleFonts.poppins(
                            fontSize: isSmallScreen ? 12 : 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.blue.shade300,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
        
        SizedBox(height: isSmallScreen ? 20 : 24),
      ],
    );
  }
}