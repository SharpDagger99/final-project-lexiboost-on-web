# Firebase Storage Deletion Fix - Documentation

## Problem Summary

When deleting a game from the game editor, **only Firestore documents were deleted**, leaving all uploaded images and audio files orphaned in Firebase Storage. This created:
- **Storage bloat** - Unused files accumulating over time
- **Cost issues** - Paying for storage of deleted game assets
- **Storage conflicts** - No way to clean up old files

---

## Root Cause

The original `_deleteGame()` function only deleted Firestore documents:
```dart
// ❌ OLD CODE - Only deletes Firestore
for (var doc in gameRoundsSnapshot.docs) {
  await doc.reference.delete();  // Only Firestore deletion
}
await gameDocRef.delete();
```

**Missing:** No logic to delete files from Firebase Storage before deleting the database records.

---

## Solution Implemented

### ✅ **Three New Functions Added**

#### 1. **`_deleteFileFromStorage(String fileUrl)`**
Deletes a single file from Firebase Storage given its URL.

**Features:**
- Handles both `gs://` and `https://` URL formats
- Parses Firebase Storage URLs correctly
- Skips placeholder/default URLs
- Graceful error handling (doesn't throw if file not found)

**Supported URL Formats:**
```dart
// gs:// format
"gs://lexiboost-36801.firebasestorage.app/game image/my_image.png"

// https:// format  
"https://firebasestorage.googleapis.com/v0/b/bucket/o/game%20image%2Fmy_image.png?alt=media&token=..."
```

#### 2. **`_collectStorageUrls()`**
Collects all storage URLs from all pages in a game.

**What it does:**
1. Queries all `game_rounds` for the game
2. For each round, gets the `game_type` subcollection data
3. Extracts URLs based on game type:
   - **Fill in the blank 2**: `imageUrl`
   - **Guess the answer**: `image`
   - **Guess the answer 2**: `image1`, `image2`, `image3`
   - **What is it called**: `image`
   - **Listen and Repeat**: `audio`
   - **Image Match**: `image1` through `image8`

**Returns:** List of all storage URLs to delete

#### 3. **`_collectPageStorageUrls(PageData pageData)`**
Collects storage URLs from a single page (used when deleting individual pages).

**What it does:**
- Extracts URLs from PageData object based on game type
- Checks all relevant fields (imageUrl, guessAnswerImageUrls, etc.)
- Returns list of URLs for that specific page

---

## Updated Functions

### ✅ **`_deleteGame()` - Now deletes Storage files**

**New workflow:**
```dart
// Step 1: Collect all storage URLs
final storageUrls = await _collectStorageUrls();

// Step 2: Delete all files from Storage
for (final url in storageUrls) {
  await _deleteFileFromStorage(url);
}

// Step 3: Delete game_type subcollection documents
// Step 4: Delete game_rounds documents  
// Step 5: Delete main game document
```

**Benefits:**
- Files deleted BEFORE Firestore documents (prevents orphaned URLs)
- Detailed debug logging
- Error messages shown to user if deletion fails

### ✅ **`_deletePageFromFirestore()` - Now deletes Storage files for single page**

**New workflow:**
```dart
// Step 1: Collect storage URLs from this page
final storageUrls = await _collectPageStorageUrls(pageData);

// Step 2: Delete storage files
for (final url in storageUrls) {
  await _deleteFileFromStorage(url);
}

// Step 3: Delete game_type subcollection
// Step 4: Delete round document
// Step 5: Update page numbers for remaining pages
```

**Benefits:**
- When you delete a single page/round, its images are also deleted
- Keeps storage clean even with partial deletions

---

## How It Works

### **Deleting Entire Game:**

```
User clicks "Delete" button
    ↓
_showDeleteConfirmationDialog()
    ↓
User confirms deletion
    ↓
_deleteGame() executes:
    ↓
1. _collectStorageUrls()
   - Queries game_rounds collection
   - Gets game_type data for each round
   - Extracts all image/audio URLs
   - Returns: ["url1", "url2", "url3", ...]
    ↓
2. For each URL: _deleteFileFromStorage(url)
   - Parses URL to get file path
   - Deletes from Firebase Storage
   - Logs success/failure
    ↓
3. Delete Firestore documents
   - Delete game_type subcollections
   - Delete game_rounds documents
   - Delete main game document
    ↓
4. Navigate away
```

### **Deleting Single Page:**

```
User clicks page delete button
    ↓
_deletePage() dialog
    ↓
User confirms
    ↓
_deletePageFromFirestore(pageIndex)
    ↓
1. _collectPageStorageUrls(pageData)
   - Gets URLs from PageData object
   - Based on game type
    ↓
2. For each URL: _deleteFileFromStorage(url)
    ↓
3. Delete game_type document
    ↓
4. Delete round document
    ↓
5. Update page numbers for subsequent pages
```

---

## Storage URL Patterns by Game Type

| Game Type | Fields with URLs | Example Path |
|-----------|-----------------|--------------|
| Fill in the blank 2 | `imageUrl` | `game image/fill_the_blank2_*.png` |
| Guess the answer | `image` | `game image/guess_the_answer_*.png` |
| Guess the answer 2 | `image1`, `image2`, `image3` | `game image/guess_the_answer_image1_*.png` |
| What is it called | `image` | `game image/what_called_image_*.png` |
| Listen and Repeat | `audio` | `gameAudio/listen_and_repeat_audio_*.m4a` |
| Image Match | `image1` to `image8` | `game image/image_match_1_*.png` |

---

## Error Handling

### **Graceful Degradation:**
- If a file doesn't exist in Storage, logs error but continues
- If URL parsing fails, skips that file but continues
- Shows user-friendly error messages via SnackBar

### **Debug Logging:**
All operations are logged for debugging:
```dart
debugPrint('Collecting storage URLs for game: $gameId');
debugPrint('Deleting 5 files from Storage...');
debugPrint('Successfully deleted file from Storage: game image/my_image.png');
debugPrint('Failed to delete file from Storage (url): File not found');
debugPrint('Game deleted successfully (including 5 storage files)');
```

---

## Testing Checklist

### ✅ **Test Full Game Deletion:**

1. **Create a test game** with multiple pages
2. **Add images** to different game types:
   - [ ] Fill in the blank 2 (1 image)
   - [ ] Guess the answer (1 image)
   - [ ] Guess the answer 2 (3 images)
   - [ ] What is it called (1 image)
   - [ ] Image Match (2-4 pairs = 4-8 images)
   - [ ] Listen and Repeat (1 audio file)
3. **Save the game**
4. **Check Firebase Storage** - verify files are uploaded
5. **Delete the game** using the delete button
6. **Check Firebase Storage again** - verify all files are deleted
7. **Check Firestore** - verify all documents are deleted

### ✅ **Test Single Page Deletion:**

1. **Create a game** with 3 pages, each with images
2. **Save the game**
3. **Note the image URLs** in Firebase Storage
4. **Delete the middle page** (page 2)
5. **Verify:**
   - [ ] Page 2 images deleted from Storage
   - [ ] Page 1 and Page 3 images still exist
   - [ ] Firestore documents updated correctly
   - [ ] Page numbers renumbered (old page 3 becomes page 2)

### ✅ **Test Error Scenarios:**

1. **Delete game with missing storage file:**
   - Manually delete a file from Storage
   - Then delete the game
   - [ ] Should complete successfully with logged error

2. **Delete game with malformed URL:**
   - Manually edit Firestore to have invalid URL
   - Delete the game
   - [ ] Should skip that file and delete others

3. **Delete game while offline:**
   - Disconnect internet
   - Try to delete game
   - [ ] Should show error message to user

---

## Additional Considerations

### **⚠️ Existing Games:**
Games created **before this fix** may have orphaned files in Storage. You may want to:
1. Run a cleanup script to find orphaned files
2. Or manually delete old unused files from Firebase Console

### **🔒 Security:**
Ensure Firebase Storage security rules allow deletion:
```javascript
service firebase.storage {
  match /b/{bucket}/o {
    match /game image/{imageId} {
      allow delete: if request.auth != null;
    }
    match /gameAudio/{audioId} {
      allow delete: if request.auth != null;
    }
  }
}
```

### **💰 Cost Savings:**
With this fix, you'll save on Firebase Storage costs by:
- Not accumulating orphaned files
- Immediately freeing up space when games are deleted
- Avoiding storage quota limits

---

## Summary

### **Before Fix:**
```
Delete Game → ❌ Images remain in Storage → Storage bloat
```

### **After Fix:**
```
Delete Game → ✅ Images deleted from Storage → ✅ Firestore deleted → Clean storage
```

### **Key Improvements:**
✅ Automatic storage cleanup on game deletion  
✅ Automatic storage cleanup on page deletion  
✅ Handles all game types (9 different types)  
✅ Handles all file types (images + audio)  
✅ Supports both URL formats (gs:// and https://)  
✅ Graceful error handling  
✅ Detailed debug logging  
✅ User-friendly error messages  

**Your Firebase Storage will now stay clean! 🎉**

