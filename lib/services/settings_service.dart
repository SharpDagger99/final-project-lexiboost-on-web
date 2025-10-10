import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsService {
  // Singleton pattern
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  // Cache settings in memory for quick access
  bool _autoSaveEnabled = true;
  bool _settingsLoaded = false;

  /// Get the current auto-save setting
  Future<bool> getAutoSaveEnabled() async {
    // If settings haven't been loaded yet, load them first
    if (!_settingsLoaded) {
      await _loadSettingsFromFirestore();
    }
    return _autoSaveEnabled;
  }

  /// Set the auto-save setting
  Future<void> setAutoSaveEnabled(bool enabled) async {
    _autoSaveEnabled = enabled;
    await _saveSettingsToFirestore();
    debugPrint('Auto-save setting updated: $enabled');
  }

  /// Check if auto-save is enabled (synchronous version for immediate use)
  bool getAutoSaveEnabledSync() {
    return _autoSaveEnabled;
  }

  /// Load user settings from Firestore
  Future<void> _loadSettingsFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('No user logged in - using default settings');
      _settingsLoaded = true;
      return;
    }

    try {
      final settingsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('user_preferences');

      final doc = await settingsRef.get();
      
      if (doc.exists) {
        final data = doc.data()!;
        _autoSaveEnabled = data['autoSave'] ?? true; // Default to true
        debugPrint('Settings loaded from Firestore: autoSave=$_autoSaveEnabled');
      } else {
        // No settings document exists, use defaults
        debugPrint('No settings found in Firestore - using defaults');
        _autoSaveEnabled = true;
        // Create default settings document
        await _saveSettingsToFirestore();
      }
    } catch (e) {
      debugPrint('Failed to load settings from Firestore: $e');
      // Use default values if loading fails
      _autoSaveEnabled = true;
    }
    
    _settingsLoaded = true;
  }

  /// Save user settings to Firestore
  Future<void> _saveSettingsToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('No user logged in - cannot save settings');
      return;
    }

    try {
      final settingsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('user_preferences');

      await settingsRef.set({
        'autoSave': _autoSaveEnabled,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('Settings saved to Firestore: autoSave=$_autoSaveEnabled');
    } catch (e) {
      debugPrint('Failed to save settings to Firestore: $e');
      rethrow; // Re-throw so the UI can handle the error
    }
  }

  /// Force reload settings from Firestore (useful when user logs in/out)
  Future<void> reloadSettings() async {
    _settingsLoaded = false;
    await _loadSettingsFromFirestore();
  }

  /// Get all user settings as a map
  Future<Map<String, dynamic>> getAllSettings() async {
    if (!_settingsLoaded) {
      await _loadSettingsFromFirestore();
    }
    
    return {
      'autoSave': _autoSaveEnabled,
    };
  }

  /// Update multiple settings at once
  Future<void> updateSettings(Map<String, dynamic> settings) async {
    if (settings.containsKey('autoSave')) {
      _autoSaveEnabled = settings['autoSave'] as bool;
    }
    
    await _saveSettingsToFirestore();
    debugPrint('Multiple settings updated: $settings');
  }

  /// Force refresh settings from Firestore (useful for testing)
  Future<void> forceRefresh() async {
    _settingsLoaded = false;
    await _loadSettingsFromFirestore();
    debugPrint('Settings force refreshed: autoSave=$_autoSaveEnabled');
  }
}
