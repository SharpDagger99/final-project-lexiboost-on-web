# Data Persistence Testing Guide

## Overview
Both `game_manage.dart` and `game_check.dart` now properly restore all data and UI appearance when the page is refreshed. This guide helps you verify the implementation.

---

## ✅ What Has Been Fixed

### **1. game_manage.dart**
- ✅ All state variables now update with `setState()`
- ✅ URL parameters are parsed on page load
- ✅ Missing data is fetched from Firestore automatically
- ✅ UI re-renders with complete data after refresh
- ✅ Comprehensive debug logging added

### **2. game_check.dart**
- ✅ All state variables now update with `setState()`
- ✅ URL parameters are parsed on page load
- ✅ Missing data is fetched from Firestore automatically
- ✅ UI re-renders with complete student submission data
- ✅ Comprehensive debug logging added

---

## 🧪 Testing Instructions

### **Test 1: game_manage.dart Data Persistence**

#### Step 1: Navigate to game_manage
1. Go to Published Games page
2. Click "Manage" button on any game
3. Page should load with:
   - Game title in AppBar
   - Control buttons (Unpublish, Lock, Edit, Check)
   - Status cards showing data
   - Student list

#### Step 2: Refresh the page
1. **Press F5** or click browser refresh
2. **Expected Result**: 
   - ✅ Page reloads completely
   - ✅ Game title still appears in AppBar
   - ✅ All control buttons remain visible
   - ✅ Status cards show correct data
   - ✅ Student list displays properly
   - ✅ No "No game data found" error

#### Step 3: Check browser console
1. Open DevTools (F12) → Console tab
2. Look for these log messages:
```
🔍 game_manage: Checking data sources...
  Get.arguments: null (if refreshed)
  URL: http://localhost:port/game_manage?gameId=...
  URL query params: {gameId: ..., title: ..., ...}
📥 game_manage arguments parsed:
  gameId: abc123
  title: Math Quiz
  gameSet: Elementary
  gameCode: GAME123
  userId: teacher456
✅ Valid arguments, loading data...
🔄 Fetching game details from Firestore... (if needed)
✅ Game details fetched and updated:
  title: Math Quiz
  gameSet: Elementary
  gameCode: GAME123
```

---

### **Test 2: game_check.dart Data Persistence**

#### Step 1: Navigate to game_check
1. From game_manage, click the purple "Check" button (with check icon)
2. OR click on a student from the list (if navigation was re-added)
3. Page should load with:
   - Game title and student name in header
   - Game rounds displayed
   - Student answers visible
   - Score information

#### Step 2: Refresh the page
1. **Press F5** or click browser refresh
2. **Expected Result**:
   - ✅ Page reloads completely
   - ✅ Game title still visible
   - ✅ Student name still displayed
   - ✅ All game rounds remain visible
   - ✅ Student submission data intact
   - ✅ No "Invalid submission data" error

#### Step 3: Check browser console
1. Open DevTools (F12) → Console tab
2. Look for these log messages:
```
📥 MyGameCheck: Getting arguments...
📥 No Get.arguments, trying URL parameters... (if refreshed)
  URL: http://localhost:port/game_check?gameId=...
  URL query params: {gameId: ..., studentUserId: ..., ...}
📥 Parsed values:
  gameId: abc123
  title: Math Quiz
  userId: teacher456
  studentUserId: student789
  studentUsername: John Doe
✅ Arguments valid, loading submission data...
🔄 Fetching missing details from Firestore... (if needed)
  Fetching game title...
  ✅ Game title fetched and updated: Math Quiz
  Fetching student username...
  ✅ Student username fetched and updated: John Doe
✅ Missing details fetch completed
```

---

## 🔍 Debugging Failed Tests

### **Issue: Page shows "No game data found" after refresh**

**Solutions:**

1. **Check URL Parameters**
   - Open DevTools → Console
   - Look for the log: `URL query params: {...}`
   - Verify parameters are present in URL

2. **Check Firestore Connection**
   - Verify Firebase is initialized
   - Check if user is authenticated
   - Look for error messages in console

