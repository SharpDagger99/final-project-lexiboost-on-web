# URL-Based Navigation Guide for LexiBoost Web

## Overview
All game management pages now support URL-based navigation with query parameters, allowing data to persist when users refresh the page.

## Navigation Flow with URL Parameters

### 1. game_published → game_manage
**URL Format:**
```
/game_manage?gameId={id}&title={title}&gameSet={set}&gameCode={code}&userId={uid}
```

**Example:**
```
/game_manage?gameId=abc123&title=Math%20Quiz&gameSet=Elementary&gameCode=GAME123&userId=teacher456
```

### 2. game_manage → game_check
**URL Format:**
```
/game_check?gameId={id}&title={title}&userId={uid}&studentUserId={sid}&studentUsername={name}
```

**Example:**
```
/game_check?gameId=abc123&title=Math%20Quiz&userId=teacher456&studentUserId=student789&studentUsername=John%20Doe
```

### 3. game_check → game_manage (Back Navigation)
**URL Format:**
```
/game_manage?gameId={id}&title={title}&userId={uid}
```

## How Data Restoration Works

### On Page Load:
1. **Parse URL Parameters** - Extract query parameters from `Uri.base`
2. **Check Get.arguments** - Fallback to GetX arguments if available
3. **Fetch Missing Data** - Query Firestore for any missing fields
4. **Load Complete Data** - Proceed with full data context

### game_manage.dart Data Restoration:
```dart
// Automatically fetches from Firestore if missing:
- title (from users/{userId}/created_games/{gameId})
- gameSet (from users/{userId}/created_games/{gameId})
- gameCode (from users/{userId}/created_games/{gameId})
```

### game_check.dart Data Restoration:
```dart
// Automatically fetches from Firestore if missing:
- title (from users/{userId}/created_games/{gameId})
- studentUsername (from users/{studentUserId})
```

## Testing Instructions

### Test 1: Navigate and Refresh game_manage
1. Go to Published Games
2. Click "Manage" on any game
3. **Refresh the page (F5)**
4. ✅ Expected: Page reloads with all game data intact
5. ❌ If fails: Check browser console for debug logs starting with 🔍 or 📥

### Test 2: Navigate and Refresh game_check
1. Go to Published Games → Manage
2. Click on a student to review their submission
3. **Refresh the page (F5)**
4. ✅ Expected: Page reloads with student submission data
5. ❌ If fails: Check browser console for debug logs

### Test 3: Back Navigation
1. From game_check, click "Back"
2. ✅ Expected: Returns to game_manage with all data
3. From game_manage, click back arrow
4. ✅ Expected: Returns to game_published

## Debug Logging

All pages now include comprehensive debug logging:

### game_manage.dart logs:
```
🔍 game_manage: Checking data sources...
  Get.arguments: {gameId: abc123, ...}
  URL: http://localhost:port/game_manage?gameId=abc123&...
  URL query params: {gameId: abc123, title: Math Quiz, ...}
📥 game_manage arguments parsed:
  gameId: abc123
  title: Math Quiz
  gameSet: Elementary
  gameCode: GAME123
  userId: teacher456
✅ Valid arguments, loading data...
✅ Game details fetched: title=Math Quiz, gameSet=Elementary, gameCode=GAME123
```

### game_check.dart logs:
```
📥 MyGameCheck: Getting arguments...
📥 Received arguments: {gameId: abc123, ...}
📥 Parsed values:
  gameId: abc123
  title: Math Quiz
  userId: teacher456
  studentUserId: student789
  studentUsername: John Doe
✅ Arguments valid, loading submission data...
✅ Fetched game title: Math Quiz
✅ Fetched student username: John Doe
```

## Troubleshooting

### Issue: "No game data found" after refresh
**Solution:**
1. Open browser DevTools (F12)
2. Check Console for debug logs
3. Verify URL contains query parameters
4. Check if Firestore fetch succeeded

### Issue: URL parameters not appearing
**Solution:**
1. Verify navigation uses `Get.toNamed()` with URL parameters
2. Check that `Uri.encodeComponent()` is used for special characters
3. Ensure route is defined in `main.dart`

### Issue: Data loads but some fields are missing
**Solution:**
1. Check if `_fetchGameDetails()` or `_fetchMissingDetails()` is called
2. Verify Firestore document structure matches expected fields
3. Check userId matches the document owner

## Files Modified

1. **lib/main.dart** - Added `/game_check` route
2. **lib/editor/game_published.dart** - Updated navigation to include URL params
3. **lib/editor/game_manage.dart** - Added URL parsing and data fetching
4. **lib/editor/game_check.dart** - Added URL parsing and data fetching

## Benefits

✅ **Data Persistence** - Page refreshes don't lose context
✅ **Shareable URLs** - Teachers can bookmark specific game management pages
✅ **Better UX** - No "no data found" errors after refresh
✅ **Debugging** - Comprehensive logging for troubleshooting
✅ **Fallback Support** - Works with both GetX arguments and URL parameters
