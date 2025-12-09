# Math Game Type - Data Flow

## Overview
This document shows how Math game type data flows from AI generation to Firestore storage.

## Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         USER INPUT                               │
│  Edit Mode: Select "Math" + Difficulty + Pages                  │
│  Prompt Mode: "Create 5 math problems"                           │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                    GEMINI AI SERVICE                             │
│  (lib/editor/gemini.dart)                                        │
│                                                                   │
│  Generates JSON with Math data:                                  │
│  {                                                                │
│    "pageNumber": 1,                                               │
│    "gameType": "Math",                                            │
│    "totalBoxes": 3,                                               │
│    "boxValues": [10, 2, 5],  ← NUMBERS ONLY                      │
│    "operators": ["÷", "+"],  ← AI CHOOSES OPERATORS              │
│    "answer": 10              ← CALCULATED RESULT                 │
│  }                                                                │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                   VALIDATION & NORMALIZATION                     │
│  (lib/editor/game_quick.dart - _saveGameTypeData)               │
│                                                                   │
│  1. Validate boxValues are numbers:                              │
│     if (value is num) → use as double                            │
│     if (value is String) → parse to double                       │
│     else → default to 0.0                                        │
│                                                                   │
│  2. Normalize operators:                                         │
│     "*" → "×"                                                     │
│     "/" → "÷"                                                     │
│                                                                   │
│  3. Validate operators:                                          │
│     Must be one of: ["+", "-", "×", "÷"]                         │
│     Invalid → default to "+"                                     │
│                                                                   │
│  4. Validate answer:                                             │
│     Convert to double                                            │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                      FIRESTORE STORAGE                           │
│  users/{userId}/created_games/{gameId}/                          │
│    game_rounds/{roundId}/game_type/{docId}                       │
│                                                                   │
│  {                                                                │
│    "gameType": "Math",                                            │
│    "totalBoxes": 3,                                               │
│    "box1": 10.0,        ← Stored as double                       │
│    "box2": 2.0,         ← Stored as double                       │
│    "box3": 5.0,         ← Stored as double                       │
│    "box4": 0.0,         ← Unused boxes = 0.0                     │
│    "box5": 0.0,                                                   │
│    ...                                                            │
│    "box10": 0.0,                                                  │
│    "operator1_2": "÷",  ← Normalized symbol                      │
│    "operator2_3": "+",  ← Normalized symbol                      │
│    "operator3_4": "",   ← Unused operators = ""                  │
│    ...                                                            │
│    "operator9_10": "",                                            │
│    "answer": 10.0,      ← Stored as double                       │
│    "timestamp": <serverTimestamp>                                │
│  }                                                                │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                      GAME EDITOR / GAMEPLAY                      │
│  (lib/editor/game types/math.dart)                               │
│                                                                   │
│  Reads Firestore data and displays:                              │
│  ┌─────┐     ┌─────┐     ┌─────┐                                │
│  │ 10  │  ÷  │  2  │  +  │  5  │  =  ?                          │
│  └─────┘     └─────┘     └─────┘                                │
│                                                                   │
│  User enters answer → validates against stored answer            │
└─────────────────────────────────────────────────────────────────┘
```

## Example: Complete Flow

### Step 1: User Request
```
User: "Create 3 easy math problems"
```

### Step 2: AI Generation
```json
{
  "pages": [
    {
      "pageNumber": 1,
      "gameType": "Math",
      "totalBoxes": 2,
      "boxValues": [5, 3],
      "operators": ["+"],
      "answer": 8
    },
    {
      "pageNumber": 2,
      "gameType": "Math",
      "totalBoxes": 2,
      "boxValues": [7, 2],
      "operators": ["-"],
      "answer": 5
    },
    {
      "pageNumber": 3,
      "gameType": "Math",
      "totalBoxes": 3,
      "boxValues": [4, 2, 3],
      "operators": ["+", "+"],
      "answer": 9
    }
  ]
}
```

### Step 3: Validation
```dart
// Page 1
totalBoxes: 2
boxValues: [5, 3] → validated as numbers
operators: ["+"] → validated
answer: 8 → converted to 8.0

