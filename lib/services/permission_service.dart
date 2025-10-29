// ignore_for_file: avoid_print

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';

class PermissionService {
  /// Request camera and microphone permissions
  /// Returns true if permissions are granted, false otherwise
  static Future<bool> requestVideoCallPermissions() async {
    if (kIsWeb) {
      // On web, permissions are handled by the browser automatically
      // when Agora SDK calls getUserMedia internally
      print('Web platform: Permissions will be requested by browser');
      return true;
    } else {
      // On mobile, use permission_handler
      print('Mobile platform: Requesting permissions via permission_handler');
      try {
        Map<Permission, PermissionStatus> statuses = await [
          Permission.camera,
          Permission.microphone,
        ].request();

        bool cameraGranted = statuses[Permission.camera]?.isGranted ?? false;
        bool micGranted = statuses[Permission.microphone]?.isGranted ?? false;

        if (!cameraGranted || !micGranted) {
          print('Permissions denied - Camera: $cameraGranted, Mic: $micGranted');
          
          // Check if permanently denied
          bool cameraPermanentlyDenied = 
              statuses[Permission.camera]?.isPermanentlyDenied ?? false;
          bool micPermanentlyDenied = 
              statuses[Permission.microphone]?.isPermanentlyDenied ?? false;
          
          if (cameraPermanentlyDenied || micPermanentlyDenied) {
            print('Permissions permanently denied. User must enable in Settings.');
            // Could open app settings here
            // await openAppSettings();
          }
          
          return false;
        }

        print('All permissions granted');
        return true;
      } catch (e) {
        print('Error requesting permissions: $e');
        return false;
      }
    }
  }

  /// Initialize Agora engine with permission-aware configuration
  /// This will trigger browser permission prompts on web
  static Future<bool> initializeAgoraWithPermissions(
    RtcEngine engine,
  ) async {
    try {
      print('Initializing Agora engine...');
      
      // Enable video first - this triggers permission prompt on web
      await engine.enableVideo();
      print('Video enabled');
      
      // Enable audio - this also triggers permission prompt on web
      await engine.enableAudio();
      print('Audio enabled');
      
      // Start preview - this actually accesses the camera
      await engine.startPreview();
      print('Preview started - permissions should be requested now');
      
      return true;
    } catch (e) {
      print('Error initializing Agora with permissions: $e');
      
      // Check if it's a permission error
      if (e.toString().contains('NotAllowedError') ||
          e.toString().contains('PermissionDenied') ||
          e.toString().contains('Permission denied')) {
        print('Permission error detected: User denied camera/microphone access');
        return false;
      }
      
      // Other errors
      return false;
    }
  }

  /// Check if permissions are already granted (mobile only)
  static Future<bool> checkPermissions() async {
    if (kIsWeb) {
      // On web, we can't check permissions beforehand
      // Browser will prompt when needed
      return true;
    }

    try {
      PermissionStatus cameraStatus = await Permission.camera.status;
      PermissionStatus micStatus = await Permission.microphone.status;

      return cameraStatus.isGranted && micStatus.isGranted;
    } catch (e) {
      print('Error checking permissions: $e');
      return false;
    }
  }

  /// Get permission error message based on platform
  static String getPermissionErrorMessage() {
    if (kIsWeb) {
      return 'Camera and microphone access is required for video calls.\n\n'
          'Please click "Allow" when your browser asks for permissions.\n\n'
          'If you blocked permissions, click the camera icon in your browser\'s '
          'address bar and reset permissions.';
    } else {
      return 'Camera and microphone permissions are required for video calls.\n\n'
          'Please grant permissions when prompted.\n\n'
          'If you denied permissions, you can enable them in Settings.';
    }
  }
}

