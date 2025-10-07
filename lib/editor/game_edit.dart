// ===== game_edit.dart =====

// ignore_for_file: deprecated_member_use, use_build_context_synchronously, avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;
import 'package:animated_button/animated_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Game types
import 'package:lexi_on_web/editor/game%20types/fill_the_blank.dart';
import 'package:lexi_on_web/editor/game%20types/fill_the_blank2.dart';
import 'package:lexi_on_web/editor/game%20types/fill_the_blank3.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:lexi_on_web/editor/game%20types/guess_the_answer.dart';
import 'package:lexi_on_web/editor/game%20types/read_the_sentence.dart';
import 'package:lexi_on_web/editor/game%20types/what_called.dart';
import 'package:lexi_on_web/editor/game%20types/listen_and_repeat.dart';
import 'package:lexi_on_web/editor/game%20types/math.dart';
import 'package:lexi_on_web/editor/game%20types/image_match.dart';

// Page data class to store page content
class PageData {
  String title;
  String description;
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
  String difficulty;
  String prizeCoins;
  String gameRule;
  String gameSet;
  String gameCode;
  String hint;
  String? docId; // Firestore document ID for this page
  String? imageUrl; // Firebase Storage URL for selectedImageBytes
  String? whatCalledImageUrl; // Firebase Storage URL for whatCalledImageBytes
  List<String?>
  guessAnswerImageUrls; // Firebase Storage URLs for guessAnswerImages
  List<String?>
  imageMatchImageUrls; // Firebase Storage URLs for imageMatchImages
  int correctAnswerIndex; // Index of correct answer for Guess the answer

  PageData({
    this.title = '',
    this.description = '',
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
    this.difficulty = 'easy',
    this.prizeCoins = '100',
    this.gameRule = 'none',
    this.gameSet = 'public',
    this.gameCode = '',
    this.hint = '',
    this.docId,
    this.imageUrl,
    this.whatCalledImageUrl,
    List<String?>? guessAnswerImageUrls,
    List<String?>? imageMatchImageUrls,
    this.correctAnswerIndex = -1,
  }) : guessAnswerImages = guessAnswerImages ?? [null, null, null],
       imageMatchImages = imageMatchImages ?? List.filled(8, null),
       guessAnswerImageUrls = guessAnswerImageUrls ?? [null, null, null],
       imageMatchImageUrls = imageMatchImageUrls ?? List.filled(8, null);
}

class MyGameEdit extends StatefulWidget {
  const MyGameEdit({super.key});

  @override
  State<MyGameEdit> createState() => _MyGameEditState();
}

