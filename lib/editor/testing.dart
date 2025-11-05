// ignore_for_file: avoid_print, deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animated_button/animated_button.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:lexi_on_web/editor/game%20types/fill_the_blank.dart';
import 'package:lexi_on_web/editor/game%20types/fill_the_blank2.dart';
import 'package:lexi_on_web/editor/game%20types/fill_the_blank3.dart';
import 'package:lexi_on_web/editor/game%20types/guess_the_answer.dart';
import 'package:lexi_on_web/editor/game%20types/read_the_sentence.dart';
import 'package:lexi_on_web/editor/game%20types/what_called.dart';
import 'package:lexi_on_web/editor/game%20types/listen_and_repeat.dart';
import 'package:lexi_on_web/editor/game%20types/math.dart';
import 'package:lexi_on_web/editor/game%20types/image_match.dart';
import 'package:lexi_on_web/editor/game%20types/stroke.dart';

// Page data class to store page content
class TestPageData {
  String gameType;
  String answer;
  String descriptionField;
  String readSentence;
  String listenAndRepeat;
  List<bool> visibleLetters;
  Uint8List? selectedImageBytes;
  Uint8List? whatCalledImageBytes;
  List<String> multipleChoices;
  List<Uint8List?> guessAnswerImages;
  List<Uint8List?> imageMatchImages;
  int imageMatchCount;
  Map<int, int>
  imageMatchMappings; // Stores which odd image matches which even image
  String hint;
  String? imageUrl;
  String? whatCalledImageUrl;
  List<String?> guessAnswerImageUrls;
  int correctAnswerIndex;
  String? listenAndRepeatAudioUrl;
  Uint8List? listenAndRepeatAudioBytes;
  int mathTotalBoxes;
  List<String> mathBoxValues;
  List<String> mathOperators;
  String mathAnswer;
  String? docId; // Firestore document ID for this page
  String? gameTypeDocId; // Firestore document ID for the game_type document

  TestPageData({
    this.gameType = 'Fill in the blank',
    this.answer = '',
    this.descriptionField = '',
    this.readSentence = '',
    this.listenAndRepeat = '',
    this.visibleLetters = const [],
    this.selectedImageBytes,
    this.whatCalledImageBytes,
    this.multipleChoices = const [],
    List<Uint8List?>? guessAnswerImages,
    List<Uint8List?>? imageMatchImages,
    this.imageMatchCount = 2,
    Map<int, int>? imageMatchMappings,
    this.hint = '',
    this.imageUrl,
    this.whatCalledImageUrl,
    List<String?>? guessAnswerImageUrls,
    this.correctAnswerIndex = -1,
    this.listenAndRepeatAudioUrl,
    this.listenAndRepeatAudioBytes,
    this.mathTotalBoxes = 1,
    this.mathBoxValues = const [],
    this.mathOperators = const [],
    this.mathAnswer = '0',
    this.docId,
    this.gameTypeDocId,
  }) : guessAnswerImages = guessAnswerImages ?? [null, null, null],
       imageMatchImages = imageMatchImages ?? List.filled(8, null),
       imageMatchMappings = imageMatchMappings ?? {},
       guessAnswerImageUrls = guessAnswerImageUrls ?? [null, null, null];
}

class MyTesting extends StatefulWidget {
  const MyTesting({super.key});

  @override
  State<MyTesting> createState() => _MyTestingState();
}

class _MyTestingState extends State<MyTesting> {
  // Controllers
  final TextEditingController answerController = TextEditingController();
  final TextEditingController descriptionFieldController =
      TextEditingController();
  final TextEditingController readSentenceController = TextEditingController();
  final TextEditingController listenAndRepeatController =
      TextEditingController();
  final TextEditingController hintController = TextEditingController();
  final TextEditingController userAnswerController =
      TextEditingController(); // For Read the sentence user answer
  final TextEditingController whatCalledUserAnswerController =
      TextEditingController(); // For What is it called user answer
  final TextEditingController listenRepeatUserAnswerController =
      TextEditingController(); // For Listen and Repeat user answer
  final TextEditingController strokeSentenceController =
      TextEditingController(); // For Stroke sentence
  final TextEditingController strokeUserAnswerController =
      TextEditingController(); // For Stroke user answer

  // State variables
  double progressValue = 0.0;
  String selectedGameType = 'Fill in the blank';
  String selectedGameRule = 'none';
  bool heartEnabled = false;
  int timerSeconds = 0;
  int remainingHearts = 5; // Track remaining hearts
  List<bool> visibleLetters = [];
  Uint8List? selectedImageBytes;
  Uint8List? whatCalledImageBytes;
  List<String> multipleChoices = [];
  List<Uint8List?> guessAnswerImages = [null, null, null];
  List<Uint8List?> imageMatchImages = List.filled(8, null);
  int imageMatchCount = 2;
  Map<int, int> imageMatchMappings = {}; // Correct match mappings
  Set<int> matchedImages = {}; // Track correctly matched images
  int? selectedOdd; // Currently selected odd image
  int? selectedEven; // Currently selected even image
  int correctAnswerIndex = -1;
  String? listenAndRepeatAudioPath;
  String listenAndRepeatAudioSource = "";
  Uint8List? listenAndRepeatAudioBytes;

  final mathState = MathState();

  int currentPageIndex = 0;
  List<TestPageData> pages = [];
  bool _isLoading = true;
  String? gameId;
  String? userId;

