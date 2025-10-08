# Firestore Settings Implementation Guide

## 🎯 **Problem Solved**

**Issue**: User settings (like Auto Save toggle) were resetting to default when leaving and returning to the website.

**Solution**: Implemented persistent user settings storage in Firestore, tied to each user's unique account.

## 🗄️ **Firestore Data Structure**

### **Collection Structure**
```
users (collection)
  └── {userId} (document)
      └── settings (subcollection)
          └── user_preferences (document)
              ├── autoSave: true/false
              └── updated_at: timestamp
```

### **Example Document**
```json
{
  "autoSave": true,
  "updated_at": "2024-01-15T10:30:00Z"
}
```

## 🔧 **Implementation Details**

### **1. Settings Service (`lib/services/settings_service.dart`)**

#### **Key Features:**
- **Singleton Pattern**: Global access to settings
- **Firestore Integration**: Saves/loads from user's document
- **Memory Caching**: Fast access with `_settingsLoaded` flag
- **Error Handling**: Graceful fallbacks to defaults
- **User Authentication**: Tied to Firebase Auth user

#### **Core Methods:**
```dart
// Get auto-save setting (loads from Firestore if needed)
Future<bool> getAutoSaveEnabled() async

// Set auto-save setting (saves to Firestore immediately)
Future<void> setAutoSaveEnabled(bool enabled) async

// Force reload from Firestore (useful for login/logout)
Future<void> reloadSettings() async

// Get all settings as a map
Future<Map<String, dynamic>> getAllSettings() async
```

#### **Firestore Operations:**
```dart
// Load settings from Firestore
Future<void> _loadSettingsFromFirestore() async {
  final settingsRef = FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('settings')
      .doc('user_preferences');
  
  final doc = await settingsRef.get();
  if (doc.exists) {
    _autoSaveEnabled = doc.data()!['autoSave'] ?? true;
  } else {
    // Create default settings document
    await _saveSettingsToFirestore();
  }
}

// Save settings to Firestore
Future<void> _saveSettingsToFirestore() async {
  await settingsRef.set({
    'autoSave': _autoSaveEnabled,
    'updated_at': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}
```

### **2. Enhanced Settings Page (`lib/admin/settings_admin.dart`)**

#### **New Features:**
- **Loading States**: Shows spinner while loading settings
- **Save States**: Disables button and shows spinner while saving
- **Error Handling**: User-friendly error messages
- **Real-time Updates**: Settings sync immediately with Firestore

#### **Loading Flow:**
```dart
// 1. Page loads → Show loading spinner
setState(() => _isLoading = true);

// 2. Load settings from Firestore
final autoSaveEnabled = await _settingsService.getAutoSaveEnabled();

// 3. Update UI with loaded settings
setState(() {
  _autoSaveEnabled = autoSaveEnabled;
  _isLoading = false;
});
```

#### **Saving Flow:**
```dart
// 1. User clicks Save → Show saving spinner
setState(() => _isSaving = true);

// 2. Save to Firestore
await _settingsService.setAutoSaveEnabled(_autoSaveEnabled);

// 3. Show success message
setState(() => _isSaving = false);
```

## 🎮 **User Experience Flow**

### **First Visit (New User)**
1. User opens Settings page
2. System checks Firestore → No settings found
3. Creates default settings document (`autoSave: true`)
4. UI shows toggle in "ON" position
5. User can change and save settings

### **Returning User**
1. User opens Settings page
2. System loads settings from Firestore
3. UI shows toggle in saved position (ON/OFF)
4. User's preferences are preserved

### **Settings Change**
1. User toggles Auto Save switch
2. UI updates immediately (local state)
3. User clicks "Save" button
4. Settings saved to Firestore
5. Success message appears
6. Settings persist across sessions

## 🔒 **Security & Data Integrity**

### **User Authentication**
- Settings are tied to `FirebaseAuth.instance.currentUser.uid`
- No settings access without authentication
- Each user has isolated settings

### **Error Handling**
```dart
try {
  await _saveSettingsToFirestore();
} catch (e) {
  // Show user-friendly error message
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Failed to save settings: $e'))
  );
}
```

### **Fallback Behavior**
- If Firestore is unavailable → Use default settings
- If user is not logged in → Use default settings
- If loading fails → Show error but don't crash

## 🚀 **Performance Optimizations**

### **Memory Caching**
```dart
bool _settingsLoaded = false;

Future<bool> getAutoSaveEnabled() async {
  // Only load from Firestore once per session
  if (!_settingsLoaded) {
    await _loadSettingsFromFirestore();
  }
  return _autoSaveEnabled;
}
```

### **Efficient Firestore Usage**
- Uses `SetOptions(merge: true)` to avoid overwriting
- Single document per user (not multiple documents)
- Timestamps for tracking updates

## 🔄 **Integration with Game Editor**

### **Auto-Save Control**
The game editor now respects the Firestore settings:

```dart
// In game_edit.dart
void _triggerAutoSave() async {
  final autoSaveEnabled = await _settingsService.getAutoSaveEnabled();
  if (!autoSaveEnabled) {
    setState(() => _autoSaveStatus = 'Auto-save disabled');
    return; // Skip auto-save
  }
  // Continue with normal auto-save logic...
}
```

### **Real-time Updates**
- Settings changes take effect immediately
- No app restart required
- Game editor checks settings on each interaction

## 📊 **Firestore Rules (Recommended)**

```javascript
// Firestore Security Rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only access their own settings
    match /users/{userId}/settings/{document} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## 🎯 **Benefits Achieved**

### **✅ Persistent Settings**
- Settings survive browser refresh
- Settings survive app restart
- Settings survive device changes

### **✅ User-Specific**
- Each user has their own settings
- Settings tied to user account
- No cross-user data leakage

### **✅ Real-time Sync**
- Changes save immediately
- No data loss on navigation
- Consistent experience across sessions

### **✅ Error Resilient**
- Graceful fallbacks to defaults
- User-friendly error messages
- No app crashes on network issues

## 🔮 **Future Enhancements**

### **Additional Settings**
```dart
// Easy to add more settings
Future<void> updateSettings(Map<String, dynamic> settings) async {
  if (settings.containsKey('autoSave')) {
    _autoSaveEnabled = settings['autoSave'] as bool;
  }
  if (settings.containsKey('theme')) {
    _theme = settings['theme'] as String;
  }
  if (settings.containsKey('language')) {
    _language = settings['language'] as String;
  }
  await _saveSettingsToFirestore();
}
```

### **Settings Categories**
```dart
// Organize settings by category
{
  "editor": {
    "autoSave": true,
    "autoSaveInterval": 10
  },
  "ui": {
    "theme": "dark",
    "language": "en"
  },
  "notifications": {
    "emailAlerts": false,
    "pushNotifications": true
  }
}
```

### **Settings Backup/Restore**
```dart
// Export/import settings
Future<Map<String, dynamic>> exportSettings() async {
  return await getAllSettings();
}

Future<void> importSettings(Map<String, dynamic> settings) async {
  await updateSettings(settings);
}
```

## 🎉 **Summary**

**The settings are now fully persistent and user-specific!**

- ✅ **Firestore Storage**: Settings saved to user's document
- ✅ **User Authentication**: Tied to Firebase Auth user ID
- ✅ **Loading States**: Smooth UX with spinners and feedback
- ✅ **Error Handling**: Graceful fallbacks and user messages
- ✅ **Real-time Sync**: Changes take effect immediately
- ✅ **Performance**: Memory caching and efficient Firestore usage

**Users can now customize their experience and have their preferences remembered across all sessions! 🎮✨**
