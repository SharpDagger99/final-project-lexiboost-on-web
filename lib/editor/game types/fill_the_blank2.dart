// ignore_for_file: deprecated_member_use

import 'dart:typed_data';
import 'package:animated_button/animated_button.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ----------- Preview Widget (for Column 2) -----------
class MyFillInTheBlank2 extends StatefulWidget {
  final TextEditingController answerController;
  final List<bool> visibleLetters;
  final Uint8List? pickedImage;
  final Function(int) onRevealLetter;
  final Function(int) onHideLetter;

  const MyFillInTheBlank2({
    super.key,
    required this.answerController,
    required this.visibleLetters,
    required this.onRevealLetter,
    required this.onHideLetter,
    this.pickedImage,
  });

  @override
  State<MyFillInTheBlank2> createState() => _MyFillInTheBlank2State();
}

class _MyFillInTheBlank2State extends State<MyFillInTheBlank2> {
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

    // Handle backspace
    if (input.length < _previousInput.length) {
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

      if (lastFilledIndex != -1) {
        setState(() {
          _userAnswers[lastFilledIndex] = "_";
        });
        widget.onHideLetter(lastFilledIndex);
      }
      _previousInput = input;
      return;
    }

    // Handle new input
    if (input.length > _previousInput.length && input.isNotEmpty) {
      final char = input[input.length - 1].toLowerCase();

      int firstBlankIndex = -1;
      for (int i = 0; i < _userAnswers.length; i++) {
        if (_userAnswers[i] == "_") {
          firstBlankIndex = i;
          break;
        }
      }

      if (firstBlankIndex != -1) {
        setState(() {
          _userAnswers[firstBlankIndex] = char;
        });

        if (char.toLowerCase() == answer[firstBlankIndex].toLowerCase()) {
          widget.onRevealLetter(firstBlankIndex);
        }
      }
    }

    _previousInput = input;
  }

  @override
  Widget build(BuildContext context) {
    final answer = widget.answerController.text;

    if (_userAnswers.length != answer.length) {
      _initializeUserAnswers();
    }

    for (int i = 0;
        i < answer.length &&
        i < _userAnswers.length &&
        i < widget.visibleLetters.length;
        i++) {
      if (widget.visibleLetters[i]) {
        _userAnswers[i] = answer[i];
      } else if (_userAnswers[i] == answer[i]) {
        _userAnswers[i] = "_";
      }
    }

    String displayAnswer = _userAnswers.join();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Fill in the blank 2:",
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "Fill in the missing letter of the word.",
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "The image will be shown as a hint.",
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 30),

        // 🔵 Image Hint Box
        Center(
          child: Container(
            width: 400,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.blue, width: 2),
            ),
            child: widget.pickedImage == null
                ? Center(
                    child: Text(
                      "Image Hint",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    child: Image.memory(
                      widget.pickedImage!,
                      fit: BoxFit.contain,
                    ),
                  ),
          ),
        ),

        const SizedBox(height: 30),

        // Display Answer TextField (disabled)
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
                  borderRadius: BorderRadius.circular(20),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Input Field
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
class MyFillInTheBlank2Settings extends StatefulWidget {
  final TextEditingController answerController;
  final List<bool> visibleLetters;
  final Function(int) onToggle;
  final Function(Uint8List) onImagePicked;

  const MyFillInTheBlank2Settings({
    super.key,
    required this.answerController,
    required this.visibleLetters,
    required this.onToggle,
    required this.onImagePicked,
  });

  @override
  State<MyFillInTheBlank2Settings> createState() =>
      _MyFillInTheBlank2SettingsState();
}

class _MyFillInTheBlank2SettingsState
    extends State<MyFillInTheBlank2Settings> {
  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );
    if (result != null && result.files.isNotEmpty) {
      final fileBytes = result.files.first.bytes;
      if (fileBytes != null) {
        widget.onImagePicked(fileBytes);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final answer = widget.answerController.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Upload Image Row
        Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 10.0, top: 10, bottom: 10),
              child: Text(
                "Image:",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: AnimatedButton(
                width: 180,
                height: 50,
                color: Colors.white,
                onPressed: _pickImage,
                child: Text(
                  "Upload Image",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Answer input
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
                  counterText: "",
                  hintText: "The Answer...",
                  hintStyle: GoogleFonts.poppins(
                    color: Colors.black54,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Dynamic letters row (same logic as fill_the_blank.dart)
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
              onTap: () => widget.onToggle(index),
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