class _MyGameEditState extends State<MyGameEdit> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController descriptionFieldController =
      TextEditingController();
  final TextEditingController answerController = TextEditingController();
  final TextEditingController readSentenceController = TextEditingController();
  final TextEditingController listenAndRepeatController =
      TextEditingController();
  final TextEditingController prizeCoinsController = TextEditingController(
    text: '100',
  );
  final TextEditingController gameCodeController = TextEditingController();
  final TextEditingController hintController = TextEditingController();

  double progressValue = 0.1;
  String selectedGameType = 'Fill in the blank';
  String selectedDifficulty = 'easy';
  String selectedGameRule = 'none';
  String selectedGameSet = 'public';

  List<bool> visibleLetters = [];
  Uint8List? selectedImageBytes;
  Uint8List? whatCalledImageBytes;
  List<String> multipleChoices = [];

  List<Uint8List?> guessAnswerImages = [null, null, null];
  List<Uint8List?> imageMatchImages = List.filled(8, null);
  int imageMatchCount = 2;
  int correctAnswerIndex = -1; // Track correct answer for Guess the answer

  List<PageData> pages = [PageData()];
  int currentPageIndex = 0;

  String? gameId;
  Timer? _debounceTimer;

  final mathState = MathState();

  // Browser event listeners
  StreamSubscription<html.Event>? _beforeUnloadSubscription;
  StreamSubscription<html.PopStateEvent>? _popStateSubscription;
  StreamSubscription<html.Event>? _reloadSubscription;

  @override
  void initState() {
    super.initState();
    answerController.addListener(_syncVisibleLetters);
    titleController.addListener(_onTitleChanged);

    // Set up browser event listeners
    _setupBrowserEventListeners();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = Get.arguments;
      if (args != null && args['gameId'] != null) {
        gameId = args['gameId'] as String;
        _loadFromFirestore(gameId!);
      } else {
        // Handle browser reload scenario - try to get gameId from URL or session
        _handleBrowserReload();
      }
    });
  }

  void _setupBrowserEventListeners() {
    // Prevent page reload (F5, Ctrl+R, etc.)
    _beforeUnloadSubscription = html.window.onBeforeUnload.listen((event) {
      final beforeUnloadEvent = event as html.BeforeUnloadEvent;
      beforeUnloadEvent.returnValue =
          'You have unsaved changes. Are you sure you want to leave?';
    });

    // Handle browser back button
    _popStateSubscription = html.window.onPopState.listen((event) {
      // Prevent default back navigation
      html.window.history.pushState(null, '', html.window.location.href);

      // Show confirmation dialog
      _showBrowserBackConfirmation();
    });

    // Handle browser reload events
    _reloadSubscription = html.window.onBeforeUnload.listen((event) {
      // Save current data before reload
      _saveCurrentPageData();
      _autoSaveToFirestore();
    });

    // Push initial state to enable popstate detection
    html.window.history.pushState(null, '', html.window.location.href);
  }

  Future<void> _showBrowserBackConfirmation() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF2A2C2A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back, color: Colors.orange, size: 50),
                const SizedBox(height: 20),
                Text(
                  'Leave Game Editor?',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'You are about to leave the game editor. Do you want to save your changes before leaving?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    AnimatedButton(
                      width: 80,
                      height: 40,
                      color: Colors.grey,
                      onPressed: () {
                        Navigator.of(context).pop();
                        // Stay on current page - push state again
                        html.window.history.pushState(
                          null,
                          '',
                          html.window.location.href,
                        );
                      },
                      child: Text(
                        'Stay',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    AnimatedButton(
                      width: 80,
                      height: 40,
                      color: Colors.red,
                      onPressed: () async {
                        Navigator.of(context).pop();
                        _removeEventListeners();
                        await _navigateBasedOnRole();
                      },
                      child: Text(
                        'Leave',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    AnimatedButton(
                      width: 80,
                      height: 40,
                      color: Colors.green,
                      onPressed: () async {
                        Navigator.of(context).pop();
                        _saveCurrentPageData();
                        await _saveToFirestore();
                        _removeEventListeners();
                        await _navigateBasedOnRole();
                      },
                      child: Text(
                        'Save',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _removeEventListeners() {
    _beforeUnloadSubscription?.cancel();
    _popStateSubscription?.cancel();
    _reloadSubscription?.cancel();
    _beforeUnloadSubscription = null;
    _popStateSubscription = null;
    _reloadSubscription = null;
  }

  void _syncVisibleLetters() {
    final text = answerController.text;
    setState(() {
      if (text.isEmpty) {
        visibleLetters = [];
      } else {
        final newVisible = List<bool>.filled(text.length, true);
        for (
          int i = 0;
          i < visibleLetters.length && i < newVisible.length;
          i++
        ) {
          newVisible[i] = visibleLetters[i];
        }
        visibleLetters = newVisible;
      }
    });
  }

  void _onTitleChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 1500), () async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || gameId == null) return;

      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('created_games')
            .doc(gameId)
            .update({
              'title': titleController.text.trim(),
              'updated_at': FieldValue.serverTimestamp(),
            });
      } catch (e) {
        debugPrint('Failed to update title: $e');
      }
    });
  }

  void _toggleLetter(int index) {
    setState(() {
      visibleLetters[index] = !visibleLetters[index];
    });
  }

  void _saveCurrentPageData() {
    pages[currentPageIndex] = PageData(
      title: '',
      description: '',
      gameType: selectedGameType,
      difficulty: '',
      gameRule: '',
      gameSet: '',
      answer: answerController.text,
      descriptionField: descriptionFieldController.text,
      readSentence: readSentenceController.text,
      listenAndRepeat: listenAndRepeatController.text,
      visibleLetters: List.from(visibleLetters),
      selectedImageBytes: selectedImageBytes,
      whatCalledImageBytes: whatCalledImageBytes,
      multipleChoices: List.from(multipleChoices),
      guessAnswerImages: List.from(guessAnswerImages),
      imageMatchImages: List.from(imageMatchImages),
      imageMatchCount: imageMatchCount,
      prizeCoins: '',
      hint: hintController.text,
      correctAnswerIndex: correctAnswerIndex,
      docId: pages[currentPageIndex].docId, // Preserve the document ID
      imageUrl: pages[currentPageIndex].imageUrl, // Preserve image URL
      whatCalledImageUrl: pages[currentPageIndex].whatCalledImageUrl,
      guessAnswerImageUrls: pages[currentPageIndex].guessAnswerImageUrls,
      imageMatchImageUrls: pages[currentPageIndex].imageMatchImageUrls,
    );
  }

  void _loadPageData(int pageIndex) {
    final pageData = pages[pageIndex];

    debugPrint('Loading page $pageIndex with gameType: ${pageData.gameType}');
    debugPrint(
      'Page selectedImageBytes is null: ${pageData.selectedImageBytes == null}',
    );
    if (pageData.selectedImageBytes != null) {
      debugPrint(
        'Page selectedImageBytes size: ${pageData.selectedImageBytes!.length}',
      );
    }

    setState(() {
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
      
      // Load correct answer index for Guess the answer and Guess the answer 2
      if (pageData.gameType == 'Guess the answer' ||
          pageData.gameType == 'Guess the answer 2') {
        correctAnswerIndex = pageData.correctAnswerIndex;
      }

      progressValue = (pageIndex + 1) / pages.length;
      
      debugPrint(
        'After setState, selectedImageBytes is null: ${selectedImageBytes == null}',
      );
    });
  }

  void _goToPreviousPage() {
    if (currentPageIndex > 0) {
      _saveCurrentPageData();
      currentPageIndex--;
      _loadPageData(currentPageIndex);
    }
  }

  void _goToNextPage() {
    _saveCurrentPageData();

    if (currentPageIndex < pages.length - 1) {
      currentPageIndex++;
      _loadPageData(currentPageIndex);
    } else {
      setState(() {
        pages.add(PageData());
        currentPageIndex++;
      });
      _loadPageData(currentPageIndex);
    }
  }

  void _showPageSelector() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF2A2C2A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Select Page',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: pages.length,
                    itemBuilder: (context, index) {
                      final isCurrentPage = index == currentPageIndex;
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: Material(
                          color: isCurrentPage
                              ? Colors.green.withOpacity(0.3)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            onTap: () {
                              if (!isCurrentPage) {
                                _saveCurrentPageData();
                                currentPageIndex = index;
                                _loadPageData(currentPageIndex);
                              }
                              Navigator.of(context).pop();
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: isCurrentPage
                                      ? Colors.green
                                      : Colors.white.withOpacity(0.3),
                                  width: isCurrentPage ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Page ${index + 1}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      color: Colors.white,
                                      fontWeight: isCurrentPage
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  if (pages[index].title.isNotEmpty)
                                    Flexible(
                                      child: Text(
                                        pages[index].title,
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          color: Colors.white70,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  if (isCurrentPage)
                                    const Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                      size: 20,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                AnimatedButton(
                  width: 100,
                  height: 40,
                  color: Colors.grey,
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Close',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _deletePage() {
    if (pages.length == 1) {
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2C2A),
          title: Text(
            'Delete Page',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to delete Page ${currentPageIndex + 1}?',
            style: GoogleFonts.poppins(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                
                // Delete the round document from Firestore and update page numbers
                await _deletePageFromFirestore(currentPageIndex);
                
                setState(() {
                  pages.removeAt(currentPageIndex);

                  if (currentPageIndex >= pages.length) {
                    currentPageIndex = pages.length - 1;
                  }
                });
                 
                _loadPageData(currentPageIndex);
              },
              child: Text(
                'Delete',
                style: GoogleFonts.poppins(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Delete a specific page/round from Firestore and update subsequent page numbers
  Future<void> _deletePageFromFirestore(int pageIndex) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || gameId == null) return;

    try {
      final gameRoundsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('created_games')
          .doc(gameId)
          .collection('game_rounds');

      // Delete the document if it exists
      if (pages[pageIndex].docId != null) {
        await gameRoundsRef.doc(pages[pageIndex].docId).delete();
      }

      // Update page numbers for all subsequent pages
      for (int i = pageIndex + 1; i < pages.length; i++) {
        if (pages[i].docId != null) {
          await gameRoundsRef.doc(pages[i].docId).update({
            'page':
                i, // New page number after deletion (0-indexed becomes i because we're removing one)
          });
        }
      }
    } catch (e) {
      debugPrint('Failed to delete page from Firestore: $e');
    }
  }

  /// Handle browser reload scenario - retrieve gameId and load data
  Future<void> _handleBrowserReload() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Try to get the most recent game from the user's created_games collection
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('created_games')
          .orderBy('updated_at', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        gameId = doc.id;
        await _loadFromFirestore(gameId!);
      }
    } catch (e) {
      debugPrint('Failed to handle browser reload: $e');
    }
  }

  /// Auto-save current data to Firestore (for reload scenarios)
  Future<void> _autoSaveToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || gameId == null) return;

    try {
      final Map<String, dynamic> gameData = {
        'title': titleController.text.trim(),
        'description': descriptionController.text.trim(),
        'difficulty': selectedDifficulty,
        'prizeCoins': prizeCoinsController.text.replaceAll(',', '').trim(),
        'gameRule': selectedGameRule,
        'gameSet': selectedGameSet,
        'gameCode': selectedGameSet == 'private'
            ? gameCodeController.text.trim()
            : '',
        'updated_at': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('created_games')
          .doc(gameId)
          .update(gameData);

      // Save all pages to game_rounds subcollection
      await _saveGameRounds();
    } catch (e) {
      debugPrint('Failed to auto-save game: $e');
    }
  }

  /// Load all game metadata from Firestore
  Future<void> _loadFromFirestore(String id) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('created_games')
          .doc(id)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          titleController.text = (data['title'] as String?) ?? '';
          descriptionController.text = (data['description'] as String?) ?? '';
          selectedDifficulty = (data['difficulty'] as String?) ?? 'easy';
          prizeCoinsController.text = (data['prizeCoins'] as String?) ?? '100';
          selectedGameRule = (data['gameRule'] as String?) ?? 'none';
          selectedGameSet = (data['gameSet'] as String?) ?? 'public';
          gameCodeController.text = (data['gameCode'] as String?) ?? '';
        });
        
        // Load game rounds data
        await _loadGameRounds();
      }
    } catch (e) {
      debugPrint('Failed to load game metadata: $e');
    }
  }

  /// Load all game rounds from Firestore
  Future<void> _loadGameRounds() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || gameId == null) return;

    try {
      final gameRoundsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('created_games')
          .doc(gameId)
          .collection('game_rounds');

      final snapshot = await gameRoundsRef.orderBy('page').get();

      if (snapshot.docs.isEmpty) {
        // No rounds saved yet, keep default single page
        return;
      }

      List<PageData> loadedPages = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final gameType = (data['gameType'] as String?) ?? 'Fill in the blank';
        
        // Load game type specific data from game_type subcollection
        final gameTypeData = await _loadGameTypeData(doc.id, gameType);
        
        debugPrint('Loading page data for gameType: $gameType');
        debugPrint(
          'ImageBytes available: ${gameTypeData['imageBytes'] != null}',
        );
        debugPrint('ImageUrl available: ${gameTypeData['imageUrl'] != null}');

        // Handle different field structures based on game type
        List<String> multipleChoices = [];
        String hint = '';
        if (gameType == 'Guess the answer') {
          // Guess the answer structure (updated with checkboxes)
          multipleChoices = [
            gameTypeData['multipleChoice1'] ?? '',
            gameTypeData['multipleChoice2'] ?? '',
            gameTypeData['multipleChoice3'] ?? '',
            gameTypeData['multipleChoice4'] ?? '',
          ];
          hint = gameTypeData['gameHint'] ?? '';
        } else if (gameType == 'Guess the answer 2') {
          // Guess the answer 2 structure (new with multiple images)
          multipleChoices = [
            gameTypeData['multipleChoice1'] ?? '',
            gameTypeData['multipleChoice2'] ?? '',
            gameTypeData['multipleChoice3'] ?? '',
            gameTypeData['multipleChoice4'] ?? '',
          ];
          hint = gameTypeData['hint'] ?? '';
        } else {
          // Other game types
          multipleChoices = gameTypeData['multipleChoices'] != null
              ? List<String>.from(gameTypeData['multipleChoices'])
              : [];
          hint = gameTypeData['gameHint'] ?? '';
        }
        
        loadedPages.add(
          PageData(
            gameType: gameType,
            answer: gameTypeData['answerText'] ?? gameTypeData['answer'] ?? '',
            descriptionField: gameTypeData['question'] ?? '',
            readSentence: gameTypeData['sentence'] ?? '',
            listenAndRepeat: gameTypeData['sentence'] ?? '',
            visibleLetters:
                gameTypeData['answer'] != null && gameTypeData['answer'] is List
                ? List<bool>.from(gameTypeData['answer'])
                : [],
            multipleChoices: multipleChoices,
            imageMatchCount: gameTypeData['imageCount'] ?? 2,
            hint: hint,
            docId: doc.id,
            selectedImageBytes: gameTypeData['imageBytes'] as Uint8List?,
            imageUrl:
                gameTypeData['imageUrl'] as String? ??
                gameTypeData['image'] as String?,
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
            correctAnswerIndex:
                gameType == 'Guess the answer' ||
                    gameType == 'Guess the answer 2'
                ? (gameTypeData['answer'] as int?) ??
                      (gameTypeData['correctAnswerIndex'] as int?) ??
                      -1
                : -1,
          ),
        );
      }

      setState(() {
        pages = loadedPages;
        currentPageIndex = 0;
        if (pages.isNotEmpty) {
          _loadPageData(0);
        }
      });
    } catch (e) {
      debugPrint('Failed to load game rounds: $e');
    }
  }

  /// Load specific game type data from game_type subcollection
  Future<Map<String, dynamic>> _loadGameTypeData(
    String roundDocId,
    String gameType,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || gameId == null) return {};

    try {
      final gameTypeRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('created_games')
          .doc(gameId)
          .collection('game_rounds')
          .doc(roundDocId)
          .collection('game_type');

      final gameTypeDocId = gameType.toLowerCase().replaceAll(' ', '_');
      final docSnapshot = await gameTypeRef.doc(gameTypeDocId).get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data() ?? {};

        // Load images from URLs if they exist
        if (gameType == 'Guess the answer 2') {
          // Handle multiple images for Guess the answer 2
          for (int i = 1; i <= 3; i++) {
            String? imageUrl = data['image$i'];
            if (imageUrl != null && imageUrl.isNotEmpty) {
              try {
                debugPrint('Downloading image $i from: $imageUrl');
                final imageBytes = await _downloadImageFromUrl(imageUrl);
                if (imageBytes != null) {
                  data['image${i}Bytes'] = imageBytes;
                  debugPrint(
                    'Image $i downloaded successfully, size: ${imageBytes.length} bytes',
                  );
                } else {
                  debugPrint('Image $i download returned null');
                }
              } catch (e) {
                debugPrint('Failed to download image $i: $e');
              }
            }
          }
        } else {
          // Handle single image for other game types
          String? imageUrl;
          if (data['imageUrl'] != null &&
              data['imageUrl'] is String &&
              (data['imageUrl'] as String).isNotEmpty) {
            imageUrl = data['imageUrl'];
          } else if (data['image'] != null &&
              data['image'] is String &&
              (data['image'] as String).isNotEmpty) {
            imageUrl = data['image'];
          }

          if (imageUrl != null) {
            try {
              debugPrint('Downloading image from: $imageUrl');
              final imageBytes = await _downloadImageFromUrl(imageUrl);
              if (imageBytes != null) {
                data['imageBytes'] = imageBytes;
                debugPrint(
                  'Image downloaded successfully, size: ${imageBytes.length} bytes',
                );
              } else {
                debugPrint('Image download returned null');
              }
            } catch (e) {
              debugPrint('Failed to download image: $e');
            }
          } else {
            debugPrint('No valid image URL found in data');
          }
        }

        return data;
      }
    } catch (e) {
      debugPrint('Failed to load game type data: $e');
    }
    return {};
  }

  /// Upload image to Firebase Storage and return download URL
  Future<String> _uploadImageToStorage(
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
      final uploadTask = await ref.putData(
        imageBytes,
        SettableMetadata(contentType: 'image/png'),
      );

      final downloadUrl = await uploadTask.ref.getDownloadURL();
      debugPrint('Image uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      rethrow;
    }
  }

  /// Download image from URL and return as Uint8List
  Future<Uint8List?> _downloadImageFromUrl(String imageUrl) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        debugPrint('Failed to download image: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error downloading image: $e');
      return null;
    }
  }

  /// Get current user's role from Firestore
  Future<String> _getUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'student';

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        return userDoc.data()?['role'] ?? 'student';
      }
      return 'student';
    } catch (e) {
      debugPrint('Failed to get user role: $e');
      return 'student';
    }
  }

  /// Navigate to appropriate page based on user role
  Future<void> _navigateBasedOnRole() async {
    final role = await _getUserRole();

    if (role == 'admin') {
      Get.offAllNamed('/admin');
    } else if (role == 'teacher') {
      Get.offAllNamed('/teacher_home');
    } else {
      Get.offAllNamed('/game_create');
    }
  }

  /// Show close confirmation dialog
  Future<void> _showCloseConfirmationDialog() async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF2A2C2A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 50),
                const SizedBox(height: 20),
                Text(
                  'Close File',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Are you sure you want to close this file? Save the file?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    AnimatedButton(
                      width: 80,
                      height: 40,
                      color: Colors.grey,
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Return',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    AnimatedButton(
                      width: 80,
                      height: 40,
                      color: Colors.red,
                      onPressed: () async {
                        Navigator.of(context).pop();
                        _removeEventListeners();
                        await _navigateBasedOnRole();
                      },
                      child: Text(
                        'No',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    AnimatedButton(
                      width: 80,
                      height: 40,
                      color: Colors.green,
                      onPressed: () async {
                        Navigator.of(context).pop();
                        _saveCurrentPageData();
                        await _saveToFirestore();
                        _removeEventListeners();
                        await _navigateBasedOnRole();
                      },
                      child: Text(
                        'Save',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Show delete confirmation dialog
  Future<void> _showDeleteConfirmationDialog() async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF2A2C2A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red, size: 50),
                const SizedBox(height: 20),
                Text(
                  'Delete Game',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Are you sure you want to delete this game? This action cannot be undone.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    AnimatedButton(
                      width: 80,
                      height: 40,
                      color: Colors.grey,
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    AnimatedButton(
                      width: 80,
                      height: 40,
                      color: Colors.red,
                      onPressed: () {
                        Navigator.of(context).pop();
                        _deleteGame();
                      },
                      child: Text(
                        'Delete',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Delete game from Firestore
  Future<void> _deleteGame() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to delete.')),
      );
      return;
    }

    if (gameId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No game to delete.')));
      return;
    }

    try {
      final gameDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('created_games')
          .doc(gameId);

      // First, delete all documents in the game_rounds subcollection
      final gameRoundsSnapshot = await gameDocRef
          .collection('game_rounds')
          .get();

      for (var doc in gameRoundsSnapshot.docs) {
        await doc.reference.delete();
      }

      // Then delete the main game document
      await gameDocRef.delete();

      _removeEventListeners();
      await _navigateBasedOnRole();
    } catch (e) {
      debugPrint('Failed to delete game: $e');
    }
  }

  /// Save all game metadata to Firestore
  Future<void> _saveToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to save.')),
      );
      return;
    }

    try {
      final Map<String, dynamic> gameData = {
        'title': titleController.text.trim(),
        'description': descriptionController.text.trim(),
        'difficulty': selectedDifficulty,
        'prizeCoins': prizeCoinsController.text.replaceAll(',', '').trim(),
        'gameRule': selectedGameRule,
        'gameSet': selectedGameSet,
        'gameCode': selectedGameSet == 'private'
            ? gameCodeController.text.trim()
            : '',
      };

      if (gameId == null) {
        final docRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('created_games')
            .doc();

        gameData['created_at'] = FieldValue.serverTimestamp();
        await docRef.set(gameData);

        setState(() {
          gameId = docRef.id;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Game created and saved successfully.')),
        );
      } else {
        gameData['updated_at'] = FieldValue.serverTimestamp();

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('created_games')
            .doc(gameId)
            .update(gameData);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Game updated successfully.')),
        );
      }

      // Save all pages to game_rounds subcollection
      await _saveGameRounds();
    } catch (e) {
      debugPrint('Failed to save game: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: ${e.toString()}')),
      );
    }
  }

  /// Save all game rounds to the game_rounds subcollection
  Future<void> _saveGameRounds() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || gameId == null) return;

    try {
      final gameRoundsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('created_games')
          .doc(gameId)
          .collection('game_rounds');

      // Save each page as a round document
      for (int i = 0; i < pages.length; i++) {
        final pageData = pages[i];

        final Map<String, dynamic> roundData = {
          'gameType': pageData.gameType,
          'page': i + 1, // Store 1-based page number
        };

        String roundDocId;
        // If document ID exists, update it; otherwise create a new one
        if (pageData.docId != null) {
          roundDocId = pageData.docId!;
          await gameRoundsRef.doc(roundDocId).set(roundData);
        } else {
          // Create new document with auto-generated ID
          final docRef = await gameRoundsRef.add(roundData);
          roundDocId = docRef.id;
          // Store the generated document ID back to the page data
          pages[i].docId = roundDocId;
        }

        // Save specific game type data to game_type subcollection
        await _saveGameTypeData(roundDocId, pageData);
      }
    } catch (e) {
      debugPrint('Failed to save game rounds: $e');
    }
  }

  /// Save specific game type data to game_type subcollection
  Future<void> _saveGameTypeData(String roundDocId, PageData pageData) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || gameId == null) return;

    try {
      final gameTypeRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('created_games')
          .doc(gameId)
          .collection('game_rounds')
          .doc(roundDocId)
          .collection('game_type');

      // Create a document with the game type as the document ID
      final gameTypeDocId = pageData.gameType.toLowerCase().replaceAll(
        ' ',
        '_',
      );

      final Map<String, dynamic> gameTypeData = {
        'gameType': pageData.gameType,
        'timestamp': FieldValue.serverTimestamp(),
      };

      // Add specific data based on game type
      if (pageData.gameType == 'Fill in the blank') {
        gameTypeData.addAll({
          'answer': pageData.visibleLetters,
          'gameHint': pageData.hint,
          'answerText': pageData.answer,
        });
      } else if (pageData.gameType == 'Fill in the blank 2') {
        gameTypeData.addAll({
          'answer': pageData.visibleLetters,
          'gameHint': pageData.hint,
          'answerText': pageData.answer,
          'imageData': pageData.selectedImageBytes != null
              ? 'image_uploaded'
              : null,
        });
      } else if (pageData.gameType == 'Guess the answer') {
        // Upload image if new bytes exist, otherwise use existing URL
        String? imageUrl = pageData.imageUrl;
        if (pageData.selectedImageBytes != null) {
          try {
            imageUrl = await _uploadImageToStorage(
              pageData.selectedImageBytes!,
              'guess_the_answer',
            );
            pageData.imageUrl = imageUrl;
          } catch (e) {
            debugPrint('Failed to upload image for Guess the answer: $e');
          }
        }
         
        gameTypeData.addAll({
          'question': pageData.descriptionField,
          'gameHint': pageData.hint,
          'answer': correctAnswerIndex,
          'image': imageUrl,
          'multipleChoice1': pageData.multipleChoices.isNotEmpty
              ? pageData.multipleChoices[0]
              : '',
          'multipleChoice2': pageData.multipleChoices.length > 1
              ? pageData.multipleChoices[1]
              : '',
          'multipleChoice3': pageData.multipleChoices.length > 2
              ? pageData.multipleChoices[2]
              : '',
          'multipleChoice4': pageData.multipleChoices.length > 3
              ? pageData.multipleChoices[3]
              : '',
        });
      } else if (pageData.gameType == 'Guess the answer 2') {
        // Upload multiple images if new bytes exist, otherwise use existing URLs
        List<String?> imageUrls = List.from(pageData.guessAnswerImageUrls);
        for (int i = 0; i < pageData.guessAnswerImages.length; i++) {
          if (pageData.guessAnswerImages[i] != null) {
            try {
              imageUrls[i] = await _uploadImageToStorage(
                pageData.guessAnswerImages[i]!,
                'guess_the_answer_image${i + 1}',
              );
            } catch (e) {
              debugPrint(
                'Failed to upload image $i for Guess the answer 2: $e',
              );
            }
          }
        }
        pageData.guessAnswerImageUrls = imageUrls;
        
        gameTypeData.addAll({
          'question': pageData.descriptionField,
          'hint': pageData.hint,
          'image1': imageUrls[0] ?? '',
          'image2': imageUrls[1] ?? '',
          'image3': imageUrls[2] ?? '',
          'multipleChoice1': pageData.multipleChoices.isNotEmpty
              ? pageData.multipleChoices[0]
              : '',
          'multipleChoice2': pageData.multipleChoices.length > 1
              ? pageData.multipleChoices[1]
              : '',
          'multipleChoice3': pageData.multipleChoices.length > 2
              ? pageData.multipleChoices[2]
              : '',
          'multipleChoice4': pageData.multipleChoices.length > 3
              ? pageData.multipleChoices[3]
              : '',
          'correctAnswerIndex': correctAnswerIndex,
        });
      } else if (pageData.gameType == 'Read the sentence') {
        gameTypeData.addAll({'sentence': pageData.readSentence});
      } else if (pageData.gameType == 'What is it called') {
        gameTypeData.addAll({
          'sentence': pageData.readSentence,
          'imageData': pageData.whatCalledImageBytes != null
              ? 'image_uploaded'
              : null,
        });
      } else if (pageData.gameType == 'Listen and Repeat') {
        gameTypeData.addAll({'sentence': pageData.listenAndRepeat});
      } else if (pageData.gameType == 'Image Match') {
        gameTypeData.addAll({
          'imageCount': pageData.imageMatchCount,
          'imagesData': pageData.imageMatchImages
              .where((img) => img != null)
              .length,
        });
      } else if (pageData.gameType == 'Math') {
        gameTypeData.addAll({'mathData': 'math_game_configured'});
      }

      await gameTypeRef
          .doc(gameTypeDocId)
          .set(gameTypeData, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to save game type data: $e');
    }
  }

  @override
  void dispose() {
    _removeEventListeners();
    _debounceTimer?.cancel();
    titleController.removeListener(_onTitleChanged);
    titleController.dispose();
    descriptionController.dispose();
    descriptionFieldController.dispose();
    answerController.removeListener(_syncVisibleLetters);
    answerController.dispose();
    readSentenceController.dispose();
    listenAndRepeatController.dispose();
    prizeCoinsController.dispose();
    gameCodeController.dispose();
    hintController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E201E),
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -------- Column 1 --------
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Title:",
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 300,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: TextField(
                      controller: titleController,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.black,
                      ),
                      decoration: InputDecoration(
                        hintText: "Enter title",
                        hintStyle: GoogleFonts.poppins(
                          color: Colors.black54,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    "Description:",
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 300,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: TextField(
                      maxLines: 4,
                      controller: descriptionController,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.black,
                      ),
                      decoration: InputDecoration(
                        hintText: "Enter description here...",
                        hintStyle: GoogleFonts.poppins(
                          color: Colors.black54,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    "Difficulty:",
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 300,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DropdownButton<String>(
                      value: selectedDifficulty,
                      dropdownColor: Colors.white,
                      underline: const SizedBox(),
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.black,
                      ),
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.black,
                        fontWeight: FontWeight.w500,
                      ),
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 'easy', child: Text('Easy')),
                        DropdownMenuItem(
                          value: 'easy-normal',
                          child: Text('Easy-Normal'),
                        ),
                        DropdownMenuItem(
                          value: 'normal',
                          child: Text('Normal'),
                        ),
                        DropdownMenuItem(value: 'hard', child: Text('Hard')),
                        DropdownMenuItem(
                          value: 'insane',
                          child: Text('Insane'),
                        ),
                        DropdownMenuItem(
                          value: 'brainstorm',
                          child: Text('Brainstorm'),
                        ),
                        DropdownMenuItem(
                          value: 'hard-brainstorm',
                          child: Text('Hard Brainstorm'),
                        ),
                      ],
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            selectedDifficulty = newValue;
                          });
                        }
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    "Prize Coin:",
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 300,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TextField(
                      controller: prizeCoinsController,
                      keyboardType: TextInputType.numberWithOptions(
                        signed: false,
                        decimal: false,
                      ),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.black,
                      ),
                      decoration: InputDecoration(
                        hintText: "Enter prize amount",
                        hintStyle: GoogleFonts.poppins(
                          color: Colors.black54,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                      ),
                      onChanged: (value) {
                        if (value.isNotEmpty) {
                          String cleanValue = value.replaceAll(',', '');
                          int? coins = int.tryParse(cleanValue);

                          if (coins != null) {
                            if (coins > 99999) {
                              prizeCoinsController.text = NumberFormat(
                                '#,##0',
                              ).format(99999);
                              prizeCoinsController.selection =
                                  TextSelection.fromPosition(
                                    TextPosition(
                                      offset: prizeCoinsController.text.length,
                                    ),
                                  );
                            } else {
                              String formatted = NumberFormat(
                                '#,##0',
                              ).format(coins);
                              if (formatted != value) {
                                prizeCoinsController.text = formatted;
                                prizeCoinsController.selection =
                                    TextSelection.fromPosition(
                                      TextPosition(offset: formatted.length),
                                    );
                              }
                            }
                          } else if (cleanValue.isEmpty) {
                            prizeCoinsController.text = '';
                          }
                        }
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    "Game Rules:",
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 300,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DropdownButton<String>(
                      value: selectedGameRule,
                      dropdownColor: Colors.white,
                      underline: const SizedBox(),
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.black,
                      ),
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.black,
                        fontWeight: FontWeight.w500,
                      ),
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 'none', child: Text('None')),
                        DropdownMenuItem(
                          value: 'heart',
                          child: Text('Heart Deduction'),
                        ),
                        DropdownMenuItem(
                          value: 'timer',
                          child: Text('Timer Countdown'),
                        ),
                        DropdownMenuItem(value: 'score', child: Text('Score')),
                      ],
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            selectedGameRule = newValue;
                          });
                        }
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    "Game Set:",
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 300,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: DropdownButton<String>(
                          value: selectedGameSet,
                          dropdownColor: Colors.white,
                          underline: const SizedBox(),
                          icon: const Icon(
                            Icons.arrow_drop_down,
                            color: Colors.black,
                          ),
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(
                              value: 'public',
                              child: Text('Public'),
                            ),
                            DropdownMenuItem(
                              value: 'private',
                              child: Text('Private'),
                            ),
                          ],
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                selectedGameSet = newValue;
                                if (newValue == 'public') {
                                  gameCodeController.clear();
                                }
                              });
                            }
                          },
                        ),
                      ),

                      if (selectedGameSet == 'private') ...[
                        const SizedBox(width: 20),

                        Container(
                          width: 120,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: TextField(
                            controller: gameCodeController,
                            keyboardType: TextInputType.numberWithOptions(
                              signed: false,
                              decimal: false,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(8),
                            ],
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: Colors.black,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              hintText: "Game Code...",
                              hintStyle: GoogleFonts.poppins(
                                color: Colors.black54,
                                fontSize: 14,
                              ),
                              border: InputBorder.none,
                            ),
                            onChanged: (value) {
                              String cleanValue = value.replaceAll('-', '');
                              if (cleanValue.length >= 5) {
                                String formatted = '';
                                for (int i = 0; i < cleanValue.length; i++) {
                                  if (i == 4) {
                                    formatted += '-${cleanValue[i]}';
                                  } else {
                                    formatted += cleanValue[i];
                                  }
                                }
                                if (formatted != value) {
                                  gameCodeController.text = formatted;
                                  gameCodeController.selection =
                                      TextSelection.fromPosition(
                                        TextPosition(offset: formatted.length),
                                      );
                                }
                              }
                            },
                          ),
                        ),
                      ],
                    ],
                  ),

                  const Spacer(),

                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 10),
                    child: Divider(color: Colors.white),
                  ),

                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        AnimatedButton(
                          width: 100,
                          height: 50,
                          color: Colors.red,
                          onPressed: () {
                            _showDeleteConfirmationDialog();
                          },
                          child: Text(
                            "Delete",
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),

                        AnimatedButton(
                          width: 100,
                          height: 50,
                          color: Colors.blue,
                          onPressed: () {
                            _showCloseConfirmationDialog();
                          },
                          child: Text(
                            "Close",
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),

                        AnimatedButton(
                          width: 100,
                          height: 50,
                          color: Colors.green,
                          onPressed: () async {
                            _saveCurrentPageData();
                            await _saveToFirestore();
                          },
                          child: Text(
                            "Save",
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
                ],
              ),
            ),

            // -------- Column 2 --------
            Expanded(
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
                                      : selectedGameType ==
                                            'Fill in the blank 2'
                                      ? MyFillInTheBlank2(
                                          answerController: answerController,
                                          visibleLetters: visibleLetters,
                                          pickedImage: selectedImageBytes,
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
                                          multipleChoices: multipleChoices,
                                          correctAnswerIndex:
                                              correctAnswerIndex,
                                        )
                                      : selectedGameType == 'Guess the answer 2'
                                      ? MyGuessTheAnswer(
                                          hintController: hintController,
                                          questionController:
                                              descriptionFieldController,
                                          visibleLetters: visibleLetters,
                                          pickedImages: guessAnswerImages,
                                          multipleChoices: multipleChoices,
                                          correctAnswerIndex:
                                              correctAnswerIndex,
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
                                        )
                                      : selectedGameType == 'Listen and Repeat'
                                      ? MyListenAndRepeat(
                                          sentenceController:
                                              listenAndRepeatController,
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
                                    color: Colors.green,
                                    onPressed: () async {
                                      _saveCurrentPageData();
                                      await _saveToFirestore();
                                    },
                                    child: Text(
                                      "Confirm",
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

            // -------- Column 3 --------
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          "Game Type:",
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 300,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: DropdownButton<String>(
                            value: selectedGameType,
                            dropdownColor: Colors.white,
                            underline: const SizedBox(),
                            icon: const Icon(
                              Icons.arrow_drop_down,
                              color: Colors.black,
                            ),
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: Colors.black,
                              fontWeight: FontWeight.w500,
                            ),
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(
                                value: 'Fill in the blank',
                                child: Text('Fill in the blank'),
                              ),
                              DropdownMenuItem(
                                value: 'Fill in the blank 2',
                                child: Text('Fill in the blank 2'),
                              ),
                              DropdownMenuItem(
                                value: 'Guess the answer',
                                child: Text('Guess the answer'),
                              ),
                              DropdownMenuItem(
                                value: 'Guess the answer 2',
                                child: Text('Guess the answer 2'),
                              ),
                              DropdownMenuItem(
                                value: 'Read the sentence',
                                child: Text('Read the sentence'),
                              ),
                              DropdownMenuItem(
                                value: 'What is it called',
                                child: Text('What is it called'),
                              ),
                              DropdownMenuItem(
                                value: 'Listen and Repeat',
                                child: Text('Listen and Repeat'),
                              ),
                              DropdownMenuItem(
                                value: 'Image Match',
                                child: Text('Image Match'),
                              ),
                              DropdownMenuItem(
                                value: 'Math',
                                child: Text('Math'),
                              ),
                            ],
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  selectedGameType = newValue;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),

                    Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 10),
                      child: Divider(color: Colors.white),
                    ),

                    if (selectedGameType == 'Fill in the blank')
                      MyFillTheBlankSettings(
                        answerController: answerController,
                        hintController: hintController,
                        visibleLetters: visibleLetters,
                        onToggle: _toggleLetter,
                      )
                    else if (selectedGameType == 'Fill in the blank 2')
                      MyFillInTheBlank2Settings(
                        answerController: answerController,
                        hintController: hintController,
                        visibleLetters: visibleLetters,
                        onToggle: _toggleLetter,
                        onImagePicked: (Uint8List imageBytes) {
                          setState(() {
                            selectedImageBytes = imageBytes;
                          });
                        },
                      )
                    else if (selectedGameType == 'Guess the answer')
                      MyFillInTheBlank3Settings(
                        hintController: hintController,
                        questionController: descriptionFieldController,
                        visibleLetters: visibleLetters,
                        onToggle: _toggleLetter,
                        onImagePicked: (Uint8List imageBytes) {
                          setState(() {
                            selectedImageBytes = imageBytes;
                          });
                        },
                        onChoicesChanged: (List<String> choices) {
                          setState(() {
                            multipleChoices = choices;
                          });
                        },
                        onCorrectAnswerSelected: (int index) {
                          setState(() {
                            correctAnswerIndex = index;
                          });
                        },
                      )
                    else if (selectedGameType == 'Guess the answer 2')
                      MyGuessTheAnswerSettings(
                        hintController: hintController,
                        questionController: descriptionFieldController,
                        visibleLetters: visibleLetters,
                        onToggle: _toggleLetter,
                        onImagePicked: (int index, Uint8List imageBytes) {
                          setState(() {
                            guessAnswerImages[index] = imageBytes;
                          });
                        },
                        onChoicesChanged: (List<String> choices) {
                          setState(() {
                            multipleChoices = choices;
                          });
                        },
                        onCorrectAnswerSelected: (int index) {
                          setState(() {
                            correctAnswerIndex = index;
                          });
                        },
                      )
                    else if (selectedGameType == 'Read the sentence')
                      MyReadTheSentenceSettings(
                        sentenceController: readSentenceController,
                      )
                    else if (selectedGameType == 'What is it called')
                      MyWhatItIsCalledSettings(
                        sentenceController: readSentenceController,
                        onImagePicked: (Uint8List imageBytes) {
                          setState(() {
                            whatCalledImageBytes = imageBytes;
                          });
                        },
                      )
                    else if (selectedGameType == 'Listen and Repeat')
                      MyListenAndRepeatSettings(
                        sentenceController: listenAndRepeatController,
                      )
                    else if (selectedGameType == 'Image Match')
                      MyImageMatchSettings(
                        onImagePicked: (int index, Uint8List imageBytes) {
                          setState(() {
                            imageMatchImages[index] = imageBytes;
                          });
                        },
                        onCountChanged: (int newCount) {
                          setState(() {
                            imageMatchCount = newCount;
                          });
                        },
                      )
                    else if (selectedGameType == 'Math')
                      MyMathSettings(mathState: mathState),

                    const Spacer(),

                    Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 10),
                      child: Divider(color: Colors.white),
                    ),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        AnimatedButton(
                          width: 50,
                          height: 50,
                          color: currentPageIndex > 0
                              ? Colors.blue
                              : Colors.grey.withOpacity(0.5),
                          onPressed: _goToPreviousPage,
                          child: Icon(
                            Icons.arrow_upward_rounded,
                            color: currentPageIndex > 0
                                ? Colors.white
                                : Colors.white.withOpacity(0.5),
                          ),
                        ),

                        AnimatedButton(
                          width: 150,
                          height: 50,
                          color: Colors.orange,
                          onPressed: _showPageSelector,
                          child: Text(
                            "Page ${currentPageIndex + 1} of ${pages.length}",
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),

                        AnimatedButton(
                          width: 50,
                          height: 50,
                          color: Colors.blue,
                          onPressed: _goToNextPage,
                          child: Icon(
                            currentPageIndex < pages.length - 1
                                ? Icons.arrow_downward_rounded
                                : Icons.add,
                            color: Colors.white,
                          ),
                        ),

                        AnimatedButton(
                          width: 50,
                          height: 50,
                          color: pages.length > 1
                              ? Colors.red
                              : Colors.red.withOpacity(0.5),
                          onPressed: _deletePage,
                          child: Icon(
                            Icons.delete_forever_rounded,
                            color: pages.length > 1
                                ? Colors.white
                                : Colors.white.withOpacity(0.5),
                          ),
                        ),

                        SizedBox(
                          height: 50,
                          child: IntrinsicHeight(
                            child: const VerticalDivider(
                              thickness: 2,
                              color: Colors.white,
                            ),
                          ),
                        ),

                        AnimatedButton(
                          width: 100,
                          height: 50,
                          color: Colors.green,
                          onPressed: () {
                            _saveCurrentPageData();
                            // Add test functionality here
                          },
                          child: Text(
                            "Test",
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
