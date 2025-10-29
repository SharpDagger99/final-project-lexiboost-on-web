// ignore_for_file: avoid_print, deprecated_member_use, curly_braces_in_flow_control_structures

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:async';

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
  int? _remoteUid;
  bool _callEnded = false;
  bool _isSharingScreen = false;
  bool _showChat = false;
  int _participantCount = 1; // Start with 1 (self)
  final TextEditingController _chatController = TextEditingController();
  final List<Map<String, String>> _chatMessages = [];
  late StreamSubscription<DocumentSnapshot> _callStatusStream;
  late StreamSubscription<QuerySnapshot> _handsRaisedStream;
  List<Map<String, dynamic>> _raisedHands = [];

  @override
  void initState() {
    super.initState();
    _setupAgoraEventHandlers();
    _listenForCallStatusChanges();
    _listenForRaisedHands();
    _checkCameraAvailability();

    // Initialize with provided remote UID
    _remoteUid = widget.remoteUid;
    if (_remoteUid != null) {
      _participantCount = 2; // Self + remote user
    }

    print("CallScreen initialized with remote UID: $_remoteUid");
  }

  // Listen for raised hands from students
  void _listenForRaisedHands() {
    _handsRaisedStream = FirebaseFirestore.instance
        .collection('VideoCalls')
        .doc(widget.vcId)
        .collection('raisedHands')
        .orderBy('raisedAt', descending: false)
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _raisedHands = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'userId': data['userId'],
            'docId': doc.id,
            'raisedAt': data['raisedAt'],
          };
        }).toList();
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
    } catch (e) {
      if (e.toString().contains('NotFound') || 
          e.toString().contains('no camera') ||
          e.toString().contains('device not found')) {
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
    widget.engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          print(
            "CallScreen: Local user ${connection.localUid} joined successfully",
          );
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          print("CallScreen: Remote user $remoteUid joined");
          setState(() {
            _remoteUid = remoteUid;
            _participantCount++;
          });
          _showUserJoinedDialog(remoteUid);
        },
        onUserOffline: (
          RtcConnection connection,
          int remoteUid,
          UserOfflineReasonType reason,
        ) {
          print("CallScreen: Remote user $remoteUid left with reason: $reason");

          // If the remote user left and it matches our tracked remote UID
          if (_remoteUid == remoteUid && !_callEnded && !isNavigatingBack) {
            print("Remote user disconnected, ending call automatically");

            setState(() {
              _remoteUid = null;
              _participantCount--;
            });

            // Show the alert dialog
            if (mounted) {
              _showUserLeftDialog();
            }

            // End the call gracefully
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted && !_callEnded && !isNavigatingBack) {
                _handleCallEnd(isRemoteEnd: true);
              }
            });
          }
        },
        onConnectionStateChanged: (
          RtcConnection connection,
          ConnectionStateType state,
          ConnectionChangedReasonType reason,
        ) {
          print("Connection state changed: $state, reason: $reason");
          if (state == ConnectionStateType.connectionStateDisconnected ||
              state == ConnectionStateType.connectionStateFailed) {
            _showConnectionLostDialog();
          }
        },
      ),
    );
  }

  void _showUserJoinedDialog(int uid) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.person_add, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Text('User Joined'),
          ],
        ),
        content: Text('User $uid joined the call'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    // Auto dismiss after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    });
  }

  void _showUserLeftDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.person_off, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('User Disconnected'),
          ],
        ),
        content: const Text('Other user has left the call.'),
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
          await _handleCallEnd();
        }
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Remote video view (full screen)
            Positioned.fill(child: _remoteVideo()),

            // Local video preview (top-right, rounded)
            Positioned(
              top: 40,
              right: 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 120,
                  height: 160,
                  color: Colors.black,
                  child: AgoraVideoView(
                    controller: VideoViewController(
                      rtcEngine: widget.engine,
                      canvas: const VideoCanvas(uid: 0),
                    ),
                  ),
                ),
              ),
            ),

            // Participant count (top-left)
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

            // Connection status indicator
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
                      _remoteUid != null ? Icons.wifi : Icons.wifi_off,
                      color: _remoteUid != null ? Colors.green : Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _remoteUid != null ? "Connected" : "Waiting...",
                      style: TextStyle(
                        color: _remoteUid != null ? Colors.green : Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Raised hands list (left side, below connection status)
            if (_raisedHands.isNotEmpty)
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
                                      'Student ${hand['userId'].toString().substring(0, 6)}...',
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

            // Chat panel (right side)
            if (_showChat)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: 300,
                child: _buildChatPanel(),
              ),

            // Bottom control buttons
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
                        color: Colors.white,
                        bgColor: _cameraOff ? Colors.red : Colors.grey.shade700,
                        onTap: () {
                          setState(() => _cameraOff = !_cameraOff);
                          widget.engine.enableLocalVideo(!_cameraOff);
                        },
                      ),
                      const SizedBox(width: 16),
                      _controlButton(
                        icon: Icons.screen_share,
                        color: Colors.white,
                        bgColor: _isSharingScreen ? Colors.blue : Colors.grey.shade700,
                        onTap: _toggleScreenShare,
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
                        onTap: () => _handleCallEnd(),
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

  // Toggle screen share
  void _toggleScreenShare() async {
    try {
      if (_isSharingScreen) {
        await widget.engine.stopScreenCapture();
        setState(() => _isSharingScreen = false);
      } else {
        await widget.engine.startScreenCapture(
          const ScreenCaptureParameters2(captureAudio: true, captureVideo: true),
        );
        setState(() => _isSharingScreen = true);
      }
    } catch (e) {
      print('Error toggling screen share: $e');
      _showErrorDialog('Screen Share Error', 
          'Failed to ${_isSharingScreen ? "stop" : "start"} screen sharing: $e');
    }
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
          // Messages list
          Expanded(
            child: _chatMessages.isEmpty
                ? const Center(
                    child: Text(
                      'No messages yet',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _chatMessages.length,
                    itemBuilder: (context, index) {
                      final message = _chatMessages[index];
                      final isMe = message['sender'] == 'You';
                      return Align(
                        alignment:
                            isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isMe ? Colors.blue : Colors.grey.shade800,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                message['sender']!,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                message['text']!,
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
  void _sendMessage() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _chatMessages.add({'sender': 'You', 'text': text});
    });

    _chatController.clear();

    // Here you could send the message via Firestore or Agora data stream
    // For now, it's local only
  }

  // Show error dialog
  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 28),
            const SizedBox(width: 12),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Styled Control Button Widget
  Widget _controlButton({
    required IconData icon,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
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

  /// Remote Video View
  Widget _remoteVideo() {
    // First check if we have a remote UID from props or state
    final remoteUid = _remoteUid ?? widget.remoteUid;

    if (remoteUid != null) {
      print("Rendering remote video with UID: $remoteUid");
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: widget.engine,
          canvas: VideoCanvas(uid: remoteUid),
          connection: RtcConnection(channelId: widget.channelName),
        ),
      );
    } else {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(color: Colors.white70),
            SizedBox(height: 20),
            Text(
              'Waiting for the other user to join...',
              style: TextStyle(color: Colors.white70, fontSize: 18),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _callStatusStream.cancel();
    _handsRaisedStream.cancel();
    _chatController.dispose();
    super.dispose();
  }
}