// Page 2
totalBoxes: 2
boxValues: [7, 2] → validated as numbers
operators: ["-"] → validated
answer: 5 → converted to 5.0

// Page 3
totalBoxes: 3
boxValues: [4, 2, 3] → validated as numbers
operators: ["+", "+"] → validated
answer: 9 → converted to 9.0
```

### Step 4: Firestore Storage
```
Round 1:
{
  "gameType": "Math",
  "totalBoxes": 2,
  "box1": 5.0,
  "box2": 3.0,
  "box3": 0.0,
  ...
  "operator1_2": "+",
  "operator2_3": "",
  ...
  "answer": 8.0
}

Round 2:
{
  "gameType": "Math",
  "totalBoxes": 2,
  "box1": 7.0,
  "box2": 2.0,
  "box3": 0.0,
  ...
  "operator1_2": "-",
  "operator2_3": "",
  ...
  "answer": 5.0
}

Round 3:
{
  "gameType": "Math",
  "totalBoxes": 3,
  "box1": 4.0,
  "box2": 2.0,
  "box3": 3.0,
  "box4": 0.0,
  ...
  "operator1_2": "+",
  "operator2_3": "+",
  "operator3_4": "",
  ...
  "answer": 9.0
}
```

## Operator Conversion Table

| AI Output | Normalized | Firestore | Display |
|-----------|------------|-----------|---------|
| `+`       | `+`        | `+`       | `+`     |
| `-`       | `-`        | `-`       | `-`     |
| `*`       | `×`        | `×`       | `×`     |
| `×`       | `×`        | `×`       | `×`     |
| `/`       | `÷`        | `÷`       | `÷`     |
| `÷`       | `÷`        | `÷`       | `÷`     |

## Validation Rules

### boxValues
- ✅ Must be numbers: `[5, 3, 2]`
- ❌ Cannot be strings: `["5", "3", "2"]`
- ✅ Can be integers or decimals: `[5.5, 3.2, 2.0]`
- ❌ Cannot be empty or null

### operators
- ✅ Must be valid symbols: `["+", "-", "×", "÷"]`
- ❌ Cannot be invalid: `["plus", "minus"]`
- ✅ Length must equal totalBoxes - 1
- ✅ AI can freely choose any combination

### answer
- ✅ Must be a number: `10` or `10.0`
- ❌ Cannot be a string: `"10"`
- ✅ Should be the correct calculated result
- ✅ Can be decimal: `10.5`

### totalBoxes
- ✅ Must be between 1 and 10
- ✅ Determines array lengths
- ✅ Unused boxes filled with 0.0

## Error Handling

### Invalid boxValue
```dart
// Input: "5" (string)
// Output: 5.0 (double)
double numericValue = double.tryParse("5") ?? 0.0;
```

### Invalid operator
```dart
// Input: "plus"
// Output: "+" (default)
if (!['+', '-', '×', '÷'].contains(operator)) {
  operator = '+';
}
```

### Invalid answer
```dart
// Input: "10" (string)
// Output: 10.0 (double)
double mathAnswer = double.tryParse("10") ?? 0.0;
```

## AI Flexibility

The AI can:
- ✅ Choose any operators based on difficulty
- ✅ Create different combinations: `["+", "×"]`, `["÷", "-"]`
- ✅ Use all operators in one problem: `["+", "-", "×", "÷"]`
- ✅ Adjust totalBoxes (1-10)
- ✅ Scale numbers based on difficulty

The AI cannot:
- ❌ Use invalid operators
- ❌ Create mismatched operator counts
- ❌ Use non-numeric boxValues
- ❌ Exceed 10 boxes

## Summary

1. **AI generates** Math data with numbers and operators
2. **Validation ensures** data integrity and correct format
3. **Normalization converts** operators to standard symbols
4. **Firestore stores** clean, validated data
5. **Game displays** math problems correctly
6. **User plays** with properly formatted equations

This flow ensures that Math game types always work correctly, regardless of how the AI generates the data.
