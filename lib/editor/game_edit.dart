// ===== game_edit.dart =====

// ignore_for_file: deprecated_member_use, use_build_context_synchronously, avoid_web_libraries_in_flutter, avoid_print, unnecessary_import

import 'dart:async';
import 'dart:html' as html;
import 'dart:io';
import 'dart:typed_data';
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
import 'package:lexi_on_web/services/settings_service.dart';

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
  String? gameTypeDocId; // Firestore document ID for game_type subcollection
  String? imageUrl; // Firebase Storage URL for selectedImageBytes
  String? whatCalledImageUrl; // Firebase Storage URL for whatCalledImageBytes
  List<String?>
  guessAnswerImageUrls; // Firebase Storage URLs for guessAnswerImages
  List<String?>
  imageMatchImageUrls; // Firebase Storage URLs for imageMatchImages
  int correctAnswerIndex; // Index of correct answer for Guess the answer
  
  // Audio data for Listen and Repeat
  String? listenAndRepeatAudioPath; // Local audio file path
  String listenAndRepeatAudioSource; // "uploaded" or "recorded"
  String? listenAndRepeatAudioUrl; // Firebase Storage URL for audio
  Uint8List? listenAndRepeatAudioBytes; // Audio file bytes

  // Math game data
  Map<String, dynamic>?
  mathData; // Stores totalBoxes, operators, boxValues, answer

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
    this.gameTypeDocId,
    this.imageUrl,
    this.whatCalledImageUrl,
    List<String?>? guessAnswerImageUrls,
    List<String?>? imageMatchImageUrls,
    this.correctAnswerIndex = -1,
    this.listenAndRepeatAudioPath,
    this.listenAndRepeatAudioSource = "",
    this.listenAndRepeatAudioUrl,
    this.listenAndRepeatAudioBytes,
    this.mathData,
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
  
  // Audio state for Listen and Repeat
  String? listenAndRepeatAudioPath;
  String listenAndRepeatAudioSource = "";
  Uint8List? listenAndRepeatAudioBytes;

  List<PageData> pages = [PageData()];
  int currentPageIndex = 0;

  String? gameId;
  Timer? _debounceTimer;
  Timer? _autoSaveTimer;
  Timer? _idleTimer; // Timer for idle detection
  String _autoSaveStatus = ''; // Auto-save status message
  bool _isSaving = false; // Loading state for save button
  bool _hasUserInteracted = false; // Track if user has started interacting
  bool _isIdle = false; // Track if user is currently idle

  final mathState = MathState();
  final SettingsService _settingsService = SettingsService();

  // Browser event listeners
  StreamSubscription<html.Event>? _beforeUnloadSubscription;
  StreamSubscription<html.PopStateEvent>? _popStateSubscription;
  StreamSubscription<html.Event>? _reloadSubscription;

  @override
  void initState() {
    super.initState();
    answerController.addListener(_syncVisibleLetters);
    answerController.addListener(_triggerAutoSave);
    titleController.addListener(_onTitleChanged);
    descriptionController.addListener(_triggerAutoSave);
    descriptionFieldController.addListener(_triggerAutoSave);
    readSentenceController.addListener(_triggerAutoSave);
    listenAndRepeatController.addListener(_triggerAutoSave);
    hintController.addListener(_triggerAutoSave);
    gameCodeController.addListener(_triggerAutoSave);

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
    bool isSavingInDialog = false;
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
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
                          color: isSavingInDialog ? Colors.grey : Colors.green,
                      onPressed: () async {
                            if (isSavingInDialog) return;
                            setDialogState(() {
                              isSavingInDialog = true;
                            });
                        _saveCurrentPageData();
                        await _saveToFirestore();
                            if (mounted) {
                              Navigator.of(context).pop();
                            }
                        _removeEventListeners();
                        await _navigateBasedOnRole();
                      },
                          child: isSavingInDialog
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Text(
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

  /// Trigger auto-save when any field changes (intelligent idle-based system)
  void _triggerAutoSave() async {
    // Check if auto-save is enabled in settings
    final autoSaveEnabled = await _settingsService.getAutoSaveEnabled();
    if (!autoSaveEnabled) {
      debugPrint('Auto-save is disabled in settings - skipping auto-save');
      if (mounted) {
        setState(() {
          _autoSaveStatus = 'Auto-save disabled';
        });
      }
      return;
    }

    // Mark that user has started interacting
    _hasUserInteracted = true;

    // Cancel any existing idle timer
    _idleTimer?.cancel();

    // Show "Unsaved changes" status
    if (mounted) {
      setState(() {
        _autoSaveStatus = 'Unsaved changes...';
        _isIdle = false;
      });
    }

    debugPrint('User interaction detected - starting 10-second idle timer');

    // Start 10-second idle timer
    _idleTimer = Timer(const Duration(seconds: 10), () async {
      // User has been idle for 10 seconds - trigger auto-save
      await _performAutoSave();
    });
  }

  /// Perform the actual auto-save operation
  Future<void> _performAutoSave() async {
    // Double-check if auto-save is still enabled (in case setting changed during idle period)
    final autoSaveEnabled = await _settingsService.getAutoSaveEnabled();
    if (!autoSaveEnabled) {
      debugPrint(
        'Auto-save was disabled during idle period - skipping auto-save',
      );
      if (mounted) {
        setState(() {
          _autoSaveStatus = 'Auto-save disabled';
        });
      }
      return;
    }

      // Only auto-save if gameId exists (game has been created)
      if (gameId != null) {
      debugPrint('User idle for 10 seconds - auto-saving game data...');

        if (mounted) {
          setState(() {
            _autoSaveStatus = 'Saving...';
          _isIdle = true;
          });
        }

        _saveCurrentPageData();
        await _autoSaveToFirestore();

        if (mounted) {
          setState(() {
            _autoSaveStatus = 'All changes saved ✓';
          });

          // Clear status after 3 seconds
          Timer(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() {
                _autoSaveStatus = '';
              });
            }
          });
        }
      } else {
        debugPrint('Skipping auto-save - no gameId yet. Save manually first.');
        if (mounted) {
          setState(() {
            _autoSaveStatus = 'Click Save to create game first';
          });
        }
      }
  }

  /// Detect user interaction and trigger auto-save
  void _onUserInteraction() {
    _triggerAutoSave();
  }

  void _toggleLetter(int index) {
    setState(() {
      visibleLetters[index] = !visibleLetters[index];
    });
    // Trigger auto-save when letter visibility changes
    _onUserInteraction();
  }

  void _saveCurrentPageData() {
    debugPrint(
      "Saving page data - Audio path: $listenAndRepeatAudioPath, Source: $listenAndRepeatAudioSource",
    );
    debugPrint(
      "Saving page data - GameType: $selectedGameType, ReadSentence: '${readSentenceController.text}'",
    );

    // Preserve existing imageUrl if no new image bytes
    String? preservedImageUrl = pages[currentPageIndex].imageUrl;
    if (selectedImageBytes != null) {
      // New image uploaded, imageUrl will be updated on save
      preservedImageUrl = null;
    }
    
    // Save Math data if current game type is Math
    Map<String, dynamic>? savedMathData;
    if (selectedGameType == 'Math') {
      savedMathData = {
        'totalBoxes': mathState.totalBoxes,
        'answer': double.tryParse(mathState.resultController.text) ?? 0,
      };

      // Save operators
      for (int i = 0; i < mathState.operators.length && i < 9; i++) {
        savedMathData['operator${i + 1}_${i + 2}'] = mathState.operators[i];
      }

      // Save box values
      for (int i = 0; i < mathState.boxControllers.length && i < 10; i++) {
        final boxValue = double.tryParse(mathState.boxControllers[i].text) ?? 0;
        savedMathData['box${i + 1}'] = boxValue;
      }
    }
    
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
      gameTypeDocId: pages[currentPageIndex]
          .gameTypeDocId, // Preserve game_type document ID
      imageUrl:
          preservedImageUrl ??
          pages[currentPageIndex].imageUrl, // Preserve image URL
      whatCalledImageUrl: pages[currentPageIndex].whatCalledImageUrl,
      guessAnswerImageUrls: List.from(
        pages[currentPageIndex].guessAnswerImageUrls,
      ),
      imageMatchImageUrls: List.from(
        pages[currentPageIndex].imageMatchImageUrls,
      ),
      listenAndRepeatAudioPath: listenAndRepeatAudioPath,
      listenAndRepeatAudioSource: listenAndRepeatAudioSource,
      listenAndRepeatAudioUrl: pages[currentPageIndex].listenAndRepeatAudioUrl,
      listenAndRepeatAudioBytes: listenAndRepeatAudioBytes,
      mathData: savedMathData,
    );
  }

  void _loadPageData(int pageIndex) {
    final pageData = pages[pageIndex];

    debugPrint('========== Loading Page Data ==========');
    debugPrint('Loading page $pageIndex with gameType: ${pageData.gameType}');
    if (pageData.gameType == 'Read the sentence') {
      debugPrint(
        'Loading Read the sentence page - readSentence: "${pageData.readSentence}"',
      );
    } else if (pageData.gameType == 'What is it called') {
      debugPrint(
        'Loading What is it called page - readSentence: "${pageData.readSentence}", hint: "${pageData.hint}"',
      );
      debugPrint(
        'What is it called imageBytes is null: ${pageData.whatCalledImageBytes == null}',
      );
      debugPrint('What is it called imageUrl: ${pageData.whatCalledImageUrl}');
      debugPrint(
        'What is it called imageBytes size: ${pageData.whatCalledImageBytes?.length ?? 0}',
      );
    }
    debugPrint(
      'Page selectedImageBytes is null: ${pageData.selectedImageBytes == null}',
    );
    debugPrint('Page imageUrl: ${pageData.imageUrl}');
    debugPrint('ImageUrl length: ${pageData.imageUrl?.length ?? 0}');
    debugPrint(
      'ImageUrl starts with https: ${pageData.imageUrl?.startsWith('https') ?? false}',
    );
    if (pageData.selectedImageBytes != null) {
      debugPrint(
        'Page selectedImageBytes size: ${pageData.selectedImageBytes!.length}',
      );
    }
    debugPrint('=====================================');

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
      listenAndRepeatAudioPath = pageData.listenAndRepeatAudioPath;
      listenAndRepeatAudioSource = pageData.listenAndRepeatAudioSource;
      listenAndRepeatAudioBytes = pageData.listenAndRepeatAudioBytes;
      
      // Load correct answer index for Guess the answer and Guess the answer 2
      if (pageData.gameType == 'Guess the answer' ||
          pageData.gameType == 'Guess the answer 2') {
        correctAnswerIndex = pageData.correctAnswerIndex;
      }

      progressValue = (pageIndex + 1) / pages.length;
      
      debugPrint(
        'After setState, selectedImageBytes is null: ${selectedImageBytes == null}',
      );
      debugPrint('ImageUrl preserved: ${pageData.imageUrl}');
      debugPrint(
        'After setState, readSentenceController.text: "${readSentenceController.text}"',
      );
      debugPrint(
        'After setState, hintController.text: "${hintController.text}"',
      );
      debugPrint(
        'After setState, whatCalledImageBytes is null: ${whatCalledImageBytes == null}',
      );
      debugPrint(
        'After setState, whatCalledImageBytes size: ${whatCalledImageBytes?.length ?? 0}',
      );
    });
    
    // Load Math data if this is a Math game type
    if (pageData.gameType == 'Math') {
      _loadMathDataToState(pageData);
    }
  }

  /// Load Math game data into MathState
  void _loadMathDataToState(PageData pageData) {
    if (pageData.mathData == null) return;

    final data = pageData.mathData!;

    // Get totalBoxes
    final totalBoxes = data['totalBoxes'] as int? ?? 1;

    // Reset MathState
    while (mathState.totalBoxes > 1) {
      mathState.decrement();
    }

    // Add boxes to match totalBoxes
    while (mathState.totalBoxes < totalBoxes) {
      mathState.increment();
    }

    // Load box values
    for (
      int i = 0;
      i < totalBoxes && i < mathState.boxControllers.length;
      i++
    ) {
      final boxValue = data['box${i + 1}'];
      if (boxValue != null) {
        mathState.boxControllers[i].text = boxValue.toString();
      }
    }

    // Load operators
    for (int i = 0; i < mathState.operators.length; i++) {
      final operator = data['operator${i + 1}_${i + 2}'] as String?;
      if (operator != null && operator.isNotEmpty) {
        mathState.operators[i] = operator;
      }
    }

    // Load answer
    final answer = data['answer'];
    if (answer != null) {
      mathState.resultController.text = answer.toString();
    }

    // MathState will automatically recalculate and notify listeners
    // when controllers are updated
  }

  void _goToPreviousPage() {
    if (currentPageIndex > 0) {
      _saveCurrentPageData();
      currentPageIndex--;
      _loadPageData(currentPageIndex);
      _onUserInteraction();
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
    _onUserInteraction();
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

  /// Collect storage URLs from a single page
  Future<List<String>> _collectPageStorageUrls(PageData pageData) async {
    List<String> urls = [];

    try {
      // Collect URLs based on what's stored in PageData
      switch (pageData.gameType) {
        case 'Fill in the blank 2':
          if (pageData.imageUrl != null && pageData.imageUrl!.isNotEmpty) {
            urls.add(pageData.imageUrl!);
          }
          break;

        case 'Guess the answer':
          if (pageData.imageUrl != null && pageData.imageUrl!.isNotEmpty) {
            urls.add(pageData.imageUrl!);
          }
          break;

        case 'Guess the answer 2':
          for (final url in pageData.guessAnswerImageUrls) {
            if (url != null && url.isNotEmpty) {
              urls.add(url);
            }
          }
          break;

        case 'What is it called':
          if (pageData.whatCalledImageUrl != null &&
              pageData.whatCalledImageUrl!.isNotEmpty) {
            urls.add(pageData.whatCalledImageUrl!);
          }
          break;

        case 'Listen and Repeat':
          if (pageData.listenAndRepeatAudioUrl != null &&
              pageData.listenAndRepeatAudioUrl!.isNotEmpty) {
            urls.add(pageData.listenAndRepeatAudioUrl!);
          }
          break;

        case 'Image Match':
          for (final url in pageData.imageMatchImageUrls) {
            if (url != null && url.isNotEmpty) {
              urls.add(url);
            }
          }
          break;

        case 'Read the sentence':
          // Read the sentence doesn't use any storage files (no images/audio)
          // No URLs to collect
          break;
      }

      debugPrint('Collected ${urls.length} storage URLs from page');
      return urls;
    } catch (e) {
      debugPrint('Failed to collect page storage URLs: $e');
      return urls;
    }
  }

  /// Delete a specific page/round from Firestore and Firebase Storage, then update subsequent page numbers
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

      // Step 1: Collect and delete storage files for this page
      final pageData = pages[pageIndex];
      final storageUrls = await _collectPageStorageUrls(pageData);

      debugPrint(
        'Deleting ${storageUrls.length} storage files for page $pageIndex',
      );
      for (final url in storageUrls) {
        await _deleteFileFromStorage(url);
      }

      // Step 2: Delete game_type subcollection documents
      if (pageData.docId != null && pageData.gameTypeDocId != null) {
        await gameRoundsRef
            .doc(pageData.docId)
            .collection('game_type')
            .doc(pageData.gameTypeDocId)
            .delete();
      }

      // Step 3: Delete the round document if it exists
      if (pages[pageIndex].docId != null) {
        await gameRoundsRef.doc(pages[pageIndex].docId).delete();
      }

      // Step 4: Update page numbers for all subsequent pages
      for (int i = pageIndex + 1; i < pages.length; i++) {
        if (pages[i].docId != null) {
          await gameRoundsRef.doc(pages[i].docId).update({
            'page':
                i, // New page number after deletion (0-indexed becomes i because we're removing one)
          });
        }
      }
      
      debugPrint(
        'Page $pageIndex deleted successfully (including ${storageUrls.length} storage files)',
      );
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

      // Use SetOptions(merge: true) to avoid overwriting existing data
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('created_games')
          .doc(gameId)
          .set(gameData, SetOptions(merge: true));

      // Save all pages to game_rounds subcollection
      await _saveGameRounds();
      
      debugPrint('Auto-save completed successfully');
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
        final gameTypeDocId = (data['gameTypeDocId'] as String?) ?? '';
        
        // Load game type specific data from game_type subcollection
        final gameTypeData = await _loadGameTypeData(
          doc.id,
          gameType,
          gameTypeDocId,
        );
        
        debugPrint('Loading page data for gameType: $gameType');
        debugPrint(
          'ImageBytes available: ${gameTypeData['imageBytes'] != null}',
        );
        debugPrint('ImageUrl available: ${gameTypeData['imageUrl'] != null}');

        // Handle different field structures based on game type
        List<String> multipleChoices = [];
        String hint = '';
        String answer = '';
        String readSentence = '';
        String listenAndRepeat = '';
        
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
        } else if (gameType == 'What is it called') {
          // What is it called uses 'answer' field for the sentence
          readSentence = gameTypeData['answer'] ?? '';
          hint = gameTypeData['gameHint'] ?? '';
          debugPrint(
            'Loading What is it called data: readSentence="$readSentence", hint="$hint"',
          );
          debugPrint(
            'What is it called gameTypeData keys: ${gameTypeData.keys.toList()}',
          );
          debugPrint('What is it called imageUrl: ${gameTypeData['imageUrl']}');
          debugPrint('What is it called image: ${gameTypeData['image']}');
          debugPrint(
            'What is it called imageBytes: ${gameTypeData['imageBytes'] != null ? '${(gameTypeData['imageBytes'] as Uint8List).length} bytes' : 'null'}',
          );
        } else if (gameType == 'Listen and Repeat') {
          // Listen and Repeat uses 'answer' field for the sentence
          listenAndRepeat = gameTypeData['answer'] ?? '';
        } else if (gameType == 'Read the sentence') {
          readSentence = gameTypeData['sentence'] ?? '';
          debugPrint('Loading Read the sentence data: "$readSentence"');
        } else {
          // Other game types
          multipleChoices = gameTypeData['multipleChoices'] != null
              ? List<String>.from(gameTypeData['multipleChoices'])
              : [];
          hint = gameTypeData['gameHint'] ?? '';
          answer = gameTypeData['answerText'] ?? '';
        }
        
        loadedPages.add(
          PageData(
            gameType: gameType,
            answer: answer.isEmpty
                ? (gameTypeData['answerText'] ?? '')
                : answer,
            descriptionField: gameTypeData['question'] ?? '',
            readSentence: readSentence,
            listenAndRepeat: listenAndRepeat,
            visibleLetters:
                gameTypeData['answer'] != null && gameTypeData['answer'] is List
                ? List<bool>.from(gameTypeData['answer'])
                : [],
            multipleChoices: multipleChoices,
            imageMatchCount: gameTypeData['imageCount'] ?? 2,
            hint: hint,
            docId: doc.id,
            gameTypeDocId: gameTypeDocId,
            selectedImageBytes: gameTypeData['imageBytes'] as Uint8List?,
            imageUrl:
                gameTypeData['imageUrl'] as String? ??
                gameTypeData['image'] as String?,
            whatCalledImageBytes: gameType == 'What is it called'
                ? gameTypeData['imageBytes'] as Uint8List?
                : null,
            whatCalledImageUrl: gameType == 'What is it called'
                ? (gameTypeData['imageUrl'] as String? ??
                      gameTypeData['image'] as String?)
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
                    gameTypeData['image1Bytes'] as Uint8List?,
                    gameTypeData['image2Bytes'] as Uint8List?,
                    gameTypeData['image3Bytes'] as Uint8List?,
                    gameTypeData['image4Bytes'] as Uint8List?,
                    gameTypeData['image5Bytes'] as Uint8List?,
                    gameTypeData['image6Bytes'] as Uint8List?,
                    gameTypeData['image7Bytes'] as Uint8List?,
                    gameTypeData['image8Bytes'] as Uint8List?,
                  ]
                : List.filled(8, null),
            imageMatchImageUrls: gameType == 'Image Match'
                ? [
                    gameTypeData['image1'] as String?,
                    gameTypeData['image2'] as String?,
                    gameTypeData['image3'] as String?,
                    gameTypeData['image4'] as String?,
                    gameTypeData['image5'] as String?,
                    gameTypeData['image6'] as String?,
                    gameTypeData['image7'] as String?,
                    gameTypeData['image8'] as String?,
                  ]
                : List.filled(8, null),
            listenAndRepeatAudioUrl: gameType == 'Listen and Repeat'
                ? gameTypeData['audio'] as String?
                : null,
            listenAndRepeatAudioSource:
                gameType == 'Listen and Repeat' && gameTypeData['audio'] != null
                ? 'uploaded'
                : '',
            correctAnswerIndex:
                gameType == 'Guess the answer' ||
                    gameType == 'Guess the answer 2'
                ? (gameTypeData['answer'] as int?) ??
                      (gameTypeData['correctAnswerIndex'] as int?) ??
                      -1
                : -1,
            mathData: gameType == 'Math' ? gameTypeData : null,
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
    String gameTypeDocId,
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

      if (gameTypeDocId.isEmpty) {
        debugPrint('No gameTypeDocId found for round $roundDocId');
        return {};
      }
      
      final docSnapshot = await gameTypeRef.doc(gameTypeDocId).get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data() ?? {};

        // Load images from URLs if they exist
        if (gameType == 'What is it called') {
          // Handle single image for What is it called
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
              debugPrint('Downloading What is it called image from: $imageUrl');
              // Preserve both imageUrl and image fields for consistency
              data['imageUrl'] = imageUrl;
              data['image'] = imageUrl; // Keep original field for consistency

              final imageBytes = await _downloadImageFromUrl(imageUrl);
              if (imageBytes != null) {
                data['imageBytes'] = imageBytes;
                debugPrint(
                  'What is it called image downloaded successfully, size: ${imageBytes.length} bytes',
                );
              } else {
                debugPrint(
                  'What is it called image download returned null, will use URL directly',
                );
              }
            } catch (e) {
              debugPrint('Failed to download What is it called image: $e');
              // Keep both fields for consistency
              data['imageUrl'] = imageUrl;
              data['image'] = imageUrl;
            }
          } else {
            debugPrint('No valid image URL found for What is it called');
          }
        } else if (gameType == 'Guess the answer 2') {
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
        } else if (gameType == 'Image Match') {
          // Handle multiple images for Image Match (up to 8 images)
          for (int i = 1; i <= 8; i++) {
            String? imageUrl = data['image$i'];
            if (imageUrl != null &&
                imageUrl.isNotEmpty &&
                !imageUrl.contains(
                  'gs://lexiboost-36801.firebasestorage.app/game image',
                )) {
              try {
                debugPrint('Downloading Image Match image $i from: $imageUrl');
                final imageBytes = await _downloadImageFromUrl(imageUrl);
                if (imageBytes != null) {
                  data['image${i}Bytes'] = imageBytes;
                  debugPrint(
                    'Image Match image $i downloaded successfully, size: ${imageBytes.length} bytes',
                  );
                } else {
                  debugPrint('Image Match image $i download returned null');
                }
              } catch (e) {
                debugPrint('Failed to download Image Match image $i: $e');
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
              // Keep the imageUrl in data even if download fails
              data['imageUrl'] = imageUrl;
              
              final imageBytes = await _downloadImageFromUrl(imageUrl);
              if (imageBytes != null) {
                data['imageBytes'] = imageBytes;
                debugPrint(
                  'Image downloaded successfully, size: ${imageBytes.length} bytes',
                );
              } else {
                debugPrint(
                  'Image download returned null, will use URL directly',
                );
              }
            } catch (e) {
              debugPrint('Failed to download image: $e');
              // Keep imageUrl so it can be displayed directly
              data['imageUrl'] = imageUrl;
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

  Future<String> _uploadAudioToStorage(
    Uint8List audioBytes,
    String audioName,
  ) async {
    try {
      final storage = FirebaseStorage.instanceFor(
        bucket: 'gs://lexiboost-36801.firebasestorage.app',
      );
      final fileName =
          '${audioName}_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final path = 'gameAudio/$fileName';

      final ref = storage.ref().child(path);
      final uploadTask = await ref.putData(
        audioBytes,
        SettableMetadata(contentType: 'audio/m4a'),
      );

      final downloadUrl = await uploadTask.ref.getDownloadURL();
      debugPrint('Audio uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading audio: $e');
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
    bool isSavingInDialog = false;
    
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
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
                          color: isSavingInDialog ? Colors.grey : Colors.green,
                      onPressed: () async {
                            if (isSavingInDialog) return;
                            setDialogState(() {
                              isSavingInDialog = true;
                            });
                        _saveCurrentPageData();
                        await _saveToFirestore();
                            if (mounted) {
                              Navigator.of(context).pop();
                            }
                        _removeEventListeners();
                        await _navigateBasedOnRole();
                      },
                          child: isSavingInDialog
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Text(
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

  /// Delete a file from Firebase Storage given its URL
  Future<void> _deleteFileFromStorage(String fileUrl) async {
    if (fileUrl.isEmpty ||
        fileUrl == 'gs://lexiboost-36801.firebasestorage.app/game image' ||
        fileUrl == 'gs://lexiboost-36801.firebasestorage.app/gameAudio') {
      // Skip default/placeholder URLs
      return;
    }

    try {
      final storage = FirebaseStorage.instanceFor(
        bucket: 'gs://lexiboost-36801.firebasestorage.app',
      );

      // Extract the file path from the URL
      String filePath;
      if (fileUrl.startsWith('gs://')) {
        // Format: gs://bucket/path/to/file
        final uri = Uri.parse(fileUrl);
        filePath = uri.path.substring(1); // Remove leading '/'
      } else if (fileUrl.startsWith('https://')) {
        // Format: https://firebasestorage.googleapis.com/v0/b/bucket/o/path%2Fto%2Ffile
        final uri = Uri.parse(fileUrl);
        final pathSegments = uri.pathSegments;

        // Find the 'o' segment and get everything after it
        final oIndex = pathSegments.indexOf('o');
        if (oIndex != -1 && oIndex < pathSegments.length - 1) {
          filePath = Uri.decodeComponent(
            pathSegments.sublist(oIndex + 1).join('/'),
          );
          // Remove query parameters like ?alt=media&token=...
          filePath = filePath.split('?')[0];
        } else {
          debugPrint('Could not parse file path from URL: $fileUrl');
          return;
        }
      } else {
        debugPrint('Unknown URL format: $fileUrl');
        return;
      }

      final ref = storage.ref().child(filePath);
      await ref.delete();
      debugPrint('Successfully deleted file from Storage: $filePath');
    } catch (e) {
      debugPrint('Failed to delete file from Storage ($fileUrl): $e');
      // Don't throw - continue with other deletions
    }
  }

  /// Collect all storage URLs from a game (images and audio)
  Future<List<String>> _collectStorageUrls() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || gameId == null) return [];

    List<String> storageUrls = [];

    try {
      final gameRoundsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('created_games')
          .doc(gameId)
          .collection('game_rounds');

      final gameRoundsSnapshot = await gameRoundsRef.get();

      for (var roundDoc in gameRoundsSnapshot.docs) {
        final roundData = roundDoc.data();
        final gameType = roundData['gameType'] as String?;
        final gameTypeDocId = roundData['gameTypeDocId'] as String?;

        if (gameTypeDocId == null || gameTypeDocId.isEmpty) continue;

        // Get game_type data
        final gameTypeSnapshot = await gameRoundsRef
            .doc(roundDoc.id)
            .collection('game_type')
            .doc(gameTypeDocId)
            .get();

        if (!gameTypeSnapshot.exists) continue;

        final gameTypeData = gameTypeSnapshot.data() ?? {};

        // Collect URLs based on game type
        switch (gameType) {
          case 'Fill in the blank 2':
            // Has imageUrl field
            final imageUrl = gameTypeData['imageUrl'] as String?;
            if (imageUrl != null && imageUrl.isNotEmpty) {
              storageUrls.add(imageUrl);
            }
            break;

          case 'Guess the answer':
            // Has image field
            final image = gameTypeData['image'] as String?;
            if (image != null && image.isNotEmpty) {
              storageUrls.add(image);
            }
            break;

          case 'Guess the answer 2':
            // Has image1, image2, image3
            for (int i = 1; i <= 3; i++) {
              final imageUrl = gameTypeData['image$i'] as String?;
              if (imageUrl != null && imageUrl.isNotEmpty) {
                storageUrls.add(imageUrl);
              }
            }
            break;

          case 'What is it called':
            // Has image field
            final image = gameTypeData['image'] as String?;
            if (image != null && image.isNotEmpty) {
              storageUrls.add(image);
            }
            break;

          case 'Listen and Repeat':
            // Has audio field
            final audio = gameTypeData['audio'] as String?;
            if (audio != null && audio.isNotEmpty) {
              storageUrls.add(audio);
            }
            break;

          case 'Image Match':
            // Has image1 through image8
            for (int i = 1; i <= 8; i++) {
              final imageUrl = gameTypeData['image$i'] as String?;
              if (imageUrl != null && imageUrl.isNotEmpty) {
                storageUrls.add(imageUrl);
              }
            }
            break;

          case 'Read the sentence':
            // Read the sentence doesn't use any storage files (no images/audio)
            // No URLs to collect
            break;
        }
      }

      debugPrint('Collected ${storageUrls.length} storage URLs for deletion');
      return storageUrls;
    } catch (e) {
      debugPrint('Failed to collect storage URLs: $e');
      return storageUrls;
    }
  }

  /// Delete game from Firestore and Firebase Storage
  Future<void> _deleteGame() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('Error: User must be logged in to delete');
      return;
    }

    if (gameId == null) {
      debugPrint('Error: No game to delete');
      return;
    }

    try {
      // Step 1: Collect all storage URLs before deleting Firestore documents
      debugPrint('Collecting storage URLs for game: $gameId');
      final storageUrls = await _collectStorageUrls();

      // Step 2: Delete all files from Firebase Storage
      debugPrint('Deleting ${storageUrls.length} files from Storage...');
      for (final url in storageUrls) {
        await _deleteFileFromStorage(url);
      }

      // Step 3: Delete Firestore documents
      debugPrint('Deleting Firestore documents...');
      final gameDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('created_games')
          .doc(gameId);

      // Delete all game_type subcollection documents first
      final gameRoundsSnapshot = await gameDocRef
          .collection('game_rounds')
          .get();

      for (var roundDoc in gameRoundsSnapshot.docs) {
        // Delete game_type subcollection
        final gameTypeSnapshot = await roundDoc.reference
            .collection('game_type')
            .get();

        for (var gameTypeDoc in gameTypeSnapshot.docs) {
          await gameTypeDoc.reference.delete();
        }
        
        // Delete the round document
        await roundDoc.reference.delete();
      }

      // Delete the main game document
      await gameDocRef.delete();

      debugPrint(
        'Game deleted successfully (including ${storageUrls.length} storage files)',
      );

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
      debugPrint('Error: User must be logged in to save');
      if (mounted) {
        setState(() {
          _isSaving = false;
          _autoSaveStatus = 'Error: Not logged in';
        });
      }
      return;
    }

    // Set loading state
    if (mounted) {
      setState(() {
        _isSaving = true;
        _autoSaveStatus = 'Saving...';
      });
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
        gameData['updated_at'] = FieldValue.serverTimestamp();
        await docRef.set(gameData);

        if (mounted) {
        setState(() {
          gameId = docRef.id;
        });
        }

        debugPrint('Game created and saved successfully');
      } else {
        gameData['updated_at'] = FieldValue.serverTimestamp();

        // Use SetOptions(merge: true) to avoid overwriting existing fields
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('created_games')
            .doc(gameId)
            .set(gameData, SetOptions(merge: true));

        debugPrint('Game updated successfully');
      }

      // Save all pages to game_rounds subcollection
      await _saveGameRounds();

      // Update UI with success state
      if (mounted) {
        setState(() {
          _isSaving = false;
          _autoSaveStatus = 'All changes saved ✓';
        });

        // Clear status after 3 seconds
        Timer(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _autoSaveStatus = '';
            });
          }
        });
      }
    } catch (e) {
      debugPrint('Failed to save game: $e');
      if (mounted) {
        setState(() {
          _isSaving = false;
          _autoSaveStatus = 'Save failed - ${e.toString()}';
        });
      }
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
          'gameTypeDocId': pageData.gameTypeDocId ?? '',
        };

        String roundDocId;
        // If document ID exists, update it; otherwise create a new one
        if (pageData.docId != null) {
          roundDocId = pageData.docId!;
          // Use SetOptions(merge: true) to preserve existing data
          await gameRoundsRef
              .doc(roundDocId)
              .set(roundData, SetOptions(merge: true));
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

      // Create document reference with auto-generated ID or use existing
      DocumentReference gameTypeDocRef;
      if (pageData.gameTypeDocId != null &&
          pageData.gameTypeDocId!.isNotEmpty) {
        // Use existing document ID
        gameTypeDocRef = gameTypeRef.doc(pageData.gameTypeDocId);
      } else {
        // Create new auto-generated document
        gameTypeDocRef = gameTypeRef.doc(); // Auto-generated ID
        // Store the ID back to pageData
        pageData.gameTypeDocId = gameTypeDocRef.id;
        // Also update the pages list
        pages[pages.indexOf(pageData)].gameTypeDocId = gameTypeDocRef.id;
      }

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
        // Upload image if new bytes exist, otherwise use existing URL
        String? imageUrl = pageData.imageUrl;
        if (pageData.selectedImageBytes != null) {
          try {
            debugPrint('Uploading new image for Fill the blank 2...');
            imageUrl = await _uploadImageToStorage(
              pageData.selectedImageBytes!,
              'fill_the_blank2',
            );
            // Update the page data with the new URL
            pages[pages.indexOf(pageData)].imageUrl = imageUrl;
            debugPrint('Image uploaded successfully: $imageUrl');
          } catch (e) {
            debugPrint('Failed to upload image for Fill the blank 2: $e');
          }
        } else {
          debugPrint('Using existing imageUrl: $imageUrl');
        }
        
        gameTypeData.addAll({
          'answer': pageData.visibleLetters,
          'gameHint': pageData.hint,
          'answerText': pageData.answer,
          'imageUrl': imageUrl ?? '',
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
        debugPrint('Saving Read the sentence data: "${pageData.readSentence}"');
        gameTypeData.addAll({'sentence': pageData.readSentence});
      } else if (pageData.gameType == 'What is it called') {
        debugPrint(
          'Saving What is it called data: readSentence="${pageData.readSentence}", hint="${pageData.hint}"',
        );
        debugPrint(
          'What is it called imageBytes is null: ${pageData.whatCalledImageBytes == null}',
        );
        debugPrint(
          'What is it called imageUrl: ${pageData.whatCalledImageUrl}',
        );
        
        // Upload image if new bytes exist, otherwise use existing URL
        String? imageUrl = pageData.whatCalledImageUrl;
        if (pageData.whatCalledImageBytes != null) {
          try {
            debugPrint('Uploading new image for What is it called...');
            imageUrl = await _uploadImageToStorage(
              pageData.whatCalledImageBytes!,
              'what_called_image',
            );
            pageData.whatCalledImageUrl = imageUrl;
            debugPrint(
              'What is it called image uploaded successfully: $imageUrl',
            );
          } catch (e) {
            debugPrint('Failed to upload image for What is it called: $e');
          }
        } else {
          debugPrint(
            'Using existing imageUrl for What is it called: $imageUrl',
          );
        }
        
        gameTypeData.addAll({
          'answer': pageData.readSentence, // The answer text
          'image':
              imageUrl ?? 'gs://lexiboost-36801.firebasestorage.app/game image',
          'imageUrl':
              imageUrl ??
              'gs://lexiboost-36801.firebasestorage.app/game image', // Add imageUrl for consistency
          'gameHint': pageData.hint, // The game hint
          'createdAt': FieldValue.serverTimestamp(),
          'gameType': 'what_called',
        });
      } else if (pageData.gameType == 'Listen and Repeat') {
        // Upload audio file if audio path exists
        print(
          "Listen and Repeat - Audio path: ${pageData.listenAndRepeatAudioPath}, Answer: ${pageData.listenAndRepeat}",
        );
        String? audioUrl;
        if (pageData.listenAndRepeatAudioBytes != null &&
            pageData.listenAndRepeatAudioBytes!.isNotEmpty) {
          try {
            print(
              "Uploading audio bytes: ${pageData.listenAndRepeatAudioBytes!.length} bytes",
            );
            audioUrl = await _uploadAudioToStorage(
              pageData.listenAndRepeatAudioBytes!,
              'listen_and_repeat_audio',
            );
            pageData.listenAndRepeatAudioUrl = audioUrl;
            print("Audio uploaded successfully: $audioUrl");
          } catch (e) {
            debugPrint('Failed to upload audio for Listen and Repeat: $e');
            print("Error details: $e");
          }
        } else if (pageData.listenAndRepeatAudioPath != null) {
          // Fallback: try to read from file path if bytes are not available
          try {
            print(
              "Attempting to read audio file: ${pageData.listenAndRepeatAudioPath}",
            );
            final audioFile = File(pageData.listenAndRepeatAudioPath!);
            if (await audioFile.exists()) {
              print("Audio file exists, reading bytes...");
              final audioBytes = await audioFile.readAsBytes();
              print("Audio bytes read: ${audioBytes.length} bytes");
              audioUrl = await _uploadAudioToStorage(
                audioBytes,
                'listen_and_repeat_audio',
              );
              pageData.listenAndRepeatAudioUrl = audioUrl;
              print("Audio uploaded successfully: $audioUrl");
            } else {
              print(
                "Audio file does not exist at path: ${pageData.listenAndRepeatAudioPath}",
              );
            }
          } catch (e) {
            debugPrint('Failed to upload audio for Listen and Repeat: $e');
            print("Error details: $e");
          }
        } else {
          print("No audio data provided for Listen and Repeat");
          // Set a default placeholder URL if no audio is available
          audioUrl = 'gs://lexiboost-36801.firebasestorage.app/gameAudio';
        }

        gameTypeData.addAll({
          'audio':
              audioUrl ?? 'gs://lexiboost-36801.firebasestorage.app/gameAudio',
          'answer':
              pageData.listenAndRepeat, // The answer text from the textfield
          'createdAt': FieldValue.serverTimestamp(),
          'gameType': 'listen_and_repeat',
        });
      } else if (pageData.gameType == 'Image Match') {
        // Upload images for odd positions (1, 3, 5, 7) and store match data
        Map<String, dynamic> imageMatchData = {
          'imageCount': pageData.imageMatchCount,
          'image_configuration':
              pageData.imageMatchCount, // Configuration number
        };

        // Upload images for all positions (1, 2, 3, 4, 5, 6, 7, 8) if they exist
        for (int i = 0; i < pageData.imageMatchImages.length; i++) {
          if (pageData.imageMatchImages[i] != null) {
            try {
              final imageUrl = await _uploadImageToStorage(
                pageData.imageMatchImages[i]!,
                'image_match_${i + 1}',
              );
              imageMatchData['image${i + 1}'] = imageUrl;
            } catch (e) {
              debugPrint('Failed to upload image ${i + 1} for Image Match: $e');
              imageMatchData['image${i + 1}'] =
                  'gs://lexiboost-36801.firebasestorage.app/game image';
            }
          } else {
            imageMatchData['image${i + 1}'] =
                'gs://lexiboost-36801.firebasestorage.app/game image';
          }
        }

        // Add match data only for odd positions (1, 3, 5, 7)
        // These are the positions that can be matched to even positions (2, 4, 6, 8)
        for (int i = 1; i <= 7; i += 2) {
          imageMatchData['image_match$i'] = 0; // Default match value
        }

        gameTypeData.addAll(imageMatchData);
      } else if (pageData.gameType == 'Math') {
        // Use saved Math data from PageData
        if (pageData.mathData != null) {
          Map<String, dynamic> mathData = Map.from(pageData.mathData!);
          
          // Ensure all operators are filled (operator1_2 through operator9_10)
          for (int i = 1; i < 10; i++) {
            final operatorKey = 'operator${i}_${i + 1}';
            if (!mathData.containsKey(operatorKey)) {
              mathData[operatorKey] = '';
            }
          }
          
          // Ensure all boxes are filled (box1 through box10)
          for (int i = 1; i <= 10; i++) {
            final boxKey = 'box$i';
            if (!mathData.containsKey(boxKey)) {
              mathData[boxKey] = 0;
            }
        }

        gameTypeData.addAll(mathData);
        } else {
          // Fallback: use default empty Math data
          gameTypeData.addAll({'totalBoxes': 1, 'answer': 0, 'box1': 0});

          for (int i = 1; i < 10; i++) {
            gameTypeData['operator${i}_${i + 1}'] = '';
          }
          for (int i = 2; i <= 10; i++) {
            gameTypeData['box$i'] = 0;
          }
        }
      }

      await gameTypeDocRef.set(gameTypeData, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to save game type data: $e');
    }
  }

  @override
  void dispose() {
    _removeEventListeners();
    _debounceTimer?.cancel();
    _autoSaveTimer?.cancel();
    _idleTimer?.cancel();
    titleController.removeListener(_onTitleChanged);
    titleController.dispose();
    descriptionController.removeListener(_triggerAutoSave);
    descriptionController.dispose();
    descriptionFieldController.removeListener(_triggerAutoSave);
    descriptionFieldController.dispose();
    answerController.removeListener(_syncVisibleLetters);
    answerController.removeListener(_triggerAutoSave);
    answerController.dispose();
    readSentenceController.removeListener(_triggerAutoSave);
    readSentenceController.dispose();
    listenAndRepeatController.removeListener(_triggerAutoSave);
    listenAndRepeatController.dispose();
    prizeCoinsController.dispose();
    gameCodeController.removeListener(_triggerAutoSave);
    gameCodeController.dispose();
    hintController.removeListener(_triggerAutoSave);
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
                          _onUserInteraction();
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
                          _onUserInteraction();
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
                              _onUserInteraction();
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

                  // Auto-save status indicator
                  if (_autoSaveStatus.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Icon(
                            _autoSaveStatus.contains('✓')
                                ? Icons.check_circle
                                : _autoSaveStatus.contains('Saving')
                                ? Icons.sync
                                : Icons.edit_note,
                            color: _autoSaveStatus.contains('✓')
                                ? Colors.green
                                : Colors.orange,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _autoSaveStatus,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: _autoSaveStatus.contains('✓')
                                    ? Colors.green
                                    : Colors.orange,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          // Show idle status indicator
                          if (_hasUserInteracted)
                            Icon(
                              _isIdle ? Icons.pause_circle : Icons.play_circle,
                              color: _isIdle ? Colors.blue : Colors.orange,
                              size: 16,
                            ),
                        ],
                      ),
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
                          color: _isSaving ? Colors.grey : Colors.green,
                          onPressed: () async {
                            if (_isSaving) return;
                            _saveCurrentPageData();
                            await _saveToFirestore();
                          },
                          child: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Text(
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
                                          imageUrl:
                                              pages[currentPageIndex].imageUrl,
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
                                          imageUrl:
                                              pages[currentPageIndex].imageUrl,
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
                                          imageUrls: pages[currentPageIndex]
                                              .guessAnswerImageUrls,
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
                                          imageUrl: pages[currentPageIndex]
                                              .whatCalledImageUrl,
                                        )
                                      : selectedGameType == 'Listen and Repeat'
                                      ? MyListenAndRepeat(
                                          sentenceController:
                                              listenAndRepeatController,
                                          audioPath: listenAndRepeatAudioPath,
                                          audioSource:
                                              listenAndRepeatAudioSource,
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
                                    color: _isSaving
                                        ? Colors.grey
                                        : Colors.green,
                                    onPressed: () async {
                                      if (_isSaving) return;
                                      _saveCurrentPageData();
                                      await _saveToFirestore();
                                    },
                                    child: _isSaving
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 3,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    Colors.white,
                                                  ),
                                            ),
                                          )
                                        : Text(
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
                                _onUserInteraction();
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
                          // Trigger auto-save when image is picked
                          _onUserInteraction();
                        },
                      )
                    else if (selectedGameType == 'Guess the answer')
                      MyFillInTheBlank3Settings(
                        hintController: hintController,
                        questionController: descriptionFieldController,
                        visibleLetters: visibleLetters,
                        initialChoices: multipleChoices,
                        initialCorrectIndex: correctAnswerIndex,
                        onToggle: _toggleLetter,
                        onImagePicked: (Uint8List imageBytes) {
                          setState(() {
                            selectedImageBytes = imageBytes;
                          });
                          _onUserInteraction();
                        },
                        onChoicesChanged: (List<String> choices) {
                          setState(() {
                            multipleChoices = choices;
                          });
                          _onUserInteraction();
                        },
                        onCorrectAnswerSelected: (int index) {
                          setState(() {
                            correctAnswerIndex = index;
                          });
                          _onUserInteraction();
                        },
                      )
                    else if (selectedGameType == 'Guess the answer 2')
                      MyGuessTheAnswerSettings(
                        hintController: hintController,
                        questionController: descriptionFieldController,
                        visibleLetters: visibleLetters,
                        initialChoices: multipleChoices,
                        initialCorrectIndex: correctAnswerIndex,
                        onToggle: _toggleLetter,
                        onImagePicked: (int index, Uint8List imageBytes) {
                          setState(() {
                            guessAnswerImages[index] = imageBytes;
                          });
                          _onUserInteraction();
                        },
                        onChoicesChanged: (List<String> choices) {
                          setState(() {
                            multipleChoices = choices;
                          });
                          _onUserInteraction();
                        },
                        onCorrectAnswerSelected: (int index) {
                          setState(() {
                            correctAnswerIndex = index;
                          });
                          _onUserInteraction();
                        },
                      )
                    else if (selectedGameType == 'Read the sentence')
                      MyReadTheSentenceSettings(
                        sentenceController: readSentenceController,
                      )
                    else if (selectedGameType == 'What is it called')
                      MyWhatItIsCalledSettings(
                        sentenceController: readSentenceController,
                        hintController: hintController,
                        onImagePicked: (Uint8List imageBytes) {
                          setState(() {
                            whatCalledImageBytes = imageBytes;
                          });
                          _onUserInteraction();
                        },
                      )
                    else if (selectedGameType == 'Listen and Repeat')
                      MyListenAndRepeatSettings(
                        sentenceController: listenAndRepeatController,
                        onAudioChanged:
                            (
                              String? audioPath,
                              String audioSource,
                              Uint8List? audioBytes,
                            ) {
                              print(
                                "Audio changed callback received: path=$audioPath, source=$audioSource, bytes=${audioBytes?.length}",
                              );
                              setState(() {
                                listenAndRepeatAudioPath = audioPath;
                                listenAndRepeatAudioSource = audioSource;
                                listenAndRepeatAudioBytes = audioBytes;
                              });
                              // Save the current page data immediately when audio changes
                              _saveCurrentPageData();
                              _onUserInteraction();
                            },
                      )
                    else if (selectedGameType == 'Image Match')
                      MyImageMatchSettings(
                        onImagePicked: (int index, Uint8List imageBytes) {
                          setState(() {
                            imageMatchImages[index] = imageBytes;
                          });
                          _onUserInteraction();
                        },
                        onCountChanged: (int newCount) {
                          setState(() {
                            imageMatchCount = newCount;
                          });
                          _onUserInteraction();
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
