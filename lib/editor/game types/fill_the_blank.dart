// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ----------- Preview Widget (for Column 2) -----------
class MyFillTheBlank extends StatefulWidget {
  final TextEditingController answerController;
  final List<bool> visibleLetters;
  final Function(int) onRevealLetter;
  final Function(int) onHideLetter;

  const MyFillTheBlank({
    super.key, 
    required this.answerController,
    required this.visibleLetters,
    required this.onRevealLetter,
    required this.onHideLetter,
  });

  @override
  State<MyFillTheBlank> createState() => _MyFillTheBlankState();
}

class _MyFillTheBlankState extends State<MyFillTheBlank> {
  late TextEditingController _userInputController;
  late List<String> _userAnswers;
  String _previousInput = "";

  @override
  void initState() {
    super.initState();
    _initializeUserAnswers();
    _userInputController = TextEditingController();
    _userInputController.addListener(_handleInput);
  }

  @override
  void dispose() {
    _userInputController.dispose();
    super.dispose();
  }

  void _initializeUserAnswers() {
    final answer = widget.answerController.text;
    _userAnswers = List.generate(answer.length, (i) {
      if (widget.visibleLetters.isNotEmpty && 
          i < widget.visibleLetters.length && 
          !widget.visibleLetters[i]) {
        return "_";
      } else if (i < answer.length) {
        return answer[i];
      }
      return "";
    });
  }

  void _handleInput() {
    final answer = widget.answerController.text;
    if (answer.isEmpty) return;

    final input = _userInputController.text;
    
    // Handle backspace (delete) - when input becomes shorter
    if (input.length < _previousInput.length) {
      // Find the last filled position (that should be hidden)
      int lastFilledIndex = -1;
      for (int i = _userAnswers.length - 1; i >= 0; i--) {
        if (widget.visibleLetters.isNotEmpty && 
            i < widget.visibleLetters.length && 
            !widget.visibleLetters[i] && 
            _userAnswers[i] != "_") {
          lastFilledIndex = i;
          break;
        }
      }

      // If there's a filled position, delete it and hide the letter
      if (lastFilledIndex != -1) {
        setState(() {
          _userAnswers[lastFilledIndex] = "_";
        });
        // Hide the letter in the configuration
        widget.onHideLetter(lastFilledIndex);
      }
      _previousInput = input;
      return;
    }

    // Handle new character input
    if (input.length > _previousInput.length && input.isNotEmpty) {
      // Get the last character typed
      final char = input[input.length - 1].toLowerCase();

      // Find the first blank position
      int firstBlankIndex = -1;
      for (int i = 0; i < _userAnswers.length; i++) {
        if (_userAnswers[i] == "_") {
          firstBlankIndex = i;
          break;
        }
      }

      // If there's a blank, fill it
      if (firstBlankIndex != -1) {
        setState(() {
          _userAnswers[firstBlankIndex] = char;
        });

        // Check if this character matches the correct answer at this position
        if (char.toLowerCase() == answer[firstBlankIndex].toLowerCase()) {
          // Reveal only this specific letter position
          widget.onRevealLetter(firstBlankIndex);
        }
      }
    }

    // Update previous input for next comparison
    _previousInput = input;
  }

  @override
  Widget build(BuildContext context) {
    final answer = widget.answerController.text;

    // Rebuild user answers if answer changed
    if (_userAnswers.length != answer.length) {
      _initializeUserAnswers();
    }

    // Update visible letters if they changed
    for (int i = 0; i < answer.length && i < _userAnswers.length && i < widget.visibleLetters.length; i++) {
      if (widget.visibleLetters[i]) {
        _userAnswers[i] = answer[i];
      } else if (_userAnswers[i] != "_" && _userAnswers[i].length == 1 && _userAnswers[i] != answer[i]) {
        // Keep user input if it's not the correct answer
        continue;
      } else if (_userAnswers[i] == answer[i]) {
        // Reset to blank if letter should be hidden
        _userAnswers[i] = "_";
      }
    }

    // Build display string
    String displayAnswer = _userAnswers.join();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          "Fill in the blank:",
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 6),

        // Subtitle
        Text(
          "Fill in the missing letter of the word.",
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),

        const SizedBox(height: 20),