  // Image URLs
  String? imageUrl;
  String? whatCalledImageUrl;
  List<String?> guessAnswerImageUrls = [null, null, null];
  String? listenAndRepeatAudioUrl;

  // Animation state
  bool _showCongratulation = false;
  String _congratulationText = '';
  final List<String> _congratulationMessages = [
    'Awesome!',
    'Wow',
    'Fantastic',
    'How?',
    'Brilliant!',
    'Are you an Ai?',
    'Chill Out!',
  ];

  // Wrong answer feedback state
  bool _showWrongAnswer = false;
  String _wrongAnswerText = '';
  final List<String> _wrongAnswerMessages = [
    'Try Again',
    'You can do it',
    'So close',
    'You missed the spot',
    'Let\'s take it slow',
    'You got this',
  ];

  // Heart loss animation state
  bool _showHeartLoss = false;

  // Selected answer state for multiple choice games
  int _selectedAnswerIndex = -1;
  
  // Error message overlay state
  bool _showErrorMessage = false;
  String _errorMessageText = '';

  // Callback function to handle answer selection
  void _onAnswerSelected(int index) {
    setState(() {
      _selectedAnswerIndex = index;
    });
  }

  // Normalize text by removing punctuation and converting to lowercase
  String _normalizeText(String text) {
    return text
        .replaceAll(RegExp(r'[^\w\s]'), '') // Remove punctuation
        .toLowerCase()
        .trim();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeTesting();
    });
  }

  Future<void> _initializeTesting() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get gameId from arguments
      final args = Get.arguments;
      if (args != null && args['gameId'] != null) {
        gameId = args['gameId'] as String;
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          userId = user.uid;
          await _loadGameData();
        }
      }
    } catch (e) {
      debugPrint('Error initializing testing: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadGameData() async {
    if (gameId == null || userId == null) return;

    try {
      // Load game metadata
      final gameDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('created_games')
          .doc(gameId)
          .get();

      if (gameDoc.exists) {
        final data = gameDoc.data()!;
        selectedGameRule = (data['gameRule'] as String?) ?? 'none';
        heartEnabled = (data['heart'] as bool?) ?? false;
        timerSeconds = (data['timer'] as int?) ?? 0;
        
        // Reset hearts when starting a new test
        if (heartEnabled) {
          remainingHearts = 5;
        }
      }

      // Load game rounds
      await _loadGameRounds();

      // Load first page
      if (pages.isNotEmpty) {
        _loadPageData(0);
      }
    } catch (e) {
      debugPrint('Error loading game data: $e');
    }
  }

  Future<void> _loadGameRounds() async {
    if (gameId == null || userId == null) {
      debugPrint('Cannot load game rounds: gameId=$gameId, userId=$userId');
      return;
    }

    try {
      debugPrint('Loading game rounds for gameId: $gameId, userId: $userId');

      // First check if the game document exists
      final gameDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('created_games')
          .doc(gameId);

      final gameDoc = await gameDocRef.get();
      if (!gameDoc.exists) {
        debugPrint('Game document does not exist: $gameId');
        return;
      }
      debugPrint(
        'Game document exists with data: ${gameDoc.data()?.keys.toList() ?? 'null'}',
      );

      final gameRoundsRef = gameDocRef.collection('game_rounds');

      // Try to get documents with orderBy first, fallback to simple get if it fails
      QuerySnapshot snapshot;
      try {
        snapshot = await gameRoundsRef.orderBy('page').get();
        debugPrint('Found ${snapshot.docs.length} game rounds (with orderBy)');
      } catch (e) {
        debugPrint('orderBy failed, trying simple query: $e');
        snapshot = await gameRoundsRef.get();
        debugPrint('Found ${snapshot.docs.length} game rounds (simple query)');
      }

      List<TestPageData> loadedPages = [];

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        debugPrint('Document ${doc.id} data: ${data?.keys.toList() ?? 'null'}');

        final gameType = (data?['gameType'] as String?) ?? 'Fill in the blank';
        final gameTypeDocId = data?['gameTypeDocId'] as String?;

        debugPrint(
          'Processing round ${doc.id}: gameType=$gameType, gameTypeDocId=$gameTypeDocId',
        );

        // Load game type specific data
        final gameTypeData = await _loadGameTypeData(
          doc.id,
          gameType,
          gameTypeDocId,
        );
        
        debugPrint(
          'Loaded gameTypeData for ${doc.id}: ${gameTypeData.keys.toList()}',
        );

        // Parse data based on game type
        String answer = '';
        String descriptionField = '';
        String readSentence = '';
        String listenAndRepeat = '';
        List<bool> visibleLetters = [];
        List<String> multipleChoices = [];
        int correctAnswerIndex = -1;
        String hint = '';

        if (gameType == 'Fill in the blank' ||
            gameType == 'Fill in the blank 2') {
          answer = gameTypeData['answerText'] ?? '';
          hint = gameTypeData['gameHint'] ?? '';
          visibleLetters =
              gameTypeData['answer'] != null && gameTypeData['answer'] is List
              ? List<bool>.from(gameTypeData['answer'])
              : [];
        } else if (gameType == 'Guess the answer') {
          descriptionField = gameTypeData['question'] ?? '';
          hint = gameTypeData['gameHint'] ?? '';
          multipleChoices = [
            gameTypeData['multipleChoice1'] ?? '',
            gameTypeData['multipleChoice2'] ?? '',
            gameTypeData['multipleChoice3'] ?? '',
            gameTypeData['multipleChoice4'] ?? '',
          ];
          correctAnswerIndex = (gameTypeData['answer'] as int?) ?? 0;
        } else if (gameType == 'Guess the answer 2') {
          descriptionField = gameTypeData['question'] ?? '';
          hint = gameTypeData['hint'] ?? '';
          multipleChoices = [
            gameTypeData['multipleChoice1'] ?? '',
            gameTypeData['multipleChoice2'] ?? '',
            gameTypeData['multipleChoice3'] ?? '',
            gameTypeData['multipleChoice4'] ?? '',
          ];
          correctAnswerIndex =
              (gameTypeData['correctAnswerIndex'] as int?) ?? 0;
        } else if (gameType == 'Read the sentence') {
          readSentence = gameTypeData['sentence'] ?? '';
        } else if (gameType == 'What is it called') {
          readSentence = gameTypeData['answer'] ?? '';
          hint = gameTypeData['gameHint'] ?? '';
        } else if (gameType == 'Listen and Repeat') {
          listenAndRepeat = gameTypeData['answer'] ?? '';
        } else if (gameType == 'Stroke') {
          readSentence = gameTypeData['sentence'] ?? '';
        }

        loadedPages.add(
          TestPageData(
            gameType: gameType,
            answer: answer,
            descriptionField: descriptionField,
            readSentence: readSentence,
            listenAndRepeat: listenAndRepeat,
            visibleLetters: visibleLetters,
            multipleChoices: multipleChoices,
            hint: hint,
            correctAnswerIndex: correctAnswerIndex,
            docId: doc.id,
            gameTypeDocId: gameTypeDocId,
            selectedImageBytes: gameTypeData['imageBytes'] as Uint8List?,
            imageUrl:
                gameTypeData['imageUrl'] as String? ??
                gameTypeData['image'] as String?,
            whatCalledImageUrl: gameType == 'What is it called'
                ? (gameTypeData['imageUrl'] as String?)
                : null,
            guessAnswerImages: gameType == 'Guess the answer 2'
                ? [
                    gameTypeData['image1Bytes'] as Uint8List?,
                    gameTypeData['image2Bytes'] as Uint8List?,
                    gameTypeData['image3Bytes'] as Uint8List?,
                  ]
                : [null, null, null],
            guessAnswerImageUrls: gameType == 'Guess the answer 2'
                ? [
                    gameTypeData['image1'] as String?,
                    gameTypeData['image2'] as String?,
                    gameTypeData['image3'] as String?,
                  ]
                : [null, null, null],
            imageMatchImages: gameType == 'Image Match'
                ? [
                    gameTypeData['imageMatch1Bytes'] as Uint8List?,
                    gameTypeData['imageMatch2Bytes'] as Uint8List?,
                    gameTypeData['imageMatch3Bytes'] as Uint8List?,
                    gameTypeData['imageMatch4Bytes'] as Uint8List?,
                    gameTypeData['imageMatch5Bytes'] as Uint8List?,
                    gameTypeData['imageMatch6Bytes'] as Uint8List?,
                    gameTypeData['imageMatch7Bytes'] as Uint8List?,
                    gameTypeData['imageMatch8Bytes'] as Uint8List?,
                  ]
                : List.filled(8, null),
            imageMatchCount: gameTypeData['imageCount'] ?? 2,
            imageMatchMappings: gameType == 'Image Match'
                ? () {
                    Map<int, int> mappings = {};
                    // Load match data from Firestore (1-based) and convert to 0-based
                    debugPrint('Loading Image Match mappings from Firestore:');
                    for (int i = 1; i <= 7; i += 2) {
                      if (gameTypeData['image_match$i'] != null) {
                        int matchValue = gameTypeData['image_match$i'] as int;
                        if (matchValue > 0) {
                          // Convert from 1-based to 0-based indexing
                          mappings[i - 1] = matchValue - 1;
                          debugPrint(
                            '  image_match$i: $matchValue → [${i - 1}] → [${matchValue - 1}]',
                          );
                        }
                      }
                    }
                    debugPrint('Final mappings (0-based): $mappings');
                    return mappings;
                  }()
                : {},
            listenAndRepeatAudioUrl: gameType == 'Listen and Repeat'
                ? (gameTypeData['audio'] as String?)
                : null,
            listenAndRepeatAudioBytes: gameType == 'Listen and Repeat'
                ? (gameTypeData['audioBytes'] as Uint8List?)
                : null,
            mathTotalBoxes: gameType == 'Math'
                ? (gameTypeData['totalBoxes'] as int?) ?? 1
                : 1,
            mathBoxValues: gameType == 'Math'
                ? () {
                    List<String> values = [];
                    int totalBoxes = (gameTypeData['totalBoxes'] as int?) ?? 1;
                    for (int i = 1; i <= totalBoxes; i++) {
                      values.add((gameTypeData['box$i'] ?? 0).toString());
                    }
                    return values;
                  }()
                : [],
            mathOperators: gameType == 'Math'
                ? () {
                    List<String> operators = [];
                    int totalBoxes = (gameTypeData['totalBoxes'] as int?) ?? 1;
                    for (int i = 1; i < totalBoxes; i++) {
                      operators.add(
                        gameTypeData['operator${i}_${i + 1}'] ?? '+',
                      );
                    }
                    return operators;
                  }()
                : [],
            mathAnswer: gameType == 'Math'
                ? (gameTypeData['answer'] ?? 0).toString()
                : '0',
          ),
        );
      }

      debugPrint('Successfully loaded ${loadedPages.length} pages');
      setState(() {
        pages = loadedPages;
      });
      debugPrint('Pages set in state: ${pages.length}');
    } catch (e) {
      debugPrint('Error loading game rounds: $e');
    }
  }

  Future<Map<String, dynamic>> _loadGameTypeData(
    String roundDocId,
    String gameType,
    String? gameTypeDocId,
  ) async {
    if (userId == null || gameId == null) {
      debugPrint('Cannot load game type data: userId=$userId, gameId=$gameId');
      return {};
    }

    try {
      debugPrint(
        'Loading game type data for roundDocId=$roundDocId, gameType=$gameType, gameTypeDocId=$gameTypeDocId',
      );
      
      final gameTypeRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('created_games')
          .doc(gameId)
          .collection('game_rounds')
          .doc(roundDocId)
          .collection('game_type');

      Map<String, dynamic> data = {};

      if (gameTypeDocId != null && gameTypeDocId.isNotEmpty) {
        debugPrint('Loading specific document: $gameTypeDocId');
        final docSnapshot = await gameTypeRef.doc(gameTypeDocId).get();
        if (docSnapshot.exists) {
          data = docSnapshot.data()!;
          debugPrint('Found specific document with ${data.keys.length} fields');
        } else {
          debugPrint('Specific document does not exist');
        }
      } else {
        debugPrint('Loading first available document');
        final snapshot = await gameTypeRef.get();
        debugPrint(
          'Found ${snapshot.docs.length} documents in game_type collection',
        );
        if (snapshot.docs.isNotEmpty) {
          data = snapshot.docs.first.data();
          debugPrint('Using first document with ${data.keys.length} fields');
        } else {
          debugPrint('No documents found in game_type collection');
        }
      }

      // Download images if URLs exist
      if (gameType == 'Guess the answer 2') {
        for (int i = 1; i <= 3; i++) {
          String? imageUrl = data['image$i'];
          if (imageUrl != null && imageUrl.isNotEmpty) {
            final imageBytes = await _downloadImageFromUrl(imageUrl);
            if (imageBytes != null) {
              data['image${i}Bytes'] = imageBytes;
            }
          }
        }
      } else if (gameType == 'Image Match') {
        for (int i = 1; i <= 8; i++) {
          String? imageUrl = data['image$i'];
          if (imageUrl != null && imageUrl.isNotEmpty) {
            final imageBytes = await _downloadImageFromUrl(imageUrl);
            if (imageBytes != null) {
              data['imageMatch${i}Bytes'] = imageBytes;
            }
          }
        }
      } else {
        String? imageUrl =
            data['imageUrl'] as String? ?? data['image'] as String?;
        if (imageUrl != null && imageUrl.isNotEmpty) {
          final imageBytes = await _downloadImageFromUrl(imageUrl);
          if (imageBytes != null) {
            data['imageBytes'] = imageBytes;
          }
        }
      }

      debugPrint(
        'Returning game type data with ${data.keys.length} fields: ${data.keys.toList()}',
      );
      return data;
    } catch (e) {
      debugPrint('Error loading game type data: $e');
      return {};
    }
  }

  Future<Uint8List?> _downloadImageFromUrl(String imageUrl) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (e) {
      debugPrint('Error downloading image: $e');
    }
    return null;
  }

  void _loadPageData(int pageIndex) {
    if (pageIndex >= pages.length) return;

    final pageData = pages[pageIndex];

    setState(() {
      currentPageIndex = pageIndex;
      selectedGameType = pageData.gameType;
      answerController.text = pageData.answer;
      descriptionFieldController.text = pageData.descriptionField;
      readSentenceController.text = pageData.readSentence;
      listenAndRepeatController.text = pageData.listenAndRepeat;
      hintController.text = pageData.hint;
      // Load Stroke sentence
      if (pageData.gameType == 'Stroke') {
        strokeSentenceController.text = pageData.readSentence;
      }
      visibleLetters = List.from(pageData.visibleLetters);
      selectedImageBytes = pageData.selectedImageBytes;
      whatCalledImageBytes = pageData.whatCalledImageBytes;
      multipleChoices = List.from(pageData.multipleChoices);
      guessAnswerImages = List.from(pageData.guessAnswerImages);
      imageMatchImages = List.from(pageData.imageMatchImages);
      imageMatchCount = pageData.imageMatchCount;
      imageMatchMappings = Map.from(pageData.imageMatchMappings);
      matchedImages = {}; // Reset matched images for new page
      selectedOdd = null; // Reset selections
      selectedEven = null;
      correctAnswerIndex = pageData.correctAnswerIndex;
      imageUrl = pageData.imageUrl;
      whatCalledImageUrl = pageData.whatCalledImageUrl;
      guessAnswerImageUrls = List.from(pageData.guessAnswerImageUrls);
      listenAndRepeatAudioUrl = pageData.listenAndRepeatAudioUrl;
      listenAndRepeatAudioBytes = pageData.listenAndRepeatAudioBytes;

      // Reset selected answer for new page
      _selectedAnswerIndex = -1;

      // Reset wrong answer feedback
      _showWrongAnswer = false;

      // Clear user answer for Read the sentence
      userAnswerController.clear();
      whatCalledUserAnswerController.clear();
      listenRepeatUserAnswerController.clear();
      strokeUserAnswerController.clear();

      // Clear user answer for Math game
      mathState.previewResultController.clear();

      // Update progress
      progressValue = (pageIndex + 1) / pages.length;

      // Load Math data
      if (pageData.gameType == 'Math') {
        while (mathState.totalBoxes < pageData.mathTotalBoxes) {
          mathState.increment();
        }
        while (mathState.totalBoxes > pageData.mathTotalBoxes) {
          mathState.decrement();
        }
        for (
          int i = 0;
          i < pageData.mathBoxValues.length &&
              i < mathState.boxControllers.length;
          i++
        ) {
          mathState.boxControllers[i].text = pageData.mathBoxValues[i];
        }
        for (
          int i = 0;
          i < pageData.mathOperators.length && i < mathState.operators.length;
          i++
        ) {
          while (mathState.operators[i] != pageData.mathOperators[i]) {
            mathState.cycleOperator(i);
          }
        }
      }
    });
  }

  @override
  void dispose() {
    answerController.dispose();
    descriptionFieldController.dispose();
    readSentenceController.dispose();
    listenAndRepeatController.dispose();
    hintController.dispose();
    userAnswerController.dispose();
    whatCalledUserAnswerController.dispose();
    listenRepeatUserAnswerController.dispose();
    strokeSentenceController.dispose();
    strokeUserAnswerController.dispose();
    super.dispose();
  }

  bool _validateAnswer() {
    if (pages.isEmpty || currentPageIndex >= pages.length) return false;

    final currentPage = pages[currentPageIndex];

    // Validate based on game type
    if (currentPage.gameType == 'Fill in the blank' ||
        currentPage.gameType == 'Fill in the blank 2') {
      // Check if all letters match (case insensitive)
      bool allFilled = true;
      for (int i = 0; i < visibleLetters.length; i++) {
        if (!visibleLetters[i]) {
          allFilled = false;
          break;
        }
      }
      return allFilled;
    } else if (currentPage.gameType == 'Guess the answer' ||
        currentPage.gameType == 'Guess the answer 2') {
      // Check if user has selected an answer
      return _selectedAnswerIndex >= 0;
    } else if (currentPage.gameType == 'Read the sentence') {
      // Check if user has provided an answer (speech recognition result)
      return userAnswerController.text.trim().isNotEmpty;
    } else if (currentPage.gameType == 'Listen and Repeat') {
      // Check if user has provided an answer (speech recognition result)
      return listenRepeatUserAnswerController.text.trim().isNotEmpty;
    } else if (currentPage.gameType == 'What is it called') {
      // Check if user has provided an answer (speech recognition result)
      return whatCalledUserAnswerController.text.trim().isNotEmpty;
    } else if (currentPage.gameType == 'Math') {
      // Check if user has entered an answer
      return mathState.previewResultController.text.trim().isNotEmpty;
    } else if (currentPage.gameType == 'Image Match') {
      // Check if all images have been matched
      return matchedImages.length == currentPage.imageMatchCount;
    } else if (currentPage.gameType == 'Stroke') {
      // For Stroke, allow empty drawing pad (for teacher/admin verification)
      // Always return true to allow proceeding even if drawing pad is empty
      return true;
    }

    // For other game types, always return true (they have their own validation)
    return true;
  }

  bool _isAnswerCorrect() {
    if (pages.isEmpty || currentPageIndex >= pages.length) return false;

    final currentPage = pages[currentPageIndex];

    // Check if answer is correct based on game type
    if (currentPage.gameType == 'Guess the answer' ||
        currentPage.gameType == 'Guess the answer 2') {
      // For multiple choice games, check if selected answer matches correct answer
      return _selectedAnswerIndex == currentPage.correctAnswerIndex;
    } else if (currentPage.gameType == 'Read the sentence') {
      // For Read the sentence, compare normalized text (ignoring punctuation)
      final targetText = _normalizeText(currentPage.readSentence);
      final userAnswer = _normalizeText(userAnswerController.text);
      return targetText == userAnswer;
    } else if (currentPage.gameType == 'Listen and Repeat') {
      // For Listen and Repeat, compare normalized text
      final targetText = _normalizeText(currentPage.listenAndRepeat);
      final userAnswer = _normalizeText(listenRepeatUserAnswerController.text);
      return targetText == userAnswer;
    } else if (currentPage.gameType == 'What is it called') {
      // For What is it called, compare normalized text
      final targetText = _normalizeText(currentPage.readSentence);
      final userAnswer = _normalizeText(whatCalledUserAnswerController.text);
      return targetText == userAnswer;
    } else if (currentPage.gameType == 'Math') {
      // For Math game, compare user's answer with the correct answer from Firebase
      final userAnswer = mathState.previewResultController.text.trim();
      final correctAnswer = currentPage.mathAnswer.trim();
      return userAnswer == correctAnswer;
    } else if (currentPage.gameType == 'Stroke') {
      // For Stroke, assume correct if user has drawn something (validation passes)
      // In the future, this could integrate with handwriting recognition
      return true;
    }

    // For other game types, assume correct if validation passes
    return true;
  }

  Future<void> _handleConfirm() async {
    if (!_validateAnswer()) {
      // Show error message specific to game type
      final currentPage = pages[currentPageIndex];
      String errorMessage = 'Please complete the question before proceeding!';

      if (currentPage.gameType == 'Image Match') {
        int remaining = currentPage.imageMatchCount - matchedImages.length;
        errorMessage = 'Please match all images! $remaining pair(s) remaining.';
      }

      // Show floating error message
      setState(() {
        _errorMessageText = errorMessage;
        _showErrorMessage = true;
      });

      // Auto-hide after 3 seconds
      await Future.delayed(const Duration(seconds: 3));

      if (mounted) {
        setState(() {
          _showErrorMessage = false;
        });
      }
      
      return;
    }

    // For Stroke game type, show confirmation dialog before proceeding
    final currentPage = pages[currentPageIndex];
    if (currentPage.gameType == 'Stroke') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: const Color(0xFF2A2C2A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            title: Text(
              'Confirm Submission',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            content: Text(
              'Are you sure you want to proceed to the next round?',
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
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  'Proceed',
                  style: GoogleFonts.poppins(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      );

      if (confirmed != true) {
        return; // User cancelled
      }

      // Proceed without win/lose logic for Stroke
      // Check if this is the last page
      if (currentPageIndex < pages.length - 1) {
        // Move to next page
        _loadPageData(currentPageIndex + 1);
      } else {
        // This is the last page, update game_test and go back
        await _updateGameTest();
      }
      return;
    }

    // Check if answer is correct for multiple choice games
    if (!_isAnswerCorrect()) {
      // Reduce heart if heart rule is enabled
      if (heartEnabled && remainingHearts > 0) {
        setState(() {
          remainingHearts--;
          _showHeartLoss = true;
        });

        // Show heart loss animation
        await Future.delayed(const Duration(milliseconds: 1000));

        if (mounted) {
          setState(() {
            _showHeartLoss = false;
          });
        }

        // Check if game over (no hearts left)
        if (remainingHearts <= 0) {
          // Show game over message
          setState(() {
            _errorMessageText = 'Game Over! No hearts remaining. Try again!';
            _showErrorMessage = true;
          });
          
          // Wait a bit then go back to game edit
          await Future.delayed(const Duration(seconds: 3));

          if (mounted) {
            setState(() {
              _showErrorMessage = false;
            });

            // Go back after hiding message
            await Future.delayed(const Duration(milliseconds: 500));
            Get.back(); // Go back to game_edit.dart
          }
          return;
        }
      }

      // Show wrong answer feedback
      setState(() {
        _wrongAnswerText =
            _wrongAnswerMessages[DateTime.now().millisecondsSinceEpoch %
                _wrongAnswerMessages.length];
        _showWrongAnswer = true;
      });

      // Wait for animation to complete
      await Future.delayed(const Duration(milliseconds: 2000));

      // Hide animation
      if (mounted) {
        setState(() {
          _showWrongAnswer = false;
        });
      }

      // Stay on the same page - don't proceed
      return;
    }

    // Show congratulation animation for correct answer
    setState(() {
      _congratulationText =
          _congratulationMessages[DateTime.now().millisecondsSinceEpoch %
              _congratulationMessages.length];
      _showCongratulation = true;
    });

    // Wait for animation to complete
    await Future.delayed(const Duration(milliseconds: 2000));

    // Hide animation
    if (mounted) {
      setState(() {
        _showCongratulation = false;
      });
    }

    // Wait a bit before transitioning
    await Future.delayed(const Duration(milliseconds: 300));

    // Check if this is the last page
    if (currentPageIndex < pages.length - 1) {
      // Move to next page
      _loadPageData(currentPageIndex + 1);
    } else {
      // This is the last page, update game_test and go back
      await _updateGameTest();
    }
  }

  Future<void> _updateGameTest() async {
    if (gameId == null || userId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('created_games')
          .doc(gameId)
          .update({'game_test': true});

      debugPrint('game_test updated to true');

      // Go back to game edit immediately (success message will be shown in game_edit)
      Get.back();
    } catch (e) {
      debugPrint('Error updating game_test: $e');
      if (mounted) {
        setState(() {
          _errorMessageText = 'Error updating game test status';
          _showErrorMessage = true;
        });

        await Future.delayed(const Duration(seconds: 3));

        if (mounted) {
          setState(() {
            _showErrorMessage = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF2C2F2C),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
              ),
              const SizedBox(height: 20),
              Text(
                'Loading game data...',
                style: GoogleFonts.poppins(fontSize: 18, color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    // Show error if no pages loaded
    if (pages.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF2C2F2C),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 60),
              const SizedBox(height: 20),
              Text(
                'No game rounds found',
                style: GoogleFonts.poppins(fontSize: 18, color: Colors.white),
              ),
              const SizedBox(height: 20),
              AnimatedButton(
                width: 150,
                height: 50,
                color: Colors.blue,
                onPressed: () => Get.back(),
                child: Text(
                  'Go Back',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    bool isLastPage = currentPageIndex == pages.length - 1;

    return Scaffold(
      backgroundColor: const Color(0xFF2C2F2C),
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            color: const Color(0xFF2C2F2C),
            child: Center(
              child: SizedBox(
                width: 428,
                height: 900,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: progressValue,
                            minHeight: 20,
                            backgroundColor: Colors.grey[300],
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.green,
                            ),
                          ),
                        ),
                      ),

                      // Hearts display (when heart rule is selected)
                      if (heartEnabled)
                        Padding(
                          padding: const EdgeInsets.only(left: 16, top: 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(
                                5,
                                (index) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: Icon(
                                    Icons.favorite,
                                    color: index < remainingHearts
                                        ? Colors.red
                                        : Colors.grey[400],
                                    size: 30,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                      // Timer display (when timer rule is selected)
                      if (selectedGameRule == 'timer' && timerSeconds > 0)
                        Padding(
                          padding: const EdgeInsets.only(right: 16, top: 8),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.timer,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${(timerSeconds ~/ 60).toString().padLeft(2, '0')}:${(timerSeconds % 60).toString().padLeft(2, '0')}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Expanded(
                                child: selectedGameType == 'Fill in the blank'
                                    ? MyFillTheBlank(
                                        answerController: answerController,
                                        visibleLetters: visibleLetters,
                                        onRevealLetter: (int index) {
                                          setState(() {
                                            visibleLetters[index] = true;
                                          });
                                        },
                                        onHideLetter: (int index) {
                                          setState(() {
                                            visibleLetters[index] = false;
                                          });
                                        },
                                      )
                                    : selectedGameType == 'Fill in the blank 2'
                                    ? MyFillInTheBlank2(
                                        answerController: answerController,
                                        visibleLetters: visibleLetters,
                                        pickedImage: selectedImageBytes,
                                        imageUrl: imageUrl,
                                        onRevealLetter: (int index) {
                                          setState(() {
                                            visibleLetters[index] = true;
                                          });
                                        },
                                        onHideLetter: (int index) {
                                          setState(() {
                                            visibleLetters[index] = false;
                                          });
                                        },
                                      )
                                    : selectedGameType == 'Guess the answer'
                                    ? MyFillInTheBlank3(
                                        hintController: hintController,
                                        questionController:
                                            descriptionFieldController,
                                        visibleLetters: visibleLetters,
                                        pickedImage: selectedImageBytes,
                                        imageUrl: imageUrl,
                                        multipleChoices: multipleChoices,
                                        correctAnswerIndex: correctAnswerIndex,
                                        selectedAnswerIndex:
                                            _selectedAnswerIndex,
                                        onAnswerSelected: _onAnswerSelected,
                                      )
                                    : selectedGameType == 'Guess the answer 2'
                                    ? MyGuessTheAnswer(
                                        hintController: hintController,
                                        questionController:
                                            descriptionFieldController,
                                        visibleLetters: visibleLetters,
                                        pickedImages: guessAnswerImages,
                                        imageUrls: guessAnswerImageUrls,
                                        multipleChoices: multipleChoices,
                                        correctAnswerIndex: correctAnswerIndex,
                                        selectedAnswerIndex:
                                            _selectedAnswerIndex,
                                        onAnswerSelected: _onAnswerSelected,
                                      )
                                    : selectedGameType == 'Read the sentence'
                                    ? MyReadTheSentence(
                                        sentenceController:
                                            readSentenceController,
                                        userAnswerController:
                                            userAnswerController,
                                      )
                                    : selectedGameType == 'What is it called'
                                    ? MyWhatItIsCalled(
                                        sentenceController:
                                            readSentenceController,
                                        pickedImage: whatCalledImageBytes,
                                        imageUrl: whatCalledImageUrl,
                                        userAnswerController:
                                            whatCalledUserAnswerController,
                                      )
                                    : selectedGameType == 'Listen and Repeat'
                                    ? MyListenAndRepeat(
                                        sentenceController:
                                            listenAndRepeatController,
                                        audioPath: listenAndRepeatAudioPath,
                                        audioSource: listenAndRepeatAudioSource,
                                        audioUrl: listenAndRepeatAudioUrl,
                                        userAnswerController:
                                            listenRepeatUserAnswerController,
                                      )
                                    : selectedGameType == 'Image Match'
                                    ? MyImageMatchTesting(
                                        pickedImages: imageMatchImages,
                                        count: imageMatchCount,
                                        matchMappings: imageMatchMappings,
                                        matchedImages: matchedImages,
                                        selectedOdd: selectedOdd,
                                        selectedEven: selectedEven,
                                        onImageTap: (int index) {
                                          setState(() {
                                            bool isOdd =
                                                (index % 2) ==
                                                0; // 0-based: 0,2,4,6 are odd positions
                                            debugPrint(
                                              'Image $index tapped (${isOdd ? "odd" : "even"})',
                                            );

                                            // Don't allow tapping matched images
                                            if (matchedImages.contains(index)) {
                                              debugPrint(
                                                'Image $index is already matched',
                                              );
                                              return;
                                            }

                                            if (isOdd) {
                                              // Toggle odd selection
                                              selectedOdd =
                                                  (selectedOdd == index)
                                                  ? null
                                                  : index;
                                              debugPrint(
                                                'Selected odd: $selectedOdd',
                                              );
                                            } else {
                                              // Toggle even selection
                                              selectedEven =
                                                  (selectedEven == index)
                                                  ? null
                                                  : index;
                                              debugPrint(
                                                'Selected even: $selectedEven',
                                              );
                                            }

                                            // Check for match when both are selected
                                            if (selectedOdd != null &&
                                                selectedEven != null) {
                                              debugPrint(
                                                'Checking match: [$selectedOdd] → [${imageMatchMappings[selectedOdd]}] vs selected [$selectedEven]',
                                              );
                                              if (imageMatchMappings[selectedOdd] ==
                                                  selectedEven) {
                                                // Correct match!
                                                debugPrint(
                                                  '✅ Correct match! Adding to matched images',
                                                );
                                                matchedImages.addAll([
                                                  selectedOdd!,
                                                  selectedEven!,
                                                ]);
                                                debugPrint(
                                                  'Matched images: $matchedImages',
                                                );
                                                selectedOdd = null;
                                                selectedEven = null;
                                              } else {
                                                // Wrong match - reset after a short delay
                                                debugPrint(
                                                  '❌ Wrong match! Resetting selections',
                                                );
                                                Future.delayed(
                                                  const Duration(
                                                    milliseconds: 500,
                                                  ),
                                                  () {
                                                    if (mounted) {
                                                      setState(() {
                                                        selectedOdd = null;
                                                        selectedEven = null;
                                                      });
                                                    }
                                                  },
                                                );
                                              }
                                            }
                                          });
                                        },
                                      )
                                    : selectedGameType == 'Stroke'
                                    ? MyStroke(
                                        sentenceController:
                                            strokeSentenceController,
                                        userAnswerController:
                                            strokeUserAnswerController,
                                        pickedImage: selectedImageBytes,
                                        imageUrl: imageUrl,
                                      )
                                    : MyMath(mathState: mathState),
                              ),

                              Center(
                                child: AnimatedButton(
                                  width: 350,
                                  height: 60,
                                  color: isLastPage
                                      ? Colors.orange
                                      : Colors.green,
                                  onPressed: _handleConfirm,
                                  child: Text(
                                    isLastPage ? "Done" : "Confirm",
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Congratulation animation overlay
          if (_showCongratulation)
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 1500),
              tween: Tween<double>(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                double opacity;
                double scale;

                if (value < 0.2) {
                  // Fade in and scale up (0 to 0.2)
                  opacity = value * 5;
                  scale = 0.5 + (value * 2.5);
                } else if (value < 0.7) {
                  // Stay visible (0.2 to 0.7)
                  opacity = 1.0;
                  scale = 1.0;
                } else {
                  // Fade out (0.7 to 1.0)
                  opacity = 1.0 - ((value - 0.7) * 3.33);
                  scale = 1.0;
                }

                return Opacity(
                  opacity: opacity,
                  child: Container(
                    color: Colors.black.withOpacity(0.3 * opacity),
                    child: Center(
                      child: Transform.scale(
                        scale: scale,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 50,
                            vertical: 30,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.orange.withOpacity(0.9),
                                Colors.deepOrange.withOpacity(0.9),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.withOpacity(0.5),
                                blurRadius: 30,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: Text(
                            _congratulationText,
                            style: GoogleFonts.poppins(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.3),
                                  offset: const Offset(2, 2),
                                  blurRadius: 5,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

          // Wrong answer feedback overlay
          if (_showWrongAnswer)
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 1500),
              tween: Tween<double>(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                double opacity;
                double scale;

                if (value < 0.2) {
                  // Fade in and scale up (0 to 0.2)
                  opacity = value * 5;
                  scale = 0.5 + (value * 2.5);
                } else if (value < 0.7) {
                  // Stay visible (0.2 to 0.7)
                  opacity = 1.0;
                  scale = 1.0;
                } else {
                  // Fade out (0.7 to 1.0)
                  opacity = 1.0 - ((value - 0.7) * 3.33);
                  scale = 1.0;
                }

                return Opacity(
                  opacity: opacity,
                  child: Container(
                    color: Colors.black.withOpacity(0.3 * opacity),
                    child: Center(
                      child: Transform.scale(
                        scale: scale,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 50,
                            vertical: 30,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.red.withOpacity(0.9),
                                Colors.deepOrange.withOpacity(0.9),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.5),
                                blurRadius: 30,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: Text(
                            _wrongAnswerText,
                            style: GoogleFonts.poppins(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.3),
                                  offset: const Offset(2, 2),
                                  blurRadius: 5,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

          // Heart loss animation overlay
          if (_showHeartLoss)
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 1000),
              tween: Tween<double>(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                double opacity;
                double scale;

                if (value < 0.3) {
                  // Fade in and scale up (0 to 0.3)
                  opacity = value * 3.33;
                  scale = 0.5 + (value * 1.67);
                } else if (value < 0.7) {
                  // Stay visible (0.3 to 0.7)
                  opacity = 1.0;
                  scale = 1.0;
                } else {
                  // Fade out (0.7 to 1.0)
                  opacity = 1.0 - ((value - 0.7) * 3.33);
                  scale = 1.0;
                }

                return Opacity(
                  opacity: opacity,
                  child: Container(
                    color: Colors.black.withOpacity(0.2 * opacity),
                    child: Center(
                      child: Transform.scale(
                        scale: scale,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 20,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.red.withOpacity(0.9),
                                Colors.pink.withOpacity(0.9),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.5),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.favorite_border,
                                color: Colors.white,
                                size: 30,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Heart Lost!',
                                style: GoogleFonts.poppins(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.3),
                                      offset: const Offset(1, 1),
                                      blurRadius: 3,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

          // Error message overlay (floating at top)
          if (_showErrorMessage)
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 1500),
              tween: Tween<double>(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                double opacity;
                double translateY;

                if (value < 0.3) {
                  // Fade in and slide down (0 to 0.3)
                  opacity = value * 3.33;
                  translateY = -50 + (value * 166.67); // -50 to 0
                } else if (value < 0.7) {
                  // Stay visible (0.3 to 0.7)
                  opacity = 1.0;
                  translateY = 0;
                } else {
                  // Fade out and slide up (0.7 to 1.0)
                  opacity = 1.0 - ((value - 0.7) * 3.33);
                  translateY = -((value - 0.7) * 166.67); // 0 to -50
                }

                return Positioned(
                  top: 20,
                  left: 0,
                  right: 0,
                  child: Transform.translate(
                    offset: Offset(0, translateY),
                    child: Opacity(
                      opacity: opacity,
                      child: Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.red.shade600,
                                Colors.red.shade700,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.4),
                                blurRadius: 15,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.white,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Text(
                                  _errorMessageText,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}