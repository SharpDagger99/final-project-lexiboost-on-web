// ignore_for_file: avoid_print, deprecated_member_use

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
  }) : guessAnswerImages = guessAnswerImages ?? [null, null, null],
       imageMatchImages = imageMatchImages ?? List.filled(8, null),
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

  // State variables
  double progressValue = 0.0;
  String selectedGameType = 'Fill in the blank';
  String selectedGameRule = 'none';
  bool heartEnabled = false;
  int timerSeconds = 0;
  List<bool> visibleLetters = [];
  Uint8List? selectedImageBytes;
  Uint8List? whatCalledImageBytes;
  List<String> multipleChoices = [];
  List<Uint8List?> guessAnswerImages = [null, null, null];
  List<Uint8List?> imageMatchImages = List.filled(8, null);
  int imageMatchCount = 2;
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
    if (gameId == null || userId == null) return;

    try {
      final gameRoundsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('created_games')
          .doc(gameId)
          .collection('game_rounds');

      final snapshot = await gameRoundsRef.orderBy('page').get();

      List<TestPageData> loadedPages = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final gameType = (data['gameType'] as String?) ?? 'Fill in the blank';
        final gameTypeDocId = data['gameTypeDocId'] as String?;

        // Load game type specific data
        final gameTypeData = await _loadGameTypeData(
          doc.id,
          gameType,
          gameTypeDocId,
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
        } else if (gameType == 'Guess the answer' ||
            gameType == 'Guess the answer 2') {
          descriptionField = gameTypeData['question'] ?? '';
          hint = gameTypeData['gameHint'] ?? gameTypeData['hint'] ?? '';
          multipleChoices = [
            gameTypeData['multipleChoice1'] ?? '',
            gameTypeData['multipleChoice2'] ?? '',
            gameTypeData['multipleChoice3'] ?? '',
            gameTypeData['multipleChoice4'] ?? '',
          ];
          correctAnswerIndex =
              (gameTypeData['answer'] as int?) ??
              (gameTypeData['correctAnswerIndex'] as int?) ??
              0;
        } else if (gameType == 'Read the sentence') {
          readSentence = gameTypeData['sentence'] ?? '';
        } else if (gameType == 'What is it called') {
          readSentence = gameTypeData['answer'] ?? '';
          hint = gameTypeData['gameHint'] ?? '';
        } else if (gameType == 'Listen and Repeat') {
          listenAndRepeat = gameTypeData['answer'] ?? '';
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

      setState(() {
        pages = loadedPages;
      });
    } catch (e) {
      debugPrint('Error loading game rounds: $e');
    }
  }

  Future<Map<String, dynamic>> _loadGameTypeData(
    String roundDocId,
    String gameType,
    String? gameTypeDocId,
  ) async {
    if (userId == null || gameId == null) return {};

    try {
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
        final docSnapshot = await gameTypeRef.doc(gameTypeDocId).get();
        if (docSnapshot.exists) {
          data = docSnapshot.data()!;
        }
      } else {
        final snapshot = await gameTypeRef.get();
        if (snapshot.docs.isNotEmpty) {
          data = snapshot.docs.first.data();
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
      visibleLetters = List.from(pageData.visibleLetters);
      selectedImageBytes = pageData.selectedImageBytes;
      whatCalledImageBytes = pageData.whatCalledImageBytes;
      multipleChoices = List.from(pageData.multipleChoices);
      guessAnswerImages = List.from(pageData.guessAnswerImages);
      imageMatchImages = List.from(pageData.imageMatchImages);
      imageMatchCount = pageData.imageMatchCount;
      correctAnswerIndex = pageData.correctAnswerIndex;
      imageUrl = pageData.imageUrl;
      whatCalledImageUrl = pageData.whatCalledImageUrl;
      guessAnswerImageUrls = List.from(pageData.guessAnswerImageUrls);
      listenAndRepeatAudioUrl = pageData.listenAndRepeatAudioUrl;
      listenAndRepeatAudioBytes = pageData.listenAndRepeatAudioBytes;

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
    }

    // For other game types, always return true (they have their own validation)
    return true;
  }

  Future<void> _handleConfirm() async {
    if (!_validateAnswer()) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please fill in all the blanks correctly!',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show congratulation animation
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

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Game tested successfully!',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Go back to game edit
      Get.back();
    } catch (e) {
      debugPrint('Error updating game_test: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error updating game test status',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
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
                                    color: Colors.red,
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
                                      )
                                    : selectedGameType == 'Read the sentence'
                                    ? MyReadTheSentence(
                                        sentenceController:
                                            readSentenceController,
                                      )
                                    : selectedGameType == 'What is it called'
                                    ? MyWhatItIsCalled(
                                        sentenceController:
                                            readSentenceController,
                                        pickedImage: whatCalledImageBytes,
                                        imageUrl: whatCalledImageUrl,
                                      )
                                    : selectedGameType == 'Listen and Repeat'
                                    ? MyListenAndRepeat(
                                        sentenceController:
                                            listenAndRepeatController,
                                        audioPath: listenAndRepeatAudioPath,
                                        audioSource: listenAndRepeatAudioSource,
                                        audioUrl: listenAndRepeatAudioUrl,
                                      )
                                    : selectedGameType == 'Image Match'
                                    ? MyImageMatch(
                                        pickedImages: imageMatchImages,
                                        count: imageMatchCount,
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
        ],
      ),
    );
  }
}