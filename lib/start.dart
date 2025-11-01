// ignore_for_file: deprecated_member_use, avoid_print, unnecessary_import

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui'; // needed for ImageFilter
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:animated_button/animated_button.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lexi_on_web/signup%20folder/student.dart';

class MyStart extends StatefulWidget {
  const MyStart({super.key});

  @override
  State<MyStart> createState() => _MyStartState();
}

class _MyStartState extends State<MyStart> with TickerProviderStateMixin {
  int _currentRatingIndex = 0;
  Timer? _ratingTimer;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late AnimationController _slideAnimationController;
  int? _selectedStarFilter; // null means show all, 1-5 means filter by that star rating
  
  // Hero carousel
  int _currentHeroIndex = 0;
  Timer? _heroTimer;
  late AnimationController _heroSlideController;
  late Animation<Offset> _heroSlideAnimation;
  final List<String> _heroImages = [
    'assets/blog/slide1.png',
    'assets/blog/slide2.png',
    'assets/blog/slide3.png',
    'assets/blog/slide4.png',
  ];
  
  @override
  void initState() {
    super.initState();
    _slideAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    // Start animation initially
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _slideAnimationController.forward();
    });
    
    // Initialize hero carousel animation
    _heroSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _heroSlideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _heroSlideController,
      curve: Curves.easeInOut,
    ));
    _heroSlideController.forward();
    
    // Auto-rotate hero images every 10 seconds
    _heroTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        _heroSlideController.reverse().then((_) {
          if (mounted) {
            setState(() {
              _currentHeroIndex = (_currentHeroIndex + 1) % _heroImages.length;
            });
            _heroSlideController.forward();
          }
        });
      }
    });
  }
  
  @override
  void dispose() {
    _ratingTimer?.cancel();
    _heroTimer?.cancel();
    _slideAnimationController.dispose();
    _heroSlideController.dispose();
    super.dispose();
  }
  
  Uint8List? _decodeBase64Image(String? base64String) {
    if (base64String == null || base64String.isEmpty) {
      return null;
    }
    try {
      String cleanBase64 = base64String;
      if (base64String.contains(',')) {
        cleanBase64 = base64String.split(',').last;
      }
      return base64Decode(cleanBase64);
    } catch (e) {
      return null;
    }
  }
  
  Widget _buildAvatar(String? profileImage, String username, {double radius = 20}) {
    final imageBytes = _decodeBase64Image(profileImage);
    
    // Get first letter of username for placeholder
    String getInitial() {
      if (username.isEmpty) return '?';
      return username[0].toUpperCase();
    }
    
    return CircleAvatar(
      backgroundColor: imageBytes != null ? Colors.white : Colors.blue.shade700,
      radius: radius,
      backgroundImage: imageBytes != null ? MemoryImage(imageBytes) : null,
      child: imageBytes == null
          ? Text(
              getInitial(),
              style: GoogleFonts.poppins(
                fontSize: radius * 0.8,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            )
          : null,
    );
  }
  
  Widget _buildHeroSection(double screenWidth) {
    final isSmallScreen = screenWidth < 600;
    final isMediumScreen = screenWidth >= 600 && screenWidth < 1024;
    final isLargeScreen = screenWidth >= 1024;
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 20 : (isMediumScreen ? 40 : 80),
        vertical: isSmallScreen ? 40 : (isMediumScreen ? 60 : 80),
      ),
      child: isSmallScreen
          ? Column(
              children: [
                // Image carousel
                _buildImageCarousel(screenWidth),
                const SizedBox(height: 40),
                // Text and button
                _buildHeroContent(screenWidth),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Text and button - Left side
                Expanded(
                  flex: isLargeScreen ? 5 : 4,
                  child: _buildHeroContent(screenWidth),
                ),
                SizedBox(width: isMediumScreen ? 40 : 80),
                // Image carousel - Right side
                Expanded(
                  flex: isLargeScreen ? 5 : 4,
                  child: _buildImageCarousel(screenWidth),
                ),
              ],
            ),
    );
  }
  
  Widget _buildImageCarousel(double screenWidth) {
    final isSmallScreen = screenWidth < 600;
    
    return SlideTransition(
      position: _heroSlideAnimation,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: isSmallScreen ? 300 : (screenWidth < 1024 ? 400 : 500),
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.lightGreenAccent.withOpacity(0.3),
              blurRadius: 30,
              spreadRadius: 5,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Image.asset(
            _heroImages[_currentHeroIndex],
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
  
  Widget _buildHeroContent(double screenWidth) {
    final isSmallScreen = screenWidth < 600;
    final isMediumScreen = screenWidth >= 600 && screenWidth < 1024;
    
    return Column(
      crossAxisAlignment: isSmallScreen ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Main Headline with gradient
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [
              Colors.lightGreenAccent,
              Colors.blue.shade300,
              Colors.purple.shade300,
            ],
          ).createShader(bounds),
          child: Text(
            'Lexi Boost',
            style: GoogleFonts.poppins(
              fontSize: isSmallScreen ? 48 : (isMediumScreen ? 64 : 80),
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.1,
              letterSpacing: -2,
            ),
            textAlign: isSmallScreen ? TextAlign.center : TextAlign.left,
          ),
        ),
        
        SizedBox(height: isSmallScreen ? 16 : 24),
        
        // Supporting text
        Container(
          constraints: BoxConstraints(
            maxWidth: isSmallScreen ? double.infinity : 500,
          ),
          child: Text(
            'Empower your child\'s learning journey with interactive lessons, engaging games, and personalized progress tracking—all in one app!',
            style: GoogleFonts.poppins(
              fontSize: isSmallScreen ? 16 : (isMediumScreen ? 18 : 20),
              fontWeight: FontWeight.w400,
              color: Colors.white.withOpacity(0.9),
              height: 1.6,
            ),
            textAlign: isSmallScreen ? TextAlign.center : TextAlign.left,
          ),
        ),
        
        SizedBox(height: isSmallScreen ? 32 : 40),
        
        // Download button
        AnimatedButton(
          width: isSmallScreen ? screenWidth * 0.8 : (isMediumScreen ? 250 : 280),
          height: isSmallScreen ? 56 : 64,
          color: Colors.lightGreenAccent,
          shadowDegree: ShadowDegree.light,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.download_rounded,
                color: Colors.black,
                size: isSmallScreen ? 24 : 28,
              ),
              const SizedBox(width: 12),
              Text(
                'Download the App',
                style: GoogleFonts.poppins(
                  fontSize: isSmallScreen ? 16 : 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MyStudent()),
            );
          },
        ),
        
        SizedBox(height: isSmallScreen ? 16 : 24),
        
        // Carousel indicators
        Row(
          mainAxisAlignment: isSmallScreen ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: List.generate(
            _heroImages.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _currentHeroIndex == index ? 32 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: _currentHeroIndex == index
                    ? Colors.lightGreenAccent
                    : Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildStarDistribution(List<QueryDocumentSnapshot> allRatings, double screenWidth) {
    // Calculate star distribution
    Map<int, int> starCounts = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    for (var doc in allRatings) {
      final data = doc.data() as Map<String, dynamic>;
      final rating = data['rating'] ?? 0;
      if (rating >= 1 && rating <= 5) {
        starCounts[rating] = (starCounts[rating] ?? 0) + 1;
      }
    }
    
    final totalRatings = allRatings.length;
    final isSmallScreen = screenWidth < 600;
    final isMediumScreen = screenWidth >= 600 && screenWidth < 1024;
    
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.lightGreenAccent.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Rating Distribution',
                style: GoogleFonts.poppins(
                  fontSize: isSmallScreen ? 14 : (isMediumScreen ? 16 : 18),
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              if (_selectedStarFilter != null)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedStarFilter = null;
                      _currentRatingIndex = 0;
                      _ratingTimer?.cancel();
                      _ratingTimer = null;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.lightGreenAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.lightGreenAccent.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Clear Filter',
                          style: GoogleFonts.poppins(
                            fontSize: isSmallScreen ? 10 : 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.lightGreenAccent,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.clear,
                          size: isSmallScreen ? 12 : 14,
                          color: Colors.lightGreenAccent,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 8 : 12),
          // Star progress bars
          ...List.generate(5, (index) {
            final starRating = 5 - index; // 5, 4, 3, 2, 1
            final count = starCounts[starRating] ?? 0;
            final percentage = totalRatings > 0 ? (count / totalRatings * 100) : 0.0;
            final isSelected = _selectedStarFilter == starRating;
            final isEmpty = count == 0;
            
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (_selectedStarFilter == starRating) {
                    _selectedStarFilter = null;
                  } else {
                    _selectedStarFilter = starRating;
                  }
                  _currentRatingIndex = 0;
                  _ratingTimer?.cancel();
                  _ratingTimer = null;
                });
              },
              child: Container(
                margin: EdgeInsets.only(bottom: isSmallScreen ? 6 : 8),
                padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? (isEmpty 
                          ? Colors.red.withOpacity(0.15)
                          : Colors.lightGreenAccent.withOpacity(0.1))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: isSelected 
                      ? Border.all(
                          color: isEmpty 
                              ? Colors.red.withOpacity(0.7)
                              : Colors.lightGreenAccent.withOpacity(0.5),
                          width: 2,
                        )
                      : null,
                ),
                child: Row(
                  children: [
                    // Star rating display
                    SizedBox(
                      width: isSmallScreen ? 50 : (isMediumScreen ? 60 : 70),
                      child: Row(
                        children: [
                          Text(
                            '$starRating',
                            style: GoogleFonts.poppins(
                              fontSize: isSmallScreen ? 12 : (isMediumScreen ? 13 : 14),
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.star_rounded,
                            color: Colors.amber,
                            size: isSmallScreen ? 14 : (isMediumScreen ? 16 : 18),
                          ),
                        ],
                      ),
                    ),
                    // Progress bar
                    Expanded(
                      child: Stack(
                        children: [
                          Container(
                            height: isSmallScreen ? 16 : (isMediumScreen ? 18 : 20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: percentage / 100,
                            child: Container(
                              height: isSmallScreen ? 16 : (isMediumScreen ? 18 : 20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.amber.shade600,
                                    Colors.amber.shade400,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.amber.withOpacity(0.3),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 8 : 12),
                    // Percentage and count
                    SizedBox(
                      width: isSmallScreen ? 60 : (isMediumScreen ? 70 : 80),
                      child: Text(
                        '${percentage.toStringAsFixed(0)}% ($count)',
                        style: GoogleFonts.poppins(
                          fontSize: isSmallScreen ? 10 : (isMediumScreen ? 11 : 12),
                          fontWeight: FontWeight.w500,
                          color: Colors.white70,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobileAppBar = screenWidth < 768;
    
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    "assets/logo/LEXIBOOST.png",
                    scale: isMobileAppBar ? 6 : 5,
                  ),
                  const Spacer(),

                  // 🔹 Sign In Button
                  AnimatedButton(
                    width: isMobileAppBar ? 50 : 60,
                    color: Colors.white,
                    child: Text(
                      "Sign In",
                      style: GoogleFonts.poppins(
                        fontSize: isMobileAppBar ? 10 : 12,
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

                  SizedBox(width: isMobileAppBar ? 8 : 10),

                  // 🔹 Create Account Button
                  AnimatedButton(
                    width: isMobileAppBar ? 50 : 60,
                    color: Colors.lightGreenAccent,
                    child: Text(
                      "Create",
                      style: GoogleFonts.poppins(
                        fontSize: isMobileAppBar ? 10 : 12,
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

      body: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.mouse,
            PointerDeviceKind.touch,
            PointerDeviceKind.stylus,
            PointerDeviceKind.trackpad,
          },
        ),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            children: [
              // Big gap from appbar
              SizedBox(height: screenWidth < 600 ? 40 : (screenWidth < 1024 ? 60 : 80)),
              
              // Hero Section
              _buildHeroSection(screenWidth),
              
              // Add spacing before footer
              SizedBox(height: screenWidth < 600 ? 60 : 80),
              
              // Footer with app ratings
              Container(
              padding: EdgeInsets.symmetric(
                vertical: screenWidth < 600 ? 16 : 24,
                horizontal: screenWidth < 600 ? 12 : 24,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF1E201E).withOpacity(0.85),
                    const Color(0xFF2D3436).withOpacity(0.95),
                  ],
                ),
                border: Border(
                  top: BorderSide(
                    color: Colors.lightGreenAccent.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('app_ratings')
                    .orderBy('timestamp', descending: true)
                    .limit(50)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(
                      child: Text(
                        "No ratings Yet",
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: screenWidth < 600 ? 14 : 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }
                  
                  if (snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Text(
                        "No ratings Yet",
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: screenWidth < 600 ? 14 : 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }
                  
                  final allRatings = snapshot.data!.docs;
                  
                  // Filter ratings based on selected star
                  final ratings = _selectedStarFilter == null
                      ? allRatings
                      : allRatings.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final rating = data['rating'] ?? 0;
                          return rating == _selectedStarFilter;
                        }).toList();
                  
                  // Set up timer to rotate ratings every 30 seconds
                  if (ratings.isNotEmpty && (_ratingTimer == null || !_ratingTimer!.isActive)) {
                    _ratingTimer?.cancel();
                    _ratingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
                      if (mounted && ratings.isNotEmpty) {
                        _slideAnimationController.reverse().then((_) {
                          if (mounted && ratings.isNotEmpty) {
                            setState(() {
                              _currentRatingIndex = (_currentRatingIndex + 1) % ratings.length;
                            });
                            _slideAnimationController.forward();
                          }
                        });
                      }
                    });
                  }
                  
                  // Ensure index is valid and ratings list is not empty
                  if (ratings.isEmpty) {
                    // This shouldn't happen normally as we handle it below, but safety check
                    _currentRatingIndex = 0;
                  } else if (_currentRatingIndex >= ratings.length) {
                    _currentRatingIndex = 0;
                  }
                  
                  // Only get rating data if ratings list is not empty
                  String username = 'Anonymous';
                  int rating = 0;
                  String? profileImage;
                  String comment = '';
                  Timestamp? timestamp;
                  
                  if (ratings.isNotEmpty) {
                    final currentRating = ratings[_currentRatingIndex].data() as Map<String, dynamic>;
                    username = currentRating['username'] ?? 'Anonymous';
                    rating = currentRating['rating'] ?? 0;
                    profileImage = currentRating['profileImage'];
                    comment = currentRating['comment'] ?? '';
                    timestamp = currentRating['timestamp'] as Timestamp?;
                  }
                  
                  // Format timestamp
                  String timeAgo = 'Just now';
                  if (ratings.isNotEmpty && timestamp != null) {
                    final now = DateTime.now();
                    final difference = now.difference(timestamp.toDate());
                    
                    if (difference.inDays > 365) {
                      timeAgo = '${(difference.inDays / 365).floor()} year${(difference.inDays / 365).floor() > 1 ? 's' : ''} ago';
                    } else if (difference.inDays > 30) {
                      timeAgo = '${(difference.inDays / 30).floor()} month${(difference.inDays / 30).floor() > 1 ? 's' : ''} ago';
                    } else if (difference.inDays > 0) {
                      timeAgo = '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
                    } else if (difference.inHours > 0) {
                      timeAgo = '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
                    } else if (difference.inMinutes > 0) {
                      timeAgo = '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
                    }
                  }
                  
                  final isSmallScreen = screenWidth < 600;
                  final isMediumScreen = screenWidth >= 600 && screenWidth < 1024;
                  
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Star distribution at the top
                      _buildStarDistribution(allRatings, screenWidth),
                      
                      SizedBox(height: screenWidth < 600 ? 16 : 20),
                      
                      // Show message if no ratings match the filter
                      if (_selectedStarFilter != null && ratings.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.red.withOpacity(0.5),
                                  width: 2,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    color: Colors.red.shade300,
                                    size: screenWidth < 600 ? 20 : 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Flexible(
                                    child: Text(
                                      'There are no ratings on that area yet',
                                      style: GoogleFonts.poppins(
                                        color: Colors.red.shade300,
                                        fontSize: screenWidth < 600 ? 14 : 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else if (ratings.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Text(
                              "No ratings Yet",
                              style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontSize: screenWidth < 600 ? 14 : 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        )
                      else if (ratings.isNotEmpty)
                        SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(1.0, 0.0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: _slideAnimationController,
                      curve: Curves.easeInOut,
                    )),
                    child: FadeTransition(
                      opacity: _slideAnimationController,
                      child: Center(
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: isSmallScreen ? screenWidth * 0.95 : 800,
                          ),
                          padding: EdgeInsets.all(isSmallScreen ? 12 : 20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.lightGreenAccent.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: isSmallScreen
                              ? Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // User info row
                                    Row(
                                      children: [
                                        _buildAvatar(profileImage, username, radius: 20),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                username,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                timeAgo,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 10,
                                                  color: Colors.white60,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Row(
                                          children: List.generate(5, (index) {
                                            return Icon(
                                              index < rating
                                                  ? Icons.star_rounded
                                                  : Icons.star_border_rounded,
                                              color: Colors.amber,
                                              size: 14,
                                            );
                                          }),
                                        ),
                                      ],
                                    ),
                                    if (comment.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          comment,
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: Colors.white70,
                                            height: 1.4,
                                          ),
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ],
                                )
                              : Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildAvatar(profileImage, username, radius: isMediumScreen ? 28 : 32),
                                    SizedBox(width: isMediumScreen ? 14 : 18),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  username,
                                                  style: GoogleFonts.poppins(
                                                    fontSize: isMediumScreen ? 16 : 18,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.white,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Row(
                                                children: List.generate(5, (index) {
                                                  return Icon(
                                                    index < rating
                                                        ? Icons.star_rounded
                                                        : Icons.star_border_rounded,
                                                    color: Colors.amber,
                                                    size: isMediumScreen ? 18 : 20,
                                                  );
                                                }),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            timeAgo,
                                            style: GoogleFonts.poppins(
                                              fontSize: isMediumScreen ? 11 : 12,
                                              color: Colors.white60,
                                            ),
                                          ),
                                          if (comment.isNotEmpty) ...[
                                            const SizedBox(height: 10),
                                            Container(
                                              width: double.infinity,
                                              padding: EdgeInsets.all(isMediumScreen ? 10 : 12),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                comment,
                                                style: GoogleFonts.poppins(
                                                  fontSize: isMediumScreen ? 13 : 14,
                                                  color: Colors.white70,
                                                  height: 1.5,
                                                ),
                                                maxLines: 3,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                        ),
                    ],
                  );
                },
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}
