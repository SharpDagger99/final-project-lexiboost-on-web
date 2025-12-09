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
  final bool showImageHint; // Add toggle state

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
    this.showImageHint = true, // Default to showing image
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
          showImageHint
              ? "Guess what's the answer on the given question with image hint."
              : "Guess the answer on the given question.",
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 20),

        // Image preview (only show if toggle is on)
        if (showImageHint) ...[
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
        ],

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
                    
                    // Calculate button width based on text length (max 80 chars)
                    final textLength = choice.length.clamp(0, 80);
                    final calculatedWidth = textLength * 8.0;
                    
                    // Cap width at 400px, text will wrap to second line if it exceeds this
                    final buttonWidth = calculatedWidth.clamp(200.0, 400.0);
                    
                    // Determine if text should wrap to 2 lines (when calculated width exceeds 400)
                    final shouldWrap = calculatedWidth >= 400.0;
                    final buttonHeight = shouldWrap ? 70.0 : 50.0;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: AnimatedButton(
                        width: buttonWidth,
                        height: buttonHeight,
                        color: isSelected ? Colors.green : Colors.lightBlue,
                        onPressed: () => onAnswerSelected(index),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                          child: Text(
                            choice.isNotEmpty ? choice : "Choice ${index + 1}",
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.visible,
                          ),
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
  final bool initialShowImageHint; // Add initial toggle state
  final Function(bool) onImageHintToggled; // Add toggle callback

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
    this.initialShowImageHint = true,
    required this.onImageHintToggled,
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
  late bool showImageHint; // Track image hint toggle state

  @override
  void initState() {
    super.initState();
    
    // Initialize image hint toggle state
    showImageHint = widget.initialShowImageHint;
    
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
      // Temporarily remove listeners to prevent infinite rebuild loop
      for (var controller in choiceControllers) {
        controller.removeListener(_onChoicesChanged);
      }

      // Update controller texts
      for (int i = 0; i < choiceControllers.length; i++) {
        if (i < widget.initialChoices.length) {
          choiceControllers[i].text = widget.initialChoices[i];
        } else {
          choiceControllers[i].text = '';
        }
      }
      
      // Re-add listeners after updating
      for (var controller in choiceControllers) {
        controller.addListener(_onChoicesChanged);
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

    // Update showImageHint when widget properties change (e.g., when switching pages)
    if (widget.initialShowImageHint != oldWidget.initialShowImageHint) {
      setState(() {
        showImageHint = widget.initialShowImageHint;
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

  /// Shows a confirmation dialog before toggling the image hint visibility
  Future<void> _showImageHintToggleConfirmation(bool newValue) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2D2D2D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            newValue ? 'Show Image Hint?' : 'Hide Image Hint?',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          content: Text(
            newValue
                ? 'Are you sure you want to show the image hint to players?'
                : 'Are you sure you want to hide the image hint from players?',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'Confirm',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      setState(() {
        showImageHint = newValue;
      });
      widget.onImageHintToggled(newValue);
    }
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
        // Upload image with toggle
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
            const SizedBox(width: 10),
            // Toggle switch for image hint
            Row(
              children: [
                Text(
                  "Show Hint",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: showImageHint,
                  onChanged: (value) {
                    _showImageHintToggleConfirmation(value);
                  },
                  activeThumbColor: Colors.green,
                  inactiveThumbColor: Colors.grey,
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Question input
        Text(
          "Question:",
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Container(
            height: 50,
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
        ),

        const SizedBox(height: 20),

        // Game Hint input
        Text(
          "Game Hint:",
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Container(
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
            // Choice 1
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                children: [
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 300),
                      child: TextField(
                        controller: choiceControllers[0],
                        maxLength: 80,
                        maxLines: 3,
                        minLines: 1,
                        decoration: InputDecoration(
                          hintText: "Choice 1...",
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
                  ),
                  const SizedBox(width: 10),
                  Checkbox(
                    value: selectedChoiceIndex == 0,
                    onChanged: (bool? value) {
                      _onChoiceSelected(0);
                    },
                    activeColor: Colors.white,
                    checkColor: Colors.blue,
                  ),
                ],
              ),
            ),

            // Choice 2
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                children: [
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 300),
                      child: TextField(
                        controller: choiceControllers[1],
                        maxLength: 80,
                        maxLines: 3,
                        minLines: 1,
                        decoration: InputDecoration(
                          hintText: "Choice 2...",
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
                  ),
                  const SizedBox(width: 10),
                  Checkbox(
                    value: selectedChoiceIndex == 1,
                    onChanged: (bool? value) {
                      _onChoiceSelected(1);
                    },
                    activeColor: Colors.white,
                    checkColor: Colors.blue,
                  ),
                ],
              ),
            ),

            // Choice 3
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                children: [
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 300),
                      child: TextField(
                        controller: choiceControllers[2],
                        maxLength: 80,
                        maxLines: 3,
                        minLines: 1,
                        decoration: InputDecoration(
                          hintText: "Choice 3...",
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
                  ),
                  const SizedBox(width: 10),
                  Checkbox(
                    value: selectedChoiceIndex == 2,
                    onChanged: (bool? value) {
                      _onChoiceSelected(2);
                    },
                    activeColor: Colors.white,
                    checkColor: Colors.blue,
                  ),
                ],
              ),
            ),

            // Choice 4
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                children: [
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 300),
                      child: TextField(
                        controller: choiceControllers[3],
                        maxLength: 80,
                        maxLines: 3,
                        minLines: 1,
                        decoration: InputDecoration(
                          hintText: "Choice 4...",
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
                  ),
                  const SizedBox(width: 10),
                  Checkbox(
                    value: selectedChoiceIndex == 3,
                    onChanged: (bool? value) {
                      _onChoiceSelected(3);
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
/// @param showImageHint - Whether to show the image hint (default: true)
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
  bool showImageHint = true,
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
      'showImageHint': showImageHint, // Toggle state for image hint
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
/// @returns Map containing question, gameHint, answer, image, multiple choices, and showImageHint
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
        'showImageHint': data?['showImageHint'] ?? true, // Default to true if not set
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
