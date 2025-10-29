// ignore_for_file: use_build_context_synchronously, deprecated_member_use, avoid_print

import 'dart:convert';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import '../services/agora_config.dart';
import '../services/permission_service.dart';
import 'call_screen.dart';

/// ✅ Reusable widget to fetch & display a user's profile image
class UserAvatar extends StatelessWidget {
  final String uid;
  final double radius;

  const UserAvatar({
    super.key,
    required this.uid,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection("users").doc(uid).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return CircleAvatar(
            radius: radius,
            backgroundColor: Colors.grey[300],
            child: const Icon(Icons.person, size: 14, color: Colors.white),
          );
        }

        final data = snapshot.data!.data();
        final profileImageBase64 = data?['profileImage'];

        return CircleAvatar(
          radius: radius,
          backgroundColor: Colors.blue,
          backgroundImage: profileImageBase64 != null
              ? MemoryImage(base64Decode(profileImageBase64))
              : null,
          child: profileImageBase64 == null
              ? const Icon(Icons.person, size: 14, color: Colors.white)
              : null,
        );
      },
    );
  }
}

class MyClassRoom extends StatefulWidget {
  final String classId;
  final String className;

  const MyClassRoom({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  State<MyClassRoom> createState() => _MyClassRoomState();
}

class _MyClassRoomState extends State<MyClassRoom> {
  final TextEditingController _messageController = TextEditingController();
  final user = FirebaseAuth.instance.currentUser;
  
  // Agora video call variables
  late RtcEngine _engine;
  bool _localUserJoined = false;
  int? _remoteUid;
  bool _isInitiatingCall = false;
  String? _activeCallMessageId; // Track the active call message

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  // ✅ Initialize Agora engine
  Future<void> _initAgora() async {
    try {
      _engine = createAgoraRtcEngine();

      await _engine.initialize(
        RtcEngineContext(
          appId: AgoraConfig.appId,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );

      // Note: We don't enable video/audio here anymore
      // It will be done when starting a call to trigger permission prompts

      _engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            print("Teacher joined channel: ${connection.channelId}");
            setState(() {
              _localUserJoined = true;
            });
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            print("Remote user $remoteUid joined");
            setState(() {
              _remoteUid = remoteUid;
            });
          },
          onUserOffline:
              (
                RtcConnection connection,
                int remoteUid,
                UserOfflineReasonType reason,
              ) {
                print("Remote user $remoteUid left channel");
                setState(() {
                  if (_remoteUid == remoteUid) {
                    _remoteUid = null;
                  }
                });
              },
          onError: (ErrorCodeType err, String msg) {
            print("Agora error: $err, $msg");
          },
        ),
      );
    } catch (e) {
      print("Error initializing Agora: $e");
    }
  }

  // ✅ fetch username
  Future<String> _getUsername(String uid) async {
    final doc =
        await FirebaseFirestore.instance.collection("users").doc(uid).get();
    return doc.data()?["username"] ?? doc.data()?["fullname"] ?? "Guest";
  }

