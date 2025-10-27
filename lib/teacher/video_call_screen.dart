// ignore_for_file: unused_field, deprecated_member_use, use_build_context_synchronously

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/agora_config.dart';

class VideoCallScreen extends StatefulWidget {
  final String channelName;
  final String className;
  final bool isTeacher;
  final String? classId; // Add classId to update message

  const VideoCallScreen({
    super.key,
    required this.channelName,
    required this.className,
    this.isTeacher = false,
    this.classId,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  late RtcEngine _engine;
  bool _localUserJoined = false;
  int? _remoteUid;
  bool _isMuted = false;
  bool _isCameraOff = false;
  final Set<int> _remoteUsers = {};
  final Map<int, bool> _remoteUsersCameraStatus = {}; // Track camera status
  String? _currentUserName;
  String? _currentUserProfileImage;
  int? _localUid;

  @override
  void initState() {
    super.initState();
    _initAgora();
    _loadCurrentUserData();
  }

  // Load current user's profile data
  Future<void> _loadCurrentUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();
      if (doc.exists) {
        setState(() {
          _currentUserName = doc.data()?["username"] ?? doc.data()?["fullname"] ?? "User";
          _currentUserProfileImage = doc.data()?["profileImage"];
        });
      }
    }
  }

  Future<void> _initAgora() async {
    // Request permissions
    await [Permission.microphone, Permission.camera].request();

    // Create Agora engine
    _engine = createAgoraRtcEngine();
    await _engine.initialize(
      const RtcEngineContext(
        appId: AgoraConfig.appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ),
    );

    // Register event handlers
    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          setState(() {
            _localUserJoined = true;
            _localUid = connection.localUid;
          });
          debugPrint('Local user ${connection.localUid} joined');
          _updateParticipantCount(1); // Increment participant count
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          setState(() {
            _remoteUsers.add(remoteUid);
            _remoteUsersCameraStatus[remoteUid] = true; // Assume camera on initially
          });
          debugPrint('Remote user $remoteUid joined');
          _updateParticipantCount(_remoteUsers.length + 1);
        },
        onUserOffline:
            (
              RtcConnection connection,
              int remoteUid,
              UserOfflineReasonType reason,
            ) {
              setState(() {
                _remoteUsers.remove(remoteUid);
                _remoteUsersCameraStatus.remove(remoteUid);
              });
              debugPrint('Remote user $remoteUid left channel');
              _updateParticipantCount(_remoteUsers.length + 1);
            },
        onRemoteVideoStateChanged: (RtcConnection connection, int remoteUid,
            RemoteVideoState state, RemoteVideoStateReason reason, int elapsed) {
          setState(() {
            _remoteUsersCameraStatus[remoteUid] = 
                state == RemoteVideoState.remoteVideoStateDecoding ||
                state == RemoteVideoState.remoteVideoStateStarting;
          });
          debugPrint('Remote user $remoteUid camera: ${_remoteUsersCameraStatus[remoteUid]}');
        },
        onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {
          debugPrint(
            '[onTokenPrivilegeWillExpire] connection: ${connection.toJson()}, token: $token',
          );
        },
      ),
    );

    // Enable video
    await _engine.enableVideo();
    await _engine.startPreview();

    // Join channel
    await _engine.joinChannel(
      token: AgoraConfig.token,
      channelId: widget.channelName,
      uid: 0,
      options: const ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileCommunication,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }

  Future<void> _dispose() async {
    await _engine.leaveChannel();
    await _engine.release();
  }

  // Toggle microphone
  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    _engine.muteLocalAudioStream(_isMuted);
  }

  // Toggle camera
  void _toggleCamera() {
    setState(() {
      _isCameraOff = !_isCameraOff;
    });
    _engine.muteLocalVideoStream(_isCameraOff);
  }

  // Switch camera (front/back)
  void _switchCamera() {
    _engine.switchCamera();
  }

  // Update participant count in Firestore
  Future<void> _updateParticipantCount(int count) async {
    if (widget.classId == null) return;
    
    try {
      final messagesQuery = await FirebaseFirestore.instance
          .collection("classes")
          .doc(widget.classId)
          .collection("messages")
          .where("type", isEqualTo: "video_call")
          .where("channelName", isEqualTo: widget.channelName)
          .orderBy("timestamp", descending: true)
          .limit(1)
          .get();

      if (messagesQuery.docs.isNotEmpty) {
        await messagesQuery.docs.first.reference.update({
          'participantCount': count,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error updating participant count: $e');
    }
  }

  // Leave call
  Future<void> _leaveCall() async {
    // Update participant count
    final newCount = _remoteUsers.length; // After I leave
    await _updateParticipantCount(newCount);
    
    // Update video call message to "ended" if this is the last person leaving
    if (_remoteUsers.isEmpty && widget.classId != null) {
      try {
        // Get the video call message and mark it as ended
        final messagesQuery = await FirebaseFirestore.instance
            .collection("classes")
            .doc(widget.classId)
            .collection("messages")
            .where("type", isEqualTo: "video_call")
            .where("channelName", isEqualTo: widget.channelName)
            .orderBy("timestamp", descending: true)
            .limit(1)
            .get();

        if (messagesQuery.docs.isNotEmpty) {
          await messagesQuery.docs.first.reference.update({
            'status': 'ended',
            'participantCount': 0,
            'endedAt': FieldValue.serverTimestamp(),
          });
        }
      } catch (e) {
        debugPrint('Error updating call status: $e');
      }
    }
    
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Main video view (remote users or local preview)
          Center(
            child: _remoteUsers.isEmpty
                ? _localUserJoined
                      ? _buildLocalVideoOrAvatar(isMainView: true)
                      : const CircularProgressIndicator()
                : _buildRemoteVideos(),
          ),

          // Local user preview (picture-in-picture)
          if (_localUserJoined && _remoteUsers.isNotEmpty)
            Positioned(
              top: 50,
              right: 16,
              child: Container(
                width: 120,
                height: 160,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _buildLocalVideoOrAvatar(isMainView: false),
                ),
              ),
            ),

          // Top bar with class name
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.school, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.className,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.circle, color: Colors.white, size: 8),
                        const SizedBox(width: 6),
                        Text(
                          'LIVE',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Control buttons at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 30),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mute/Unmute button
                  _buildControlButton(
                    icon: _isMuted ? Icons.mic_off : Icons.mic,
                    onPressed: _toggleMute,
                    color: _isMuted ? Colors.red : Colors.white,
                  ),

                  // Camera on/off button
                  _buildControlButton(
                    icon: _isCameraOff ? Icons.videocam_off : Icons.videocam,
                    onPressed: _toggleCamera,
                    color: _isCameraOff ? Colors.red : Colors.white,
                  ),

                  // Switch camera button
                  _buildControlButton(
                    icon: Icons.flip_camera_ios,
                    onPressed: _switchCamera,
                    color: Colors.white,
                  ),

                  // End call button
                  _buildControlButton(
                    icon: Icons.call_end,
                    onPressed: _leaveCall,
                    color: Colors.white,
                    backgroundColor: Colors.red,
                    size: 60,
                  ),
                ],
              ),
            ),
          ),

          // Participants count
          Positioned(
            top: 110,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.people, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '${_remoteUsers.length + 1}',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build local video or avatar based on camera status
  Widget _buildLocalVideoOrAvatar({required bool isMainView}) {
    if (_isCameraOff) {
      // Show profile avatar when camera is off
      return Container(
        color: Colors.blue.shade900,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _currentUserProfileImage != null
                  ? CircleAvatar(
                      radius: isMainView ? 60 : 30,
                      backgroundImage: MemoryImage(
                        base64Decode(_currentUserProfileImage!),
                      ),
                    )
                  : CircleAvatar(
                      radius: isMainView ? 60 : 30,
                      backgroundColor: Colors.blue.shade300,
                      child: Text(
                        _currentUserName?.substring(0, 1).toUpperCase() ?? 'U',
                        style: GoogleFonts.poppins(
                          fontSize: isMainView ? 40 : 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
              if (isMainView) ...[
                const SizedBox(height: 16),
                Text(
                  _currentUserName ?? 'You',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.videocam_off, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Camera Off',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    } else {
      // Show video when camera is on
      return AgoraVideoView(
        controller: VideoViewController(
          rtcEngine: _engine,
          canvas: const VideoCanvas(uid: 0),
        ),
      );
    }
  }

  // Build remote user videos in a grid
  Widget _buildRemoteVideos() {
    if (_remoteUsers.isEmpty) {
      return const Center(
        child: Text(
          'Waiting for others to join...',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    if (_remoteUsers.length == 1) {
      final remoteUid = _remoteUsers.first;
      final isCameraOn = _remoteUsersCameraStatus[remoteUid] ?? true;
      
      return Stack(
        children: [
          if (isCameraOn)
            AgoraVideoView(
              controller: VideoViewController.remote(
                rtcEngine: _engine,
                canvas: VideoCanvas(uid: remoteUid),
                connection: RtcConnection(channelId: widget.channelName),
              ),
            )
          else
            Container(
              color: Colors.blue.shade900,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.blue.shade300,
                      child: const Icon(
                        Icons.person,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'User $remoteUid',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.videocam_off, color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Camera Off',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    }

    // Grid layout for multiple users
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _remoteUsers.length <= 4 ? 2 : 3,
        childAspectRatio: 0.75,
      ),
      itemCount: _remoteUsers.length,
      itemBuilder: (context, index) {
        final remoteUid = _remoteUsers.elementAt(index);
        final isCameraOn = _remoteUsersCameraStatus[remoteUid] ?? true;
        
        return Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white24, width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                if (isCameraOn)
                  AgoraVideoView(
                    controller: VideoViewController.remote(
                      rtcEngine: _engine,
                      canvas: VideoCanvas(uid: remoteUid),
                      connection: RtcConnection(channelId: widget.channelName),
                    ),
                  )
                else
                  Container(
                    color: Colors.blue.shade900,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.blue.shade300,
                            child: const Icon(
                              Icons.person,
                              size: 30,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'User',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Build control button
  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
    Color? backgroundColor,
    double size = 50,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.white.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: size * 0.5),
      ),
    );
  }
}
