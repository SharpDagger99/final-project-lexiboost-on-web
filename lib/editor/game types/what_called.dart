// ignore_for_file: avoid_print, deprecated_member_use

import 'dart:typed_data';
import 'package:animated_button/animated_button.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class MyWhatItIsCalled extends StatefulWidget {
  final TextEditingController sentenceController;
  final Uint8List? pickedImage; // 🔹 added image hint
  final String? imageUrl; // 🔹 Add imageUrl parameter

  const MyWhatItIsCalled({
    super.key,
    required this.sentenceController,
    this.pickedImage,
    this.imageUrl, // 🔹 Optional imageUrl
  });

  @override
  State<MyWhatItIsCalled> createState() => _MyWhatItIsCalledState();
}

class _MyWhatItIsCalledState extends State<MyWhatItIsCalled> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _speechEnabled = false;
  final TextEditingController _speechController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initSpeech();
  }

  void _initSpeech() async {
    _speechEnabled = await _speech.initialize(
      onStatus: (status) => print('Speech status: $status'),
      onError: (error) => print('Speech error: $error'),
    );
    setState(() {});
    print('Speech enabled: $_speechEnabled');
  }

  @override
  void dispose() {
    _speechController.dispose();
    super.dispose();
  }

  /// Load What is it called game data from Firebase
  ///
  /// Path: users/{userId}/created_games/{gameId}/game_rounds/{roundDocId}/game_type/{gameTypeDocId}
  ///
  /// @param userId - The user ID
  /// @param gameId - The game ID from created_games collection
  /// @param roundDocId - The document ID from game_rounds collection
  /// @param gameTypeDocId - The document ID from game_type subcollection
  /// @returns Map containing answer, gameHint, imageUrl, and imageBytes
  static Future<Map<String, dynamic>?> loadWhatCalledDataFromFirebase({
    required String userId,
    required String gameId,
    required String roundDocId,
    required String gameTypeDocId,
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

      // Get the document
      final docSnapshot = await docRef.get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data() ?? {};

        // Extract the data according to the structure shown in the image
        final result = {
          'answer': data['answer'] ?? '', // The answer text (e.g., "sample")
          'gameHint': data['gameHint'] ?? '', // The game hint (e.g., "sample")
          'imageUrl': data['imageUrl'] ?? '', // Firebase Storage path/URL
          'gameType': data['gameType'] ?? 'what_called',
          'createdAt': data['createdAt'],
          'timestamp': data['timestamp'],
        };

        // Download image bytes if imageUrl exists
        final imageUrl = result['imageUrl'] as String?;
        if (imageUrl != null && imageUrl.isNotEmpty) {
          try {
            print('Downloading What is it called image from: $imageUrl');
            final imageBytes = await _downloadImageFromFirebaseStorage(
              imageUrl,
            );
            if (imageBytes != null) {
              result['imageBytes'] = imageBytes;
              print(
                'What is it called image downloaded successfully, size: ${imageBytes.length} bytes',
              );
            } else {
              print('What is it called image download returned null');
            }
          } catch (e) {
            print('Failed to download What is it called image: $e');
          }
        }

        print('What is it called data loaded successfully: $result');
        return result;
      } else {
        print('What is it called document does not exist');
        return null;
      }
    } catch (e) {
      print('Error loading What is it called data: $e');
      return null;
    }
  }

  /// Download image from Firebase Storage path and return as Uint8List
  static Future<Uint8List?> _downloadImageFromFirebaseStorage(
    String storagePath,
  ) async {
    try {
      // Check if it's a Firebase Storage path (gs://)
      if (storagePath.startsWith('gs://')) {
        // Extract the path from the gs:// URL
        final uri = Uri.parse(storagePath);
        final path = uri.path;

        print('Loading image from Firebase Storage path: $path');

        // Use Firebase Storage SDK to get the image
        final storage = FirebaseStorage.instanceFor(
          bucket: 'gs://lexiboost-36801.firebasestorage.app',
        );
        final ref = storage.ref().child(path);
        final imageBytes = await ref.getData();

        print('Image loaded successfully: ${imageBytes?.length ?? 0} bytes');
        return imageBytes;
      } else {
        // Fallback to HTTP request if not a Firebase Storage path
        print('Using HTTP fallback for URL: $storagePath');
        final response = await http.get(Uri.parse(storagePath));
        if (response.statusCode == 200) {
          return response.bodyBytes;
        } else {
          print('Failed to download image: ${response.statusCode}');
          return null;
        }
      }
    } catch (e) {
      print('Error downloading image from Firebase Storage: $e');
      return null;
    }
  }

  /// Save What is it called game data to Firebase
  ///
  /// Path: users/{userId}/created_games/{gameId}/game_rounds/{roundDocId}/game_type/{gameTypeDocId}
  ///
  /// @param userId - The user ID
  /// @param gameId - The game ID from created_games collection
  /// @param roundDocId - The document ID from game_rounds collection
  /// @param gameTypeDocId - The document ID from game_type subcollection
  /// @param answer - The answer text
  /// @param gameHint - The game hint
  /// @param imageUrl - URL of the uploaded image
  /// @param imageBytes - Optional image bytes to upload
  static Future<void> saveWhatCalledDataToFirebase({
    required String userId,
    required String gameId,
    required String roundDocId,
    required String gameTypeDocId,
    required String answer,
    required String gameHint,
    String? imageUrl,
    Uint8List? imageBytes,
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

      String? finalImageUrl = imageUrl;

      // Upload image if new bytes are provided
      if (imageBytes != null) {
        try {
          finalImageUrl = await _uploadImageToStorage(
            imageBytes,
            'what_called_image',
          );
          print(
            'What is it called image uploaded successfully: $finalImageUrl',
          );
        } catch (e) {
          print('Failed to upload What is it called image: $e');
        }
      }

      // Prepare the data according to the structure shown in the image
      final data = {
        'answer': answer, // The answer text (e.g., "sample")
        'gameHint': gameHint, // The game hint (e.g., "sample")
        'imageUrl': finalImageUrl ?? '', // Firebase Storage path/URL
        'gameType': 'what_called',
        'createdAt': FieldValue.serverTimestamp(),
        'timestamp': FieldValue.serverTimestamp(),
      };

      // Save to Firebase
      await docRef.set(data, SetOptions(merge: true));

      print('What is it called data saved successfully!');
    } catch (e) {
      print('Error saving What is it called data: $e');
      rethrow;
    }
  }

  /// Upload image to Firebase Storage and return download URL
  static Future<String> _uploadImageToStorage(
    Uint8List imageBytes,
    String imageName,
  ) async {
    try {
      final storage = FirebaseStorage.instanceFor(
        bucket: 'gs://lexiboost-36801.firebasestorage.app',
      );
      final fileName =
          '${imageName}_${DateTime.now().millisecondsSinceEpoch}.png';
      final path = 'game image/$fileName';

      final ref = storage.ref().child(path);
      await ref.putData(
        imageBytes,
        SettableMetadata(contentType: 'image/png'),
      );

      // Return the Firebase Storage path instead of download URL
      final storagePath = 'gs://lexiboost-36801.firebasestorage.app/$path';
      print('Image uploaded successfully: $storagePath');
      return storagePath;
    } catch (e) {
      print('Error uploading image: $e');
      rethrow;
    }
  }

  void _toggleListening() async {
    if (!_isListening) {
      if (!_speechEnabled) {
        _speechEnabled = await _speech.initialize(
          onStatus: (status) => print('Speech status: $status'),
          onError: (error) => print('Speech error: $error'),
        );
      }

      if (_speechEnabled) {
        setState(() => _isListening = true);
        print('Starting to listen...');

        await _speech.listen(
          onResult: (result) {
            print('Recognized words: ${result.recognizedWords}');
            if (mounted) {
              setState(() {
                _speechController.text = result.recognizedWords;
              });
            }
          },
          listenFor: const Duration(minutes: 5),
          pauseFor: const Duration(seconds: 5),
          partialResults: true,
          onSoundLevelChange: (level) => print('Sound level: $level'),
          cancelOnError: true,
          listenMode: stt.ListenMode.confirmation,
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Speech recognition not available. Please check microphone permissions.',
              ),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } else {
      print('Stopping listening...');
      setState(() => _isListening = false);
      await _speech.stop();
    }
  }

  void _clearSpeechAnswer() {
    setState(() {
      _speechController.clear();
    });
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
      // Check if it's a Firebase Storage path (gs://)
      if (imageUrl.startsWith('gs://')) {
        // Extract the path from the gs:// URL
        final uri = Uri.parse(imageUrl);
        final path = uri.path;

        print('Loading image from Firebase Storage path: $path');

        // Use Firebase Storage SDK to get the image
        final storage = FirebaseStorage.instanceFor(
          bucket: 'gs://lexiboost-36801.firebasestorage.app',
        );
        final ref = storage.ref().child(path);
        final imageBytes = await ref.getData();

        print('Image loaded successfully: ${imageBytes?.length ?? 0} bytes');
        return imageBytes;
      }
      // Check if it's a Firebase Storage URL (legacy support)
      else if (imageUrl.contains('firebasestorage.googleapis.com')) {
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "What is it called?",
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),

        Text(
          "Guess the image by saying something.",
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),

        const SizedBox(height: 10),

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

        const SizedBox(height: 20),

        // ✅ Only "Your answer" remains
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Center(
            child: Text(
              "Your answer:",
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
        ),

        SizedBox(
          width: 400,
          child: TextField(
            readOnly: true,
            maxLines: 6,
            controller: _speechController,
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.black),
            decoration: InputDecoration(
              hintText: "Say something first...",
              hintStyle: GoogleFonts.poppins(
                color: Colors.black54,
                fontSize: 14,
              ),
              filled: true,
              fillColor: Colors.white,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.green, width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.blue, width: 2),
              ),
            ),
          ),
        ),

        Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                AnimatedButton(
                  width: 70,
                  height: 70,
                  color: Colors.pinkAccent,
                  onPressed: _clearSpeechAnswer,
                  child: const Icon(
                    Icons.restart_alt_rounded,
                    color: Colors.black,
                    size: 50,
                  ),
                ),
                AnimatedButton(
                  width: 70,
                  height: 70,
                  color: _isListening ? Colors.orange : Colors.green,
                  onPressed: _toggleListening,
                  child: Icon(
                    _isListening ? Icons.mic : Icons.mic_none_rounded,
                    color: Colors.black,
                    size: 50,
                  ),
                ),
               
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ================================
// Column 3 - Settings Widget
// ================================
class MyWhatItIsCalledSettings extends StatefulWidget {
  final TextEditingController sentenceController;
  final TextEditingController
  hintController; // 🔹 hint controller from game_edit
  final Function(Uint8List) onImagePicked; // 🔹 callback for image

