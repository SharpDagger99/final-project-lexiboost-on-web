// ===== game_edit.dart =====

// ignore_for_file: deprecated_member_use, use_build_context_synchronously, avoid_web_libraries_in_flutter, avoid_print, unnecessary_import

import 'dart:async';
import 'dart:html' as html;
import 'dart:io';
import 'dart:typed_data';
import 'package:animated_button/animated_button.dart';
import 'package:flutter/gestures.dart';
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
  String? gameTypeDocId; // Firestore document ID for the game_type document
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
  
  // Math data
  int mathTotalBoxes; // Total number of boxes
  List<String> mathBoxValues; // Values in each box
  List<String> mathOperators; // Operators between boxes
  String mathAnswer; // The calculated result

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
    this.mathTotalBoxes = 1,
    this.mathBoxValues = const [],
    this.mathOperators = const [],
    this.mathAnswer = '0',
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

class _MyGameEditState extends State<MyGameEdit> with WidgetsBindingObserver {
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
  final TextEditingController timerMinutesController = TextEditingController();
  final TextEditingController timerSecondsController = TextEditingController();
  
  // Scroll controller for page selector
  final ScrollController _pageSelectorScrollController = ScrollController();

  double progressValue = 0.1;
  String selectedGameType = 'Fill in the blank';
  String selectedDifficulty = 'easy';
  String selectedGameRule = 'none';
  String selectedGameSet = 'public';
  
  // Game Rules Configuration
  bool heartEnabled = false;
  int timerSeconds = 0;
  Map<int, int> pageScores = {}; // Map of page index to score

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
  String _autoSaveStatus = ''; // Auto-save status message
  bool _isLoading = false; // Loading state indicator
  bool _isSaving = false; // Save button loading state
  bool _showSaveSuccess = false; // Show save success message
  bool _showValidationError = false; // Show validation error message
  String _validationErrorMessage = ''; // Validation error message text
  bool _autoSaveEnabled = true; // Auto-save setting from user preferences
  final SettingsService _settingsService = SettingsService();

  final mathState = MathState();

  // Image cache to reduce Firebase reads
  static final Map<String, Uint8List> _imageCache = {};

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

    // Set up browser event listeners
    _setupBrowserEventListeners();

