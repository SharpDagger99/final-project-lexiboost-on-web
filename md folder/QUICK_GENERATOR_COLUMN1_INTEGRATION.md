# Quick Activity Generator - Column 1 Integration

## Overview
The Quick Activity Generator (`game_quick.dart`) is now integrated with the Game Editor (`game_edit.dart`) to automatically update Column 1 metadata fields when generating activities.

## What Gets Updated

### Column 1 Fields (Game Metadata)
When AI generates an activity, it can update:

#### Always Updated (if AI provides values):
- **Title**: Activity title (max 50 characters)
- **Description**: What the activity teaches (max 200 characters)
- **Difficulty**: Difficulty level (easy, normal, hard, etc.)
- **Game Rule**: Game rule type (none, heart, timer, score)

#### Conditionally Updated (ONLY if user explicitly requests):
- **Prize Coins**: Reward amount (e.g., 100, 500, 1000)
- **Game Set**: Public/Private setting
- **Game Code**: 6-digit code for private games
- **Heart**: Heart deduction enabled/disabled
- **Timer**: Timer countdown in seconds (e.g., 60, 120, 300)

### How to Request Advanced Settings

Users can request AI to set advanced settings by including them in their prompt:

**Examples:**
- "Create a math game with 500 prize coins"
- "Make a private game with code 123456"
- "Create an activity with a 2-minute timer"
- "Generate a game with heart deduction enabled"
- "Create a public game worth 1000 coins with a 5-minute timer"

## How It Works

### 1. User Opens Quick Generator from Game Editor
```dart
// In game_edit.dart, user clicks "Quick Generate" button
_navigateToGameQuick() {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => MyGameQuick(gameId: gameId),
    ),
  );
}
```

### 2. AI Generates Activity with Metadata
The AI generates (basic example):
```json
{
  "title": "Math Practice for Grade 3",
  "description": "Learn addition and subtraction with fun exercises",
  "gameTypes": ["Math", "Fill in the blank"],
  "difficulty": "easy",
  "gameRule": "score",
  "totalPages": 5,
  "pages": [...]
}
```

Or with advanced settings (if user requests):
```json
{
  "title": "Timed Math Challenge",
  "description": "Fast-paced math problems with rewards",
  "gameTypes": ["Math"],
  "difficulty": "hard",
  "gameRule": "timer",
  "totalPages": 10,
  "prizeCoins": 1000,
  "gameSet": "public",
  "heart": true,
  "timer": 300,
  "pages": [...]
}
```

### 3. Metadata is Saved to Firestore
```dart
// In game_quick.dart
Map<String, dynamic> gameMetadataUpdates = {
  'updated_at': FieldValue.serverTimestamp(),
};

// Basic metadata (always checked)
if (title != null && title.isNotEmpty) {
  gameMetadataUpdates['title'] = title;
}

if (description != null && description.isNotEmpty) {
  gameMetadataUpdates['description'] = description;
}

if (difficulty != null && difficulty.isNotEmpty) {
  gameMetadataUpdates['difficulty'] = difficulty;
}

if (gameRule != null && gameRule.isNotEmpty) {
  gameMetadataUpdates['gameRule'] = gameRule;
}

// Advanced settings (only if AI provides them)
if (prizeCoins != null) {
  gameMetadataUpdates['prizeCoins'] = prizeCoins.toString();
}

if (gameSet != null && (gameSet == 'public' || gameSet == 'private')) {
  gameMetadataUpdates['gameSet'] = gameSet;
}

if (gameCode != null && gameCode.isNotEmpty) {
  gameMetadataUpdates['gameCode'] = gameCode;
}

if (heart != null) {
  gameMetadataUpdates['heart'] = heart;
}

if (timer != null && timer >= 0) {
  gameMetadataUpdates['timer'] = timer;
}

await FirebaseFirestore.instance
    .collection('users')
    .doc(user.uid)
    .collection('created_games')
    .doc(gameId)
    .update(gameMetadataUpdates);
```

### 4. User Returns to Game Editor
When the user navigates back to `game_edit.dart`, the updated metadata is automatically loaded from Firestore.

## User Experience

### Automatic Updates
- AI-generated title and description are applied automatically
- Difficulty and game rule are set based on AI's analysis
- User sees a notification showing which fields were updated

### Manual Control
- User can still manually edit all Column 1 fields in the game editor
- Manual changes override AI-generated values
- User can regenerate activities to get new AI suggestions

## AI Prompt Guidelines

The AI is instructed to:
1. Generate appropriate titles based on activity content
2. Create descriptive summaries for the description field
3. Set difficulty based on content complexity
4. Choose appropriate game rules based on activity type
5. Parse user requests for advanced settings (coins, timer, heart, etc.)

### User Prompt Examples

#### Basic Prompts (Standard Metadata Only)
- "Create a vocabulary quiz for beginners"
- "Generate 10 math problems for grade 5"
- "Make a reading comprehension activity"