  const MyWhatItIsCalledSettings({
    super.key,
    required this.sentenceController,
    required this.hintController,
    required this.onImagePicked,
  });

  TextEditingController get answerController => sentenceController;

  @override
  State<MyWhatItIsCalledSettings> createState() =>
      _MyWhatItIsCalledSettingsState();
}

class _MyWhatItIsCalledSettingsState extends State<MyWhatItIsCalledSettings> {
  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.isNotEmpty) {
      final fileBytes = result.files.first.bytes;
      if (fileBytes != null) {
        widget.onImagePicked(fileBytes); // pass image back
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
            maxLength: 25, // 🔹 limit to 25 characters
            style: GoogleFonts.poppins(fontSize: 16, color: Colors.black),
            decoration: InputDecoration(
              hintText: "The Answer...",
              hintStyle: GoogleFonts.poppins(
                color: Colors.black54,
                fontSize: 14,
              ),
              border: InputBorder.none,
              counterText: "", // 🔹 hides default counter below field
            ),
          ),
        ),

        const SizedBox(height: 20),

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
            maxLength: 50, // 🔹 limit to 50 characters
            style: GoogleFonts.poppins(fontSize: 16, color: Colors.black),
            decoration: InputDecoration(
              hintText: "Enter game hint...",
              hintStyle: GoogleFonts.poppins(
                color: Colors.black54,
                fontSize: 14,
              ),
              border: InputBorder.none,
              counterText: "", // 🔹 hides default counter below field
            ),
          ),
        ),
      ],
    );
  }
}

