// ignore_for_file: deprecated_member_use, avoid_print, prefer_interpolation_to_compose_strings

import 'dart:typed_data';
import 'package:animated_button/animated_button.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;

// ----------- Preview Widget (for Column 2) -----------
class MyFillInTheBlank2 extends StatefulWidget {
  final TextEditingController answerController; 
  final List<bool> visibleLetters;
  final Uint8List? pickedImage;
  final String? imageUrl; // Add imageUrl parameter
  final Function(int) onRevealLetter;
  final Function(int) onHideLetter;

  const MyFillInTheBlank2({
    super.key,
    required this.answerController,
    required this.visibleLetters,
    required this.onRevealLetter,
    required this.onHideLetter,
    this.pickedImage,
    this.imageUrl, // Optional imageUrl
  });

  @override
  State<MyFillInTheBlank2> createState() => _MyFillInTheBlank2State();
}

class _MyFillInTheBlank2State extends State<MyFillInTheBlank2> {
  late TextEditingController _userInputController;
  late List<String> _userAnswers;
  String _previousInput = "";
  String _previousAnswer = "";

  @override
  void initState() {
    super.initState();
    _previousAnswer = widget.answerController.text;
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

  void _resetUserInput() {
    _userInputController.clear();
    _previousInput = "";
    _initializeUserAnswers();
  }

  // Build the appropriate image widget based on available data
  Widget _buildImageWidget() {
    // Priority: pickedImage (local) > imageUrl (from Firebase)
    if (widget.pickedImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: Image.memory(widget.pickedImage!, fit: BoxFit.contain),
      );
    } else if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
      // Use FutureBuilder to load image with Firebase Storage SDK (bypasses CORS)
      return FutureBuilder<Uint8List?>(
        future: _loadImageFromFirebaseStorage(widget.imageUrl!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            print('========== IMAGE LOAD ERROR ==========');
            print('Image load error for URL: ${widget.imageUrl}');
            print('Error: ${snapshot.error}');
            print('======================================');

            // Fallback to CachedNetworkImage if Firebase Storage fails
            return ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: CachedNetworkImage(
                imageUrl: widget.imageUrl!,
                fit: BoxFit.contain,
                placeholder: (context, url) =>
                    const Center(child: CircularProgressIndicator()),
                errorWidget: (context, url, error) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error, color: Colors.red, size: 40),
                          const SizedBox(height: 8),
                          Text(
                            'Failed to load image',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'CORS issue - Configure Firebase Storage',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          }

          // Successfully loaded image bytes
          return ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: Image.memory(snapshot.data!, fit: BoxFit.contain),
          );
        },
      );
    } else {
      return Center(
        child: Text(
          "Image Hint",
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.blue,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }
  }

  /// Load image from Firebase Storage using the SDK (bypasses CORS)
  Future<Uint8List?> _loadImageFromFirebaseStorage(String imageUrl) async {
    try {
      // Check if it's a Firebase Storage URL
      if (imageUrl.contains('firebasestorage.googleapis.com')) {
        // Extract the path from the URL
        final uri = Uri.parse(imageUrl);
        final pathSegments = uri.pathSegments;

        // Find the path after /o/
        int oIndex = pathSegments.indexOf('o');
        if (oIndex != -1 && oIndex + 1 < pathSegments.length) {
          // Decode the path (it's URL encoded)
          String filePath = Uri.decodeComponent(pathSegments[oIndex + 1]);

          print('Loading image from Firebase Storage path: $filePath');

          // Use Firebase Storage SDK to get the image
          final storage = FirebaseStorage.instanceFor(
            bucket: 'gs://lexiboost-36801.firebasestorage.app',
          );
          final ref = storage.ref().child(filePath);
          final imageBytes = await ref.getData();

          print('Image loaded successfully: ${imageBytes?.length ?? 0} bytes');
          return imageBytes;
        }
      }

      // Fallback to HTTP request if not a Firebase Storage URL
      print('Using HTTP fallback for URL: $imageUrl');
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (e) {
      print('Error loading image from Firebase Storage: $e');
    }

    return null;
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

    // Check if answer changed (new page loaded) and reset
    if (_previousAnswer != answer) {
      _previousAnswer = answer;
      _resetUserInput();
    }

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
              
            ),
            child: _buildImageWidget(),
          ),
        ),

        const SizedBox(height: 30),

        // Display Answer TextField (disabled)
        Center(
          child: SizedBox(
            width: (MediaQuery.of(context).size.width * 0.6).clamp(0, 400),
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
            width: (MediaQuery.of(context).size.width * 0.6).clamp(0, 400),
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
  final TextEditingController hintController;
  final List<bool> visibleLetters;
  final Function(int) onToggle;
  final Function(Uint8List) onImagePicked;

  const MyFillInTheBlank2Settings({
    super.key,
    required this.answerController,
    required this.hintController,
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
              width: (MediaQuery.of(context).size.width * 0.6).clamp(0, 200),
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.black, width: 1),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextField(
                controller: widget.answerController,
                maxLength: 150,
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
              width: (MediaQuery.of(context).size.width * 0.6).clamp(0, 200),
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
                style: GoogleFonts.poppins(fontSize: 16, color: Colors.black),
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

// ----------- Firebase Storage Functions -----------

/// Uploads image to Firebase Storage and returns the download URL
///
/// @param imageBytes - The image data as Uint8List
/// @returns The download URL of the uploaded image
Future<String> uploadImageToFirebase({required Uint8List imageBytes}) async {
  try {
    // Use the specific storage bucket
    final storage = FirebaseStorage.instanceFor(
      bucket: 'gs://lexiboost-36801.firebasestorage.app',
    );
    final fileName =
        'fill_the_blank2_${DateTime.now().millisecondsSinceEpoch}.png';
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

/// Saves Fill the Blank 2 game data to Firebase
///
/// Structure: users/{userId}/created_games/{gameId}/game_rounds/{roundDocId}/game_type/{gameTypeDocId}
///
/// @param userId - The user ID
/// @param gameId - The game ID from created_games collection
/// @param roundDocId - The auto document ID from game_rounds collection
/// @param gameTypeDocId - The auto document ID from game_type subcollection
/// @param answer - The complete answer string
/// @param visibleLetters - Array of booleans (true = visible, false = hidden)
/// @param imageUrl - URL of the uploaded image hint
/// @param gameHint - Hint string for the game
Future<void> saveFillTheBlank2ToFirebase({
  required String userId,
  required String gameId,
  required String roundDocId,
  required String gameTypeDocId,
  required String answer,
  required List<bool> visibleLetters,
  required String imageUrl,
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
      'imageUrl': imageUrl, // URL of the image hint
      'answerText': answer, // Store the full answer text for reference
      'gameHint': gameHint, // Hint for the game
      'gameType': 'fill_the_blank2',
      'timestamp': FieldValue.serverTimestamp(),
    };

    // Save to Firebase
    await docRef.set(data, SetOptions(merge: true));

    print('Fill the Blank 2 data saved successfully!');
  } catch (e) {
    print('Error saving Fill the Blank 2 data: $e');
    rethrow;
  }
}

/// Loads Fill the Blank 2 game data from Firebase
///
/// @param userId - The user ID
/// @param gameId - The game ID from created_games collection
/// @param roundDocId - The document ID from game_rounds collection
/// @param gameTypeDocId - The document ID from game_type subcollection
/// @returns Map containing answer, visibleLetters, imageUrl, and gameHint
Future<Map<String, dynamic>?> loadFillTheBlank2FromFirebase({
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
        'imageUrl': data?['imageUrl'] ?? '',
        'gameHint': data?['gameHint'] ?? '',
      };
    } else {
      print('Document does not exist');
      return null;
    }
  } catch (e) {
    print('Error loading Fill the Blank 2 data: $e');
    rethrow;
  }
}

// ----------- Example Usage Widget -----------

class FillTheBlank2GameManager extends StatefulWidget {
  final String userId;
  final String gameId;
  final String roundDocId;
  final String gameTypeDocId;

  const FillTheBlank2GameManager({
    super.key,
    required this.userId,
    required this.gameId,
    required this.roundDocId,
    required this.gameTypeDocId,
  });

  @override
  State<FillTheBlank2GameManager> createState() =>
      _FillTheBlank2GameManagerState();
}

class _FillTheBlank2GameManagerState extends State<FillTheBlank2GameManager> {
  late TextEditingController _answerController;
  late TextEditingController _hintController;
  late List<bool> _visibleLetters;
  Uint8List? _pickedImage;
  String? _imageUrl;

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
    final data = await loadFillTheBlank2FromFirebase(
      userId: widget.userId,
      gameId: widget.gameId,
      roundDocId: widget.roundDocId,
      gameTypeDocId: widget.gameTypeDocId,
    );

    if (data != null) {
      setState(() {
        _answerController.text = data['answerText'];
        _visibleLetters = data['answer'];
        _imageUrl = data['imageUrl'];
        _hintController.text = data['gameHint'] ?? '';
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

    if (_pickedImage == null && (_imageUrl == null || _imageUrl!.isEmpty)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please upload an image'))); 
      return;
    }

    try {
      String finalImageUrl = _imageUrl ?? '';

      // Upload new image if one was picked
      if (_pickedImage != null) {
        finalImageUrl = await uploadImageToFirebase(imageBytes: _pickedImage!);
      }

      await saveFillTheBlank2ToFirebase(
        userId: widget.userId,
        gameId: widget.gameId,
        roundDocId: widget.roundDocId,
        gameTypeDocId: widget.gameTypeDocId,
        answer: _answerController.text,
        visibleLetters: _visibleLetters,
        imageUrl: finalImageUrl,
        gameHint: _hintController.text,
      );

      if (mounted) {
        setState(() {
          _imageUrl = finalImageUrl;
          _pickedImage = null; // Clear picked image after saving
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

  void _onImagePicked(Uint8List imageBytes) {
    setState(() {
      _pickedImage = imageBytes;
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
        title: const Text('Fill The Blank 2 Game'),
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
              child: MyFillInTheBlank2(
                answerController: _answerController,
                visibleLetters: _visibleLetters,
                pickedImage: _pickedImage,
                imageUrl: _imageUrl, // Pass the imageUrl from Firebase
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
              child: MyFillInTheBlank2Settings(
                answerController: _answerController,
                hintController: _hintController,
                visibleLetters: _visibleLetters,
                onToggle: _toggleLetterVisibility,
                onImagePicked: _onImagePicked,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