#### Advanced Prompts (With Custom Settings)
- "Create a math game with **500 prize coins**"
- "Generate a **private game** with code **123456**"
- "Make a quiz with a **3-minute timer**"
- "Create an activity with **heart deduction** enabled"
- "Generate a **public game** worth **1000 coins** with a **5-minute timer** and **hearts**"

#### Combined Prompts
- "Create a hard difficulty vocabulary game with 750 coins and a 2-minute timer"
- "Generate a private math challenge (code: 999888) with heart deduction and 1500 coin reward"
- "Make an easy reading activity for public access with 200 coins"

### AI Detection Keywords
The AI looks for these keywords to set advanced settings:
- **Prize Coins**: "coins", "prize", "reward", "points", "worth"
- **Game Set**: "public", "private", "access"
- **Game Code**: "code", "password", "pin" (for private games)
- **Heart**: "heart", "hearts", "lives", "health", "deduction"
- **Timer**: "timer", "time limit", "countdown", "minutes", "seconds"

## Benefits

1. **Time Saving**: Users don't need to manually fill in metadata or configure settings
2. **Consistency**: AI ensures metadata matches activity content
3. **Flexibility**: Users can still override AI suggestions
4. **Smart Defaults**: AI chooses appropriate difficulty and rules
5. **Natural Language Control**: Users can configure complex settings using simple prompts
6. **Complete Automation**: One prompt can configure all game settings and generate content
7. **Intelligent Parsing**: AI understands context and user intent from natural language

## Example Workflows

### Basic Workflow (Standard Metadata Only)
1. User creates a new game in Game Editor
2. User clicks "Quick Generate" button
3. User enters prompt: "Create a math activity for grade 3 students"
4. AI generates:
   - Title: "Grade 3 Math Practice"
   - Description: "Addition and subtraction exercises for elementary students"
   - Difficulty: "easy"
   - Game Rule: "score"
   - 5 pages of math activities
5. User returns to Game Editor and sees updated metadata
6. User can manually adjust any field if needed
7. User saves the complete game

### Advanced Workflow (With Custom Settings)
1. User creates a new game in Game Editor
2. User clicks "Quick Generate" button
3. User enters prompt: "Create a challenging math game with 1000 prize coins, 5-minute timer, and heart deduction enabled"
4. AI generates:
   - Title: "Timed Math Challenge"
   - Description: "Fast-paced math problems with high rewards"
   - Difficulty: "hard"
   - Game Rule: "timer"
   - Prize Coins: 1000
   - Heart: true
   - Timer: 300 seconds
   - 10 pages of challenging math activities
5. User sees notification: "AI Updated: Title, Description, Difficulty, Game Rule, Prize Coins, Heart, Timer"
6. User returns to Game Editor with all settings configured
7. User can fine-tune any settings if needed
8. User saves the complete game

## Technical Notes

### Firestore Structure
```
users/{userId}/created_games/{gameId}
  ├── title (updated by AI if provided)
  ├── description (updated by AI if provided)
  ├── difficulty (updated by AI if provided)
  ├── gameRule (updated by AI if provided)
  ├── prizeCoins (updated by AI if user requests)
  ├── gameSet (updated by AI if user requests)
  ├── gameCode (updated by AI if user requests)
  ├── heart (updated by AI if user requests)
  ├── timer (updated by AI if user requests)
  └── game_rounds/{roundId}
      └── game_type/{typeId}
```

### Error Handling
- If AI doesn't provide metadata, existing values are preserved
- Empty or null values are ignored (no overwrite)
- User is notified of any update failures

## Future Enhancements

Potential improvements:
1. ✅ ~~Allow user to specify which fields AI should update~~ (IMPLEMENTED)
2. Add "Revert to AI suggestion" button in Game Editor
3. Show AI-generated vs user-modified fields differently
4. ✅ ~~Add AI suggestions for Prize Coins based on difficulty~~ (IMPLEMENTED)
5. ✅ ~~Smart Game Set recommendations (public/private)~~ (IMPLEMENTED)
6. Add preset templates (e.g., "Quick Quiz", "Timed Challenge", "Practice Mode")
7. AI-suggested game codes based on activity theme
8. Smart timer recommendations based on activity length and difficulty
9. Batch generation with different settings for multiple games

## Troubleshooting

### Metadata Not Updating
- Check that gameId is passed correctly to MyGameQuick
- Verify user is logged in (FirebaseAuth.instance.currentUser)
- Check Firestore permissions for the user
- Look for error messages in debug console

### AI Not Generating Metadata
- Check Gemini API response in debug logs
- Verify AI prompt includes metadata instructions
- Check for JSON parsing errors
- Ensure AI response includes title/description fields

## Code References

### Key Files
- `lib/editor/game_quick.dart`: Quick generator UI and save logic
- `lib/editor/gemini.dart`: AI service with metadata generation
- `lib/editor/game_edit.dart`: Main game editor (receives updates)

### Key Methods
- `_saveGeneratedActivityToFirestore()`: Saves activity and metadata
- `generateActivityPlan()`: AI generates activity plan with metadata
- `generateFullActivity()`: AI generates complete activity with metadata