// ================================
// Example Usage Widget
// ================================

/// Example widget demonstrating how to use the What is it called game type
/// with proper Firebase data loading and retention
class WhatCalledGameManager extends StatefulWidget {
  final String userId;
  final String gameId;
  final String roundDocId;
  final String gameTypeDocId;

  const WhatCalledGameManager({
    super.key,
    required this.userId,
    required this.gameId,
    required this.roundDocId,
    required this.gameTypeDocId,
  });

  @override
  State<WhatCalledGameManager> createState() => _WhatCalledGameManagerState();
}

class _WhatCalledGameManagerState extends State<WhatCalledGameManager> {
  late TextEditingController _sentenceController;
  late TextEditingController _hintController;
  Uint8List? _pickedImage;
  String? _imageUrl;
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _sentenceController = TextEditingController();
    _hintController = TextEditingController();

    // Load existing data from Firebase
    _loadGameData();
  }

  /// Load What is it called game data from Firebase
  /// This demonstrates how to retrieve data from the Firebase structure:
  /// users/{userId}/created_games/{gameId}/game_rounds/{roundDocId}/game_type/{gameTypeDocId}
  Future<void> _loadGameData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data = await _MyWhatItIsCalledState.loadWhatCalledDataFromFirebase(
        userId: widget.userId,
        gameId: widget.gameId,
        roundDocId: widget.roundDocId,
        gameTypeDocId: widget.gameTypeDocId,
      );

      if (data != null && mounted) {
        setState(() {
          _sentenceController.text = data['answer'] ?? '';
          _hintController.text = data['gameHint'] ?? '';
          _imageUrl = data['imageUrl'] ?? '';
          _pickedImage = data['imageBytes'] as Uint8List?;
        });

        print('Data loaded successfully:');
        print('- Answer: ${data['answer']}');
        print('- Game Hint: ${data['gameHint']}');
        print('- Image URL: ${data['imageUrl']}');
        print(
          '- Image Bytes: ${data['imageBytes'] != null ? '${(data['imageBytes'] as Uint8List).length} bytes' : 'null'}',
        );
      } else {
        print('No data found for What is it called game');
      }
    } catch (e) {
      print('Error loading What is it called data: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Save What is it called game data to Firebase
  /// This demonstrates how to save data to the Firebase structure:
  /// users/{userId}/created_games/{gameId}/game_rounds/{roundDocId}/game_type/{gameTypeDocId}
  Future<void> _saveGameData() async {
    if (_sentenceController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter an answer')));
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _MyWhatItIsCalledState.saveWhatCalledDataToFirebase(
        userId: widget.userId,
        gameId: widget.gameId,
        roundDocId: widget.roundDocId,
        gameTypeDocId: widget.gameTypeDocId,
        answer: _sentenceController.text,
        gameHint: _hintController.text,
        imageUrl: _imageUrl,
        imageBytes: _pickedImage,
      );

      if (mounted) {
        setState(() {
          _pickedImage = null; // Clear picked image after saving
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Game data saved successfully!')),
        );
      }
    } catch (e) {
      print('Error saving What is it called data: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving data: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _onImagePicked(Uint8List imageBytes) {
    setState(() {
      _pickedImage = imageBytes;
    });
  }

  @override
  void dispose() {
    _sentenceController.dispose();
    _hintController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('What is it called Game'),
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            onPressed: _isSaving ? null : _saveGameData,
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
              child: MyWhatItIsCalled(
                sentenceController: _sentenceController,
                pickedImage: _pickedImage,
                imageUrl: _imageUrl,
              ),
            ),
          ),

          // Settings Column
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.blue.shade700,
              padding: const EdgeInsets.all(20),
              child: MyWhatItIsCalledSettings(
                sentenceController: _sentenceController,
                hintController: _hintController,
                onImagePicked: _onImagePicked,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
