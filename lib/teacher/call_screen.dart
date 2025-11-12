// ignore_for_file: avoid_print, deprecated_member_use, curly_braces_in_flow_control_structures, unnecessary_to_list_in_spreads, unused_local_variable

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';

class CallScreen extends StatefulWidget {
  final String channelName;
  final RtcEngine engine;
  final bool localUserJoined;
  final int? remoteUid;
  final String vcId;

  const CallScreen({
    super.key,
    required this.channelName,
    required this.engine,
    required this.vcId,
    required this.localUserJoined,
    this.remoteUid,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  bool _muted = false;
  bool _cameraOff = false;
  bool _cameraAvailable = true;
  final Set<int> _remoteUsers = {}; // Track multiple remote users
  final Map<int, Map<String, dynamic>> _userProfiles = {}; // Cache user profile data
  final Set<int> _speakingUsers = {}; // Track currently speaking users
  String? _teacherProfileImage;
  bool _callEnded = false;
  bool _showChat = false;
  int _participantCount = 1; // Start with 1 (self)
  final TextEditingController _chatController = TextEditingController();
  late StreamSubscription<DocumentSnapshot> _callStatusStream;
  late StreamSubscription<QuerySnapshot> _handsRaisedStream;
  StreamSubscription<QuerySnapshot>? _chatMessagesStream;
  List<Map<String, dynamic>> _raisedHands = [];

  @override
  void initState() {
    super.initState();
    _setupAgoraEventHandlers();
    _listenForCallStatusChanges();
    _listenForRaisedHands();
    _checkCameraAvailability();
    _loadTeacherProfile();

    // Initialize with provided remote UID if exists
    if (widget.remoteUid != null) {
      _remoteUsers.add(widget.remoteUid!);
      _loadUserProfile(widget.remoteUid!);
      _participantCount = 2; // Self + remote user
    }
    
    _updateParticipantCount(_participantCount);

    print("CallScreen initialized with ${_remoteUsers.length} remote user(s)");
  }

  // Load teacher profile
  Future<void> _loadTeacherProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        setState(() {
          _teacherProfileImage = userDoc.data()?['profileImage'];
        });
      }
    } catch (e) {
      print('Error loading teacher profile: $e');
    }
  }

  // Load user profile from Firestore (for students)
  Future<void> _loadUserProfile(int uid) async {
    try {
      // Get students from the class
      final callDoc = await FirebaseFirestore.instance
          .collection('VideoCalls')
          .doc(widget.vcId)
          .get();
      
      if (callDoc.exists) {
        final callData = callDoc.data();
        final classId = callData?['classId'];
        
        if (classId != null) {
          // Get class document to find student IDs
          final classDoc = await FirebaseFirestore.instance
              .collection('classes')
              .doc(classId)
              .get();
          
          if (classDoc.exists) {
            final classData = classDoc.data();
            final studentIds = List<String>.from(classData?['studentIds'] ?? []);
            
            // Fetch all students from the class
            for (var studentId in studentIds) {
              try {
                final studentDoc = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(studentId)
                    .get();
                
                if (studentDoc.exists) {
                  final studentData = studentDoc.data();
                  // For now, use first student found (in real app, need proper UID mapping)
                  setState(() {
                    _userProfiles[uid] = {
                      'username': studentData?['username'] ?? 'Student',
                      'profileImage': studentData?['profileImage'],
                    };
                  });
                  break;
                }
              } catch (e) {
                continue;
              }
            }
          }
        }
      }
      
      // Fallback: just get any student
      if (!_userProfiles.containsKey(uid)) {
        final userQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'student')
            .limit(1)
            .get();
        
        if (userQuery.docs.isNotEmpty) {
          final userData = userQuery.docs.first.data();
          setState(() {
            _userProfiles[uid] = {
              'username': userData['username'] ?? 'Student',
              'profileImage': userData['profileImage'],
            };
          });
        }
      }
    } catch (e) {
      print('Error loading user profile: $e');
    }
  }

  // Update participant count in Firestore
  Future<void> _updateParticipantCount(int count) async {
    try {
      await FirebaseFirestore.instance
          .collection('VideoCalls')
          .doc(widget.vcId)
          .update({'participantCount': count});
    } catch (e) {
      print('Error updating participant count: $e');
    }
  }

  // Listen for raised hands from students
  void _listenForRaisedHands() {
    _handsRaisedStream = FirebaseFirestore.instance
        .collection('VideoCalls')
        .doc(widget.vcId)
        .collection('raisedHands')
        .orderBy('raisedAt', descending: false)
        .snapshots()
        .listen((snapshot) async {
      List<Map<String, dynamic>> hands = [];
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final userId = data['userId'];
        
        // Fetch username from users collection
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();
          
          final username = userDoc.data()?['username'] ?? 'Student ${userId.substring(0, 6)}';
          
          hands.add({
            'userId': userId,
            'username': username,
            'docId': doc.id,
            'raisedAt': data['raisedAt'],
          });
        } catch (e) {
          print('Error fetching username: $e');
          hands.add({
            'userId': userId,
            'username': 'Student ${userId.substring(0, 6)}',
            'docId': doc.id,
            'raisedAt': data['raisedAt'],
          });
        }
      }
      
      setState(() {
        _raisedHands = hands;
      });
    });
  }

  // Lower a student's hand
  Future<void> _lowerHand(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('VideoCalls')
          .doc(widget.vcId)
          .collection('raisedHands')
          .doc(docId)
          .delete();
    } catch (e) {
      print('Error lowering hand: $e');
    }
  }

  // Check if camera is available
  Future<void> _checkCameraAvailability() async {
    try {
      // Try to enable video to check if camera exists
      await widget.engine.enableVideo();
      setState(() {
        _cameraAvailable = true;
      });
    } catch (e) {
      if (e.toString().contains('NotFound') || 
          e.toString().contains('no camera') ||
          e.toString().contains('device not found')) {
        setState(() {
          _cameraAvailable = false;
          _cameraOff = true;
        });
        // Show dialog but allow continuation
        if (mounted) {
          _showNoCameraDialog();
        }
      }
    }
  }

  void _showNoCameraDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.videocam_off, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('No Camera Detected'),
          ],
        ),
        content: const Text(
          'No camera was detected on your device.\n\n'
          'You can continue with audio only, but others won\'t see your video.',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _cameraOff = true;
              });
            },
            child: const Text('Continue with Audio Only'),
          ),
        ],
      ),
    );
  }

  void _listenForCallStatusChanges() {
    _callStatusStream = FirebaseFirestore.instance
        .collection('VideoCalls')
        .doc(widget.vcId)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.exists) {
            final data = snapshot.data() as Map<String, dynamic>;
            final status = data['status'];

            print("Call status changed: $status");

            if (status == 'ended' && !_callEnded) {
              print("Call ended detected from Firestore");
              _showCallEndedDialog();
              _handleCallEnd(isRemoteEnd: true);
            }
          }
        });
  }

  void _setupAgoraEventHandlers() {
    // Enable audio volume indication to detect speaking
    widget.engine.enableAudioVolumeIndication(
      interval: 200,
      smooth: 3,
      reportVad: true,
    );

    widget.engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          print(
            "CallScreen: Local user ${connection.localUid} joined successfully",
          );
        },
        onAudioVolumeIndication: (
          RtcConnection connection,
          List<AudioVolumeInfo> speakers,
          int speakerNumber,
          int totalVolume,
        ) {
          // Track speaking users
          final newSpeakingUsers = <int>{};
          for (var speaker in speakers) {
            if (speaker.volume != null && speaker.volume! > 10) {
              newSpeakingUsers.add(speaker.uid ?? 0);
            }
          }
          if (mounted) {
            setState(() {
              _speakingUsers.clear();
              _speakingUsers.addAll(newSpeakingUsers);
            });
          }
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          print("CallScreen: Remote user $remoteUid joined");
          setState(() {
            _remoteUsers.add(remoteUid);
            _participantCount = _remoteUsers.length + 1; // +1 for teacher
          });
          _loadUserProfile(remoteUid);
          _updateParticipantCount(_participantCount);
          // Removed user joined dialog
        },
        onUserOffline: (
          RtcConnection connection,
          int remoteUid,
          UserOfflineReasonType reason,
        ) {
          print("CallScreen: Remote user $remoteUid left with reason: $reason");

          if (_remoteUsers.contains(remoteUid) && !_callEnded && !isNavigatingBack) {
            print("Remote user disconnected");

            setState(() {
              _remoteUsers.remove(remoteUid);
              _userProfiles.remove(remoteUid);
              _participantCount = _remoteUsers.length + 1; // +1 for teacher
            });
            _updateParticipantCount(_participantCount);

            // Show notification that a user left
            if (mounted) {
              _showUserLeftNotification(remoteUid);
            }
          }
        },
        onConnectionStateChanged: (
          RtcConnection connection,
          ConnectionStateType state,
          ConnectionChangedReasonType reason,
        ) {
          print("Connection state changed: $state, reason: $reason");
          // Only show connection lost if it's a real network failure, not intentional disconnect
          if ((state == ConnectionStateType.connectionStateDisconnected ||
              state == ConnectionStateType.connectionStateFailed) &&
              !_callEnded && 
              !isNavigatingBack &&
              reason != ConnectionChangedReasonType.connectionChangedLeaveChannel) {
            _showConnectionLostDialog();
          }
        },
      ),
    );
  }

  void _showUserLeftNotification(int uid) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.person_off, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text('A student left the call (${_remoteUsers.length} remaining)'),
            ),
          ],
        ),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showCallEndedDialog() {
    if (_callEnded || isNavigatingBack) return;

    setState(() {
      _callEnded = true;
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted || isNavigatingBack) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.call_end, color: Colors.red, size: 28),
              SizedBox(width: 12),
              Text('Call Ended'),
            ],
          ),
          content: const Text('The call has been ended by the other user.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _handleCallEnd(isRemoteEnd: true);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    });
  }

  void _showConnectionLostDialog() {
    if (_callEnded || isNavigatingBack) return;

    setState(() {
      _callEnded = true;
    });

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Text('Connection Lost'),
            content: const Text(
              'The connection to the call was lost. The call will end now.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  if (mounted && !isNavigatingBack) {
                    _handleCallEnd(isRemoteEnd: true);
                  }
                },
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  bool isNavigatingBack = false;

  // Show confirmation dialog before ending call
  void _showEndCallConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('End Call'),
          ],
        ),
        content: const Text(
          'Are you sure you want to end the call for everyone? All participants will be disconnected.',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close confirmation dialog
              _handleCallEnd(isRemoteEnd: false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('End Call'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCallEnd({bool isRemoteEnd = false}) async {
    if (_callEnded || isNavigatingBack) return; // Prevent duplicate handling

    print("Handling call end (remote: $isRemoteEnd)");

    setState(() {
      _callEnded = true;
    });

    try {
      // Leave the Agora channel first
      await widget.engine.leaveChannel();
      print("Left Agora channel");

      if (!isRemoteEnd) {
        // Only update Firestore if we're the one ending the call
        try {
          await FirebaseFirestore.instance
              .collection('VideoCalls')
              .doc(widget.vcId)
              .update({
                'status': 'ended',
                'endedAt': FieldValue.serverTimestamp(),
              });

          print("Updated Firestore call status to ended");
        } catch (e) {
          print("Error updating call status: $e");
        }
      }
    } catch (e) {
      print("Error in handleCallEnd: $e");
    }

    // Mark as navigating back
    isNavigatingBack = true;

    // Exit the call screen if we're still mounted and not already navigating
    if (mounted && Navigator.of(context).canPop()) {
      print("Exiting call screen");
      Navigator.of(context).pop('call_ended');
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (!_callEnded && !isNavigatingBack) {
          _showEndCallConfirmation();
        }
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Video grid view (full screen, includes local + remote users)
            // Keep video rendering even when chat is open (just hide visually)
            Positioned.fill(
              child: Visibility(
                visible: !_showChat,
                maintainState: true,
                maintainAnimation: true,
                maintainSize: false,
                child: _remoteVideo(),
              ),
            ),

            // Participant count (top-left) - only show when chat is closed
            if (!_showChat)
              Positioned(
                top: 40,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.people, color: Colors.white, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        '$_participantCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Connection status indicator - only show when chat is closed
            if (!_showChat)
              Positioned(
                top: 90,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _remoteUsers.isNotEmpty ? Icons.wifi : Icons.wifi_off,
                        color: _remoteUsers.isNotEmpty ? Colors.green : Colors.red,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _remoteUsers.isNotEmpty ? "Connected" : "Waiting...",
                        style: TextStyle(
                          color: _remoteUsers.isNotEmpty ? Colors.green : Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Raised hands list (left side, below connection status) - only show when chat is closed
            if (_raisedHands.isNotEmpty && !_showChat)
              Positioned(
                top: 150,
                left: 16,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 250, maxHeight: 300),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.yellow.shade700, width: 2),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.yellow.shade700,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(10),
                            topRight: Radius.circular(10),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.pan_tool, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Raised Hands (${_raisedHands.length})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // List of raised hands
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _raisedHands.length,
                          itemBuilder: (context, index) {
                            final hand = _raisedHands[index];
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.grey.shade800,
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.person,
                                    color: Colors.white70,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      hand['username'] ?? 'Student',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.check,
                                      color: Colors.green,
                                      size: 18,
                                    ),
                                    onPressed: () => _lowerHand(hand['docId']),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    tooltip: 'Lower hand',
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Chat panel (full screen overlay) - covers everything when open
            if (_showChat)
              Positioned.fill(
                child: _buildChatPanel(),
              ),

            // Bottom control buttons - only show when chat is closed
            if (!_showChat)
              Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _controlButton(
                        icon: _muted ? Icons.mic_off : Icons.mic,
                        color: Colors.white,
                        bgColor: _muted ? Colors.red : Colors.grey.shade700,
                        onTap: () {
                          setState(() => _muted = !_muted);
                          widget.engine.enableLocalAudio(!_muted);
                        },
                      ),
                      const SizedBox(width: 16),
                      _controlButton(
                        icon: _cameraOff ? Icons.videocam_off : Icons.videocam,
                        color: _cameraAvailable ? Colors.white : Colors.grey,
                        bgColor: _cameraOff ? Colors.red : (_cameraAvailable ? Colors.grey.shade700 : Colors.grey.shade900),
                        onTap: _cameraAvailable ? () {
                          setState(() => _cameraOff = !_cameraOff);
                          widget.engine.enableLocalVideo(!_cameraOff);
                        } : null,
                      ),
                      const SizedBox(width: 16),
                      _controlButton(
                        icon: Icons.chat,
                        color: Colors.white,
                        bgColor: _showChat ? Colors.blue : Colors.grey.shade700,
                        onTap: () {
                          setState(() => _showChat = !_showChat);
                        },
                      ),
                      const SizedBox(width: 16),
                      _controlButton(
                        icon: Icons.flip_camera_ios,
                        color: Colors.white,
                        bgColor: Colors.grey.shade700,
                        onTap: () {
                          widget.engine.switchCamera();
                        },
                      ),
                      const SizedBox(width: 16),
                      _controlButton(
                        icon: Icons.call_end,
                        color: Colors.white,
                        bgColor: Colors.red,
                        onTap: () => _showEndCallConfirmation(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build chat panel
  Widget _buildChatPanel() {
    return Container(
      color: Colors.black87,
      child: Column(
        children: [
          // Chat header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              border: Border(bottom: BorderSide(color: Colors.grey.shade800)),
            ),
            child: Row(
              children: [
                const Icon(Icons.chat, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Chat',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => setState(() => _showChat = false),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          // Messages list with StreamBuilder
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('VideoCalls')
                  .doc(widget.vcId)
                  .collection('messages')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No messages yet',
                      style: TextStyle(color: Colors.white54),
                    ),
                  );
                }

                final messages = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final messageData = messages[index].data() as Map<String, dynamic>;
                    final senderName = messageData['senderName'] ?? 'Unknown';
                    final text = messageData['text'] ?? '';
                    final isTeacher = messageData['isTeacher'] ?? false;

                    return Align(
                      alignment:
                          isTeacher ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isTeacher ? Colors.blue : Colors.grey.shade800,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              senderName,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              text,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
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
          // Message input
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              border: Border(top: BorderSide(color: Colors.grey.shade800)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.grey.shade800,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _sendMessage,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Send chat message
  Future<void> _sendMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    _chatController.clear();

    try {
      await FirebaseFirestore.instance
          .collection('VideoCalls')
          .doc(widget.vcId)
          .collection('messages')
          .add({
        'text': text,
        'senderName': 'Teacher',
        'isTeacher': true,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error sending message: $e');
    }
  }

  /// Styled Control Button Widget
  Widget _controlButton({
    required IconData icon,
    required Color color,
    required Color bgColor,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: CircleAvatar(
        radius: 28,
        backgroundColor: bgColor,
        child: Icon(icon, color: color, size: 28),
      ),
    );
  }

  /// Remote Video View - Minimized grid layout (300x300 boxes)
  Widget _remoteVideo() {
    // Get all users: local (0), then remote users
    List<int> allUsers = [];
    
    // Add local user
    allUsers.add(0);
    
    // Add remote users
    allUsers.addAll(_remoteUsers);
    
    if (allUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(color: Colors.white70),
            SizedBox(height: 20),
            Text(
              'Waiting for students to join...',
              style: TextStyle(color: Colors.white70, fontSize: 18),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Fixed 300x300 container size for minimized view
        final double boxSize = 300.0;
        final double spacing = 12.0;
        
        // Calculate grid columns based on screen width
        final int crossAxisCount = ((constraints.maxWidth - spacing) / (boxSize + spacing)).floor().clamp(1, 10);
        
        // Show all users in minimized grid (300x300 each) - centered
        return Center(
          child: GridView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
              childAspectRatio: 1.0, // Square boxes (300x300)
            ),
            itemCount: allUsers.length,
            itemBuilder: (context, index) {
              final uid = allUsers[index];
              final isSpeaking = _speakingUsers.contains(uid);
              return Container(
                width: boxSize,
                height: boxSize,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSpeaking
                        ? Colors.green
                        : (uid == 0 ? Colors.blue.shade400 : Colors.grey.shade700),
                    width: isSpeaking ? 3 : 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildVideoView(uid),
                      _buildVideoOverlay(uid),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
  
  // Build video view widget
  Widget _buildVideoView(int uid) {
    final isLocalUser = uid == 0;
    final userProfile = _userProfiles[uid];
    
    // Show avatar if camera is off or not available
    if (isLocalUser && (_cameraOff || !_cameraAvailable)) {
      return _buildAvatarView(_teacherProfileImage, 'Teacher');
    }
    
    if (isLocalUser) {
      // Local user camera
      return AgoraVideoView(
        controller: VideoViewController(
          rtcEngine: widget.engine,
          canvas: const VideoCanvas(
            uid: 0,
            sourceType: VideoSourceType.videoSourceCamera,
          ),
        ),
      );
    } else {
      // Remote users - check if they have camera on
      // For now, show video view (we can't detect if remote user has camera off from here)
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: widget.engine,
          canvas: VideoCanvas(
            uid: uid,
            sourceType: VideoSourceType.videoSourceCamera,
          ),
          connection: RtcConnection(channelId: widget.channelName),
        ),
        onAgoraVideoViewCreated: (viewId) {
          print("Video view created for UID: $uid");
        },
      );
    }
  }
  
  // Build avatar view when camera is off
  Widget _buildAvatarView(String? profileImageBase64, String fallbackText) {
    return Container(
      color: Colors.grey.shade900,
      child: Center(
        child: profileImageBase64 != null
            ? CircleAvatar(
                radius: 80,
                backgroundImage: MemoryImage(base64Decode(profileImageBase64)),
              )
            : CircleAvatar(
                radius: 80,
                backgroundColor: Colors.blue.shade700,
                child: Text(
                  fallbackText.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
      ),
    );
  }
  
  // Build video overlay (username, indicators)
  Widget _buildVideoOverlay(int uid) {
    final userProfile = _userProfiles[uid];
    final isLocalUser = uid == 0;
    
    return Stack(
      fit: StackFit.expand,
      children: [
        // Username overlay
        Positioned(
          bottom: 8,
          left: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isLocalUser
                  ? 'Teacher'
                  : (userProfile?['username'] ?? 'Student'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _callStatusStream.cancel();
    _handsRaisedStream.cancel();
    _chatMessagesStream?.cancel();
    _chatController.dispose();
    super.dispose();
  }
}
