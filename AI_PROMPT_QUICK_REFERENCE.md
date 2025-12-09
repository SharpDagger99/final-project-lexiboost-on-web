# AI Prompt Quick Reference Guide

## How to Use AI to Configure Your Game

The Quick Activity Generator can automatically configure all game settings based on your natural language prompts. Simply describe what you want, and the AI will set everything up for you!

## Basic Prompts (Auto-configured)

These prompts will automatically set title, description, difficulty, and game rule:

```
"Create a math quiz for grade 3"
"Generate vocabulary practice for beginners"
"Make a reading comprehension activity"
"Create 10 fill-in-the-blank questions about animals"
```

## Advanced Prompts (Full Control)

### Setting Prize Coins

**Keywords:** coins, prize, reward, points, worth

**Examples:**
- "Create a math game with **500 coins**"
- "Generate a quiz worth **1000 points**"
- "Make an activity with **250 prize coins**"

### Setting Game Visibility (Public/Private)

**Keywords:** public, private, access

**Examples:**
- "Create a **public** math game"
- "Generate a **private** quiz for my class"
- "Make a **private game** with code 123456"

### Setting Game Code (for Private Games)

**Keywords:** code, password, pin

**Examples:**
- "Create a private game with code **999888**"
- "Generate a quiz with password **123456**"
- "Make a private activity, code: **555777**"

### Enabling Heart Deduction

**Keywords:** heart, hearts, lives, health, deduction

**Examples:**
- "Create a game with **heart deduction**"
- "Generate a quiz with **3 hearts**"
- "Make an activity with **lives enabled**"

### Setting Timer

**Keywords:** timer, time limit, countdown, minutes, seconds

**Examples:**
- "Create a game with a **5-minute timer**"
- "Generate a quiz with **120 seconds**"
- "Make an activity with a **3-minute time limit**"

## Combined Prompts (Multiple Settings)

You can combine multiple settings in one prompt:

### Example 1: Competitive Challenge
```
"Create a hard math challenge with 1000 coins, 5-minute timer, and heart deduction"
```
**AI will set:**
- Title: "Math Challenge"
- Difficulty: hard
- Game Rule: timer
- Prize Coins: 1000
- Heart: true
- Timer: 300 seconds

### Example 2: Private Class Quiz
```
"Generate a private vocabulary quiz (code: 123456) with 500 coins and 10 minutes"
```
**AI will set:**
- Game Set: private
- Game Code: 123456
- Prize Coins: 500
- Timer: 600 seconds

### Example 3: Practice Mode
```
"Create an easy reading activity for public access with 200 coins"
```
**AI will set:**
- Difficulty: easy
- Game Set: public
- Prize Coins: 200

### Example 4: Timed Competition
```
"Make a hard math game with 2-minute timer, hearts, and 1500 coin reward"
```
**AI will set:**
- Difficulty: hard
- Game Rule: timer
- Timer: 120 seconds
- Heart: true
- Prize Coins: 1500

## Keyword Detection Table

| Setting | Keywords | Example Values |
|---------|----------|----------------|
| **Prize Coins** | coins, prize, reward, points, worth | 100, 500, 1000, 1500 |
| **Game Set** | public, private, access | public, private |
| **Game Code** | code, password, pin | 123456, 999888 |
| **Heart** | heart, hearts, lives, health | true, false |
| **Timer** | timer, time limit, countdown, minutes, seconds | 60, 120, 300 (in seconds) |
| **Difficulty** | easy, normal, hard, insane | easy, normal, hard |
| **Game Rule** | score, timer, heart, none | score, timer, heart |

## Tips for Best Results

### 1. Be Specific
❌ "Create a game"
✅ "Create a math game with 500 coins and a 3-minute timer"

### 2. Use Natural Language
You don't need to use exact keywords. The AI understands context:
- "Give 1000 points as reward" → Sets prizeCoins: 1000
- "Make it last 5 minutes" → Sets timer: 300
- "Add a countdown" → Enables timer
- "Use lives system" → Enables heart

### 3. Combine Settings Naturally
✅ "Create a challenging quiz worth 750 coins with a 2-minute limit and heart deduction for my private class (code: 555123)"

### 4. Specify Time Units
- "5 minutes" → 300 seconds
- "2 min" → 120 seconds
- "90 seconds" → 90 seconds

## What Gets Updated

### Always Updated (if AI provides):
✅ Title
✅ Description
✅ Difficulty
✅ Game Rule

### Only Updated if You Request:
🔹 Prize Coins
🔹 Game Set (Public/Private)
🔹 Game Code
🔹 Heart Deduction
🔹 Timer

## Common Use Cases

### Quick Practice Quiz
```
"Create an easy vocabulary quiz with 200 coins"
```

### Classroom Assessment
```
"Generate a private math test (code: 789456) with 10-minute timer"
```

### Competitive Challenge
```
"Make a hard quiz with 1500 coins, 5-minute timer, and hearts"
```

### Public Learning Activity
```
"Create a public reading activity for beginners with 300 coins"
```

### Timed Competition
```
"Generate a math race with 2-minute countdown and 1000 coin prize"
```

## Troubleshooting

### AI Didn't Set My Coins
- Make sure you mention "coins", "prize", "reward", or "points"
- Specify the amount: "500 coins" not just "coins"

### Timer Not Working
- Specify time unit: "5 minutes" or "300 seconds"
- Use keywords: "timer", "time limit", "countdown"

### Game Not Private
- Explicitly say "private" or "private game"
- Include a code: "private game with code 123456"

### Heart Not Enabled
- Use keywords: "heart", "hearts", "lives", "health"
- Say "enable hearts" or "with heart deduction"

## Examples by Difficulty

### Easy (Beginners)
```
"Create an easy vocabulary game with 200 coins for public access"
```

### Normal (Intermediate)
```
"Generate a normal math quiz with 500 coins and 5-minute timer"
```

### Hard (Advanced)
```
"Make a hard reading challenge with 1000 coins, 3-minute timer, and hearts"
```

### Insane (Expert)
```
"Create an insane math competition with 2000 coins, 2-minute countdown, and heart deduction"
```

## Remember

- You can always manually edit any setting in the Game Editor after AI generates it
- AI suggestions are smart defaults based on your prompt
- The more specific your prompt, the better the AI configuration
- All settings are optional - AI will use smart defaults if you don't specify

---

**Need Help?** Just describe what you want in natural language, and the AI will figure out the rest!
