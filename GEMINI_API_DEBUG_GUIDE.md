# Gemini API Debug Guide

## Latest Updates

### Gemini 2.0 Flash Model
- Updated to use `gemini-2.0-flash-exp` (latest, fastest model)
- Better JSON format compliance
- Faster generation times

### Image-Required Game Types Warning
Game types that require manual image upload now show:
- ⚠️ Confirmation dialog when selected
- 🖼️ Orange icon in dropdown menu
- 🟠 Orange border on selected chips
- ℹ️ Info banner when any image-required type is selected

**Image-Required Game Types:**
- Image Match
- What is it called
- Listen and Repeat
- Guess the answer 2
- Fill in the blank 2

## Changes Made

### 1. Enhanced Error Logging in `gemini.dart`

Added comprehensive debug logging throughout the API calls:

- **Request logging**: Shows URL, prompt length, and request body size
- **Response logging**: Shows status code, response body length, and finish reason
- **Error logging**: Detailed error messages for all HTTP status codes (400, 403, 429, 500, 503)
- **JSON parsing logging**: Shows each step of JSON extraction and parsing
- **Exception logging**: Captures full exception details and stack traces

### 2. Enhanced Error Display in `game_quick.dart`

#### Edit Mode:
- Shows detailed error dialog with:
  - Error message
  - Full error details (API response)
  - Option to create basic structure as fallback
- Debug prints for all generation steps

#### Prompt Mode:
- Displays detailed errors in chat with:
  - Error message with emoji indicators
  - Error details (truncated to 300 chars)
  - Raw response preview (truncated to 200 chars)
- Error messages styled differently (red background, monospace font)
- Debug prints for all generation steps

## How to Debug API Issues

### Step 1: Check Debug Console

When you run the app and try to generate an activity, look for these debug messages:

```
=== EDIT MODE: Starting AI generation ===
Game Types: [Fill in the blank, Math]
Difficulty: easy
Total Pages: 5

=== Gemini API Request ===
URL: https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=API_KEY_HIDDEN
Prompt length: 1234 characters
Request body size: 2345 bytes

=== Gemini API Response ===
Status: 200
Response body length: 5678 bytes
```

### Step 2: Check for Common Errors

#### Error 400 - Bad Request
- **Cause**: Invalid request format or parameters
- **Look for**: "Invalid request" message
- **Check**: Request body structure in debug logs

#### Error 403 - Forbidden
- **Cause**: Invalid API key or insufficient permissions
- **Look for**: "API key is invalid" message
- **Solution**: Verify API key in `gemini.dart`

#### Error 429 - Too Many Requests
- **Cause**: Rate limit exceeded
- **Look for**: "Too many requests" message
- **Solution**: Wait a few minutes before trying again

#### JSON Parse Error
- **Cause**: AI returned non-JSON or malformed JSON
- **Look for**: "Failed to parse AI response" message
- **Check**: Raw response in error details

### Step 3: View Error Details in UI

#### In Edit Mode:
1. Try to generate an activity
2. If it fails, a dialog will appear with:
   - Error message
   - Full error details (scrollable)
   - Option to create basic structure

#### In Prompt Mode:
1. Type a prompt and send
2. If it fails, the error appears in chat with:
   - ❌ Error message
   - 📋 Details section
   - 📄 Response preview

### Step 4: Common Solutions

1. **API Key Issues**:
   - Verify the API key in `lib/editor/gemini.dart`
   - Check if the key has Gemini API access enabled
   - Ensure billing is enabled in Google Cloud Console

2. **Network Issues**:
   - Check internet connection
   - Look for timeout errors in debug console
   - Try increasing timeout in code (currently 60 seconds)

3. **Content Blocked**:
   - Look for "SAFETY" finish reason in logs
   - Modify your prompt to be more educational/appropriate
   - Check safety ratings in error details

4. **JSON Parse Errors**:
   - Check raw response in error details
   - AI might be returning markdown instead of pure JSON
   - Code attempts to clean markdown automatically

## Testing the API

### Quick Test - Edit Mode:
1. Open game_quick.dart
2. Select "Edit Mode"
3. Choose 1-2 game types
4. Set total pages to 3
5. Click Generate
6. Check debug console for detailed logs

### Quick Test - Prompt Mode:
1. Open game_quick.dart
2. Select "Prompt Mode"
3. Type: "Create a simple math activity for grade 1"
4. Click Send
5. Check debug console and chat for errors

## Debug Output Examples

### Successful Request:
```
=== PROMPT MODE: Starting AI generation ===
User Prompt: Create a math activity
Has Document: false
=== Gemini API Request ===
URL: https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=API_KEY_HIDDEN
Prompt length: 1500 characters
Request body size: 2000 bytes
=== Gemini API Response ===
Status: 200
Response body length: 3000 bytes
Response parsed successfully
Finish reason: STOP
✅ Generated text length: 2500 characters
Attempting to parse JSON directly...
✅ JSON parsed successfully!
=== PROMPT MODE: AI generation result ===
Success: true
```

### Failed Request (API Key Error):
```
=== Gemini API Response ===
Status: 403
Response body length: 150 bytes
❌ API Error 403 - Forbidden
Response: {"error": {"code": 403, "message": "API key not valid"}}
=== PROMPT MODE: AI generation result ===
Success: false
Error: API key is invalid or has insufficient permissions.
Details: {"error": {"code": 403, "message": "API key not valid"}}
```

## Next Steps

If you're still experiencing issues after checking the debug logs:

1. Copy the full debug output from console
2. Check the error details shown in the UI
3. Verify your API key has proper permissions
4. Test the API key directly using curl or Postman
5. Check Google Cloud Console for API quotas and billing

## API Key Setup

To get a working Gemini API key:

1. Go to https://makersuite.google.com/app/apikey
2. Create a new API key
3. Enable the Gemini API
4. Replace the key in `lib/editor/gemini.dart`:
   ```dart
   static const String apiKey = 'YOUR_NEW_API_KEY_HERE';
   ```
