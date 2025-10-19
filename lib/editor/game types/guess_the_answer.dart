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
class MyGuessTheAnswer extends StatelessWidget {
  final TextEditingController hintController;
  final TextEditingController questionController;
  final List<bool> visibleLetters;
  final List<Uint8List?> pickedImages; // ✅ now supports 3 images
  final List<String?> imageUrls; // ✅ Add image URLs parameter
  final List<String> multipleChoices;
  final int correctAnswerIndex;
  final int selectedAnswerIndex;
  final Function(int) onAnswerSelected; 

  const MyGuessTheAnswer({
    super.key,
    required this.hintController,
    required this.questionController,
    required this.visibleLetters,
    this.pickedImages = const [null, null, null],
    this.imageUrls = const [null, null, null],
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
          "Guess what's the answer of the given question with image hints.",
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 20),

        // Image preview row (3 images)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            final img = pickedImages.length > index
                ? pickedImages[index]
                : null;
            final imgUrl = imageUrls.length > index ? imageUrls[index] : null;
            
            return Container(
              width: 120,
              height: 120,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                
              ),
              child: img != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Image.memory(img, fit: BoxFit.cover),
                    )
                  : imgUrl != null && imgUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Image.network(
                        imgUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 24,
                            ),
                          );
                        },
                      ),
                    )
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          "Image ${index + 1}",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
            );
          }),
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

        // Multiple choice buttons (only show if choices exist)
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
class MyGuessTheAnswerSettings extends StatefulWidget {
  final TextEditingController hintController;
  final TextEditingController questionController;
  final List<bool> visibleLetters;
  final Function(int) onToggle;
  final Function(int, Uint8List) onImagePicked; // ✅ index + image
  final Function(List<String>) onChoicesChanged;
  final Function(int) onCorrectAnswerSelected;
  final List<String> initialChoices; // ✅ Add initial choices
  final int initialCorrectIndex; // ✅ Add initial correct answer index

