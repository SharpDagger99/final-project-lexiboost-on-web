// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:animated_button/animated_button.dart';
import 'package:lexi_on_web/utils/ban_check.dart';

class MyNotification2 extends StatefulWidget {
  const MyNotification2({super.key});

  @override
  State<MyNotification2> createState() => _MyNotification2State();
}

class _MyNotification2State extends State<MyNotification2> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _showHidden = false;

  @override
  void initState() {
    super.initState();
    // Start ban monitoring
    WidgetsBinding.instance.addPostFrameCallback((_) {
      BanCheckService().startBanMonitoring(context);
    });
  }

  @override
  void dispose() {
    BanCheckService().stopBanMonitoring();
    super.dispose();
  }

  // Mark notification as read
  Future<void> _markAsRead(String notificationId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  // Delete notification
  Future<void> _deleteNotification(String notificationId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('notifications')
          .doc(notificationId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notification deleted'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('Error deleting notification: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete notification: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Mark all as read
  Future<void> _markAllAsRead() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      final unreadNotifications = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .get();

      for (var doc in unreadNotifications.docs) {
        await doc.reference.update({'read': true});
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All notifications marked as read'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('Error marking all as read: $e');
    }
  }

  // Pin/Unpin notification
  Future<void> _togglePin(String notificationId, bool currentPinStatus) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('notifications')
          .doc(notificationId)
          .update({'pinned': !currentPinStatus});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !currentPinStatus ? 'Notification pinned' : 'Notification unpinned',
          ),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('Error toggling pin: $e');
    }
  }

  // Unhide notification
  Future<void> _unhideNotification(String notificationId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('notifications')
          .doc(notificationId)
          .update({'hidden': false});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notification restored'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('Error unhiding notification: $e');
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Just now';

    final now = DateTime.now();
    final date = timestamp.toDate();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      return const Center(
        child: Text(
          'Please login to view notifications',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      );
    }

    return Container(
      color: const Color(0xFF1E201E),
      child: Column(
        children: [
          // Header with actions
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white.withOpacity(0.05),
            child: Row(
              children: [
                Text(
                  'Notifications',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                // Toggle hidden notifications button
                IconButton(
                  onPressed: () {
                    setState(() {
                      _showHidden = !_showHidden;
                    });
                  },
                  icon: Icon(
                    _showHidden ? Icons.visibility : Icons.visibility_off,
                    color: Colors.white,
                  ),
                  tooltip: _showHidden ? 'Hide hidden' : 'Show hidden',
                ),
                StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('users')
                      .doc(currentUser.uid)
                      .collection('notifications')
                      .where('read', isEqualTo: false)
                      .snapshots(),
                  builder: (context, snapshot) {
                    final unreadCount =
                        snapshot.hasData ? snapshot.data!.docs.length : 0;

                    if (unreadCount > 0) {
                      return TextButton.icon(
                        onPressed: _markAllAsRead,
                        icon: const Icon(
                          Icons.done_all,
                          color: Colors.white,
                          size: 18,
                        ),
                        label: Text(
                          'Mark all read',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),

          // Notifications list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('users')
                  .doc(currentUser.uid)
                  .collection('notifications')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading notifications',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_none,
                          size: 100,
                          color: Colors.white.withOpacity(0.3),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'No notifications',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Filter notifications based on hidden status
                final allNotifications = snapshot.data!.docs;
                final notifications = allNotifications.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final isHidden = data['hidden'] ?? false;
                  return _showHidden ? isHidden : !isHidden;
                }).toList();

                // Sort notifications: pinned first, then by timestamp
                notifications.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;

                  final aPinned = aData['pinned'] ?? false;
                  final bPinned = bData['pinned'] ?? false;

                  if (aPinned != bPinned) {
                    return bPinned ? 1 : -1;
                  }

                  final aTimestamp = aData['timestamp'] as Timestamp?;
                  final bTimestamp = bData['timestamp'] as Timestamp?;

                  if (aTimestamp == null && bTimestamp == null) return 0;
                  if (aTimestamp == null) return 1;
                  if (bTimestamp == null) return -1;

                  return bTimestamp.compareTo(aTimestamp);
                });

                if (notifications.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _showHidden
                              ? Icons.visibility_off
                              : Icons.notifications_none,
                          size: 100,
                          color: Colors.white.withOpacity(0.3),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _showHidden
                              ? 'No hidden notifications'
                              : 'No notifications',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    final data = notification.data() as Map<String, dynamic>;

                    final title = data['title'] ?? 'Notification';
                    final message = data['message'] ?? '';
                    final fromName = data['fromName'] ?? 'Unknown';
                    final timestamp = data['timestamp'] as Timestamp?;
                    final isRead = data['read'] ?? false;
                    final isPinned = data['pinned'] ?? false;
                    final type = data['type'] ?? 'message';
                    final isHidden = data['hidden'] ?? false;

                    return GestureDetector(
                      onTap: () {
                        if (!isRead) {
                          _markAsRead(notification.id);
                        }
                        // Show full message dialog
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            backgroundColor: const Color(0xFF2C2F2C),
                            title: Text(
                              title,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'From: $fromName',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  message,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _formatTimestamp(timestamp),
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.white54,
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text(
                                  'Close',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: isRead
                              ? const Color(0xFF2C2F2C)
                              : Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isPinned
                                ? Colors.amber
                                : (isRead
                                    ? Colors.white.withOpacity(0.1)
                                    : Colors.blue.withOpacity(0.3)),
                            width: isPinned ? 2.5 : (isRead ? 1 : 2),
                          ),
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Icon
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: type == 'message'
                                          ? Colors.blue.withOpacity(0.2)
                                          : type == 'teacher_accepted'
                                              ? Colors.green.withOpacity(0.2)
                                              : type == 'student_removed'
                                                  ? Colors.red.withOpacity(0.2)
                                                  : Colors.orange.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      type == 'message'
                                          ? Icons.message
                                          : type == 'teacher_accepted'
                                              ? Icons.check_circle
                                              : type == 'student_removed'
                                                  ? Icons.person_remove
                                                  : type == 'game_hidden' || type == 'game_removed'
                                                      ? Icons.visibility_off
                                                      : type == 'game_restored'
                                                          ? Icons.restore
                                                          : Icons.notifications,
                                      color: type == 'message'
                                          ? Colors.blue
                                          : type == 'teacher_accepted'
                                              ? Colors.green
                                              : type == 'student_removed'
                                                  ? Colors.red
                                                  : type == 'game_hidden' || type == 'game_removed'
                                                      ? Colors.orange
                                                      : type == 'game_restored'
                                                          ? Colors.green
                                                          : Colors.orange,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Content
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                title,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 14,
                                                  fontWeight: isRead
                                                      ? FontWeight.w600
                                                      : FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (!isRead)
                                              Container(
                                                width: 8,
                                                height: 8,
                                                decoration: const BoxDecoration(
                                                  color: Colors.blue,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          message,
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: Colors.white70,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          _formatTimestamp(timestamp),
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            color: Colors.white54,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Action buttons row
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.2),
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(12),
                                  bottomRight: Radius.circular(12),
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // Mark as read/unread button
                                  AnimatedButton(
                                    width: 70,
                                    height: 32,
                                    color: isRead
                                        ? Colors.blue.withOpacity(0.2)
                                        : Colors.green.withOpacity(0.2),
                                    shadowDegree: ShadowDegree.light,
                                    onPressed: () {
                                      if (!isRead) {
                                        _markAsRead(notification.id);
                                      } else {
                                        _firestore
                                            .collection('users')
                                            .doc(currentUser.uid)
                                            .collection('notifications')
                                            .doc(notification.id)
                                            .update({'read': false});
                                      }
                                    },
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          isRead
                                              ? Icons.mark_email_unread
                                              : Icons.check,
                                          size: 14,
                                          color: isRead
                                              ? Colors.blue
                                              : Colors.green,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          isRead ? 'Unread' : 'Read',
                                          style: GoogleFonts.poppins(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: isRead
                                                ? Colors.blue
                                                : Colors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Pin button
                                  AnimatedButton(
                                    width: 60,
                                    height: 32,
                                    color: isPinned
                                        ? Colors.amber.withOpacity(0.2)
                                        : Colors.white.withOpacity(0.1),
                                    shadowDegree: ShadowDegree.light,
                                    onPressed: () {
                                      _togglePin(notification.id, isPinned);
                                    },
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          isPinned
                                              ? Icons.push_pin
                                              : Icons.push_pin_outlined,
                                          size: 14,
                                          color: isPinned
                                              ? Colors.amber
                                              : Colors.white70,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Pin',
                                          style: GoogleFonts.poppins(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: isPinned
                                                ? Colors.amber
                                                : Colors.white70,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Hide/Unhide or Delete button
                                  AnimatedButton(
                                    width: 70,
                                    height: 32,
                                    color: isHidden
                                        ? Colors.green.withOpacity(0.2)
                                        : Colors.red.withOpacity(0.2),
                                    shadowDegree: ShadowDegree.light,
                                    onPressed: () {
                                      if (isHidden) {
                                        _unhideNotification(notification.id);
                                      } else {
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            backgroundColor:
                                                const Color(0xFF2C2F2C),
                                            title: Text(
                                              'Delete Notification',
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                            content: Text(
                                              'Are you sure you want to delete this notification?',
                                              style: GoogleFonts.poppins(
                                                fontSize: 14,
                                                color: Colors.white70,
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                child: Text(
                                                  'Cancel',
                                                  style: GoogleFonts.poppins(
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.white70,
                                                  ),
                                                ),
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  Navigator.pop(context);
                                                  _deleteNotification(
                                                    notification.id,
                                                  );
                                                },
                                                child: Text(
                                                  'Delete',
                                                  style: GoogleFonts.poppins(
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.red,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                    },
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          isHidden
                                              ? Icons.visibility
                                              : Icons.delete_outline,
                                          size: 14,
                                          color: isHidden
                                              ? Colors.green
                                              : Colors.red,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          isHidden ? 'Unhide' : 'Delete',
                                          style: GoogleFonts.poppins(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: isHidden
                                                ? Colors.green
                                                : Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
