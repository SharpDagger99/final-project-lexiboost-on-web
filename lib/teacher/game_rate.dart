// ignore_for_file: use_build_context_synchronously, deprecated_member_use, avoid_print

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

class MyGameRate extends StatefulWidget {
  const MyGameRate({super.key});

  @override
  State<MyGameRate> createState() => _MyGameRateState();
}

class _MyGameRateState extends State<MyGameRate> {
  final User? user = FirebaseAuth.instance.currentUser;
  String? gameId;
  String? gameTitle;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get arguments from either Get routing or standard Navigator
    final getArgs = Get.arguments as Map<String, dynamic>?;
    final modalRoute = ModalRoute.of(context);
    final routeArgs = modalRoute?.settings.arguments as Map<String, dynamic>?;
    
    // Try Get arguments first, then route arguments
    final args = getArgs ?? routeArgs;
    
    if (gameId == null) {
      gameId = args?['gameId'];
      gameTitle = args?['title'] ?? 'Game Reviews';
      
      print('MyGameRate initialized with gameId: $gameId, title: $gameTitle');
      print('Arguments source: ${getArgs != null ? "Get.arguments" : "RouteSettings"}');
    }
  }

  /// Toggle heart on a review
  Future<void> _toggleHeart(String reviewId, bool isCurrentlyHearted) async {
    if (user == null || gameId == null) return;

    try {
      final reviewRef = FirebaseFirestore.instance
          .collection('rate')
          .doc(reviewId);

      if (isCurrentlyHearted) {
        // Remove heart
        await reviewRef.update({
          'hearts': FieldValue.arrayRemove([user!.uid]),
        });
      } else {
        // Add heart
        await reviewRef.update({
          'hearts': FieldValue.arrayUnion([user!.uid]),
        });
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to update heart: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// Delete a review (only for teacher who owns the game)
  Future<void> _deleteReview(String reviewId) async {
    try {
      await FirebaseFirestore.instance
          .collection('rate')
          .doc(reviewId)
          .delete();
      
      Get.snackbar(
        'Success',
        'Review deleted successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to delete review: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// Show delete confirmation dialog
  Future<void> _showDeleteDialog(String reviewId, String username) async {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2C2F33),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.orangeAccent),
            const SizedBox(width: 8),
            Text(
              "Delete Review",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        content: Text(
          "Are you sure you want to delete the review from $username?",
          style: GoogleFonts.poppins(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              "Cancel",
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _deleteReview(reviewId);
            },
            child: Text(
              "Delete",
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  /// Format timestamp
  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    try {
      DateTime date;
      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else if (timestamp is String) {
        date = DateTime.parse(timestamp);
      } else {
        return 'Unknown';
      }
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 7) {
        return '${date.day}/${date.month}/${date.year}';
      } else if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  /// Build rating stars
  Widget _buildStars(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < rating.floor()) {
          return const Icon(Icons.star, color: Colors.amber, size: 18);
        } else if (index < rating && rating - index >= 0.5) {
          return const Icon(Icons.star_half, color: Colors.amber, size: 18);
        } else {
          return Icon(Icons.star_border, color: Colors.amber.shade200, size: 18);
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (gameId == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF1E201E),
        appBar: AppBar(
          backgroundColor: Colors.white.withOpacity(0.05),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            "Reviews",
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 80, color: Colors.red),
              const SizedBox(height: 20),
              Text(
                "No game ID provided",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1E201E),
      appBar: AppBar(
        backgroundColor: Colors.white.withOpacity(0.05),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              gameTitle ?? 'Game Reviews',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              'Reviews & Ratings',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.white60,
              ),
            ),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('rate')
            .where('gameId', isEqualTo: gameId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 80, color: Colors.red),
                  const SizedBox(height: 20),
                  Text(
                    "Error loading reviews",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "${snapshot.error}",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.rate_review_outlined,
                    size: 80,
                    color: Colors.white30,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "No reviews yet",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Reviews from players will appear here",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            );
          }

          // Sort reviews by timestamp (client-side sorting)
          final reviews = snapshot.data!.docs.toList();
          reviews.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTime = aData['timestamp'] as Timestamp?;
            final bTime = bData['timestamp'] as Timestamp?;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime); // Descending order
          });
          
          // Calculate statistics
          double totalRating = 0;
          for (var review in reviews) {
            final data = review.data() as Map<String, dynamic>?;
            totalRating += (data?['rating'] ?? 0).toDouble();
          }
          double avgRating = reviews.isEmpty ? 0 : totalRating / reviews.length;

          return Column(
            children: [
              // Statistics Header
              Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade700, Colors.purple.shade500],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text(
                          avgRating.toStringAsFixed(1),
                          style: GoogleFonts.poppins(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        _buildStars(avgRating),
                        const SizedBox(height: 4),
                        Text(
                          'Average Rating',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 1,
                      height: 60,
                      color: Colors.white24,
                    ),
                    Column(
                      children: [
                        Text(
                          '${reviews.length}',
                          style: GoogleFonts.poppins(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Total Reviews',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Reviews List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: reviews.length,
                  itemBuilder: (context, index) {
                    final review = reviews[index];
                    final reviewData = review.data() as Map<String, dynamic>?;
                    final reviewId = review.id;
                    final username = reviewData?['username'] ?? 'Anonymous';
                    final profileImage = reviewData?['profileImage'];
                    final rating = (reviewData?['rating'] ?? 0).toDouble();
                    final comment = reviewData?['comment'] ?? '';
                    final timestamp = reviewData?['timestamp'];
                    final hearts = List<String>.from(reviewData?['hearts'] ?? []);
                    final isHearted = user != null && hearts.contains(user!.uid);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // User Info Row
                          Row(
                            children: [
                              // Profile Picture
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.purple,
                                backgroundImage: profileImage != null &&
                                        profileImage.toString().isNotEmpty
                                    ? MemoryImage(base64Decode(profileImage))
                                    : null,
                                child: profileImage == null ||
                                        profileImage.toString().isEmpty
                                    ? Text(
                                        username[0].toUpperCase(),
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 12),

                              // Username and Date
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      username,
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      _formatDate(timestamp),
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.white54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Rating Stars
                              _buildStars(rating),

                              const SizedBox(width: 8),

                              // Delete Button (for teacher)
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                onPressed: () => _showDeleteDialog(reviewId, username),
                                tooltip: 'Delete review',
                              ),
                            ],
                          ),

                          // Comment
                          if (comment.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              comment,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.white70,
                                height: 1.5,
                              ),
                            ),
                          ],

                          const SizedBox(height: 12),

                          // Heart Button
                          Row(
                            children: [
                              InkWell(
                                onTap: () => _toggleHeart(reviewId, isHearted),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isHearted
                                        ? Colors.red.withOpacity(0.2)
                                        : Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isHearted
                                          ? Colors.red
                                          : Colors.white24,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isHearted
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        color: isHearted
                                            ? Colors.red
                                            : Colors.white60,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${hearts.length}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: isHearted
                                              ? Colors.red
                                              : Colors.white60,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
