# Prompt Mode Confirmation Flow

## Overview
The Prompt Mode now uses a two-step confirmation process to ensure users review and approve the activity plan before it's created.

## How It Works

### Step 1: User Sends Prompt
User describes what they want:
```
"Create a math activity for grade 3 with 5 pages"
```

### Step 2: AI Generates Activity Plan
AI responds with a detailed plan showing:
- **Title**: Activity name
- **Description**: What the activity teaches
- **Game Types**: Which game types will be used
- **Difficulty**: Difficulty level
- **Game Rule**: Game rule (heart, timer, score, none)
- **Total Pages**: Number of pages
- **Reasoning**: Why AI chose these settings

### Step 3: User Reviews Plan
The plan is displayed in a blue card with two buttons:
- ✅ **Confirm & Create**: Proceeds to create the full activity
- ✏️ **Modify Plan**: Allows user to request changes

### Step 4A: User Confirms
If user clicks "Confirm & Create" or types "yes", "confirm", "create", or "proceed":
- AI generates the full activity with detailed content
- Activity is automatically saved to Firestore
- User sees success message

### Step 4B: User Modifies
If user wants changes, they can type modifications:
```
"Change difficulty to hard and add 3 more pages"
"Use only Fill in the blank game type"
"Make it about animals instead"
```

AI will generate a new plan based on the modifications, and the process repeats.

## Benefits

### 1. User Control
- Users see exactly what will be created before committing
- Can request changes without wasting API calls
- Clear understanding of activity structure

### 2. Better Results
- AI explains reasoning for choices
- Users can catch issues early
- Iterative refinement possible

### 3. Transparency
- All required fields are shown upfront
- No surprises after generation
- Clear confirmation step

## Visual Design

### Activity Plan Card (Blue)
```
┌─────────────────────────────────────┐
│ 📋 Activity Plan                    │
├─────────────────────────────────────┤
│ Title: Math Adventure               │
│ Description: Learn addition...      │
│ Game Types: Math, Fill in blank    │
│ Difficulty: easy                    │
│ Game Rule: score                    │
│ Total Pages: 5                      │
│                                     │
│ Reasoning:                          │
│ I chose these settings because...   │
│                                     │
│ [✅ Confirm & Create] [✏️ Modify]   │
└─────────────────────────────────────┘
```

### Activity Created Card (Green)
```
┌─────────────────────────────────────┐
│ ✅ Activity Generated                │
├─────────────────────────────────────┤
│ Title: Math Adventure               │
│ Difficulty: easy                    │
│ Total Pages: 5                      │
│ Game Types: Math, Fill in blank    │
│                                     │
│ [Use This Activity]                 │
└─────────────────────────────────────┘
```

## API Methods

### New Methods in GeminiService

#### 1. `generateActivityPlan()`
- **Purpose**: Generate high-level plan for user review
- **Returns**: Plan with title, description, game types, etc.
- **Timeout**: 30 seconds
- **Token Limit**: 2048 tokens (smaller, faster)

#### 2. `generateFullActivity()`
- **Purpose**: Generate complete activity from confirmed plan
- **Input**: Confirmed activity plan
- **Returns**: Full activity with detailed page content
- **Timeout**: 60 seconds
- **Token Limit**: 8192 tokens (larger, detailed)

#### 3. `generateGameActivity()` (Legacy)
- **Status**: Kept for backward compatibility
- **Note**: Not used in new confirmation flow

## User Experience Flow

```
User Types Prompt
       ↓
AI Generates Plan (30s)
       ↓
User Reviews Plan
       ↓
   ┌───┴───┐
   │       │
Confirm  Modify
   │       │
   │    User Types Changes
   │       ↓
   │    AI Generates New Plan
   │       ↓
   └───────┘
       ↓
AI Generates Full Activity (60s)
       ↓
Activity Saved to Firestore
       ↓
Success Message
```

## Example Conversation

**User:** "Create a vocabulary activity for grade 2"

**AI:** 
```
📋 Activity Plan

Title: Grade 2 Vocabulary Builder
Description: Learn new words through fun games
Game Types: Fill in the blank, Guess the answer
Difficulty: easy
Game Rule: heart
Total Pages: 5

Reasoning: I chose Fill in the blank and Guess the answer 
because they're great for vocabulary learning. Easy difficulty 
is appropriate for grade 2, and heart system adds engagement 
without time pressure.

[✅ Confirm & Create] [✏️ Modify Plan]
```

**User:** "Make it 8 pages and add Read the sentence"

**AI:**
```
📋 Activity Plan (Updated)

Title: Grade 2 Vocabulary Builder
Description: Learn new words through fun games
Game Types: Fill in the blank, Guess the answer, Read the sentence
Difficulty: easy
Game Rule: heart
Total Pages: 8

Reasoning: Added Read the sentence to reinforce vocabulary 
in context. Increased to 8 pages for more practice.

[✅ Confirm & Create] [✏️ Modify Plan]
```

**User:** *clicks Confirm & Create*

**AI:** "⏳ Creating your activity... Please wait."

**AI:** "✅ Activity created successfully! Saving to your game..."

## Technical Implementation

### State Management
```dart
Map<String, dynamic>? pendingActivityPlan; // Stores plan awaiting confirmation
```

### Confirmation Detection
```dart
if (pendingActivityPlan != null && 
    (userPrompt.toLowerCase().contains('yes') || 
     userPrompt.toLowerCase().contains('confirm') ||
     userPrompt.toLowerCase().contains('create') ||
     userPrompt.toLowerCase().contains('proceed'))) {
  // User is confirming the plan
  await _createActivityFromPlan(pendingActivityPlan!);
}
```

### Plan Message Builder
```dart
String _buildActivityPlanMessage(Map<String, dynamic> plan) {
  // Formats plan data into readable message
  // Shows all required fields
  // Adds confirmation instructions
}
```

## Error Handling

### Plan Generation Fails
- Shows detailed error message
- User can try again with different prompt
- No partial data saved

### Activity Generation Fails
- Plan remains available
- User can confirm again
- Error message suggests modifications

## Future Enhancements

1. **Preview Pages**: Show sample page content in plan
2. **Edit Individual Fields**: Click to edit specific fields
3. **Save Plans**: Save plans for later use
4. **Plan Templates**: Quick start with common plans
5. **Comparison**: Compare multiple plan variations

## Notes

- Plans are temporary (cleared after confirmation or new prompt)
- Users can modify plans unlimited times
- Full activity only generated after confirmation
- Saves API costs by confirming before detailed generation