  // ✅ send message
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || user == null) return;

    final senderName = await _getUsername(user!.uid);

    await FirebaseFirestore.instance
        .collection("classes")
        .doc(widget.classId)
        .collection("messages")
        .add({
      "senderId": user!.uid,
      "senderName": senderName,
      "text": text,
      "type": "text",
      "timestamp": FieldValue.serverTimestamp(),
    });

    _messageController.clear();
  }

  // ✅ upload file (image, video, or document)
  Future<void> _uploadFile() async {
    if (user == null) return;

    try {
      // Pick file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'mp4', 'mov', 'avi', 'pdf', 'doc', 'docx', 'txt'],
        withData: kIsWeb, // Load bytes for web
      );

      if (result == null || result.files.isEmpty) return;

      final platformFile = result.files.single;
      final fileName = platformFile.name;
      final fileExtension = fileName.split('.').last.toLowerCase();

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Colors.blue),
        ),
      );

      // Determine file type and storage path
      String fileType = 'file';
      String storagePath = 'other files/$fileName';
      
      if (['jpg', 'jpeg', 'png', 'gif'].contains(fileExtension)) {
        fileType = 'image';
        storagePath = 'other files/$fileName';
      } else if (['mp4', 'mov', 'avi'].contains(fileExtension)) {
        fileType = 'video';
        storagePath = 'videos/$fileName';
      }

      // Upload to Firebase Storage
      final storageRef = FirebaseStorage.instance.ref().child(storagePath);
      
      // Upload based on platform
      if (kIsWeb) {
        // For web, use bytes
        if (platformFile.bytes == null) {
          throw Exception('No file data available');
        }
        await storageRef.putData(
          platformFile.bytes!,
          SettableMetadata(contentType: _getContentType(fileExtension)),
        );
      } else {
        // For mobile, use file path
        if (platformFile.path == null) {
          throw Exception('No file path available');
        }
        final file = await platformFile.xFile.readAsBytes();
        await storageRef.putData(
          file,
          SettableMetadata(contentType: _getContentType(fileExtension)),
        );
      }
      
      final downloadUrl = await storageRef.getDownloadURL();

      // Get sender name
      final senderName = await _getUsername(user!.uid);

      // Save message with file URL
      await FirebaseFirestore.instance
          .collection("classes")
          .doc(widget.classId)
          .collection("messages")
          .add({
        "senderId": user!.uid,
        "senderName": senderName,
        "type": fileType,
        "fileUrl": downloadUrl,
        "fileName": fileName,
        "timestamp": FieldValue.serverTimestamp(),
      });

      Navigator.of(context).pop(); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$fileType uploaded successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog if open
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ✅ Get content type based on file extension
  String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'avi':
        return 'video/x-msvideo';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  // ✅ Start video call and notify students
  Future<void> _startVideoCall() async {
    if (user == null) return;

    setState(() {
      _isInitiatingCall = true;
      _remoteUid = null; // Reset remote UID
    });

    try {
      // Request permissions (mobile) or prepare for browser prompt (web)
      bool permissionsGranted =
          await PermissionService.requestVideoCallPermissions();

      if (!permissionsGranted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: const [
                Icon(Icons.warning, color: Colors.orange, size: 28),
                SizedBox(width: 12),
                Text('Permissions Required'),
              ],
            ),
            content: Text(PermissionService.getPermissionErrorMessage()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        setState(() {
          _isInitiatingCall = false;
        });
        return;
      }

      // Initialize Agora with permissions - this will trigger browser prompt on web
      bool agoraInitialized =
          await PermissionService.initializeAgoraWithPermissions(_engine);

      if (!agoraInitialized) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: const [
                Icon(Icons.error, color: Colors.red, size: 28),
                SizedBox(width: 12),
                Text('Camera/Microphone Error'),
              ],
            ),
            content: Text(
              'Failed to access camera/microphone.\n\n'
              '${PermissionService.getPermissionErrorMessage()}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        setState(() {
          _isInitiatingCall = false;
        });
        return;
      }
      // Get teacher name
      final teacherName = await _getUsername(user!.uid);

      // Create a unique channel name and call ID
      final channelName = AgoraConfig.getClassChannelName(widget.classId);
      final vcId = "${widget.classId}_${DateTime.now().millisecondsSinceEpoch}";

      // Store call details in Firestore for students to join
      await FirebaseFirestore.instance.collection('VideoCalls').doc(vcId).set({
        'callerId': user!.uid,
        'callerName': teacherName,
        'classId': widget.classId,
        'className': widget.className,
        'channelName': channelName,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'initiated',
        'teacherUid': AgoraConfig.getTeacherUid(user!.uid),
      });

      // Send message in class chat about video call
      final messageRef = await FirebaseFirestore.instance
          .collection("classes")
          .doc(widget.classId)
          .collection("messages")
          .add({
            "senderId": user!.uid,
            "senderName": teacherName,
            "text": "📞 Video call started! Tap to join.",
            "type": "video_call",
            "status": "active",
            "participantCount": 0,
            "timestamp": FieldValue.serverTimestamp(),
            "channelName": channelName,
            "className": widget.className,
            "vcId": vcId,
          });

      setState(() {
        _activeCallMessageId = messageRef.id;
      });

      // Reset the engine event handler to ensure clean event handling
      _engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            print("Teacher joined channel: ${connection.channelId}");
            print("Local UID: ${connection.localUid}");
            setState(() {
              _localUserJoined = true;
            });
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            print("Remote user $remoteUid joined the channel");
            setState(() {
              _remoteUid = remoteUid;
            });
          },
          onUserOffline:
              (
                RtcConnection connection,
                int remoteUid,
                UserOfflineReasonType reason,
              ) {
                print("Remote user $remoteUid left channel");
                setState(() {
                  if (_remoteUid == remoteUid) {
                    _remoteUid = null;
                  }
                });
              },
          onError: (ErrorCodeType err, String msg) {
            print("Agora error: $err, $msg");
          },
        ),
      );

      // Join the channel with teacher UID
      await _engine.joinChannel(
        token: '', // Leave empty for App ID authentication in testing
        channelId: channelName,
        uid: AgoraConfig.getTeacherUid(user!.uid),
        options: const ChannelMediaOptions(
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
          publishMicrophoneTrack: true,
          publishCameraTrack: true,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );

      // Navigate to the call screen
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CallScreen(
            channelName: channelName,
            engine: _engine,
            localUserJoined: _localUserJoined,
            remoteUid: _remoteUid,
            vcId: vcId,
          ),
        ),
      );

      // When teacher returns from call, end it for everyone
      await _endCallForEveryone(vcId);

      setState(() {
        _isInitiatingCall = false;
      });

      // Show call result notification if needed
      if (result == 'call_ended') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Call ended'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      print('Error initiating video call: $e');
      String errorMessage = 'Failed to initiate video call: $e';
      if (e.toString().contains('permission')) {
        errorMessage =
            'Failed to initiate video call: Camera or microphone permission denied.';
      } else if (e.toString().contains('network')) {
        errorMessage =
            'Failed to initiate video call: Network error. Please check your connection.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isInitiatingCall = false;
      });
    }
  }

  // ✅ End call for everyone when teacher leaves
  Future<void> _endCallForEveryone(String vcId) async {
    try {
      // Update Firestore call status to ended
      await FirebaseFirestore.instance
          .collection('VideoCalls')
          .doc(vcId)
          .update({'status': 'ended', 'endedAt': FieldValue.serverTimestamp()});

      // Update the message in chat
      if (_activeCallMessageId != null) {
        await FirebaseFirestore.instance
            .collection("classes")
            .doc(widget.classId)
            .collection("messages")
            .doc(_activeCallMessageId)
            .update({'status': 'ended'});
      }

      print("Call ended for everyone");
    } catch (e) {
      print("Error ending call: $e");
    }
  }

  // ✅ Show message options popup
  void _showMessageOptions(
    BuildContext context,
    String messageId,
    bool isMyMessage,
    List<String> likes,
    List<String> dislikes,
    bool isHidden,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final currentUserId = user?.uid ?? '';
        final hasLiked = likes.contains(currentUserId);
        final hasDisliked = dislikes.contains(currentUserId);

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.blue.shade50, Colors.white],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Message Options',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
                const SizedBox(height: 20),

                // Like button
                _buildOptionButton(
                  icon: Icons.thumb_up,
                  label: hasLiked ? 'Unlike' : 'Like',
                  color: Colors.blue,
                  onTap: () {
                    Navigator.pop(context);
                    _toggleLike(messageId, hasLiked);
                  },
                ),
                const SizedBox(height: 12),

                // Dislike button
                _buildOptionButton(
                  icon: Icons.thumb_down,
                  label: hasDisliked ? 'Remove Dislike' : 'Dislike',
                  color: Colors.red,
                  onTap: () {
                    Navigator.pop(context);
                    _toggleDislike(messageId, hasDisliked);
                  },
                ),
                const SizedBox(height: 12),

                // Hide/Unhide button
                _buildOptionButton(
                  icon: isHidden ? Icons.visibility : Icons.visibility_off,
                  label: isHidden ? 'Unhide Message' : 'Hide Message',
                  color: isHidden ? Colors.green : Colors.orange,
                  onTap: () {
                    Navigator.pop(context);
                    if (isHidden) {
                      _unhideMessage(messageId);
                    } else {
                      _hideMessage(messageId);
                    }
                  },
                ),

                // Delete button (only for own messages)
                if (isMyMessage) ...[
                  const SizedBox(height: 12),
                  _buildOptionButton(
                    icon: Icons.delete,
                    label: 'Delete Message',
                    color: Colors.red.shade700,
                    onTap: () {
                      Navigator.pop(context);
                      _deleteMessage(messageId);
                    },
                  ),
                ],

                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
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

  // ✅ Build option button
  Widget _buildOptionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Toggle like
  Future<void> _toggleLike(String messageId, bool hasLiked) async {
    if (user == null) return;

    try {
      final messageRef = FirebaseFirestore.instance
          .collection("classes")
          .doc(widget.classId)
          .collection("messages")
          .doc(messageId);

      if (hasLiked) {
        await messageRef.update({
          'likes': FieldValue.arrayRemove([user!.uid]),
        });
      } else {
        await messageRef.update({
          'likes': FieldValue.arrayUnion([user!.uid]),
          'dislikes': FieldValue.arrayRemove([
            user!.uid,
          ]), // Remove dislike if exists
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update like: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ✅ Toggle dislike
  Future<void> _toggleDislike(String messageId, bool hasDisliked) async {
    if (user == null) return;

    try {
      final messageRef = FirebaseFirestore.instance
          .collection("classes")
          .doc(widget.classId)
          .collection("messages")
          .doc(messageId);

      if (hasDisliked) {
        await messageRef.update({
          'dislikes': FieldValue.arrayRemove([user!.uid]),
        });
      } else {
        await messageRef.update({
          'dislikes': FieldValue.arrayUnion([user!.uid]),
          'likes': FieldValue.arrayRemove([user!.uid]), // Remove like if exists
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update dislike: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ✅ Hide message
  Future<void> _hideMessage(String messageId) async {
    if (user == null) return;

    try {
      final messageRef = FirebaseFirestore.instance
          .collection("classes")
          .doc(widget.classId)
          .collection("messages")
          .doc(messageId);

      await messageRef.update({
        'hiddenBy': FieldValue.arrayUnion([user!.uid]),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message hidden'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to hide message: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ✅ Unhide message
  Future<void> _unhideMessage(String messageId) async {
    if (user == null) return;

    try {
      final messageRef = FirebaseFirestore.instance
          .collection("classes")
          .doc(widget.classId)
          .collection("messages")
          .doc(messageId);

      await messageRef.update({
        'hiddenBy': FieldValue.arrayRemove([user!.uid]),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message unhidden'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to unhide message: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ✅ Delete message
  Future<void> _deleteMessage(String messageId) async {
    try {
      await FirebaseFirestore.instance
          .collection("classes")
          .doc(widget.classId)
          .collection("messages")
          .doc(messageId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message deleted'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete message: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _engine.leaveChannel();
    _engine.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF1E201E),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.school, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.className,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              onPressed: () => _showClassInfo(context),
              icon: const Icon(Icons.info_outline, color: Colors.white),
            ),
            IconButton(
              onPressed: _isInitiatingCall ? null : () => _startVideoCall(),
              icon: _isInitiatingCall
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.video_camera_front, color: Colors.white),
              tooltip: 'Start video call',
            ),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: Colors.white),
            ),
          ],
        ),
      ),
      body: Container(
        color: const Color(0xFF2C2E2C),
        child: Column(
          children: [
            // ✅ messages stream
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection("classes")
                    .doc(widget.classId)
                    .collection("messages")
                    .orderBy("timestamp", descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.blue),
                    );
                  }

                  final docs = snapshot.data!.docs;

                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 80,
                            color: Colors.white.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No messages yet',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Start a conversation with your students!',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(12),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final isMe = data["senderId"] == user?.uid;
                      final messageType = data["type"] ?? "text";
                      final messageId = docs[index].id;
                      final likes = List<String>.from(data["likes"] ?? []);
                      final dislikes = List<String>.from(
                        data["dislikes"] ?? [],
                      );
                      final hiddenBy = List<String>.from(
                        data["hiddenBy"] ?? [],
                      );
                      final isHidden = hiddenBy.contains(user?.uid);

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisAlignment:
                              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Avatar (other user, left side)
                            if (!isMe) ...[
                              UserAvatar(uid: data["senderId"], radius: 14),
                              const SizedBox(width: 8),
                            ],

                            // Message + Username
                            Flexible(
                              child: GestureDetector(
                                onLongPress: () => _showMessageOptions(
                                  context,
                                  messageId,
                                  isMe,
                                  likes,
                                  dislikes,
                                  isHidden,
                                ),
                                child: Column(
                                  crossAxisAlignment: isMe
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: [
                                    if (!isHidden)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 2,
                                        ),
                                        child: Text(
                                          data["senderName"] ?? "Guest",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: Colors.white.withOpacity(
                                              0.8,
                                            ),
                                          ),
                                        ),
                                      ),
                                    isHidden
                                        ? Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 10,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.withOpacity(
                                                0.3,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: Colors.grey.withOpacity(
                                                  0.5,
                                                ),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.visibility_off,
                                                  size: 14,
                                                  color: Colors.grey.shade400,
                                                ),
                                                const SizedBox(width: 8),
                                                Flexible(
                                                  child: Text(
                                                    'This message is hidden, hold this message to unhide',
                                                    style: TextStyle(
                                                      color:
                                                          Colors.grey.shade400,
                                                      fontSize: 13,
                                                      fontStyle:
                                                          FontStyle.italic,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        : _buildMessageContent(
                                            data,
                                            isMe,
                                            messageType,
                                          ),
                                    if (!isHidden &&
                                        (likes.isNotEmpty ||
                                            dislikes.isNotEmpty))
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (likes.isNotEmpty) ...[
                                              Icon(
                                                Icons.thumb_up,
                                                size: 12,
                                                color: Colors.blue.shade300,
                                              ),
                                              const SizedBox(width: 2),
                                              Text(
                                                '${likes.length}',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.blue.shade300,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                            ],
                                            if (dislikes.isNotEmpty) ...[
                                              Icon(
                                                Icons.thumb_down,
                                                size: 12,
                                                color: Colors.red.shade300,
                                              ),
                                              const SizedBox(width: 2),
                                              Text(
                                                '${dislikes.length}',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.red.shade300,
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

                            // Avatar (me, right side)
                            if (isMe) ...[
                              const SizedBox(width: 8),
                              UserAvatar(uid: data["senderId"], radius: 14),
                            ],
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            // ✅ input
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E201E),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.attach_file, color: Colors.white),
                      onPressed: _uploadFile,
                      tooltip: 'Upload file',
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        style: GoogleFonts.poppins(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Send Message",
                          hintStyle: GoogleFonts.poppins(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.1),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white),
                        onPressed: _sendMessage,
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
  }

  // ✅ build message content based on type
  Widget _buildMessageContent(Map<String, dynamic> data, bool isMe, String messageType) {
    if (messageType == 'image') {
      return GestureDetector(
        onTap: () => _showImageViewer(data["fileUrl"]),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 250, maxHeight: 250),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isMe ? Colors.blue.shade300 : Colors.grey.shade400,
              width: 2,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              data["fileUrl"],
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  height: 150,
                  color: Colors.grey[800],
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.blue),
                  ),
                );
              },
            ),
          ),
        ),
      );
    } else if (messageType == 'video') {
      return GestureDetector(
        onTap: () => _showVideoPlayer(data["fileUrl"]),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 250, maxHeight: 150),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isMe ? Colors.blue.shade300 : Colors.grey.shade400,
              width: 2,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.play_circle_fill, color: Colors.white, size: 50),
                    const SizedBox(height: 8),
                    Text(
                      data["fileName"] ?? "Video",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } else if (messageType == 'file') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? Colors.blue : Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.insert_drive_file,
              color: isMe ? Colors.white : Colors.black,
              size: 24,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                data["fileName"] ?? "File",
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.black,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    } else if (messageType == 'video_call') {
      // Video call message
      final callStatus = data["status"] ?? "active";
      final isEnded = callStatus == "ended";
      final participantCount = data["participantCount"] ?? 0;
      final hasParticipants = participantCount > 0;

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isEnded
                ? [Colors.grey.shade400, Colors.grey.shade600]
                : hasParticipants
                ? [Colors.green.shade400, Colors.green.shade600]
                : [Colors.orange.shade400, Colors.orange.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: isEnded
                  ? Colors.grey.withOpacity(0.3)
                  : hasParticipants
                  ? Colors.green.withOpacity(0.3)
                  : Colors.orange.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isEnded ? Icons.call_end : Icons.video_camera_front,
              color: Colors.white,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              isEnded
                  ? "Video call ended"
                  : hasParticipants
                  ? "Video call in progress"
                  : "Video call started - waiting for participants",
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (!isEnded && hasParticipants) ...[
              const SizedBox(height: 8),
              Text(
                '$participantCount ${participantCount == 1 ? "participant" : "participants"}',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      );
    } else {
      // Text message
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? Colors.blue : Colors.grey[300],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: isMe ? const Radius.circular(12) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(12),
          ),
        ),
        child: Text(
          data["text"] ?? "",
          style: TextStyle(
            color: isMe ? Colors.white : Colors.black,
            fontSize: 15,
          ),
        ),
      );
    }
  }

  // ✅ show image viewer
  void _showImageViewer(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                panEnabled: true,
                boundaryMargin: const EdgeInsets.all(20),
                minScale: 0.5,
                maxScale: 4,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 20,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ show video player
  void _showVideoPlayer(String videoUrl) {
    showDialog(
      context: context,
      builder: (context) => VideoPlayerDialog(videoUrl: videoUrl),
    );
  }

  // Show class info dialog
  void _showClassInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue.shade50,
                  Colors.white,
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.school,
                    size: 40,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(height: 20),
                
                // Title
                Text(
                  widget.className,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                
                // Description
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Classroom Chat',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'This is your private classroom chat. You can communicate with all students enrolled in this class. Use this space to share announcements, answer questions, and facilitate discussions.',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Close button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: Text(
                      'Got it!',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
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
}

/// ✅ Video Player Dialog Widget
class VideoPlayerDialog extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerDialog({super.key, required this.videoUrl});

  @override
  State<VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<VideoPlayerDialog> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        setState(() {
          _isInitialized = true;
        });
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Center(
            child: _isInitialized
                ? AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  )
                : const CircularProgressIndicator(color: Colors.white),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          if (_isInitialized)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 40,
                    ),
                    onPressed: () {
                      setState(() {
                        _controller.value.isPlaying
                            ? _controller.pause()
                            : _controller.play();
                      });
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}