3. **Check Navigation URLs**
   - Ensure navigation uses proper URL format:
     ```dart
     Get.toNamed(
       '/game_manage?gameId=$gameId&title=${Uri.encodeComponent(title ?? '')}...',
       arguments: {...}
     );
     ```

---

### **Issue: Some data missing but not all**

**Solutions:**

1. **Check which data is missing**
   - If title/gameSet/gameCode missing: Check `_fetchGameDetails()` logs
   - If studentUsername missing: Check `_fetchMissingDetails()` logs

2. **Verify Firestore document structure**
   - Path for game: `users/{userId}/created_games/{gameId}`
   - Path for user: `users/{userId}`
   - Check if documents exist with correct field names

3. **Check setState calls**
   - All data updates should be wrapped in `setState()`
   - Look for error: `setState() called after dispose()`

---

## 📊 Data Flow Diagram

### **game_manage.dart Flow**
```
Page Load/Refresh
  ↓
initState() → addPostFrameCallback
  ↓
_getArguments()
  ├─ Parse Get.arguments (if available)
  ├─ Parse URL parameters (if no arguments)
  └─ setState() with parsed values
  ↓
_loadData()
  ├─ setState(isLoading: true)
  ├─ _fetchGameDetails() [if title/gameSet/gameCode missing]
  │   └─ Fetch from Firestore → setState()
  ├─ _fetchCompletedUsers()
  ├─ _fetchMyStudentIds()
  ├─ _fetchGameRule()
  └─ setState(data + isLoading: false)
  ↓
UI Renders with Complete Data ✅
```

### **game_check.dart Flow**
```
Page Load/Refresh
  ↓
initState()
  ↓
_getArguments()
  ├─ Parse Get.arguments (if available)
  ├─ Parse URL parameters (if no arguments)
  └─ setState() with parsed values
  ↓
addPostFrameCallback
  ├─ _checkScreenSize()
  └─ _loadSubmissionData()
      ├─ _fetchMissingDetails() [if title/username missing]
      │   └─ Fetch from Firestore → setState()
      ├─ Load game rounds
      ├─ Load student scores
      └─ Load stroke submissions (if applicable)
  ↓
setState(pages + isLoading: false)
  ↓
UI Renders with Complete Data ✅
```

---

## ✨ Key Improvements

### **State Management**
- All data now properly updates using `setState()`
- Ensures UI re-renders when data changes
- Prevents stale UI with outdated data

### **URL-Based Navigation**
- Full URLs with query parameters
- Data persists in browser URL
- Shareable/bookmarkable pages

### **Firestore Fallback**
- Missing data fetched automatically
- No manual re-navigation needed
- Seamless user experience

### **Debug Logging**
- Comprehensive logging at each step
- Easy troubleshooting
- Clear success/error indicators

---

## 🎯 Expected Behavior Summary

| Page | On Refresh | Data Source | Fallback |
|------|-----------|-------------|----------|
| **game_manage** | ✅ Loads fully | URL params | Firestore fetch |
| **game_check** | ✅ Loads fully | URL params | Firestore fetch |
| **Title Display** | ✅ Persists | URL/Firestore | Always shown |
| **Student List** | ✅ Persists | Firestore query | Re-fetched |
| **Control Buttons** | ✅ Visible | Static UI | N/A |
| **Status Cards** | ✅ Shows data | Firestore query | Re-calculated |

---

## 📝 Notes

- **First Load**: Uses `Get.arguments` (faster)
- **Refresh**: Uses URL parameters + Firestore (reliable)
- **Network Required**: Firestore fetch needs internet
- **Auth Required**: User must be logged in
- **Performance**: Minimal overhead (only fetches missing data)

---

## ✅ Success Criteria

Both pages are working correctly if:
- ✅ No errors in console
- ✅ All data visible after refresh
- ✅ UI appears correctly
- ✅ Debug logs show successful data fetch
- ✅ Can navigate between pages and refresh multiple times

If all tests pass, the implementation is working correctly! 🎉
