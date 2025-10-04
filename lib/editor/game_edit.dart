// ===== game_edit.dart =====

// ignore_for_file: deprecated_member_use, use_build_context_synchronously

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
import 'package:lexi_on_web/editor/game%20types/guess_the_answer.dart';
import 'package:lexi_on_web/editor/game%20types/read_the_sentence.dart';
import 'package:lexi_on_web/editor/game%20types/what_called.dart';
import 'package:lexi_on_web/editor/game%20types/listen_and_repeat.dart';
import 'package:lexi_on_web/editor/game%20types/math.dart';
import 'package:lexi_on_web/editor/game%20types/image_match.dart'; // ✅ NEW Import

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
  String difficulty; // Add difficulty property
  String prizeCoins;
  String gameRule; // Add game rule property
  String gameSet; // Add game set property
  String gameCode; // Add game code property

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
    this.difficulty = 'easy', // Initialize difficulty
    this.prizeCoins = '100',
    this.gameRule = 'none', // Initialize game rule
    this.gameSet = 'public', // Initialize game set
    this.gameCode = '', // Initialize game code
  }) : guessAnswerImages = guessAnswerImages ?? [null, null, null],
       imageMatchImages = imageMatchImages ?? List.filled(8, null);
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

  double progressValue = 0.1; // Progress bar value (10%)
  String selectedGameType = 'Fill in the blank'; // Default game type
  String selectedDifficulty = 'easy'; // Default difficulty
  String selectedGameRule = 'none'; // Default game rule
  String selectedGameSet = 'public'; // Default game set

  List<bool> visibleLetters = [];
  Uint8List? selectedImageBytes;
  Uint8List? whatCalledImageBytes;
  List<String> multipleChoices = [];

  // ✅ Support 3 image hints for Guess the Answer 2
  List<Uint8List?> guessAnswerImages = [null, null, null];

  // ✅ Support for Image Match (up to 8 images)
  List<Uint8List?> imageMatchImages = List.filled(8, null);
  int imageMatchCount = 2; // default number of slots

  // Page management
  List<PageData> pages = [PageData()]; // Start with one page
  int currentPageIndex = 0;

  // Firestore related
  String? gameId; // set when opening an existing game or creating one

  @override
  void initState() {
    super.initState();
    answerController.addListener(_syncVisibleLetters);

    // If arguments were passed via Get (gameId), load the title from Firestore
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = Get.arguments;
      if (args != null && args['gameId'] != null) {
        gameId = args['gameId'] as String;
        _loadFromFirestore(gameId!);
      }
    });
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

  void _toggleLetter(int index) {
    setState(() {
      visibleLetters[index] = !visibleLetters[index];
    });
  }

  // Save current page data before switching (Column 1 fields are global, not per-page)
  void _saveCurrentPageData() {
    pages[currentPageIndex] = PageData(
      title: '', // Column 1 fields are global, don't save per page
      description: '',
      gameType: selectedGameType,
      difficulty: '', // Column 1 fields are global, don't save per page
      gameRule: '', // Column 1 fields are global, don't save per page
      gameSet: '', // Column 1 fields are global, don't save per page
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
      prizeCoins: '', // Column 1 fields are global, don't save per page
    );
  }

  // Load page data when switching (Column 1 fields remain global and unchanged)
  void _loadPageData(int pageIndex) {
    final pageData = pages[pageIndex];

    // Column 1 fields are global and don't change per page - keep current values
    // titleController.text remains unchanged (global game title)
    // descriptionController.text remains unchanged (global game description) 
    // selectedDifficulty remains unchanged (global game difficulty)
    // selectedGameRule remains unchanged (general game rules)
    // selectedGameSet remains unchanged (general game setting)
    // prizeCoinsController.text remains unchanged (global prize coins)

    // Only load page-specific content (Columns 2 & 3)
    selectedGameType = pageData.gameType;
    answerController.text = pageData.answer;
    descriptionFieldController.text = pageData.descriptionField;
    readSentenceController.text = pageData.readSentence;
    listenAndRepeatController.text = pageData.listenAndRepeat;
    visibleLetters = List.from(pageData.visibleLetters);
    selectedImageBytes = pageData.selectedImageBytes;
    whatCalledImageBytes = pageData.whatCalledImageBytes;
    multipleChoices = List.from(pageData.multipleChoices);
    guessAnswerImages = List.from(pageData.guessAnswerImages);
    imageMatchImages = List.from(pageData.imageMatchImages);
    imageMatchCount = pageData.imageMatchCount;

    // Update progress based on current page
    progressValue = (pageIndex + 1) / pages.length;
  }

  // Navigate to previous page
  void _goToPreviousPage() {
    if (currentPageIndex > 0) {
      _saveCurrentPageData();
      setState(() {
        currentPageIndex--;
        _loadPageData(currentPageIndex);
      });
    }
  }

  // Navigate to next page or create new
  void _goToNextPage() {
    _saveCurrentPageData();

    if (currentPageIndex < pages.length - 1) {
      // Go to existing next page
      setState(() {
        currentPageIndex++;
        _loadPageData(currentPageIndex);
      });
    } else {
      // Create new page
      setState(() {
        pages.add(PageData());
        currentPageIndex++;
        _loadPageData(currentPageIndex);
      });
    }
  }

  // Show page selector dialog
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
                                setState(() {
                                  currentPageIndex = index;
                                  _loadPageData(currentPageIndex);
                                });
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

  // Delete current page
  void _deletePage() {
    if (pages.length == 1) {
      return; // Can't delete the only page
    }

    // Show confirmation dialog
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
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  pages.removeAt(currentPageIndex);

                  // Adjust current page index if necessary
                  if (currentPageIndex >= pages.length) {
                    currentPageIndex = pages.length - 1;
                  }

                  _loadPageData(currentPageIndex);
                });
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

  /// Load metadata (title, etc.) from Firestore for the provided gameId
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
          // If you later store more fields (pages, description, progress etc.) in Firestore,
          // you can load them here and populate the editor state.
        });
      }
    } catch (e) {
      debugPrint('Failed to load game metadata: $e');
    }
  }

  /// Save metadata (currently: title) back to Firestore
  Future<void> _saveToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to save.')),
      );
      return;
    }

    try {
      if (gameId == null) {
        // If the editor was opened without a gameId (e.g. direct open), create a new doc
        final docRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('created_games')
            .doc();

        await docRef.set({
          'title': titleController.text.trim(),
          'created_at': FieldValue.serverTimestamp(),
        });

        setState(() {
          gameId = docRef.id;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Created new game and saved title.')),
        );
      } else {
        // Update existing document
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('created_games')
            .doc(gameId)
            .update({
              'title': titleController.text.trim(),
              'updated_at': FieldValue.serverTimestamp(),
            });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Title updated successfully.')),
        );
      }
    } catch (e) {
      debugPrint('Failed to save title: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save. See logs.')),
      );
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    descriptionFieldController.dispose();
    answerController.dispose();
    readSentenceController.dispose();
    listenAndRepeatController.dispose();
    prizeCoinsController.dispose();
    gameCodeController.dispose();
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
                      keyboardType: TextInputType.numberWithOptions(signed: false, decimal: false),
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
                          // Remove commas for parsing
                          String cleanValue = value.replaceAll(',', '');
                          int? coins = int.tryParse(cleanValue);
                          
                          if (coins != null) {
                            if (coins > 99999) {
                              // Format with commas
                              prizeCoinsController.text = NumberFormat('#,##0').format(99999);
                              prizeCoinsController.selection = TextSelection.fromPosition(
                                TextPosition(offset: prizeCoinsController.text.length),
                              );
                            } else {
                              // Format with commas
                              String formatted = NumberFormat('#,##0').format(coins);
                              // Only update if formatting actually changed to avoid cursor issues
                              if (formatted != value) {
                                prizeCoinsController.text = formatted;
                                prizeCoinsController.selection = TextSelection.fromPosition(
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
                        DropdownMenuItem(value: 'heart', child: Text('Heart Deduction')),
                        DropdownMenuItem(value: 'timer', child: Text('Timer Countdown')),
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
                            DropdownMenuItem(value: 'public', child: Text('Public')),
                            DropdownMenuItem(value: 'private', child: Text('Private')),
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
                      
                      // Conditional Game Code text field (only shows for Private) next to dropdown
                      if (selectedGameSet == 'private') ...[
                        const SizedBox(width: 20),
                        
                        Container(
                          width: 120, // Reduced width to fit 8 digits comfortably
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: TextField(
                            
                            controller: gameCodeController,
                            keyboardType: TextInputType.numberWithOptions(signed: false, decimal: false),
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
                              // Format with dash if 5 or more digits
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
                                  gameCodeController.selection = TextSelection.fromPosition(
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
                            // Add delete functionality here
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
                            // Add delete functionality here
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
                            // Save current page before saving
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
                                          answerController: answerController,
                                          visibleLetters: visibleLetters,
                                          pickedImage: selectedImageBytes,
                                          questionController:
                                              descriptionFieldController,
                                          multipleChoices: multipleChoices,
                                        )
                                      : selectedGameType == 'Guess the answer 2'
                                      ? MyGuessTheAnswer(
                                          answerController: answerController,
                                          visibleLetters: visibleLetters,
                                          pickedImages: guessAnswerImages,
                                          questionController:
                                              descriptionFieldController,
                                          multipleChoices: multipleChoices,
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
                                      : const MyMath(),
                                ),

                                Center(
                                  child: AnimatedButton(
                                    width: 350,
                                    height: 60,
                                    color: Colors.green,
                                    onPressed: () async {
                                      // Save current page before saving title
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
                        visibleLetters: visibleLetters,
                        onToggle: _toggleLetter,
                      )
                    else if (selectedGameType == 'Fill in the blank 2')
                      MyFillInTheBlank2Settings(
                        answerController: answerController,
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
                        answerController: answerController,
                        visibleLetters: visibleLetters,
                        onToggle: _toggleLetter,
                        onImagePicked: (Uint8List imageBytes) {
                          setState(() {
                            selectedImageBytes = imageBytes;
                          });
                        },
                        questionController: descriptionFieldController,
                        onChoicesChanged: (List<String> choices) {
                          setState(() {
                            multipleChoices = choices;
                          });
                        },
                      )
                    else if (selectedGameType == 'Guess the answer 2')
                      MyGuessTheAnswerSettings(
                        answerController: answerController,
                        visibleLetters: visibleLetters,
                        onToggle: _toggleLetter,
                        onImagePicked: (int index, Uint8List imageBytes) {
                          setState(() {
                            guessAnswerImages[index] = imageBytes;
                          });
                        },
                        questionController: descriptionFieldController,
                        onChoicesChanged: (List<String> choices) {
                          setState(() {
                            multipleChoices = choices;
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
                      const MyMathSettings(),

                    const Spacer(),

                    Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 10),
                      child: Divider(color: Colors.white),
                    ),

                    // Last lane 3 controller with added functionality
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Previous page button
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

                        // Page selector button
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

                        // Next/New page button
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

                        // Delete page button
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
                            // Save current page before testing
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