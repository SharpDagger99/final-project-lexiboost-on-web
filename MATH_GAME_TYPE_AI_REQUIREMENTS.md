# Math Game Type - AI Requirements

## Overview
This document explains how the AI generates Math game type activities in the Quick Generator.

## Critical Requirements

### 1. Box Values - NUMBERS ONLY
- **boxValues** must be an array of **numbers**, not strings
- ✅ Correct: `"boxValues": [5, 3, 2]`
- ❌ Wrong: `"boxValues": ["5", "3", "2"]`

### 2. Operators - AI Can Change
The AI can freely choose and change operators to create different math problems:
- **Available operators**: `+`, `-`, `×`, `÷`
- Alternative formats: `*` (converted to `×`), `/` (converted to `÷`)
- **operators** array length must equal `totalBoxes - 1`

### 3. Total Boxes
- Range: 1-10 boxes
- Determines how many numbers are in the equation

### 4. Answer
- Must be a **number** (not a string)
- Should be the correct calculated result
- ✅ Correct: `"answer": 10`
- ❌ Wrong: `"answer": "10"`

## Examples

### Easy (2 boxes, addition)
```json
{
  "pageNumber": 1,
  "gameType": "Math",
  "totalBoxes": 2,
  "boxValues": [5, 3],
  "operators": ["+"],
  "answer": 8
}
```

### Normal (3 boxes, mixed operations)
```json
{
  "pageNumber": 2,
  "gameType": "Math",
  "totalBoxes": 3,
  "boxValues": [10, 2, 5],
  "operators": ["÷", "+"],
  "answer": 10
}
```

### Hard (4 boxes, complex operations)
```json
{
  "pageNumber": 3,
  "gameType": "Math",
  "totalBoxes": 4,
  "boxValues": [20, 4, 3, 2],
  "operators": ["÷", "+", "×"],
  "answer": 11
}
```

## Difficulty Guidelines

### Easy
- Use only `+` and `-` operators
- Small numbers (1-10)
- 2-3 boxes maximum

### Normal
- Use `+`, `-`, `×` operators
- Numbers up to 20
- 3-4 boxes

### Hard
- Use all operators: `+`, `-`, `×`, `÷`
- Larger numbers (up to 100)
- 4-10 boxes

## Validation in game_quick.dart

The `_saveGameTypeData` function validates and normalizes Math data:

1. **Number Validation**: Ensures all boxValues are numeric
   ```dart
   double numericValue = 0.0;
   if (value is num) {
     numericValue = value.toDouble();
   } else if (value is String) {
     numericValue = double.tryParse(value) ?? 0.0;
   }
   ```

2. **Operator Normalization**: Converts `*` to `×` and `/` to `÷`
   ```dart
   if (operator == '*') operator = '×';
   if (operator == '/') operator = '÷';
   ```

3. **Operator Validation**: Ensures only valid operators are used
   ```dart
   if (['+', '-', '×', '÷'].contains(operator)) {
     gameTypeData['operator${i}_${i + 1}'] = operator;
   } else {
     gameTypeData['operator${i}_${i + 1}'] = '+'; // Default to + if invalid
   }
   ```

## AI Prompt Instructions

The AI is instructed to:
1. Generate **only numeric values** for boxValues
2. **Freely choose operators** based on difficulty level
3. Calculate the correct answer
4. Match operator count to totalBoxes - 1

## Firestore Structure

Math game type data is saved to:
```
users/{userId}/created_games/{gameId}/game_rounds/{roundId}/game_type/{docId}
```

Fields:
- `gameType`: "Math"
- `totalBoxes`: 1-10
- `box1` to `box10`: numeric values (0.0 if unused)
- `operator1_2` to `operator9_10`: operator strings (empty if unused)
- `answer`: calculated result as double
- `timestamp`: server timestamp

## Testing

To test Math game type generation:

1. **Edit Mode**: Select "Math" game type, set difficulty, generate
2. **Prompt Mode**: Ask AI to create math activities
   - "Create 5 easy math problems"
   - "Generate 10 hard math questions with division"
   - "Make a math activity for grade 3"

3. **Verify**:
   - Check that boxValues are numbers
   - Verify operators are correct symbols
   - Confirm answer is calculated correctly
   - Test in game editor that values display properly

## Common Issues

### Issue: boxValues contains strings
**Solution**: AI prompt emphasizes "NUMBERS ONLY" and validation converts strings to numbers

### Issue: Wrong operator symbols
**Solution**: Normalization converts `*` → `×` and `/` → `÷`

### Issue: Operator count mismatch
**Solution**: AI prompt specifies operators.length = totalBoxes - 1

### Issue: Answer is a string
**Solution**: Validation parses answer to double

## Related Files

- `lib/editor/gemini.dart` - AI prompt generation
- `lib/editor/game_quick.dart` - Data validation and Firestore saving
- `lib/editor/game types/math.dart` - Math game type UI component