        // Display TextField (shows the answer with blanks filled)
        Center(
          child: SizedBox(
            width: 400,
            child: TextField(
              enabled: false,
              controller: TextEditingController(text: displayAnswer),
              maxLines: 4,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              decoration: InputDecoration(
                disabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Input field - now always visible
        Center(
          child: SizedBox(
            width: 400,
            child: TextField(
              controller: _userInputController,
              autofocus: true,
              obscureText: true,
              obscuringCharacter: '*',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              decoration: InputDecoration(
                hintText: "Type here to fill the blanks...",
                hintStyle: GoogleFonts.poppins(
                  color: Colors.black54,
                  fontSize: 14,
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.grey, width: 1),
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              ),
            ),
          ),
        ),

        const Spacer(),
      ],
    );
  }
}

// ----------- Settings Widget (for Column 3) -----------
class MyFillTheBlankSettings extends StatefulWidget {
  final TextEditingController answerController;
  final TextEditingController hintController;
  final List<bool> visibleLetters;
  final Function(int) onToggle;

  const MyFillTheBlankSettings({
    super.key,
    required this.answerController,
    required this.hintController,
    required this.visibleLetters,
    required this.onToggle,
  });

  @override
  State<MyFillTheBlankSettings> createState() =>
      _MyFillTheBlankSettingsState();
}

class _MyFillTheBlankSettingsState extends State<MyFillTheBlankSettings> {
  @override
  Widget build(BuildContext context) {
    final answer = widget.answerController.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Answer Row
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              "Answer:",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 300,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.black, width: 1),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextField(
                controller: widget.answerController,
                maxLength: 25,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.black,
                ),
                decoration: InputDecoration(
                  hintText: "The Answer...",
                  hintStyle: GoogleFonts.poppins(
                    color: Colors.black54,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  counterText: "",
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Game Hint Row
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              "Game Hint:",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 300,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.black, width: 1),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextField(
                controller: widget.hintController,
                maxLength: 100,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.black,
                ),
                decoration: InputDecoration(
                  hintText: "Give a hint if user use a hint...",
                  hintStyle: GoogleFonts.poppins(
                    color: Colors.black54,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  counterText: "",
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Dynamic letters row
        Text(
          "Answer Configuration:",
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(answer.length, (index) {
            return GestureDetector(
              onTap: () {
                widget.onToggle(index);
              },
              child: Container(
                width: 40,
                height: 45,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.black87, width: 1),
                ),
                child: Text(
                  widget.visibleLetters.isNotEmpty &&
                          !widget.visibleLetters[index]
                      ? "_"
                      : answer[index],
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ----------- Firebase Storage Functions -----------

/// Saves Fill the Blank game data to Firebase
///
/// Structure: users/{userId}/created_games/{gameId}/game_rounds/{roundDocId}/game_type/{gameTypeDocId}
///
/// @param userId - The user ID
/// @param gameId - The game ID from created_games collection
/// @param roundDocId - The auto document ID from game_rounds collection
/// @param gameTypeDocId - The auto document ID from game_type subcollection
/// @param answer - The complete answer string
/// @param visibleLetters - Array of booleans (true = visible, false = hidden)
/// @param gameHint - Hint string for the game
Future<void> saveFillTheBlankToFirebase({
  required String userId,
  required String gameId,
  required String roundDocId,
  required String gameTypeDocId,
  required String answer,
  required List<bool> visibleLetters,
  required String gameHint,
}) async {
  try {
    final firestore = FirebaseFirestore.instance;

    // Reference to the specific document in the nested structure
    final docRef = firestore
        .collection('users')
        .doc(userId)
        .collection('created_games')
        .doc(gameId)
        .collection('game_rounds')
        .doc(roundDocId)
        .collection('game_type')
        .doc(gameTypeDocId);

    // Prepare the data
    final data = {
      'answer': visibleLetters, // Array of booleans for each letter
      'gameHint': gameHint,
      'answerText': answer, // Store the full answer text for reference
      'gameType': 'fill_the_blank',
      'timestamp': FieldValue.serverTimestamp(),
    };

    // Save to Firebase
    await docRef.set(data, SetOptions(merge: true));

    print('Fill the Blank data saved successfully!');
  } catch (e) {
    print('Error saving Fill the Blank data: $e');
    rethrow;
  }
}

/// Loads Fill the Blank game data from Firebase
///
/// @param userId - The user ID
/// @param gameId - The game ID from created_games collection
/// @param roundDocId - The document ID from game_rounds collection
/// @param gameTypeDocId - The document ID from game_type subcollection
/// @returns Map containing answer, visibleLetters, and gameHint
Future<Map<String, dynamic>?> loadFillTheBlankFromFirebase({
  required String userId,
  required String gameId,
  required String roundDocId,
  required String gameTypeDocId,
}) async {
  try {
    final firestore = FirebaseFirestore.instance;

    // Reference to the specific document
    final docRef = firestore
        .collection('users')
        .doc(userId)
        .collection('created_games')
        .doc(gameId)
        .collection('game_rounds')
        .doc(roundDocId)
        .collection('game_type')
        .doc(gameTypeDocId);

    // Get the document
    final docSnapshot = await docRef.get();

    if (docSnapshot.exists) {
      final data = docSnapshot.data();
      return {
        'answerText': data?['answerText'] ?? '',
        'answer': List<bool>.from(data?['answer'] ?? []),
        'gameHint': data?['gameHint'] ?? '',
      };
    } else {
      print('Document does not exist');
      return null;
    }
  } catch (e) {
    print('Error loading Fill the Blank data: $e');
    rethrow;
  }
}

// ----------- Example Usage Widget -----------

class FillTheBlankGameManager extends StatefulWidget {
  final String userId;
  final String gameId;
  final String roundDocId;
  final String gameTypeDocId;

  const FillTheBlankGameManager({
    super.key,
    required this.userId,
    required this.gameId,
    required this.roundDocId,
    required this.gameTypeDocId,
  });

  @override
  State<FillTheBlankGameManager> createState() =>
      _FillTheBlankGameManagerState();
}

class _FillTheBlankGameManagerState extends State<FillTheBlankGameManager> {
  late TextEditingController _answerController;
  late TextEditingController _hintController;
  late List<bool> _visibleLetters;

  @override
  void initState() {
    super.initState();
    _answerController = TextEditingController();
    _hintController = TextEditingController();
    _visibleLetters = [];

    // Add listener to update visible letters when answer changes
    _answerController.addListener(_updateVisibleLetters);

    // Load existing data if available
    _loadGameData();
  }

  void _updateVisibleLetters() {
    final answer = _answerController.text;
    if (_visibleLetters.length != answer.length) {
      setState(() {
        _visibleLetters = List.generate(answer.length, (_) => true);
      });
    }
  }

  Future<void> _loadGameData() async {
    final data = await loadFillTheBlankFromFirebase(
      userId: widget.userId,
      gameId: widget.gameId,
      roundDocId: widget.roundDocId,
      gameTypeDocId: widget.gameTypeDocId,
    );

    if (data != null) {
      setState(() {
        _answerController.text = data['answerText'];
        _visibleLetters = data['answer'];
        _hintController.text = data['gameHint'];
      });
    }
  }

  Future<void> _saveGameData() async {
    if (_answerController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter an answer')));
      return;
    }

    try {
      await saveFillTheBlankToFirebase(
        userId: widget.userId,
        gameId: widget.gameId,
        roundDocId: widget.roundDocId,
        gameTypeDocId: widget.gameTypeDocId,
        answer: _answerController.text,
        visibleLetters: _visibleLetters,
        gameHint: _hintController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Game data saved successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving data: $e')));
      }
    }
  }

  void _toggleLetterVisibility(int index) {
    setState(() {
      if (index < _visibleLetters.length) {
        _visibleLetters[index] = !_visibleLetters[index];
      }
    });
  }

  void _revealLetter(int index) {
    setState(() {
      if (index < _visibleLetters.length) {
        _visibleLetters[index] = true;
      }
    });
  }

  void _hideLetter(int index) {
    setState(() {
      if (index < _visibleLetters.length) {
        _visibleLetters[index] = false;
      }
    });
  }

  @override
  void dispose() {
    _answerController.dispose();
    _hintController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fill The Blank Game'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveGameData,
            tooltip: 'Save Game Data',
          ),
        ],
      ),
      body: Row(
        children: [
          // Preview Column
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(20),
              child: MyFillTheBlank(
                answerController: _answerController,
                visibleLetters: _visibleLetters,
                onRevealLetter: _revealLetter,
                onHideLetter: _hideLetter,
              ),
            ),
          ),

          // Settings Column
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.blue.shade700,
              padding: const EdgeInsets.all(20),
              child: MyFillTheBlankSettings(
                answerController: _answerController,
                hintController: _hintController,
                visibleLetters: _visibleLetters,
                onToggle: _toggleLetterVisibility,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