    // Add observer for app lifecycle changes
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAutoSaveSettings();
      _initializeGameEditor();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Refresh auto-save settings when app becomes active
      _refreshAutoSaveSettings();
    }
  }

  /// Load auto-save settings from user preferences
  Future<void> _loadAutoSaveSettings() async {
    try {
      _autoSaveEnabled = await _settingsService.getAutoSaveEnabled();
      debugPrint('Auto-save setting loaded: $_autoSaveEnabled');

      if (mounted) {
        setState(() {
          // Update UI to reflect the current auto-save status
          if (!_autoSaveEnabled) {
            _autoSaveStatus = 'Auto-save disabled in settings';
          }
        });
      }
    } catch (e) {
      debugPrint('Failed to load auto-save settings: $e');
      // Default to enabled if loading fails
      _autoSaveEnabled = true;
    }
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

  /// Validate all pages for required data
  Map<int, String> _validatePages() {
    Map<int, String> errors = {};

    for (int i = 0; i < pages.length; i++) {
      final page = pages[i];

      // Validate Image Match
      if (page.gameType == 'Image Match') {
        int requiredImageCount = page.imageMatchCount;
        int filledImageCount = 0;

        for (int j = 0; j < requiredImageCount; j++) {
          if (page.imageMatchImages[j] != null) {
            filledImageCount++;
          }
        }

        if (filledImageCount > 0 && filledImageCount < requiredImageCount) {
          errors[i] =
              'Image Match: ${requiredImageCount - filledImageCount} image(s) missing';
        }
      }
    }

    return errors;
  }

  /// Trigger auto-save when any field changes
  void _triggerAutoSave() {
    _autoSaveTimer?.cancel();

    // Show "Unsaved changes" status
    if (mounted) {
      setState(() {
        if (!_autoSaveEnabled) {
          _autoSaveStatus = 'Auto-save disabled - unsaved changes';
        } else {
          _autoSaveStatus = 'Unsaved changes...';
        }
      });
    }

    // Only proceed with auto-save if it's enabled
    if (!_autoSaveEnabled) {
      debugPrint('Auto-save is disabled in settings - skipping auto-save');
      return;
    }

    _autoSaveTimer = Timer(const Duration(seconds: 3), () async {
      // Only auto-save if gameId exists (game has been created)
      if (gameId != null) {
        debugPrint('Auto-saving game data...');
        if (mounted) {
          setState(() {
            _autoSaveStatus = 'Saving...';
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
    });
  }

  void _toggleLetter(int index) {
    setState(() {
      visibleLetters[index] = !visibleLetters[index];
    });
    // Trigger auto-save when letter visibility changes
    _triggerAutoSave();
  }

  void _saveCurrentPageData() {
    debugPrint(
      "Saving page data - Audio path: $listenAndRepeatAudioPath, Source: $listenAndRepeatAudioSource",
    );

    // Preserve existing imageUrl if no new image bytes
    String? preservedImageUrl = pages[currentPageIndex].imageUrl;
    if (selectedImageBytes != null) {
      // New image uploaded, imageUrl will be updated on save
      preservedImageUrl = null;
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
          .gameTypeDocId, // Preserve the game type document ID
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
      mathTotalBoxes: mathState.totalBoxes,
      mathBoxValues: mathState.boxControllers.map((c) => c.text).toList(),
      mathOperators: List.from(mathState.operators),
      mathAnswer: mathState.resultController.text,
    );
  }

  void _loadPageData(int pageIndex) {
    final pageData = pages[pageIndex];

    debugPrint('========== Loading Page Data ==========');
    debugPrint('Loading page $pageIndex with gameType: ${pageData.gameType}');
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
      
      // Debug Image Match loading
      if (pageData.gameType == 'Image Match') {
        debugPrint('Loading Image Match page with count: $imageMatchCount');
        for (int i = 0; i < imageMatchImages.length; i++) {
          if (imageMatchImages[i] != null) {
            debugPrint(
              'Image Match image $i loaded: ${imageMatchImages[i]!.length} bytes',
            );
          }
        }
      }
      
      listenAndRepeatAudioPath = pageData.listenAndRepeatAudioPath;
      listenAndRepeatAudioSource = pageData.listenAndRepeatAudioSource;
      listenAndRepeatAudioBytes = pageData.listenAndRepeatAudioBytes;
      
      // Load Listen and Repeat specific data
      if (pageData.gameType == 'Listen and Repeat') {
        debugPrint(
          'Loaded Listen and Repeat audioUrl: ${pageData.listenAndRepeatAudioUrl}',
        );
        debugPrint(
          'Loaded Listen and Repeat audioBytes: ${listenAndRepeatAudioBytes != null ? '${listenAndRepeatAudioBytes!.length} bytes' : 'null'}',
        );
      }
      
      // Load correct answer index for Guess the answer and Guess the answer 2
      if (pageData.gameType == 'Guess the answer' ||
          pageData.gameType == 'Guess the answer 2') {
        correctAnswerIndex = pageData.correctAnswerIndex >= 0
            ? pageData.correctAnswerIndex
            : 0;
      }

      // Load What is it called specific data
      if (pageData.gameType == 'What is it called') {
        whatCalledImageBytes = pageData.selectedImageBytes;
        debugPrint(
          'Loaded What is it called imageUrl: ${pageData.whatCalledImageUrl}',
        );
        debugPrint(
          'Loaded What is it called imageBytes: ${whatCalledImageBytes != null ? '${whatCalledImageBytes!.length} bytes' : 'null'}',
        );
      }
      
      // Load Math specific data
      if (pageData.gameType == 'Math') {
        debugPrint(
          'Loading Math page with totalBoxes: ${pageData.mathTotalBoxes}',
        );

        // Set totalBoxes and rebuild controllers
        while (mathState.totalBoxes < pageData.mathTotalBoxes) {
          mathState.increment();
        }
        while (mathState.totalBoxes > pageData.mathTotalBoxes) {
          mathState.decrement();
        }

        // Set box values
        for (
          int i = 0;
          i < pageData.mathBoxValues.length &&
              i < mathState.boxControllers.length;
          i++
        ) {
          mathState.boxControllers[i].text = pageData.mathBoxValues[i];
        }

        // Set operators
        for (
          int i = 0;
          i < pageData.mathOperators.length && i < mathState.operators.length;
          i++
        ) {
          while (mathState.operators[i] != pageData.mathOperators[i]) {
            mathState.cycleOperator(i);
          }
        }

        debugPrint('Math page loaded successfully');
      }

      progressValue = (pageIndex + 1) / pages.length;
      
      debugPrint(
        'After setState, selectedImageBytes is null: ${selectedImageBytes == null}',
      );
      debugPrint('ImageUrl preserved: ${pageData.imageUrl}');
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
    // Get validation errors for all pages
    final validationErrors = _validatePages();
    
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
                  child: Scrollbar(
                    controller: _pageSelectorScrollController,
                    thumbVisibility: true,
                    trackVisibility: true,
                    thickness: 8,
                    radius: const Radius.circular(10),
                    child: GestureDetector(
                      onPanUpdate: (details) {
                        // Drag to scroll functionality
                        _pageSelectorScrollController.position.moveTo(
                          _pageSelectorScrollController.offset -
                              details.delta.dy,
                        );
                      },
                      child: ListView.builder(
                        controller: _pageSelectorScrollController,
                        shrinkWrap: true,
                        itemCount: pages.length,
                        itemBuilder: (context, index) {
                        final isCurrentPage = index == currentPageIndex;
                        final hasError = validationErrors.containsKey(index);
                        
                        return Container(
                          margin: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 4,
                          ),
                            child: Row(
                              children: [
                                // Page button section
                                Expanded(
                                  flex: selectedGameRule == 'score' ? 3 : 1,
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
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Row(
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
                                            if (hasError) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.red,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.error,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                              ),
                                            ],
                                            if (selectedGameRule != 'score' &&
                                                pages[index].title.isNotEmpty)
                                              Flexible(
                                                child: Text(
                                                  pages[index].title,
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 14,
                                                    color: Colors.white70,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
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
                                ),
                                // Score text field section (separate from page button)
                                if (selectedGameRule == 'score') ...[
                                const SizedBox(width: 10),
                                Expanded(
                                    flex: 1,
                                    child: Container(
                                      height:
                                          48, // Match page button height (12*2 + 24 for text)
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF3A3C3A),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.2),
                                        ),
                                      ),
                                      child: Center(
                                        child: TextField(
                                          controller: TextEditingController(
                                            text:
                                                pageScores[index]?.toString() ??
                                                '',
                                          ),
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly,
                                            LengthLimitingTextInputFormatter(4),
                                          ],
                                          textAlign: TextAlign.center,
                                          textAlignVertical:
                                              TextAlignVertical.center,
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          decoration: InputDecoration(
                                            hintText: "Score",
                                            hintStyle: GoogleFonts.poppins(
                                              color: Colors.white54,
                                              fontSize: 14,
                                            ),
                                            border: InputBorder.none,
                                            contentPadding: EdgeInsets.zero,
                                            isDense: true,
                                          ),
                                          onChanged: (value) {
                                            setState(() {
                                              if (value.isEmpty) {
                                                pageScores.remove(index);
                                              } else {
                                                pageScores[index] =
                                                    int.tryParse(value) ?? 0;
                                              }
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
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

  /// Refresh auto-save settings (call this when returning to the editor)
  Future<void> _refreshAutoSaveSettings() async {
    try {
      final newAutoSaveEnabled = await _settingsService.getAutoSaveEnabled();
      if (newAutoSaveEnabled != _autoSaveEnabled) {
        _autoSaveEnabled = newAutoSaveEnabled;
        debugPrint('Auto-save setting refreshed: $_autoSaveEnabled');

        if (mounted) {
          setState(() {
            if (!_autoSaveEnabled) {
              _autoSaveStatus = 'Auto-save disabled in settings';
            } else {
              _autoSaveStatus = '';
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Failed to refresh auto-save settings: $e');
    }
  }

  /// Enhanced game editor initialization with multiple fallback mechanisms
  Future<void> _initializeGameEditor() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Priority 1: Try Get.arguments first (normal navigation)
      final args = Get.arguments;
      if (args != null && args['gameId'] != null) {
        gameId = args['gameId'] as String;
        debugPrint('GameId from Get.arguments: $gameId');
        await _loadFromFirestore(gameId!);
        return;
      }

      // Priority 2: Try URL parameters
      final urlGameId = _getGameIdFromUrl();
      if (urlGameId != null && urlGameId.isNotEmpty) {
        gameId = urlGameId;
        debugPrint('GameId from URL: $gameId');
        await _loadFromFirestore(gameId!);
        return;
      }

      // Priority 3: Try session storage
      final sessionGameId = await _getGameIdFromSession();
      if (sessionGameId != null && sessionGameId.isNotEmpty) {
        gameId = sessionGameId;
        debugPrint('GameId from session storage: $gameId');
        await _loadFromFirestore(gameId!);
        return;
      }

      // Priority 4: Fallback to most recent game
      debugPrint('No gameId found, loading most recent game...');
      await _handleBrowserReload();
    } catch (e) {
      debugPrint('Failed to initialize game editor: $e');
      _showLoadingError('Failed to load game data. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Extract gameId from URL query parameters
  String? _getGameIdFromUrl() {
    try {
      final uri = Uri.parse(html.window.location.href);
      return uri.queryParameters['gameId'];
    } catch (e) {
      debugPrint('Failed to parse URL: $e');
      return null;
    }
  }

  /// Save gameId to browser session storage
  Future<void> _saveGameIdToSession(String gameId) async {
    try {
      html.window.sessionStorage['currentGameId'] = gameId;
      debugPrint('GameId saved to session storage: $gameId');
    } catch (e) {
      debugPrint('Failed to save gameId to session storage: $e');
    }
  }

  /// Get gameId from browser session storage
  Future<String?> _getGameIdFromSession() async {
    try {
      final gameId = html.window.sessionStorage['currentGameId'];
      debugPrint('GameId from session storage: $gameId');
      return gameId;
    } catch (e) {
      debugPrint('Failed to get gameId from session storage: $e');
      return null;
    }
  }

  /// Update URL with gameId for bookmarking
  void _updateUrlWithGameId(String gameId) {
    try {
      final uri = Uri.parse(html.window.location.href);
      final newUri = uri.replace(
        queryParameters: {...uri.queryParameters, 'gameId': gameId},
      );
      html.window.history.replaceState(null, '', newUri.toString());
      debugPrint('URL updated with gameId: $gameId');
    } catch (e) {
      debugPrint('Failed to update URL: $e');
    }
  }

  /// Show loading error to user
  void _showLoadingError(String message) {
    debugPrint('Loading Error: $message');
  }

  /// Debug method to test data loading - call this from console
  void debugTestDataLoading() {
    debugPrint('=== DEBUG: Current Page Data ===');
    if (pages.isNotEmpty) {
      final currentPage = pages[currentPageIndex];
      debugPrint('Current Page Index: $currentPageIndex');
      debugPrint('Game Type: ${currentPage.gameType}');
      debugPrint('Answer: ${currentPage.answer}');
      debugPrint('Description Field: ${currentPage.descriptionField}');
      debugPrint('Read Sentence: ${currentPage.readSentence}');
      debugPrint('Listen and Repeat: ${currentPage.listenAndRepeat}');
      debugPrint('Visible Letters: ${currentPage.visibleLetters}');
      debugPrint('Multiple Choices: ${currentPage.multipleChoices}');
      debugPrint('Hint: ${currentPage.hint}');
      debugPrint('Correct Answer Index: ${currentPage.correctAnswerIndex}');
      debugPrint('Image URL: ${currentPage.imageUrl}');
      debugPrint('Doc ID: ${currentPage.docId}');
    } else {
      debugPrint('No pages loaded');
    }
    debugPrint('===============================');
  }

  /// Comprehensive debug method to check Firestore data structure
  Future<void> debugFirestoreStructure() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || gameId == null) {
      debugPrint('❌ Cannot debug: user or gameId is null');
      return;
    }

    try {
      debugPrint('=== FIRESTORE STRUCTURE DEBUG ===');
      debugPrint('User ID: ${user.uid}');
      debugPrint('Game ID: $gameId');

      // Check game_rounds
      final gameRoundsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('created_games')
          .doc(gameId)
          .collection('game_rounds');
      
      final roundsSnapshot = await gameRoundsRef.get();
      debugPrint('Found ${roundsSnapshot.docs.length} game rounds');
      
      for (var roundDoc in roundsSnapshot.docs) {
        final roundData = roundDoc.data();
        debugPrint(
          'Round ${roundDoc.id}: gameType=${roundData['gameType']}, page=${roundData['page']}',
        );
        
        // Check game_type subcollection
        final gameTypeRef = gameRoundsRef
            .doc(roundDoc.id)
            .collection('game_type');
        final gameTypeSnapshot = await gameTypeRef.get();
        debugPrint(
          '  └─ Found ${gameTypeSnapshot.docs.length} game_type documents',
        );
        
        for (var gameTypeDoc in gameTypeSnapshot.docs) {
          final gameTypeData = gameTypeDoc.data();
          debugPrint(
            '    └─ Document ${gameTypeDoc.id}: gameType=${gameTypeData['gameType']}',
          );
          debugPrint('       Fields: ${gameTypeData.keys.join(', ')}');
        }
      }
      debugPrint('================================');
    } catch (e) {
      debugPrint('❌ Error debugging Firestore structure: $e');
    }
  }

  /// Handle browser reload scenario - retrieve gameId and load data
  Future<void> _handleBrowserReload() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showLoadingError('You must be logged in to load games.');
      return;
    }

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
        debugPrint('Loaded most recent game: $gameId');
        await _loadFromFirestore(gameId!);
      } else {
        _showLoadingError('No games found. Please create a new game.');
      }
    } catch (e) {
      debugPrint('Failed to handle browser reload: $e');
      _showLoadingError('Failed to load recent games. Please try again.');
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
        'heart': heartEnabled,
        'timer': timerSeconds,
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
    if (user == null) {
      _showLoadingError('You must be logged in to load games.');
      return;
    }

    try {
      debugPrint('Loading game data for ID: $id');

      // Save gameId to session storage and update URL
      await _saveGameIdToSession(id);
      _updateUrlWithGameId(id);

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('created_games')
          .doc(id)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        debugPrint('Game metadata loaded successfully');
        
        setState(() {
          titleController.text = (data['title'] as String?) ?? '';
          descriptionController.text = (data['description'] as String?) ?? '';
          selectedDifficulty = (data['difficulty'] as String?) ?? 'easy';
          prizeCoinsController.text = (data['prizeCoins'] as String?) ?? '100';
          selectedGameRule = (data['gameRule'] as String?) ?? 'none';
          selectedGameSet = (data['gameSet'] as String?) ?? 'public';
          gameCodeController.text = (data['gameCode'] as String?) ?? '';
          
          // Load game rules configuration
          heartEnabled = (data['heart'] as bool?) ?? false;
          timerSeconds = (data['timer'] as int?) ?? 0;

          // Update timer controllers
          int minutes = timerSeconds ~/ 60;
          int seconds = timerSeconds % 60;
          timerMinutesController.text = minutes > 0 ? minutes.toString() : '';
          timerSecondsController.text = seconds > 0 ? seconds.toString() : '';
        });
        
        // Load game rounds data
        await _loadGameRounds();
        
        // Load page scores if score rule is selected
        if (selectedGameRule == 'score') {
          await _loadPageScores();
        }
        
        // Game loaded successfully
        debugPrint('Game loaded successfully ✓');
      } else {
        _showLoadingError('Game not found. Please check the game ID.');
      }
    } catch (e) {
      debugPrint('Failed to load game metadata: $e');
      _showLoadingError('Failed to load game data: ${e.toString()}');
    }
  }

  /// Load all game rounds from Firestore
  Future<void> _loadGameRounds() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || gameId == null) {
      debugPrint('Cannot load game rounds: user or gameId is null');
      return;
    }

    try {
      debugPrint('Loading game rounds for gameId: $gameId');
      
      final gameRoundsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('created_games')
          .doc(gameId)
          .collection('game_rounds');

      final snapshot = await gameRoundsRef.orderBy('page').get();
      debugPrint('Found ${snapshot.docs.length} game rounds');

      if (snapshot.docs.isEmpty) {
        debugPrint('No rounds saved yet, keeping default single page');
        return;
      }

      List<PageData> loadedPages = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final gameType = (data['gameType'] as String?) ?? 'Fill in the blank';
        final gameTypeDocId = data['gameTypeDocId'] as String?;
        debugPrint(
          'Loading round ${doc.id} with gameType: $gameType, gameTypeDocId: $gameTypeDocId',
        );
        
        // Load game type specific data from game_type subcollection using stored document ID
        final gameTypeData = await _loadGameTypeData(
          doc.id,
          gameType,
          gameTypeDocId,
        );
        debugPrint('Game type data loaded: ${gameTypeData.keys.join(', ')}');

        // Handle different field structures based on game type
        List<String> multipleChoices = [];
        String hint = '';
        String answer = '';
        String descriptionField = '';
        String readSentence = '';
        String listenAndRepeat = '';
        List<bool> visibleLetters = [];
        int correctAnswerIndex = -1;
        
        if (gameType == 'Fill in the blank') {
          answer = gameTypeData['answerText'] ?? '';
          hint = gameTypeData['gameHint'] ?? '';
          visibleLetters =
              gameTypeData['answer'] != null && gameTypeData['answer'] is List
              ? List<bool>.from(gameTypeData['answer'])
              : [];
        } else if (gameType == 'Fill in the blank 2') {
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
          correctAnswerIndex =
              (gameTypeData['answer'] as int?) ??
              0; // Default to 0 instead of -1
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
              (gameTypeData['correctAnswerIndex'] as int?) ??
              0; // Default to 0 instead of -1
        } else if (gameType == 'Read the sentence') {
          readSentence = gameTypeData['sentence'] ?? '';
        } else if (gameType == 'What is it called') {
          readSentence = gameTypeData['answer'] ?? '';
          hint = gameTypeData['gameHint'] ?? '';
          // Load the image URL for What is it called
          debugPrint('What is it called imageUrl: ${gameTypeData['imageUrl']}');
        } else if (gameType == 'Listen and Repeat') {
          listenAndRepeat = gameTypeData['answer'] ?? '';
          // Load the audio URL for Listen and Repeat
          debugPrint('Listen and Repeat audioUrl: ${gameTypeData['audio']}');
        } else if (gameType == 'Image Match') {
          // Image Match specific fields - images will be loaded below
          debugPrint('Image Match imageCount: ${gameTypeData['imageCount']}');
          debugPrint('Image Match URLs loaded:');
          for (int i = 1; i <= 8; i++) {
            if (gameTypeData['image$i'] != null) {
              debugPrint('  - image$i: ${gameTypeData['image$i']}');
            }
          }
        } else if (gameType == 'Math') {
          // Math specific fields - will be loaded into MathState when page is displayed
          debugPrint('Math totalBoxes: ${gameTypeData['totalBoxes']}');
          debugPrint('Math answer: ${gameTypeData['answer']}');
          for (int i = 1; i <= 10; i++) {
            if (gameTypeData['box$i'] != null) {
              debugPrint('  - box$i: ${gameTypeData['box$i']}');
            }
          }
        }

        // Debug print the loaded data for this game type
        debugPrint('=== LOADED DATA FOR $gameType ===');
        debugPrint('Answer: $answer');
        debugPrint('Description Field: $descriptionField');
        debugPrint('Read Sentence: $readSentence');
        debugPrint('Listen and Repeat: $listenAndRepeat');
        debugPrint('Visible Letters: $visibleLetters');
        debugPrint('Multiple Choices: $multipleChoices');
        debugPrint('Hint: $hint');
        debugPrint('Correct Answer Index: $correctAnswerIndex');
        debugPrint(
          'Image URL: ${gameTypeData['imageUrl'] ?? gameTypeData['image']}',
        );
        if (gameType == 'Guess the answer') {
          debugPrint('Guess the answer specific data:');
          debugPrint('  - multipleChoice1: ${gameTypeData['multipleChoice1']}');
          debugPrint('  - multipleChoice2: ${gameTypeData['multipleChoice2']}');
          debugPrint('  - multipleChoice3: ${gameTypeData['multipleChoice3']}');
          debugPrint('  - multipleChoice4: ${gameTypeData['multipleChoice4']}');
          debugPrint('  - answer (correct index): ${gameTypeData['answer']}');
        } else if (gameType == 'Guess the answer 2') {
          debugPrint('Guess the answer 2 specific data:');
          debugPrint('  - multipleChoice1: ${gameTypeData['multipleChoice1']}');
          debugPrint('  - multipleChoice2: ${gameTypeData['multipleChoice2']}');
          debugPrint('  - multipleChoice3: ${gameTypeData['multipleChoice3']}');
          debugPrint('  - multipleChoice4: ${gameTypeData['multipleChoice4']}');
          debugPrint(
            '  - correctAnswerIndex: ${gameTypeData['correctAnswerIndex']}',
          );
          debugPrint('  - image1: ${gameTypeData['image1']}');
          debugPrint('  - image2: ${gameTypeData['image2']}');
          debugPrint('  - image3: ${gameTypeData['image3']}');
        }
        debugPrint('================================');
        
        loadedPages.add(
          PageData(
            gameType: gameType,
            answer: answer,
            descriptionField: descriptionField,
            readSentence: readSentence,
            listenAndRepeat: listenAndRepeat,
            visibleLetters: visibleLetters,
            multipleChoices: multipleChoices,
            imageMatchCount: gameTypeData['imageCount'] ?? 2,
            hint: hint,
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
            correctAnswerIndex: correctAnswerIndex,
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
        // Start at the last page instead of the first
        currentPageIndex = pages.length - 1;
        if (pages.isNotEmpty) {
          _loadPageData(currentPageIndex);
        }
      });
    } catch (e) {
      debugPrint('Failed to load game rounds: $e');
      _showLoadingError('Failed to load game activities: ${e.toString()}');
    }
  }

  /// Load specific game type data from game_type subcollection
  Future<Map<String, dynamic>> _loadGameTypeData(
    String roundDocId,
    String gameType,
    String? gameTypeDocId,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || gameId == null) {
      debugPrint('Cannot load game type data: user or gameId is null');
      return {};
    }

    try {
      debugPrint(
        'Loading game type data for round: $roundDocId, type: $gameType, gameTypeDocId: $gameTypeDocId',
      );
      
      final gameTypeRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('created_games')
          .doc(gameId)
          .collection('game_rounds')
          .doc(roundDocId)
          .collection('game_type');

      Map<String, dynamic> data = {};

      // Use the stored gameTypeDocId if available
      if (gameTypeDocId != null && gameTypeDocId.isNotEmpty) {
        debugPrint(
          'Loading document with stored gameTypeDocId: $gameTypeDocId',
        );
        final docSnapshot = await gameTypeRef.doc(gameTypeDocId).get();
        if (docSnapshot.exists) {
          data = docSnapshot.data()!;
          debugPrint('✅ Found document using stored gameTypeDocId');
        } else {
          debugPrint('❌ Document with stored gameTypeDocId not found');
        }
      } else {
        debugPrint(
          '⚠️ No stored gameTypeDocId found, trying fallback approaches',
        );
        
        // Fallback: Try to find any document in the game_type subcollection
        final snapshot = await gameTypeRef.get();
        debugPrint(
          'Found ${snapshot.docs.length} documents in game_type subcollection',
        );
        
        if (snapshot.docs.isNotEmpty) {
          data = snapshot.docs.first.data();
          debugPrint(
            '⚠️ Using fallback approach with first document: ${snapshot.docs.first.id}',
          );
        }
      }

      if (data.isEmpty) {
        debugPrint(
          '❌ No game type data found for round: $roundDocId with gameType: $gameType',
        );
        return {};
      }

      debugPrint('Loaded game type data: ${data.keys.join(', ')}');

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
      } else if (gameType == 'Image Match') {
        // Handle multiple images for Image Match (up to 8 images)
        for (int i = 1; i <= 8; i++) {
          String? imageUrl = data['image$i'];
          if (imageUrl != null &&
              imageUrl.isNotEmpty &&
              !imageUrl.endsWith('game image')) {
            try {
              debugPrint('Downloading Image Match image $i from: $imageUrl');
              final imageBytes = await _downloadImageFromUrl(imageUrl);
              if (imageBytes != null) {
                data['imageMatch${i}Bytes'] = imageBytes;
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
            debugPrint('Processing image URL: $imageUrl');

            // Convert gs:// URL to downloadable URL if needed
            String? finalImageUrl = imageUrl;
            if (imageUrl.startsWith('gs://')) {
              finalImageUrl = await _convertGsUrlToDownloadUrl(imageUrl);
              if (finalImageUrl != null) {
                data['imageUrl'] =
                    finalImageUrl; // Update with downloadable URL
                debugPrint(
                  'Updated imageUrl with downloadable URL: $finalImageUrl',
                );

                // Update the Firestore document with the downloadable URL
                try {
                  await gameTypeRef.doc(gameTypeDocId).update({
                    'imageUrl': finalImageUrl,
                  });
                  debugPrint(
                    'Updated Firestore document with downloadable URL',
                  );
                } catch (e) {
                  debugPrint(
                    'Failed to update Firestore with downloadable URL: $e',
                  );
                }
              }
            }

            // Download image bytes for caching
            final imageBytes = await _downloadImageFromUrl(
              finalImageUrl ?? imageUrl,
            );
            if (imageBytes != null) {
              data['imageBytes'] = imageBytes;
              debugPrint(
                'Image downloaded successfully, size: ${imageBytes.length} bytes',
              );
            } else {
              debugPrint('Image download returned null, will use URL directly');
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

      // Handle audio URL for Listen and Repeat
      if (gameType == 'Listen and Repeat') {
        String? audioUrl;
        if (data['audio'] != null &&
            data['audio'] is String &&
            (data['audio'] as String).isNotEmpty) {
          audioUrl = data['audio'];
        }

        if (audioUrl != null) {
          try {
            debugPrint('Processing audio URL: $audioUrl');

            // Convert gs:// URL to downloadable URL if needed
            String? finalAudioUrl = audioUrl;
            if (audioUrl.startsWith('gs://')) {
              finalAudioUrl = await _convertGsUrlToDownloadUrl(audioUrl);
              if (finalAudioUrl != null) {
                data['audio'] = finalAudioUrl; // Update with downloadable URL
                debugPrint(
                  'Updated audio URL with downloadable URL: $finalAudioUrl',
                );

                // Update the Firestore document with the downloadable URL
                try {
                  await gameTypeRef.doc(gameTypeDocId).update({
                    'audio': finalAudioUrl,
                  });
                  debugPrint(
                    'Updated Firestore document with downloadable audio URL',
                  );
                } catch (e) {
                  debugPrint(
                    'Failed to update Firestore with downloadable audio URL: $e',
                  );
                }
              }
            }

            // Download audio bytes for caching
            final audioBytes = await _downloadAudioFromUrl(
              finalAudioUrl ?? audioUrl,
            );
            if (audioBytes != null) {
              data['audioBytes'] = audioBytes;
              debugPrint(
                'Audio downloaded successfully, size: ${audioBytes.length} bytes',
              );
            } else {
              debugPrint('Audio download returned null, will use URL directly');
            }
          } catch (e) {
            debugPrint('Failed to download audio: $e');
            // Keep audioUrl so it can be used directly
            data['audio'] = audioUrl;
          }
        } else {
          debugPrint('No valid audio URL found in data');
        }
      }

      return data;
    } catch (e) {
      debugPrint('Failed to load game type data: $e');
      _showLoadingError('Failed to load game activity data: ${e.toString()}');
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

  /// Convert gs:// URL to downloadable URL
  Future<String?> _convertGsUrlToDownloadUrl(String gsUrl) async {
    try {
      if (!gsUrl.startsWith('gs://')) {
        return gsUrl; // Already a downloadable URL
      }

      // Extract the path from the gs:// URL
      final uri = Uri.parse(gsUrl);
      final path = uri.path;

      debugPrint('Converting gs:// URL to download URL: $gsUrl');
      debugPrint('Extracted path: $path');

      // Use Firebase Storage SDK to get the download URL
      final storage = FirebaseStorage.instanceFor(
        bucket: 'gs://lexiboost-36801.firebasestorage.app',
      );
      final ref = storage.ref().child(path);
      final downloadUrl = await ref.getDownloadURL();

      debugPrint('Converted to download URL: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('Error converting gs:// URL to download URL: $e');
      return gsUrl; // Return original URL if conversion fails
    }
  }

  /// Download image from URL and return as Uint8List (with caching)
  Future<Uint8List?> _downloadImageFromUrl(String imageUrl) async {
    try {
      // Check cache first
      if (_imageCache.containsKey(imageUrl)) {
        debugPrint('Image found in cache: $imageUrl');
        return _imageCache[imageUrl];
      }

      debugPrint('Downloading image from URL: $imageUrl');
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        // Cache the image
        _imageCache[imageUrl] = response.bodyBytes;
        debugPrint(
          'Image downloaded and cached: ${response.bodyBytes.length} bytes',
        );
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

  /// Download audio from URL and return as Uint8List (with caching)
  Future<Uint8List?> _downloadAudioFromUrl(String audioUrl) async {
    try {
      // Check cache first
      if (_imageCache.containsKey(audioUrl)) {
        debugPrint('Audio found in cache: $audioUrl');
        return _imageCache[audioUrl];
      }

      debugPrint('Downloading audio from URL: $audioUrl');
      final response = await http.get(Uri.parse(audioUrl));
      if (response.statusCode == 200) {
        // Cache the audio
        _imageCache[audioUrl] = response.bodyBytes;
        debugPrint(
          'Audio downloaded and cached: ${response.bodyBytes.length} bytes',
        );
        return response.bodyBytes;
      } else {
        debugPrint('Failed to download audio: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error downloading audio: $e');
      return null;
    }
  }

  /// Clear image cache (useful for memory management)
  static void clearImageCache() {
    _imageCache.clear();
    debugPrint('Image cache cleared');
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
      debugPrint('You must be logged in to delete.');
      return;
    }

    if (gameId == null) {
      debugPrint('No game to delete.');
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
      debugPrint('You must be logged in to save.');
      return;
    }

    // Validate all pages before saving
    _saveCurrentPageData();
    final validationErrors = _validatePages();
    if (validationErrors.isNotEmpty) {
      setState(() {
        _showValidationError = true;
        _validationErrorMessage =
            'You cannot save your game due to missing requirements. Please try again after you fix the problem.';
      });

      // Hide error message after 3 seconds
      Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showValidationError = false;
          });
        }
      });

      debugPrint('Validation errors found:');
      validationErrors.forEach((pageIndex, error) {
        debugPrint('  Page ${pageIndex + 1}: $error');
      });

      return;
    }

    setState(() {
      _isSaving = true;
    });

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
        'heart': heartEnabled,
        'timer': timerSeconds,
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

        setState(() {
          gameId = docRef.id;
        });

        debugPrint('Game created and saved successfully.');
      } else {
        gameData['updated_at'] = FieldValue.serverTimestamp();

        // Use SetOptions(merge: true) to avoid overwriting existing fields
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('created_games')
            .doc(gameId)
            .set(gameData, SetOptions(merge: true));

        debugPrint('Game updated successfully.');
      }

      // Save all pages to game_rounds subcollection
      await _saveGameRounds();
      
      // Save page scores if score rule is selected
      if (selectedGameRule == 'score') {
        await _savePageScores();
      }

      // Show success message
      if (mounted) {
        setState(() {
          _isSaving = false;
          _showSaveSuccess = true;
        });

        // Hide success message after 2 seconds
        Timer(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _showSaveSuccess = false;
            });
          }
        });
      }
    } catch (e) {
      debugPrint('Failed to save game: $e');
      debugPrint('Failed to save: ${e.toString()}');
      
      if (mounted) {
        setState(() {
          _isSaving = false;
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

        // Save specific game type data to game_type subcollection and get the document ID
        final gameTypeDocId = await _saveGameTypeData(roundDocId, pageData);

        // Store the game_type document ID in the round data and update the page data
        if (gameTypeDocId != null) {
          roundData['gameTypeDocId'] = gameTypeDocId;
          pages[i].gameTypeDocId = gameTypeDocId;

          // Update the round document with the gameTypeDocId
          await gameRoundsRef.doc(roundDocId).update({
            'gameTypeDocId': gameTypeDocId,
          });
        }
      }
    } catch (e) {
      debugPrint('Failed to save game rounds: $e');
    }
  }

  /// Save page scores to game_score subcollection
  Future<void> _savePageScores() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || gameId == null) return;

    try {
      final gameScoreRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('created_games')
          .doc(gameId)
          .collection('game_score');

      // Delete all existing scores first
      final existingScores = await gameScoreRef.get();
      for (var doc in existingScores.docs) {
        await doc.reference.delete();
      }

      // Save new scores
      for (var entry in pageScores.entries) {
        await gameScoreRef.add({
          'page': entry.key + 1, // Store as 1-based page number
          'score': entry.value,
        });
      }

      debugPrint('Page scores saved successfully');
    } catch (e) {
      debugPrint('Failed to save page scores: $e');
    }
  }

  /// Load page scores from game_score subcollection
  Future<void> _loadPageScores() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || gameId == null) return;

    try {
      final gameScoreRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('created_games')
          .doc(gameId)
          .collection('game_score');

      final scoresSnapshot = await gameScoreRef.get();

      setState(() {
        pageScores.clear();
        for (var doc in scoresSnapshot.docs) {
          final data = doc.data();
          final page = (data['page'] as int?) ?? 0;
          final score = (data['score'] as int?) ?? 0;
          if (page > 0) {
            pageScores[page - 1] = score; // Convert to 0-based index
          }
        }
      });

      debugPrint('Page scores loaded successfully: $pageScores');
    } catch (e) {
      debugPrint('Failed to load page scores: $e');
    }
  }

  /// Save specific game type data to game_type subcollection
  /// Returns the document ID of the created/updated game_type document
  Future<String?> _saveGameTypeData(
    String roundDocId,
    PageData pageData,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || gameId == null) return null;

    try {
      final gameTypeRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('created_games')
          .doc(gameId)
          .collection('game_rounds')
          .doc(roundDocId)
          .collection('game_type');

      // Use existing gameTypeDocId if available, otherwise create a new auto-generated one
      String gameTypeDocId;
      if (pageData.gameTypeDocId != null &&
          pageData.gameTypeDocId!.isNotEmpty) {
        gameTypeDocId = pageData.gameTypeDocId!;
        debugPrint('Using existing gameTypeDocId: $gameTypeDocId');
      } else {
        // Create new auto-generated document ID
        final docRef = gameTypeRef.doc();
        gameTypeDocId = docRef.id;
        debugPrint('Created new auto-generated gameTypeDocId: $gameTypeDocId');
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
        gameTypeData.addAll({'sentence': pageData.readSentence});
      } else if (pageData.gameType == 'What is it called') {
        // Upload image if new bytes exist, otherwise use existing URL
        String? imageUrl = pageData.whatCalledImageUrl;
        if (pageData.whatCalledImageBytes != null) {
          try {
            imageUrl = await _uploadImageToStorage(
              pageData.whatCalledImageBytes!,
              'what_called_image',
            );
            pageData.whatCalledImageUrl = imageUrl;
          } catch (e) {
            debugPrint('Failed to upload image for What is it called: $e');
          }
        }
        
        gameTypeData.addAll({
          'answer': pageData.readSentence, // The answer text
          'imageUrl': imageUrl ?? '', // Firebase Storage path/URL
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
        // Upload images for all positions (1, 2, 3, 4, 5, 6, 7, 8) and store match data
        Map<String, dynamic> imageMatchData = {
          'imageCount': pageData.imageMatchCount,
          'image_configuration':
              pageData.imageMatchCount, // Configuration number
        };

        // Upload images for all positions if new bytes exist, otherwise preserve existing URLs
        for (int i = 0; i < pageData.imageMatchImages.length; i++) {
          if (pageData.imageMatchImages[i] != null) {
            // Upload new image
            try {
              final imageUrl = await _uploadImageToStorage(
                pageData.imageMatchImages[i]!,
                'image_match_${i + 1}',
              );
              imageMatchData['image${i + 1}'] = imageUrl;
              // Update the URL in pageData for future saves
              pageData.imageMatchImageUrls[i] = imageUrl;
              debugPrint('Image Match image ${i + 1} uploaded: $imageUrl');
            } catch (e) {
              debugPrint('Failed to upload image ${i + 1} for Image Match: $e');
              // Use existing URL if available, otherwise use placeholder
              imageMatchData['image${i + 1}'] = 
                  pageData.imageMatchImageUrls[i] ?? 
                  'gs://lexiboost-36801.firebasestorage.app/game image';
            }
          } else if (pageData.imageMatchImageUrls[i] != null &&
              pageData.imageMatchImageUrls[i]!.isNotEmpty) {
            // Preserve existing URL
            imageMatchData['image${i + 1}'] = pageData.imageMatchImageUrls[i];
            debugPrint(
              'Image Match image ${i + 1} preserved: ${pageData.imageMatchImageUrls[i]}',
            );
          } else {
            // No image data
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
        // Get the math state from the current page

        Map<String, dynamic> mathData = {
          'totalBoxes': mathState.totalBoxes,
          'answer': double.tryParse(mathState.resultController.text) ?? 0,
        };

        // Add operators as individual fields (operator1_2, operator2_3, etc.)
        for (int i = 0; i < mathState.operators.length && i < 9; i++) {
          mathData['operator${i + 1}_${i + 2}'] = mathState.operators[i];
        }

        // Fill remaining operators with empty string if less than 9 operators
        for (int i = mathState.operators.length; i < 9; i++) {
          mathData['operator${i + 1}_${i + 2}'] = '';
        }

        // Add box values (box1 to box10)
        for (int i = 0; i < mathState.boxControllers.length && i < 10; i++) {
          final boxValue =
              double.tryParse(mathState.boxControllers[i].text) ?? 0;
          mathData['box${i + 1}'] = boxValue;
        }

        // Fill remaining boxes with 0 if less than 10 boxes
        for (int i = mathState.boxControllers.length; i < 10; i++) {
          mathData['box${i + 1}'] = 0;
        }

        gameTypeData.addAll(mathData);
      }

      await gameTypeRef
          .doc(gameTypeDocId)
          .set(gameTypeData, SetOptions(merge: true));
      
      debugPrint('Game type data saved with document ID: $gameTypeDocId');
      return gameTypeDocId;
    } catch (e) {
      debugPrint('Failed to save game type data: $e');
      return null;
    }
  }

  @override
  void dispose() {
    // Remove observer
    WidgetsBinding.instance.removeObserver(this);
    
    _removeEventListeners();
    _debounceTimer?.cancel();
    _autoSaveTimer?.cancel();
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
    gameCodeController.dispose();
    hintController.removeListener(_triggerAutoSave);
    hintController.dispose();
    timerMinutesController.dispose();
    timerSecondsController.dispose();
    
    // Clear image cache to free memory
    clearImageCache();
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while initializing
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF1E201E),
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

    return Scaffold(
      backgroundColor: const Color(0xFF1E201E),
      body: Stack(
        children: [
          ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: MediaQuery.of(context).size.width,
                ),
                child: IntrinsicWidth(
                  child: Padding(
                    padding: const EdgeInsets.all(30.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
            // -------- Column 1 --------
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                              Expanded(
                                child: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
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
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        child: TextField(
                                          maxLines: 4,
                                          controller: descriptionController,
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            color: Colors.black,
                                          ),
                                          decoration: InputDecoration(
                                            hintText:
                                                "Enter description here...",
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
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
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
                                            DropdownMenuItem(
                                              value: 'easy',
                                              child: Text('Easy'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'easy-normal',
                                              child: Text('Easy-Normal'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'normal',
                                              child: Text('Normal'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'hard',
                                              child: Text('Hard'),
                                            ),
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
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        child: TextField(
                                          controller: prizeCoinsController,
                                          keyboardType:
                                              TextInputType.numberWithOptions(
                                                signed: false,
                                                decimal: false,
                                              ),
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly,
                                          ],
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
                                              String cleanValue = value
                                                  .replaceAll(',', '');
                                              int? coins = int.tryParse(
                                                cleanValue,
                                              );

                                              if (coins != null) {
                                                if (coins > 99999) {
                                                  prizeCoinsController.text =
                                                      NumberFormat(
                                                        '#,##0',
                                                      ).format(99999);
                                                  prizeCoinsController
                                                          .selection =
                                                      TextSelection.fromPosition(
                                                        TextPosition(
                                                          offset:
                                                              prizeCoinsController
                                                                  .text
                                                                  .length,
                                                        ),
                                                      );
                                                } else {
                                                  String formatted =
                                                      NumberFormat(
                                                        '#,##0',
                                                      ).format(coins);
                                                  if (formatted != value) {
                                                    prizeCoinsController.text =
                                                        formatted;
                                                    prizeCoinsController
                                                            .selection =
                                                        TextSelection.fromPosition(
                                                          TextPosition(
                                                            offset: formatted
                                                                .length,
                                                          ),
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
                                      Row(
                                        children: [
                                          Container(
                                            width: 300,
                                            height: 50,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                            ),
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
                                                DropdownMenuItem(
                                                  value: 'none',
                                                  child: Text('None'),
                                                ),
                                                DropdownMenuItem(
                                                  value: 'heart',
                                                  child: Text(
                                                    'Heart Deduction',
                                                  ),
                                                ),
                                                DropdownMenuItem(
                                                  value: 'timer',
                                                  child: Text(
                                                    'Timer Countdown',
                                                  ),
                                                ),
                                                DropdownMenuItem(
                                                  value: 'score',
                                                  child: Text('Score'),
                                                ),
                                              ],
                                              onChanged: (String? newValue) {
                                                if (newValue != null) {
                                                  setState(() {
                                                    selectedGameRule = newValue;
                                                    // Update heart and timer states based on selection
                                                    heartEnabled =
                                                        newValue == 'heart';
                                                    if (newValue != 'timer') {
                                                      timerMinutesController
                                                          .clear();
                                                      timerSecondsController
                                                          .clear();
                                                      timerSeconds = 0;
                                                    }
                                                  });
                                                }
                                              },
                                            ),
                                          ),

                                          // Timer configuration (minutes and seconds)
                                          if (selectedGameRule == 'timer') ...[
                                            const SizedBox(width: 15),
                                            // Minutes field
                                            Container(
                                              width: 80,
                                              height: 50,
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                  ),
                                              child: TextField(
                                                controller:
                                                    timerMinutesController,
                                                keyboardType:
                                                    TextInputType.number,
                                                inputFormatters: [
                                                  FilteringTextInputFormatter
                                                      .digitsOnly,
                                                  LengthLimitingTextInputFormatter(
                                                    2,
                                                  ),
                                                ],
                                                textAlign: TextAlign.center,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 16,
                                                  color: Colors.black,
                                                ),
                                                decoration: InputDecoration(
                                                  hintText: "Min",
                                                  hintStyle:
                                                      GoogleFonts.poppins(
                                                        color: Colors.black54,
                                                        fontSize: 14,
                                                      ),
                                                  border: InputBorder.none,
                                                ),
                                                onChanged: (value) {
                                                  setState(() {
                                                    int minutes =
                                                        int.tryParse(value) ??
                                                        0;
                                                    int seconds =
                                                        int.tryParse(
                                                          timerSecondsController
                                                              .text,
                                                        ) ??
                                                        0;
                                                    timerSeconds =
                                                        (minutes * 60) +
                                                        seconds;
                                                  });
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              ":",
                                              style: GoogleFonts.poppins(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(width: 5),
                                            // Seconds field
                                            Container(
                                              width: 80,
                                              height: 50,
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                  ),
                                              child: TextField(
                                                controller:
                                                    timerSecondsController,
                                                keyboardType:
                                                    TextInputType.number,
                                                inputFormatters: [
                                                  FilteringTextInputFormatter
                                                      .digitsOnly,
                                                  LengthLimitingTextInputFormatter(
                                                    2,
                                                  ),
                                                ],
                                                textAlign: TextAlign.center,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 16,
                                                  color: Colors.black,
                                                ),
                                                decoration: InputDecoration(
                                                  hintText: "Sec",
                                                  hintStyle:
                                                      GoogleFonts.poppins(
                                                        color: Colors.black54,
                                                        fontSize: 14,
                                                      ),
                                                  border: InputBorder.none,
                                                ),
                                                onChanged: (value) {
                                                  setState(() {
                                                    int minutes =
                                                        int.tryParse(
                                                          timerMinutesController
                                                              .text,
                                                        ) ??
                                                        0;
                                                    int seconds =
                                                        int.tryParse(value) ??
                                                        0;
                                                    // Limit seconds to 59
                                                    if (seconds > 59) {
                                                      seconds = 59;
                                                      timerSecondsController
                                                              .text =
                                                          '59';
                                                      timerSecondsController
                                                              .selection =
                                                          TextSelection.fromPosition(
                                                            TextPosition(
                                                              offset:
                                                                  timerSecondsController
                                                                      .text
                                                                      .length,
                                                            ),
                                                          );
                                                    }
                                                    timerSeconds =
                                                        (minutes * 60) +
                                                        seconds;
                                                  });
                                                },
                                              ),
                                            ),
                                          ],
                                        ],
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 300,
                                            height: 50,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                            ),
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
                                                      gameCodeController
                                                          .clear();
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
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                  ),
                                              child: TextField(
                                                controller: gameCodeController,
                                                keyboardType:
                                                    TextInputType.numberWithOptions(
                                                      signed: false,
                                                      decimal: false,
                                                    ),
                                                inputFormatters: [
                                                  FilteringTextInputFormatter
                                                      .digitsOnly,
                                                  LengthLimitingTextInputFormatter(
                                                    8,
                                                  ),
                                                ],
                                                style: GoogleFonts.poppins(
                                                  fontSize: 16,
                                                  color: Colors.black,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                decoration: InputDecoration(
                                                  hintText: "Game Code...",
                                                  hintStyle:
                                                      GoogleFonts.poppins(
                                                        color: Colors.black54,
                                                        fontSize: 14,
                                                      ),
                                                  border: InputBorder.none,
                                                ),
                                                onChanged: (value) {
                                                  String cleanValue = value
                                                      .replaceAll('-', '');
                                                  if (cleanValue.length >= 5) {
                                                    String formatted = '';
                                                    for (
                                                      int i = 0;
                                                      i < cleanValue.length;
                                                      i++
                                                    ) {
                                                      if (i == 4) {
                                                        formatted +=
                                                            '-${cleanValue[i]}';
                                                      } else {
                                                        formatted +=
                                                            cleanValue[i];
                                                      }
                                                    }
                                                    if (formatted != value) {
                                                      gameCodeController.text =
                                                          formatted;
                                                      gameCodeController
                                                              .selection =
                                                          TextSelection.fromPosition(
                                                            TextPosition(
                                                              offset: formatted
                                                                  .length,
                                                            ),
                                                          );
                                                    }
                                                  }
                                                },
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),

                                      const SizedBox(height: 40),

                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: 10,
                                          bottom: 10,
                                        ),
                                        child: Divider(color: Colors.white),
                                      ),

                                      // Auto-save status indicator
                                      if (_autoSaveStatus.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 10,
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                _autoSaveStatus.contains('✓')
                                                    ? Icons.check_circle
                                                    : _autoSaveStatus.contains(
                                                        'Saving',
                                                      )
                                                    ? Icons.sync
                                                    : _autoSaveStatus.contains(
                                                        'disabled',
                                                      )
                                                    ? Icons
                                                          .settings_backup_restore
                                                    : Icons.edit_note,
                                                color:
                                                    _autoSaveStatus.contains(
                                                      '✓',
                                                    )
                                                    ? Colors.green
                                                    : _autoSaveStatus.contains(
                                                        'disabled',
                                                      )
                                                    ? Colors.grey
                                                    : Colors.orange,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  _autoSaveStatus,
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 12,
                                                    color:
                                                        _autoSaveStatus
                                                            .contains('✓')
                                                        ? Colors.green
                                                        : _autoSaveStatus
                                                              .contains(
                                                                'disabled',
                                                              )
                                                        ? Colors.grey
                                                        : Colors.orange,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 10,
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
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
                                              onPressed: _isSaving
                                                  ? () {}
                                                  : () async {
                                                      _saveCurrentPageData();
                                                      await _saveToFirestore();
                                                    },
                                              child: _isSaving
                                                  ? const SizedBox(
                                                      width: 20,
                                                      height: 20,
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        valueColor:
                                                            AlwaysStoppedAnimation<
                                                              Color
                                                            >(Colors.white),
                                                      ),
                                                    )
                                                  : Text(
                                                      "Save",
                                                      style:
                                                          GoogleFonts.poppins(
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight.bold,
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

                            // Hearts display (when heart rule is selected) - moved to left side below progress bar
                            if (heartEnabled)
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 16,
                                  top: 8,
                                ),
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
                                padding: const EdgeInsets.only(
                                  right: 16,
                                  top: 8,
                                ),
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
                                          audioUrl: pages[currentPageIndex]
                                              .listenAndRepeatAudioUrl,
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
                                        onPressed: _isSaving
                                            ? () {}
                                            : () async {
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
                                                      AlwaysStoppedAnimation<
                                                        Color
                                                      >(Colors.black),
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

                                // Scrollable game-specific settings area
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Validation Warning Banner
                                        if (_validatePages().containsKey(
                                          currentPageIndex,
                                        ))
                                          Container(
                                            margin: const EdgeInsets.only(
                                              bottom: 15,
                                            ),
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withOpacity(
                                                0.2,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: Colors.red,
                                                width: 2,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.warning_amber_rounded,
                                                  color: Colors.red,
                                                  size: 24,
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    _validatePages()[currentPageIndex] ??
                                                        'Error',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 14,
                                                      color: Colors.red,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                        if (selectedGameType ==
                                            'Fill in the blank')
                                          MyFillTheBlankSettings(
                                            answerController: answerController,
                                            hintController: hintController,
                                            visibleLetters: visibleLetters,
                                            onToggle: _toggleLetter,
                                          )
                                        else if (selectedGameType ==
                                            'Fill in the blank 2')
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
                                              _triggerAutoSave();
                                            },
                                          )
                                        else if (selectedGameType ==
                                            'Guess the answer')
                                          MyFillInTheBlank3Settings(
                                            hintController: hintController,
                                            questionController:
                                                descriptionFieldController,
                                            visibleLetters: visibleLetters,
                                            onToggle: _toggleLetter,
                                            onImagePicked:
                                                (Uint8List imageBytes) {
                                                  setState(() {
                                                    selectedImageBytes =
                                                        imageBytes;
                                                  });
                                                },
                                            onChoicesChanged:
                                                (List<String> choices) {
                                                  setState(() {
                                                    multipleChoices = choices;
                                                  });
                                                },
                                            onCorrectAnswerSelected:
                                                (int index) {
                                                  setState(() {
                                                    correctAnswerIndex = index;
                                                  });
                                                },
                                            initialChoices: multipleChoices,
                                            initialCorrectIndex:
                                                correctAnswerIndex,
                                          )
                                        else if (selectedGameType ==
                                            'Guess the answer 2')
                                          MyGuessTheAnswerSettings(
                                            hintController: hintController,
                                            questionController:
                                                descriptionFieldController,
                                            visibleLetters: visibleLetters,
                                            onToggle: _toggleLetter,
                                            onImagePicked:
                                                (
                                                  int index,
                                                  Uint8List imageBytes,
                                                ) {
                                                  setState(() {
                                                    guessAnswerImages[index] =
                                                        imageBytes;
                                                  });
                                                },
                                            onChoicesChanged:
                                                (List<String> choices) {
                                                  setState(() {
                                                    multipleChoices = choices;
                                                  });
                                                },
                                            onCorrectAnswerSelected:
                                                (int index) {
                                                  setState(() {
                                                    correctAnswerIndex = index;
                                                  });
                                                },
                                            initialChoices: multipleChoices,
                                            initialCorrectIndex:
                                                correctAnswerIndex,
                                          )
                                        else if (selectedGameType ==
                                            'Read the sentence')
                                          MyReadTheSentenceSettings(
                                            sentenceController:
                                                readSentenceController,
                                          )
                                        else if (selectedGameType ==
                                            'What is it called')
                                          MyWhatItIsCalledSettings(
                                            sentenceController:
                                                readSentenceController,
                                            hintController: hintController,
                                            onImagePicked:
                                                (Uint8List imageBytes) {
                                                  setState(() {
                                                    whatCalledImageBytes =
                                                        imageBytes;
                                                  });
                                                },
                                          )
                                        else if (selectedGameType ==
                                            'Listen and Repeat')
                                          MyListenAndRepeatSettings(
                                            sentenceController:
                                                listenAndRepeatController,
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
                                                    listenAndRepeatAudioPath =
                                                        audioPath;
                                                    listenAndRepeatAudioSource =
                                                        audioSource;
                                                    listenAndRepeatAudioBytes =
                                                        audioBytes;
                                                  });
                                                  // Save the current page data immediately when audio changes
                                                  _saveCurrentPageData();
                                                },
                                          )
                                        else if (selectedGameType ==
                                            'Image Match')
                                          MyImageMatchSettings(
                                            onImagePicked:
                                                (
                                                  int index,
                                                  Uint8List imageBytes,
                                                ) {
                                                  setState(() {
                                                    imageMatchImages[index] =
                                                        imageBytes;
                                                  });
                                                  debugPrint(
                                                    'Image Match image $index picked, size: ${imageBytes.length} bytes',
                                                  );
                                                  // Trigger auto-save when image is picked
                                                  _triggerAutoSave();
                                                },
                                            onCountChanged: (int newCount) {
                                              setState(() {
                                                imageMatchCount = newCount;
                                              });
                                              debugPrint(
                                                'Image Match count changed to: $newCount',
                                              );
                                              // Trigger auto-save when count changes
                                              _triggerAutoSave();
                                            },
                                            initialImages: imageMatchImages,
                                            initialCount: imageMatchCount,
                                          )
                                        else if (selectedGameType == 'Math')
                                          MyMathSettings(mathState: mathState),
                                      ],
                                    ),
                                  ),
                                ),

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

                            Stack(
                              clipBehavior: Clip.none,
                              children: [
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
                                // Red error badge
                                if (_validatePages().containsKey(
                                  currentPageIndex,
                                ))
                                  Positioned(
                                    top: -5,
                                    right: -5,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: const Color(0xFF1E201E),
                                          width: 2,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.error,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                              ],
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
                ),
              ),
            ),
          ),

          // Success Message Overlay with Fade Animation
          if (_showSaveSuccess)
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 1500),
              tween: Tween<double>(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                // Fade in for first 500ms, stay visible for 500ms, fade out for 500ms
                double opacity;
                if (value < 0.33) {
                  // Fade in
                  opacity = value * 3;
                } else if (value < 0.67) {
                  // Stay visible
                  opacity = 1.0;
                } else {
                  // Fade out
                  opacity = 1.0 - ((value - 0.67) * 3);
                }

                return Opacity(
                  opacity: opacity,
                  child: Container(
                    color: Colors.black.withOpacity(0.5),
                    child: Center(
                      child: Transform.scale(
                        scale: value < 0.33 ? 0.8 + (value * 0.6) : 1.0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 30,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withOpacity(0.5),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check_circle_outline,
                                color: Colors.white,
                                size: 80,
                              ),
                              const SizedBox(height: 20),
                              Text(
                                "Game Saved",
                                style: GoogleFonts.poppins(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "Your game has been saved successfully!",
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: Colors.white.withOpacity(0.9),
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

          // Validation Error Message Overlay with Fade Animation
          if (_showValidationError)
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 2000),
              tween: Tween<double>(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                // Fade in for first 500ms, stay visible for 1000ms, fade out for 500ms
                double opacity;
                if (value < 0.25) {
                  // Fade in
                  opacity = value * 4;
                } else if (value < 0.75) {
                  // Stay visible
                  opacity = 1.0;
                } else {
                  // Fade out
                  opacity = 1.0 - ((value - 0.75) * 4);
                }

                return Opacity(
                  opacity: opacity,
                  child: Container(
                    color: Colors.black.withOpacity(0.5),
                    child: Center(
                      child: Transform.scale(
                        scale: value < 0.25 ? 0.8 + (value * 0.8) : 1.0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 30,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.5),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.white,
                                size: 80,
                              ),
                              const SizedBox(height: 20),
                              Text(
                                "Cannot Save",
                                style: GoogleFonts.poppins(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: 400,
                                child: Text(
                                  _validationErrorMessage,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    color: Colors.white.withOpacity(0.9),
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
