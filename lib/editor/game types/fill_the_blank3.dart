import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:animated_button/animated_button.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';

// ----------- Preview Widget (for Column 2) -----------
class MyFillInTheBlank3 extends StatelessWidget {
  final TextEditingController answerController;
  final TextEditingController questionController;
  final List<bool> visibleLetters;
  final Uint8List? pickedImage;
  final List<String> multipleChoices;

  const MyFillInTheBlank3({
    super.key,
    required this.answerController,
    required this.questionController,
    required this.visibleLetters,
    this.pickedImage,
    this.multipleChoices = const [],
  });

  @override
  Widget build(BuildContext context) {
    final question = questionController.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Guess the answer:",
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),

        Text(
          "Guess what's the answer of the given question with an image hint.",
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 20),

        // Image preview
        Center(
          child: Container(
            width: 400,
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.blue, width: 2),
            ),
            child: pickedImage == null
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
                    child: Image.memory(pickedImage!, fit: BoxFit.contain),
                  ),
          ),
        ),

        const SizedBox(height: 20),

        // Question text
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!, width: 1),
          ),
          child: Text(
            question.isEmpty ? "Your question will appear here..." : question,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Multiple choice buttons (only show if choices have content)
        if (multipleChoices.any((choice) => choice.trim().isNotEmpty)) ...[
          Center(
            child: Column(
              children: multipleChoices
                  .where((choice) => choice.trim().isNotEmpty)
                  .map(
                    (choice) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: AnimatedButton(
                        width: 200,
                        height: 50,
                        color: Colors.lightBlue,
                        onPressed: () {},
                        child: Text(
                          choice,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 20),
        ],

        
        const Spacer(),
      ],
    );
  }
}

// ----------- Settings Widget (for Column 3) -----------
class MyFillInTheBlank3Settings extends StatefulWidget {
  final TextEditingController answerController;
  final TextEditingController questionController;
  final List<bool> visibleLetters;
  final Function(int) onToggle;
  final Function(Uint8List) onImagePicked;
  final Function(List<String>) onChoicesChanged;

  const MyFillInTheBlank3Settings({
    super.key,
    required this.answerController,
    required this.questionController,
    required this.visibleLetters,
    required this.onToggle,
    required this.onImagePicked,
    required this.onChoicesChanged,
  });

  @override
  State<MyFillInTheBlank3Settings> createState() =>
      _MyFillInTheBlank3SettingsState();
}

class _MyFillInTheBlank3SettingsState extends State<MyFillInTheBlank3Settings> {
  final List<TextEditingController> choiceControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];

  @override
  void initState() {
    super.initState();
    for (var controller in choiceControllers) {
      controller.addListener(_onChoicesChanged);
    }
  }

  @override
  void dispose() {
    for (var controller in choiceControllers) {
      controller.removeListener(_onChoicesChanged);
      controller.dispose();
    }
    super.dispose();
  }

  void _onChoicesChanged() {
    final choices = choiceControllers
        .map((controller) => controller.text)
        .toList();
    widget.onChoicesChanged(choices);
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.isNotEmpty) {
      final fileBytes = result.files.first.bytes;
      if (fileBytes != null) {
        widget.onImagePicked(fileBytes);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Upload image
        Row(
          children: [
            Text(
              "Image:",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            AnimatedButton(
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
          ],
        ),

        const SizedBox(height: 20),

        // Question input
        Row(
          children: [
            Text(
              "Question:",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 300,
              height: 45,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.black, width: 1),
                color: Colors.white,
              ),
              child: TextField(
                controller: widget.questionController,
                maxLength: 80,
                style: GoogleFonts.poppins(fontSize: 16, color: Colors.black),
                decoration: InputDecoration(
                  counterText: "",
                  hintText: "Enter your question...",
                  hintStyle: GoogleFonts.poppins(color: Colors.black54),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Answer input
        Row(
          children: [
            Text(
              "Answer:",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 25),
            Container(
              width: 300,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.black, width: 1),
                color: Colors.white,
              ),
              child: TextField(
                controller: widget.answerController,
                maxLength: 80,
                style: GoogleFonts.poppins(fontSize: 16, color: Colors.black),
                decoration: InputDecoration(
                  counterText: "",
                  hintText: "Enter your answer...",
                  hintStyle: GoogleFonts.poppins(color: Colors.black54),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 30),

        // Multiple choice
        Text(
          "Multiple choice:",
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),

        const SizedBox(height: 10),

        Column(
          children: [
            for (int i = 0; i < 4; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0), // bottom padding
                child: SizedBox(
                  width: 400,
                  height: 50,
                  child: TextField(
                    controller: choiceControllers[i],
                    decoration: InputDecoration(
                      hintText: "Choice ${i + 1}...",
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
