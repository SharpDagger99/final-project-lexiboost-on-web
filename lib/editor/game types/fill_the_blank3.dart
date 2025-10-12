// ignore_for_file: avoid_print

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:animated_button/animated_button.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;

// ----------- Preview Widget (for Column 2) -----------
class MyFillInTheBlank3 extends StatelessWidget {
  final TextEditingController hintController;
  final TextEditingController questionController;
  final List<bool> visibleLetters;
  final Uint8List? pickedImage;
  final String? imageUrl; // Add imageUrl parameter
  final List<String> multipleChoices;
  final int correctAnswerIndex;
  final int selectedAnswerIndex;
  final Function(int) onAnswerSelected;

  const MyFillInTheBlank3({
    super.key,
    required this.hintController,
    required this.questionController,
    required this.visibleLetters,
    this.pickedImage,
    this.imageUrl,
    this.multipleChoices = const [],
    this.correctAnswerIndex = -1,
    this.selectedAnswerIndex = -1,
    required this.onAnswerSelected,
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
              
            ),
            child: pickedImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    child: Image.memory(pickedImage!, fit: BoxFit.contain),
                  )
                : imageUrl != null && imageUrl!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    child: Image.network(
                      imageUrl!,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Text(
                            "Failed to load image",
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      },
                    ),
                  )
                : Center(
                    child: Text(
                      "Image Hint",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
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
                  .toList()
                  .asMap()
                  .entries
                  .map(
                    (entry) {
                    final index = entry.key;
                    final choice = entry.value;
                    final isSelected = selectedAnswerIndex == index;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: AnimatedButton(
                        width: 200,
                        height: 50,
                        color: isSelected ? Colors.green : Colors.lightBlue,
                        onPressed: () => onAnswerSelected(index),
                        child: Text(
                          choice.isNotEmpty ? choice : "Choice ${index + 1}",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  },
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
  final TextEditingController hintController;
  final TextEditingController questionController;
  final List<bool> visibleLetters;
  final Function(int) onToggle;
  final Function(Uint8List) onImagePicked;
  final Function(List<String>) onChoicesChanged;
  final Function(int) onCorrectAnswerSelected;
  final List<String> initialChoices; // Add initial choices
  final int initialCorrectIndex; // Add initial correct answer index

  const MyFillInTheBlank3Settings({
    super.key,
    required this.hintController,
    required this.questionController,
    required this.visibleLetters,
    required this.onToggle,
    required this.onImagePicked,
    required this.onChoicesChanged,
    required this.onCorrectAnswerSelected,
    this.initialChoices = const [],
    this.initialCorrectIndex = -1,
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
  int selectedChoiceIndex =
      0; // Track which choice is selected (default to first choice)

  @override
  void initState() {
    super.initState();
    
    // Load initial choices into controllers
    for (int i = 0; i < choiceControllers.length; i++) {
      if (i < widget.initialChoices.length) {
        choiceControllers[i].text = widget.initialChoices[i];
      }
      choiceControllers[i].addListener(_onChoicesChanged);
    }

    // Set initial correct answer index (default to 0 if not provided)
    selectedChoiceIndex = widget.initialCorrectIndex >= 0
        ? widget.initialCorrectIndex
        : 0;

    // Notify parent of the default selection
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onCorrectAnswerSelected(selectedChoiceIndex);
    });
  }

  @override
  void didUpdateWidget(MyFillInTheBlank3Settings oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update choices when widget properties change (e.g., when switching pages)
    if (widget.initialChoices != oldWidget.initialChoices) {
      for (int i = 0; i < choiceControllers.length; i++) {
        if (i < widget.initialChoices.length) {
          choiceControllers[i].text = widget.initialChoices[i];
        } else {
          choiceControllers[i].text = '';
        }
      }
    }

    // Update correct answer index when widget properties change
    if (widget.initialCorrectIndex != oldWidget.initialCorrectIndex) {
      setState(() {
        selectedChoiceIndex = widget.initialCorrectIndex >= 0
            ? widget.initialCorrectIndex
            : 0;
      });
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

  void _onChoiceSelected(int index) {
    setState(() {
      if (selectedChoiceIndex == index) {
        // If clicking the same checkbox, uncheck it
        selectedChoiceIndex = -1;
      } else {
        // Select the new choice (automatically unchecks the previous one)
        selectedChoiceIndex = index;
      }
    });
    widget.onCorrectAnswerSelected(selectedChoiceIndex);
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

        // Game Hint input
        Row(
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
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.black, width: 1),
                color: Colors.white,
              ),
              child: TextField(
                controller: widget.hintController,
                maxLength: 100,
                style: GoogleFonts.poppins(fontSize: 16, color: Colors.black),
                decoration: InputDecoration(
                  counterText: "",
                  hintText: "Enter game hint...",
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
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  children: [
                    SizedBox(
                      width: 350,
                      child: TextField(
                        controller: choiceControllers[i],
                        maxLength: 50,
                        maxLines: 3,
                        minLines: 1,
                        decoration: InputDecoration(
                          hintText: "Choice ${i + 1}...",
                          filled: true,
                          fillColor: Colors.white,
                          counterText: "",
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
                    const SizedBox(width: 10),
                    Checkbox(
                      value: selectedChoiceIndex == i,
                      onChanged: (bool? value) {
                        _onChoiceSelected(i);
                      },
                      activeColor: Colors.white,
                      checkColor: Colors.blue,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ----------- Firebase Storage Functions -----------

/// Uploads image to Firebase Storage and returns the download URL
///
/// @param imageBytes - The image data as Uint8List
/// @returns The download URL of the uploaded image
Future<String> uploadFillTheBlank3ImageToFirebase({
  required Uint8List imageBytes,
}) async {
  try {
    // Use the specific storage bucket
    final storage = FirebaseStorage.instanceFor(
      bucket: 'gs://lexiboost-36801.firebasestorage.app',
    );
    final fileName =
        'fill_the_blank3_${DateTime.now().millisecondsSinceEpoch}.png';
    final path = 'game image/$fileName';

    final ref = storage.ref().child(path);
    final uploadTask = await ref.putData(
      imageBytes,
      SettableMetadata(contentType: 'image/png'),
    );

    final downloadUrl = await uploadTask.ref.getDownloadURL();
    print('Image uploaded successfully: $downloadUrl');
    return downloadUrl;
  } catch (e) {
    print('Error uploading image: $e');
    rethrow;
  }
}

/// Saves Fill The Blank 3 game data to Firebase
///
/// Structure: users/{userId}/created_games/{gameId}/game_rounds/{roundDocId}/game_type/{gameTypeDocId}
///
/// @param userId - The user ID
/// @param gameId - The game ID from created_games collection
/// @param roundDocId - The auto document ID from game_rounds collection
/// @param gameTypeDocId - The auto document ID from game_type subcollection
/// @param question - The question string
/// @param gameHint - The game hint string
/// @param answer - The correct answer index (0-3)
/// @param image - URL of the uploaded image
/// @param multipleChoice1 - First multiple choice option
/// @param multipleChoice2 - Second multiple choice option
/// @param multipleChoice3 - Third multiple choice option
/// @param multipleChoice4 - Fourth multiple choice option
Future<void> saveFillTheBlank3ToFirebase({
  required String userId,
  required String gameId,
  required String roundDocId,
  required String gameTypeDocId,
  required String question,
  required String gameHint,
  required int answer,
  required String image,
  required String multipleChoice1,
  required String multipleChoice2,
  required String multipleChoice3,
  required String multipleChoice4,
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
      'image': image, // URL of the uploaded image
      'question': question, // The question text
      'gameHint': gameHint, // The game hint
      'answer': answer, // Index of correct answer (0-3)
      'multipleChoice1': multipleChoice1, // First choice
      'multipleChoice2': multipleChoice2, // Second choice
      'multipleChoice3': multipleChoice3, // Third choice
      'multipleChoice4': multipleChoice4, // Fourth choice
      'gameType': 'fill_the_blank3',
      'timestamp': FieldValue.serverTimestamp(),
    };

    // Save to Firebase
    await docRef.set(data, SetOptions(merge: true));

    print('Fill The Blank 3 data saved successfully!');
  } catch (e) {
    print('Error saving Fill The Blank 3 data: $e');
    rethrow;
  }
}

/// Loads Fill The Blank 3 game data from Firebase
///
/// @param userId - The user ID
/// @param gameId - The game ID from created_games collection
/// @param roundDocId - The document ID from game_rounds collection
/// @param gameTypeDocId - The document ID from game_type subcollection
/// @returns Map containing question, gameHint, answer, image, and multiple choices
Future<Map<String, dynamic>?> loadFillTheBlank3FromFirebase({
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
        'question': data?['question'] ?? '',
        'gameHint': data?['gameHint'] ?? '',
        'answer': data?['answer'] ?? -1,
        'image': data?['image'] ?? '',
        'multipleChoice1': data?['multipleChoice1'] ?? '',
        'multipleChoice2': data?['multipleChoice2'] ?? '',
        'multipleChoice3': data?['multipleChoice3'] ?? '',
        'multipleChoice4': data?['multipleChoice4'] ?? '',
      };
    } else {
      print('Document does not exist');
      return null;
    }
  } catch (e) {
    print('Error loading Fill The Blank 3 data: $e');
    rethrow;
  }
}

/// Download image from URL and return as Uint8List
Future<Uint8List?> downloadImageFromUrl(String imageUrl) async {
  try {
    final response = await http.get(Uri.parse(imageUrl));
    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      print('Failed to download image: ${response.statusCode}');
      return null;
    }
  } catch (e) {
    print('Error downloading image: $e');
    return null;
  }
}
