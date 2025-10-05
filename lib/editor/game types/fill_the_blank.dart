import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
  final List<bool> visibleLetters;
  final Function(int) onToggle;

  const MyFillTheBlankSettings({
    super.key,
    required this.answerController,
    required this.visibleLetters,
    required this.onToggle,
  });
  
  TextEditingController? get hintController => null;

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

        const SizedBox(height: 20,),

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
                maxLength: 25,
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