  const MyGuessTheAnswerSettings({
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
  State<MyGuessTheAnswerSettings> createState() =>
      _MyGuessTheAnswerSettingsState();
}

class _MyGuessTheAnswerSettingsState extends State<MyGuessTheAnswerSettings> {
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
    
    // ✅ Load initial choices into controllers
    for (int i = 0; i < choiceControllers.length; i++) {
      if (i < widget.initialChoices.length) {
        choiceControllers[i].text = widget.initialChoices[i];
      }
      choiceControllers[i].addListener(_onChoicesChanged);
    }

    // ✅ Set initial correct answer index (default to 0 if not provided)
    selectedChoiceIndex = widget.initialCorrectIndex >= 0
        ? widget.initialCorrectIndex
        : 0;

    // Notify parent of the default selection
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onCorrectAnswerSelected(selectedChoiceIndex);
    });
  }

  @override
  void didUpdateWidget(MyGuessTheAnswerSettings oldWidget) {
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

  Future<void> _pickImage(int index) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.isNotEmpty) {
      final fileBytes = result.files.first.bytes;
      if (fileBytes != null) {
        widget.onImagePicked(index, fileBytes);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Upload images row
        Row(
          children: [
            Text(
              "Images:",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),

            const SizedBox(width: 10),

            Row(
              children: List.generate(3, (index) {
                return Padding(
                  padding: const EdgeInsets.only(left: 5, right: 5),
                  child: AnimatedButton(
                    width: 80,
                    height: 45,
                    color: Colors.white,
                    onPressed: () => _pickImage(index),
                    child: Text(
                      "Image ${index + 1}",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                );
              }),
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
                      constraints: const BoxConstraints(maxWidth: 350),
                      child: TextField(
                        controller: choiceControllers[0],
                        maxLength: 50,
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
                      constraints: const BoxConstraints(maxWidth: 350),
                      child: TextField(
                        controller: choiceControllers[1],
                        maxLength: 50,
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
                      constraints: const BoxConstraints(maxWidth: 350),
                      child: TextField(
                        controller: choiceControllers[2],
                        maxLength: 50,
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
                      constraints: const BoxConstraints(maxWidth: 350),
                      child: TextField(
                        controller: choiceControllers[3],
                        maxLength: 50,
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
/// @param imageIndex - The index of the image (1, 2, or 3)
/// @returns The download URL of the uploaded image
Future<String> uploadGuessTheAnswerImageToFirebase({
  required Uint8List imageBytes,
  required int imageIndex,
}) async {
  try {
    // Use the specific storage bucket
    final storage = FirebaseStorage.instanceFor(
      bucket: 'gs://lexiboost-36801.firebasestorage.app',
    );
    final fileName =
        'guess_the_answer_image${imageIndex}_${DateTime.now().millisecondsSinceEpoch}.png';
    final path = 'game image/$fileName';

    final ref = storage.ref().child(path);
    final uploadTask = await ref.putData(
      imageBytes,
      SettableMetadata(contentType: 'image/png'),
    );

    final downloadUrl = await uploadTask.ref.getDownloadURL();
    print('Image $imageIndex uploaded successfully: $downloadUrl');
    return downloadUrl;
  } catch (e) {
    print('Error uploading image $imageIndex: $e');
    rethrow;
  }
}

/// Saves Guess The Answer game data to Firebase
///
/// Structure: users/{userId}/created_games/{gameId}/game_rounds/{roundDocId}/game_type/{gameTypeDocId}
///
/// @param userId - The user ID
/// @param gameId - The game ID from created_games collection
/// @param roundDocId - The auto document ID from game_rounds collection
/// @param gameTypeDocId - The auto document ID from game_type subcollection
/// @param question - The question string
/// @param hint - The game hint string
/// @param image1 - URL of the first uploaded image
/// @param image2 - URL of the second uploaded image
/// @param image3 - URL of the third uploaded image
/// @param multipleChoice1 - First multiple choice option
/// @param multipleChoice2 - Second multiple choice option
/// @param multipleChoice3 - Third multiple choice option
/// @param multipleChoice4 - Fourth multiple choice option
/// @param correctAnswerIndex - Index of the correct answer (0-3)
Future<void> saveGuessTheAnswerToFirebase({
  required String userId,
  required String gameId,
  required String roundDocId,
  required String gameTypeDocId,
  required String question,
  required String hint,
  required String image1,
  required String image2,
  required String image3,
  required String multipleChoice1,
  required String multipleChoice2,
  required String multipleChoice3,
  required String multipleChoice4,
  required int correctAnswerIndex,
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
      'question': question, // The question text
      'hint': hint, // The game hint
      'image1': image1, // URL of the first image
      'image2': image2, // URL of the second image
      'image3': image3, // URL of the third image
      'multipleChoice1': multipleChoice1, // First choice
      'multipleChoice2': multipleChoice2, // Second choice
      'multipleChoice3': multipleChoice3, // Third choice
      'multipleChoice4': multipleChoice4, // Fourth choice
      'correctAnswerIndex': correctAnswerIndex, // Index of correct answer (0-3)
      'gameType': 'guess_the_answer',
      'timestamp': FieldValue.serverTimestamp(),
    };

    // Save to Firebase
    await docRef.set(data, SetOptions(merge: true));

    print('Guess The Answer data saved successfully!');
  } catch (e) {
    print('Error saving Guess The Answer data: $e');
    rethrow;
  }
}

/// Loads Guess The Answer game data from Firebase
///
/// @param userId - The user ID
/// @param gameId - The game ID from created_games collection
/// @param roundDocId - The document ID from game_rounds collection
/// @param gameTypeDocId - The document ID from game_type subcollection
/// @returns Map containing question, hint, images, multiple choices, and correct answer index
Future<Map<String, dynamic>?> loadGuessTheAnswerFromFirebase({
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
        'hint': data?['hint'] ?? '',
        'image1': data?['image1'] ?? '',
        'image2': data?['image2'] ?? '',
        'image3': data?['image3'] ?? '',
        'multipleChoice1': data?['multipleChoice1'] ?? '',
        'multipleChoice2': data?['multipleChoice2'] ?? '',
        'multipleChoice3': data?['multipleChoice3'] ?? '',
        'multipleChoice4': data?['multipleChoice4'] ?? '',
        'correctAnswerIndex': data?['correctAnswerIndex'] ?? -1,
      };
    } else {
      print('Document does not exist');
      return null;
    }
  } catch (e) {
    print('Error loading Guess The Answer data: $e');
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

// ----------- Example Usage Widget -----------

class GuessTheAnswerGameManager extends StatefulWidget {
  final String userId;
  final String gameId;
  final String roundDocId;
  final String gameTypeDocId;

  const GuessTheAnswerGameManager({
    super.key,
    required this.userId,
    required this.gameId,
    required this.roundDocId,
    required this.gameTypeDocId,
  });

  @override
  State<GuessTheAnswerGameManager> createState() =>
      _GuessTheAnswerGameManagerState();
}

class _GuessTheAnswerGameManagerState extends State<GuessTheAnswerGameManager> {
  late TextEditingController _questionController;
  late TextEditingController _hintController;
  late List<TextEditingController> _choiceControllers;
  List<Uint8List?> _pickedImages = [null, null, null];
  List<String> _imageUrls = ['', '', ''];
  int _selectedChoiceIndex = 0; // Default to first choice

  @override
  void initState() {
    super.initState();
    _questionController = TextEditingController();
    _hintController = TextEditingController();
    _choiceControllers = List.generate(4, (index) => TextEditingController());

    // Load existing data if available
    _loadGameData();
  }

  Future<void> _loadGameData() async {
    final data = await loadGuessTheAnswerFromFirebase(
      userId: widget.userId,
      gameId: widget.gameId,
      roundDocId: widget.roundDocId,
      gameTypeDocId: widget.gameTypeDocId,
    );

    if (data != null) {
      setState(() {
        _questionController.text = data['question'];
        _hintController.text = data['hint'];
        _imageUrls[0] = data['image1'];
        _imageUrls[1] = data['image2'];
        _imageUrls[2] = data['image3'];
        _selectedChoiceIndex = data['correctAnswerIndex'] ?? -1;
        _choiceControllers[0].text = data['multipleChoice1'];
        _choiceControllers[1].text = data['multipleChoice2'];
        _choiceControllers[2].text = data['multipleChoice3'];
        _choiceControllers[3].text = data['multipleChoice4'];
      });

      // Download images if URLs exist
      for (int i = 0; i < 3; i++) {
        if (_imageUrls[i].isNotEmpty) {
          try {
            final imageBytes = await downloadImageFromUrl(_imageUrls[i]);
            if (imageBytes != null) {
              setState(() {
                _pickedImages[i] = imageBytes;
              });
            }
          } catch (e) {
            print('Failed to download image ${i + 1}: $e');
          }
        }
      }
    }
  }

  Future<void> _saveGameData() async {
    if (_questionController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a question')));
      return;
    }

    if (_selectedChoiceIndex < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a correct answer')),
      );
      return;
    }

    try {
      List<String> finalImageUrls = List.from(_imageUrls);

      // Upload new images if they were picked
      for (int i = 0; i < 3; i++) {
        if (_pickedImages[i] != null) {
          finalImageUrls[i] = await uploadGuessTheAnswerImageToFirebase(
            imageBytes: _pickedImages[i]!,
            imageIndex: i + 1,
          );
        }
      }

      await saveGuessTheAnswerToFirebase(
        userId: widget.userId,
        gameId: widget.gameId,
        roundDocId: widget.roundDocId,
        gameTypeDocId: widget.gameTypeDocId,
        question: _questionController.text,
        hint: _hintController.text,
        image1: finalImageUrls[0],
        image2: finalImageUrls[1],
        image3: finalImageUrls[2],
        multipleChoice1: _choiceControllers[0].text,
        multipleChoice2: _choiceControllers[1].text,
        multipleChoice3: _choiceControllers[2].text,
        multipleChoice4: _choiceControllers[3].text,
        correctAnswerIndex: _selectedChoiceIndex,
      );

      if (mounted) {
        setState(() {
          _imageUrls = finalImageUrls;
          _pickedImages = [
            null,
            null,
            null,
          ]; // Clear picked images after saving
        });

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

  void _onImagePicked(int index, Uint8List imageBytes) {
    setState(() {
      _pickedImages[index] = imageBytes;
    });
  }

  void _onChoicesChanged(List<String> choices) {
    // This can be used to update the choices in real-time if needed
  }

  void _onCorrectAnswerSelected(int index) {
    setState(() {
      _selectedChoiceIndex = index;
    });
  }

  @override
  void dispose() {
    _questionController.dispose();
    _hintController.dispose();
    for (var controller in _choiceControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Guess The Answer Game'),
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
              child: MyGuessTheAnswer(
                questionController: _questionController,
                hintController: _hintController,
                visibleLetters: [], // Not used in this game type
                pickedImages: _pickedImages,
                multipleChoices: _choiceControllers
                    .map((controller) => controller.text)
                    .toList(),
                correctAnswerIndex: _selectedChoiceIndex,
                selectedAnswerIndex: -1, // Not used in this example
                onAnswerSelected: (index) {}, // Not used in this example
              ),
            ),
          ),

          // Settings Column
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.blue.shade700,
              padding: const EdgeInsets.all(20),
              child: MyGuessTheAnswerSettings(
                questionController: _questionController,
                hintController: _hintController,
                visibleLetters: [], // Not used in this game type
                onToggle: (int index) {}, // Not used in this game type
                onImagePicked: _onImagePicked,
                onChoicesChanged: _onChoicesChanged,
                onCorrectAnswerSelected: _onCorrectAnswerSelected,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
