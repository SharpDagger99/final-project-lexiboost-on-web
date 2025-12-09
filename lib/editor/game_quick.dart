// ignore_for_file: use_build_context_synchronously, unused_element, unnecessary_import, deprecated_member_use, unused_import

import 'dart:typed_data';
import 'package:animated_button/animated_button.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:lexi_on_web/editor/gemini.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:get/get.dart';

class MyGameQuick extends StatefulWidget {
  final String? gameId; // Accept gameId from game_edit.dart
  
  const MyGameQuick({super.key, this.gameId});

  @override
  State<MyGameQuick> createState() => _MyGameQuickState();
}

class _MyGameQuickState extends State<MyGameQuick> with SingleTickerProviderStateMixin {
  // Controllers
  final TextEditingController totalPageController = TextEditingController(text: '5');
  final TextEditingController promptController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _chatScrollController = ScrollController();
  
  // Services
  final GeminiService _geminiService = GeminiService();
  
  // State variables
  String selectedMode = 'edit'; // 'edit' or 'prompt'
  String selectedDifficulty = 'easy';
  String selectedGameRule = 'none';
  List<String> selectedGameTypes = [];
  String? selectedFolder;
  List<Uint8List> uploadedImages = [];
  List<String> uploadedFileNames = [];
  
  // Chat/Prompt state
  List<Map<String, dynamic>> chatMessages = [];
  Map<String, dynamic>? generatedActivity;
  Map<String, dynamic>? pendingActivityPlan; // Activity plan waiting for confirmation
  
  // Document upload state
  Uint8List? uploadedDocumentBytes;
  String? uploadedDocumentName;
  String? uploadedDocumentExtension;
  String? extractedDocumentContent;
  bool _isAnalyzingDocument = false;
  
  // Animation controller for generate button
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isGenerating = false;
  
  // Firebase state
  String? gameId; // Will be set from widget.gameId
  bool _isSaving = false;
  String _saveStatus = '';
  int _existingPagesCount = 0; // Track existing pages in the game

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    // Set gameId from widget parameter
    gameId = widget.gameId;
    
    // Load existing pages count if gameId exists
    if (gameId != null) {
      _loadExistingPagesCount();
    }
    
    // Add listener to prompt controller to update UI when text changes
    promptController.addListener(() {
      setState(() {});
    });
  }
  
  /// Load the count of existing pages in the game
  Future<void> _loadExistingPagesCount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || gameId == null) return;
    
    try {
      final gameRoundsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('created_games')
          .doc(gameId)
          .collection('game_rounds')
          .get();
      
      setState(() {
        _existingPagesCount = gameRoundsSnapshot.docs.length;
      });
      
      debugPrint('Existing pages count: $_existingPagesCount');
    } catch (e) {
      debugPrint('Failed to load existing pages count: $e');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    _chatScrollController.dispose();
    totalPageController.dispose();
    promptController.dispose();
    super.dispose();
  }

  // Check if all required fields are filled
  bool get _isFormValid {
    if (selectedMode == 'edit') {
      return selectedGameTypes.isNotEmpty &&
             totalPageController.text.isNotEmpty &&
             int.tryParse(totalPageController.text) != null &&
             int.parse(totalPageController.text) > 0;
    } else {
      return promptController.text.trim().isNotEmpty;
    }
  }

  // Pick images
  Future<void> _pickImages() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.image,
      );

      if (result != null) {
        setState(() {
          uploadedImages = result.files.map((file) => file.bytes!).toList();
          uploadedFileNames = result.files.map((file) => file.name).toList();
          selectedFolder = '${result.files.length} images selected';
        });
      }
    } catch (e) {
      debugPrint('Error picking images: $e');
    }
  }

  // Pick document (PDF, DOCX, PPT)
  Future<void> _pickDocument() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx'],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final extension = file.extension?.toLowerCase() ?? '';
        
        setState(() {
          _isAnalyzingDocument = true;
          uploadedDocumentBytes = file.bytes;
          uploadedDocumentName = file.name;
          uploadedDocumentExtension = extension;
        });

        // Analyze document with Gemini
        if (file.bytes != null) {
          final analysisResult = await _geminiService.analyzeDocument(
            fileBytes: file.bytes!,
            fileName: file.name,
            fileExtension: extension,
          );

          if (analysisResult['success'] == true) {
            setState(() {
              extractedDocumentContent = analysisResult['text'];
              _isAnalyzingDocument = false;
            });
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Document analyzed successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } else {
            setState(() {
              _isAnalyzingDocument = false;
            });
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error: ${analysisResult['error']}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error picking document: $e');
      setState(() {
        _isAnalyzingDocument = false;
      });
    }
  }

  // Remove uploaded document
  void _removeDocument() {
    setState(() {
      uploadedDocumentBytes = null;
      uploadedDocumentName = null;
      uploadedDocumentExtension = null;
      extractedDocumentContent = null;
    });
  }

  // Game types that require images
  final List<String> _imageRequiredGameTypes = [
    'Image Match',
    'What is it called',
    'Listen and Repeat',
    'Guess the answer 2',
    'Fill in the blank 2',
  ];

  // Add game type to the list
  void _addGameType(String gameType) {
    if (selectedGameTypes.contains(gameType)) {
      return; // Already added
    }
    
    // Check if this game type requires images
    if (_imageRequiredGameTypes.contains(gameType)) {
      _showImageRequiredDialog(gameType);
    } else {
      setState(() {
        selectedGameTypes.add(gameType);
      });
    }
  }
  
  // Show dialog for image-required game types
  void _showImageRequiredDialog(String gameType) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2C2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            const Icon(Icons.image, color: Colors.orange, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Image Required',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The game type "$gameType" requires images to function properly.',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Important Notice:',
                        style: GoogleFonts.poppins(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• AI will create the activity structure\n'
                    '• You MUST manually add images later\n'
                    '• Images can be added in the game editor\n'
                    '• Activity won\'t work without images',
                    style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Do you want to continue with this game type?',
              style: GoogleFonts.poppins(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: Colors.grey,
                fontSize: 15,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                selectedGameTypes.add(gameType);
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'I Understand, Add It',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Remove game type from the list
  void _removeGameType(String gameType) {
    setState(() {
      selectedGameTypes.remove(gameType);
    });
  }

  // Generate activity based on mode
  Future<void> _generateActivity() async {
    if (!_isFormValid) return;

    setState(() {
      _isGenerating = true;
    });

    try {
      if (selectedMode == 'edit') {
        // Manual edit mode - create activity from form data
        await _generateFromEditMode();
      } else {
        // AI prompt mode - generate from user prompt
        await _generateFromPromptMode();
      }
    } catch (e) {
      debugPrint('Error generating activity: $e');
      if (mounted) {
        _showErrorDialog('Failed to generate activity: $e');
      }
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  // Generate from edit mode
  Future<void> _generateFromEditMode() async {
    final totalPages = int.parse(totalPageController.text);
    
    // Use Gemini AI to generate content for Edit Mode
    debugPrint('=== EDIT MODE: Starting AI generation ===');
    debugPrint('Game Types: $selectedGameTypes');
    debugPrint('Difficulty: $selectedDifficulty');
    debugPrint('Total Pages: $totalPages');
    
    final result = await _geminiService.generateEditModeActivity(
      gameTypes: selectedGameTypes,
      difficulty: selectedDifficulty,
      gameRule: selectedGameRule,
      totalPages: totalPages,
      documentContent: extractedDocumentContent,
      documentFileName: uploadedDocumentName,
    );

    debugPrint('=== EDIT MODE: AI generation result ===');
    debugPrint('Success: ${result['success']}');
    if (result['success'] != true) {
      debugPrint('Error: ${result['error']}');
      debugPrint('Details: ${result['details']}');
      debugPrint('Raw Response: ${result['rawResponse']}');
    }

    if (result['success'] == true) {
      final activityData = result['data'] as Map<String, dynamic>;
      
      // Ensure the activity has the correct structure
      final activity = {
        'title': activityData['title'] ?? 'Custom Activity',
        'description': activityData['description'] ?? 'Activity created with AI assistance',
        'gameTypes': selectedGameTypes,
        'difficulty': selectedDifficulty,
        'gameRule': selectedGameRule,
        'totalPages': totalPages,
        'pages': activityData['pages'] ?? _createDefaultPages(totalPages),
        'images': uploadedImages.length,
      };

      setState(() {
        generatedActivity = activity;
      });

      // Auto-save to Firestore
      await _saveGeneratedActivityToFirestore(activity);

      if (mounted) {
        _showSuccessDialog(
          'Activity created successfully with $totalPages pages!',
        );
      }
    } else {
      // Show detailed error to user
      final errorMessage = result['error'] ?? 'Unknown error';
      final errorDetails = result['details'] ?? '';
      
      debugPrint('AI generation failed: $errorMessage');
      debugPrint('Error details: $errorDetails');
      
      if (mounted) {
        // Show detailed error dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF2A2C2A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: Text(
              'AI Generation Error',
              style: GoogleFonts.poppins(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Error Message:',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    errorMessage,
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
                  ),
                  if (errorDetails.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Details:',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        errorDetails.length > 500 
                            ? '${errorDetails.substring(0, 500)}...' 
                            : errorDetails,
                        style: GoogleFonts.robotoMono(
                          color: Colors.red.shade200,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    'Would you like to create a basic activity structure instead?',
                    style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(color: Colors.grey),
                ),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  
                  // Create basic structure
                  final activity = {
                    'title': 'Custom Activity',
                    'description': 'Activity created from manual input',
                    'gameTypes': selectedGameTypes,
                    'difficulty': selectedDifficulty,
                    'gameRule': selectedGameRule,
                    'totalPages': totalPages,
                    'pages': _createDefaultPages(totalPages),
                    'images': uploadedImages.length,
                  };

                  setState(() {
                    generatedActivity = activity;
                  });

                  // Auto-save to Firestore
                  await _saveGeneratedActivityToFirestore(activity);

                  if (mounted) {
                    _showSuccessDialog(
                      'Basic activity structure created with $totalPages pages.',
                    );
                  }
                },
                child: Text(
                  'Create Basic Structure',
                  style: GoogleFonts.poppins(color: Colors.green),
                ),
              ),
            ],
          ),
        );
      }
    }
  }
  
  // Create default pages structure when AI is unavailable
  List<Map<String, dynamic>> _createDefaultPages(int totalPages) {
    final List<Map<String, dynamic>> pages = [];
    for (int i = 0; i < totalPages; i++) {
      final gameType = selectedGameTypes[i % selectedGameTypes.length];
      pages.add({
        'pageNumber': i + 1,
        'gameType': gameType,
        'content': '',
        'answer': '',
        'hint': '',
        'choices': [],
      });
    }
    return pages;
  }

  // Generate from prompt mode using AI
  Future<void> _generateFromPromptMode() async {
    final userPrompt = promptController.text.trim();
    
    debugPrint('=== PROMPT MODE: Starting AI generation ===');
    debugPrint('User Prompt: $userPrompt');
    debugPrint('Has Document: ${extractedDocumentContent != null}');
    
    // Check if user is confirming a pending plan
    if (pendingActivityPlan != null && 
        (userPrompt.toLowerCase().contains('yes') || 
         userPrompt.toLowerCase().contains('confirm') ||
         userPrompt.toLowerCase().contains('create') ||
         userPrompt.toLowerCase().contains('proceed'))) {
      
      // Add user confirmation message
      setState(() {
        chatMessages.add({
          'role': 'user',
          'content': userPrompt,
          'timestamp': DateTime.now(),
        });
      });
      
      // Create the activity from pending plan
      await _createActivityFromPlan(pendingActivityPlan!);
      promptController.clear();
      return;
    }
    
    // Add user message to chat
    setState(() {
      chatMessages.add({
        'role': 'user',
        'content': userPrompt,
        'timestamp': DateTime.now(),
      });
    });

    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    // Generate activity plan with AI
    final result = await _geminiService.generateActivityPlan(
      userPrompt: userPrompt,
      imageDescriptions: uploadedFileNames,
      documentContent: extractedDocumentContent,
      documentFileName: uploadedDocumentName,
    );

    debugPrint('=== PROMPT MODE: AI generation result ===');
    debugPrint('Success: ${result['success']}');
    if (result['success'] != true) {
      debugPrint('Error: ${result['error']}');
      debugPrint('Details: ${result['details']}');
      debugPrint('Raw Response: ${result['rawResponse']}');
    }

    if (result['success'] == true) {
      final activityPlan = result['data'];
      
      // Store pending plan
      setState(() {
        pendingActivityPlan = activityPlan;
        chatMessages.add({
          'role': 'assistant',
          'content': _buildActivityPlanMessage(activityPlan),
          'activityPlan': activityPlan,
          'timestamp': DateTime.now(),
        });
      });

      // Scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_chatScrollController.hasClients) {
          _chatScrollController.animateTo(
            _chatScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });

      promptController.clear();
    } else {
      final errorMessage = result['error'] ?? 'Unknown error';
      final errorDetails = result['details'] ?? '';
      final rawResponse = result['rawResponse'] ?? '';
      
      // Create detailed error message for chat
      String detailedError = 'Sorry, I encountered an error:\n\n';
      detailedError += '❌ $errorMessage\n';
      
      if (errorDetails.isNotEmpty) {
        detailedError += '\n📋 Details:\n${errorDetails.length > 300 ? errorDetails.substring(0, 300) + '...' : errorDetails}\n';
      }
      
      if (rawResponse.isNotEmpty) {
        detailedError += '\n📄 Response Preview:\n${rawResponse.length > 200 ? rawResponse.substring(0, 200) + '...' : rawResponse}';
      }
      
      setState(() {
        chatMessages.add({
          'role': 'assistant',
          'content': detailedError,
          'isError': true,
          'timestamp': DateTime.now(),
        });
      });
      
      // Scroll to bottom to show error
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_chatScrollController.hasClients) {
          _chatScrollController.animateTo(
            _chatScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }
  
  // Build activity plan message
  String _buildActivityPlanMessage(Map<String, dynamic> plan) {
    final title = plan['title'] ?? 'Untitled Activity';
    final description = plan['description'] ?? 'No description';
    final gameTypes = (plan['gameTypes'] as List?)?.join(', ') ?? 'Not specified';
    final difficulty = plan['difficulty'] ?? 'Not specified';
    final gameRule = plan['gameRule'] ?? 'none';
    final totalPages = plan['totalPages'] ?? 0;
    final reasoning = plan['reasoning'] ?? '';
    
    String message = '📋 **Activity Plan**\n\n';
    message += '**Title:** $title\n';
    message += '**Description:** $description\n\n';
    message += '**Game Types:** $gameTypes\n';
    message += '**Difficulty:** $difficulty\n';
    message += '**Game Rule:** $gameRule\n';
    message += '**Total Pages:** $totalPages\n';
    
    if (reasoning.isNotEmpty) {
      message += '\n**Why this plan?**\n$reasoning\n';
    }
    
    message += '\n✅ **To create this activity, type "yes" or "confirm"**\n';
    message += '✏️ **To modify, describe what you want to change**';
    
    return message;
  }
  
  // Create activity from confirmed plan
  Future<void> _createActivityFromPlan(Map<String, dynamic> plan) async {
    setState(() {
      chatMessages.add({
        'role': 'assistant',
        'content': '⏳ Creating your activity... Please wait.',
        'timestamp': DateTime.now(),
      });
    });
    
    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
    
    // Generate full activity with AI
    final result = await _geminiService.generateFullActivity(activityPlan: plan);
    
    if (result['success'] == true) {
      final activityData = result['data'];
      
      setState(() {
        generatedActivity = activityData;
        pendingActivityPlan = null; // Clear pending plan
        chatMessages.add({
          'role': 'assistant',
          'content': '✅ Activity created successfully! Saving to your game...',
          'activity': activityData,
          'timestamp': DateTime.now(),
        });
      });

      // Scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_chatScrollController.hasClients) {
          _chatScrollController.animateTo(
            _chatScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
      
      // Auto-save to Firestore
      await _saveGeneratedActivityToFirestore(activityData);
    } else {
      setState(() {
        chatMessages.add({
          'role': 'assistant',
          'content': '❌ Failed to create activity: ${result['error']}\n\nPlease try again or modify your request.',
          'isError': true,
          'timestamp': DateTime.now(),
        });
      });
    }
  }

  // Save generated activity to Firestore automatically
  Future<void> _saveGeneratedActivityToFirestore(Map<String, dynamic> activityData) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('User not logged in - cannot save activity');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to save activities'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Check if gameId exists (opened from game_edit.dart)
    if (gameId == null) {
      debugPrint('No gameId provided - cannot add pages to non-existent game');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please open a game in the editor first'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _isSaving = true;
      _saveStatus = 'Saving activity to game...';
    });

    try {
      // Extract activity data
      final gameTypes = activityData['gameTypes'] as List? ?? [];
      final pages = activityData['pages'] as List? ?? [];
      final title = activityData['title'] as String?;
      final description = activityData['description'] as String?;
      final difficulty = activityData['difficulty'] as String?;
      final gameRule = activityData['gameRule'] as String?;
      final prizeCoins = activityData['prizeCoins'];
      final gameSet = activityData['gameSet'] as String?;
      final gameCode = activityData['gameCode'] as String?;
      final heart = activityData['heart'] as bool?;
      final timer = activityData['timer'] as int?;

      debugPrint('Adding ${pages.length} pages to existing game: $gameId');

      // Update game metadata (Column 1) if provided by AI
      Map<String, dynamic> gameMetadataUpdates = {
        'updated_at': FieldValue.serverTimestamp(),
      };

      if (title != null && title.isNotEmpty) {
        gameMetadataUpdates['title'] = title;
        debugPrint('Updating game title: $title');
      }

      if (description != null && description.isNotEmpty) {
        gameMetadataUpdates['description'] = description;
        debugPrint('Updating game description: $description');
      }

      if (difficulty != null && difficulty.isNotEmpty) {
        gameMetadataUpdates['difficulty'] = difficulty;
        debugPrint('Updating game difficulty: $difficulty');
      }

      if (gameRule != null && gameRule.isNotEmpty) {
        gameMetadataUpdates['gameRule'] = gameRule;
        debugPrint('Updating game rule: $gameRule');
      }

      // AI-controlled Prize Coins (if user requests it)
      if (prizeCoins != null) {
        String coinsValue = prizeCoins.toString();
        gameMetadataUpdates['prizeCoins'] = coinsValue;
        debugPrint('Updating prize coins: $coinsValue');
      }

      // AI-controlled Game Set (if user requests it)
      if (gameSet != null && (gameSet == 'public' || gameSet == 'private')) {
        gameMetadataUpdates['gameSet'] = gameSet;
        debugPrint('Updating game set: $gameSet');
      }

      // AI-controlled Game Code (if user requests private game)
      if (gameCode != null && gameCode.isNotEmpty) {
        gameMetadataUpdates['gameCode'] = gameCode;
        debugPrint('Updating game code: $gameCode');
      }

      // AI-controlled Heart setting (if user requests it)
      if (heart != null) {
        gameMetadataUpdates['heart'] = heart;
        debugPrint('Updating heart setting: $heart');
      }

      // AI-controlled Timer setting (if user requests it)
      if (timer != null && timer >= 0) {
        gameMetadataUpdates['timer'] = timer;
        debugPrint('Updating timer: $timer seconds');
      }

      // Update game metadata in Firestore
      if (gameMetadataUpdates.length > 1) { // More than just updated_at
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('created_games')
            .doc(gameId)
            .update(gameMetadataUpdates);

        debugPrint('Game metadata updated successfully');
        
        // Show notification about metadata updates
        List<String> updatedFields = [];
        if (title != null && title.isNotEmpty) updatedFields.add('Title');
        if (description != null && description.isNotEmpty) updatedFields.add('Description');
        if (difficulty != null && difficulty.isNotEmpty) updatedFields.add('Difficulty');
        if (gameRule != null && gameRule.isNotEmpty) updatedFields.add('Game Rule');
        if (prizeCoins != null) updatedFields.add('Prize Coins');
        if (gameSet != null) updatedFields.add('Game Set');
        if (gameCode != null && gameCode.isNotEmpty) updatedFields.add('Game Code');
        if (heart != null) updatedFields.add('Heart');
        if (timer != null) updatedFields.add('Timer');
        
        if (updatedFields.isNotEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('AI Updated: ${updatedFields.join(', ')}'),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }

      // Save game rounds (pages) - they will be appended to existing pages
      await _saveGameRounds(pages, gameTypes);

      setState(() {
        _isSaving = false;
        _saveStatus = 'Activity saved successfully! ✓';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Activity saved! ${pages.length} page(s) added to game.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () {
                // Navigate back to game_edit.dart
                Navigator.pop(context);
              },
            ),
          ),
        );
      }

      // Clear save status after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _saveStatus = '';
          });
        }
      });
    } catch (e) {
      debugPrint('Error saving activity to game: $e');
      setState(() {
        _isSaving = false;
        _saveStatus = 'Failed to save activity';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding pages: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Save game rounds to Firestore
  Future<void> _saveGameRounds(List<dynamic> pages, List<dynamic> gameTypes) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || gameId == null) return;

    try {
      final gameRoundsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('created_games')
          .doc(gameId)
          .collection('game_rounds');

      // Save each page as a round document, starting from existing page count
      for (int i = 0; i < pages.length; i++) {
        final pageData = pages[i];
        final gameType = pageData['gameType'] ?? (gameTypes.isNotEmpty ? gameTypes[i % gameTypes.length] : 'Fill in the blank');

        final Map<String, dynamic> roundData = {
          'gameType': gameType,
          'page': _existingPagesCount + i + 1, // Append after existing pages
        };

        // Create new document with auto-generated ID
        final docRef = await gameRoundsRef.add(roundData);
        final roundDocId = docRef.id;

        // Save specific game type data
        await _saveGameTypeData(roundDocId, pageData, gameType);
      }

      debugPrint('${pages.length} game rounds added successfully (starting from page ${_existingPagesCount + 1})');
      
      // Update existing pages count
      _existingPagesCount += pages.length;
    } catch (e) {
      debugPrint('Failed to save game rounds: $e');
    }
  }

  // Save game type specific data to game_type subcollection
  Future<void> _saveGameTypeData(String roundDocId, Map<String, dynamic> pageData, String gameType) async {
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

      final docRef = gameTypeRef.doc();

      final Map<String, dynamic> gameTypeData = {
        'gameType': gameType,
        'timestamp': FieldValue.serverTimestamp(),
      };

      // Add specific data based on game type
      final content = pageData['content'] ?? '';
      final answer = pageData['answer'] ?? '';
      final hint = pageData['hint'] ?? '';
      final choices = pageData['choices'] as List? ?? [];
      
      // AI-controlled configurations
      final visibleLettersFromAI = pageData['visibleLetters'] as List?;
      final correctAnswerIndexFromAI = pageData['correctAnswerIndex'] as int?;
      final showImageHintFromAI = pageData['showImageHint'] as bool?;
      final imageCountFromAI = pageData['imageCount'] as int?;
      final totalBoxesFromAI = pageData['totalBoxes'] as int?;
      final boxValuesFromAI = pageData['boxValues'] as List?;
      final operatorsFromAI = pageData['operators'] as List?;
      final mathAnswerFromAI = pageData['answer'];

      if (gameType == 'Fill in the blank' || gameType == 'Fill in the blank 2') {
        // Use AI-generated visible letters or create default based on difficulty
        List<bool> visibleLetters;
        if (visibleLettersFromAI != null && visibleLettersFromAI.isNotEmpty) {
          visibleLetters = visibleLettersFromAI.map((e) => e as bool).toList();
        } else {
          // Default: hide ~50% of letters for medium difficulty
          visibleLetters = List.generate(
            answer.toString().length,
            (index) => index % 2 == 0, // Alternate visibility
          );
        }
        
        gameTypeData.addAll({
          'answer': visibleLetters,
          'gameHint': hint,
          'answerText': answer,
        });

        if (gameType == 'Fill in the blank 2') {
          gameTypeData['imageUrl'] = '';
        }
      } else if (gameType == 'Guess the answer' || gameType == 'Guess the answer 2') {
        // Use AI-controlled correct answer index (default to 0 if not provided)
        final correctIndex = correctAnswerIndexFromAI ?? 0;
        
        gameTypeData.addAll({
          'question': content,
          'gameHint': hint,
          'answer': correctIndex,
          'multipleChoice1': choices.isNotEmpty ? choices[0] : '',
          'multipleChoice2': choices.length > 1 ? choices[1] : '',
          'multipleChoice3': choices.length > 2 ? choices[2] : '',
          'multipleChoice4': choices.length > 3 ? choices[3] : '',
        });

        if (gameType == 'Guess the answer') {
          gameTypeData['image'] = '';
          // AI controls whether to show image hint - default to FALSE for text-based questions
          gameTypeData['showImageHint'] = showImageHintFromAI ?? false;
          debugPrint('AI set showImageHint to: ${gameTypeData['showImageHint']} for Guess the answer');
        } else {
          gameTypeData['image1'] = '';
          gameTypeData['image2'] = '';
          gameTypeData['image3'] = '';
          gameTypeData['correctAnswerIndex'] = correctIndex;
        }
      } else if (gameType == 'Read the sentence') {
        gameTypeData['sentence'] = content.isNotEmpty ? content : answer;
      } else if (gameType == 'What is it called') {
        gameTypeData.addAll({
          'answer': answer,
          'imageUrl': '',
          'gameHint': hint,
          'createdAt': FieldValue.serverTimestamp(),
          'gameType': 'what_called',
        });
      } else if (gameType == 'Listen and Repeat') {
        gameTypeData.addAll({
          'audio': 'gs://lexiboost-36801.firebasestorage.app/gameAudio',
          'answer': answer,
          'createdAt': FieldValue.serverTimestamp(),
          'gameType': 'listen_and_repeat',
        });
      } else if (gameType == 'Image Match') {
        // AI can control image count (2, 4, 6, or 8)
        final imageCount = imageCountFromAI ?? 2;
        gameTypeData.addAll({
          'imageCount': imageCount,
          'image_configuration': imageCount,
          'image1': '',
          'image2': '',
          'image3': '',
          'image4': '',
          'image5': '',
          'image6': '',
          'image7': '',
          'image8': '',
          'image_match1': 0,
          'image_match3': 0,
          'image_match5': 0,
          'image_match7': 0,
        });
      } else if (gameType == 'Math') {
        // AI controls math configuration
        final totalBoxes = totalBoxesFromAI ?? 2;
        final boxValues = boxValuesFromAI ?? [];
        final operators = operatorsFromAI ?? ['+'];
        
        // Parse math answer - ensure it's a number
        double mathAnswer = 0.0;
        if (mathAnswerFromAI != null) {
          if (mathAnswerFromAI is num) {
            mathAnswer = mathAnswerFromAI.toDouble();
          } else if (mathAnswerFromAI is String) {
            mathAnswer = double.tryParse(mathAnswerFromAI) ?? 0.0;
          }
        }
        
        gameTypeData.addAll({
          'totalBoxes': totalBoxes,
          'answer': mathAnswer,
        });
        
        // Set box values from AI - ONLY NUMBERS ALLOWED
        for (int i = 1; i <= 10; i++) {
          if (i <= boxValues.length) {
            final value = boxValues[i - 1];
            // Ensure only numeric values are stored
            double numericValue = 0.0;
            if (value is num) {
              numericValue = value.toDouble();
            } else if (value is String) {
              numericValue = double.tryParse(value) ?? 0.0;
            }
            gameTypeData['box$i'] = numericValue;
          } else {
            gameTypeData['box$i'] = 0.0;
          }
        }
        
        // Set operators from AI - AI can change these (+, -, ×, ÷)
        for (int i = 1; i < 10; i++) {
          if (i <= operators.length) {
            String operator = operators[i - 1].toString();
            // Normalize operator symbols (convert * to ×, / to ÷)
            if (operator == '*') operator = '×';
            if (operator == '/') operator = '÷';
            // Validate operator is one of the allowed types
            if (['+', '-', '×', '÷'].contains(operator)) {
              gameTypeData['operator${i}_${i + 1}'] = operator;
            } else {
              gameTypeData['operator${i}_${i + 1}'] = '+'; // Default to + if invalid
            }
          } else {
            gameTypeData['operator${i}_${i + 1}'] = '';
          }
        }
        
        debugPrint('AI configured Math: totalBoxes=$totalBoxes, boxValues=$boxValues, operators=$operators, answer=$mathAnswer');
      } else if (gameType == 'Stroke') {
        gameTypeData['imageUrl'] = '';
        gameTypeData['sentence'] = content.isNotEmpty ? content : answer;
      }

      await docRef.set(gameTypeData);
      debugPrint('Game type data saved for $gameType with AI configurations');
    } catch (e) {
      debugPrint('Failed to save game type data: $e');
    }
  }

  // Upload image to Firebase Storage
  Future<String> _uploadImageToStorage(Uint8List imageBytes, String imageName) async {
    try {
      final storage = FirebaseStorage.instanceFor(
        bucket: 'gs://lexiboost-36801.firebasestorage.app',
      );
      final fileName = '${imageName}_${DateTime.now().millisecondsSinceEpoch}.png';
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

  // Show success dialog
  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2C2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(
          'Success!',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          message,
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ),
          if (gameId != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Go back to game_edit.dart
              },
              child: Text(
                'Back to Editor',
                style: GoogleFonts.poppins(color: Colors.green),
              ),
            ),
        ],
      ),
    ).then((_) {
      // Auto-navigate back to editor after 5 seconds if dialog is still open
      if (gameId != null) {
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted && Navigator.canPop(context)) {
            Navigator.pop(context); // Close dialog
            Navigator.pop(context); // Go back to game_edit.dart
          }
        });
      }
    });
  }

  // Show error dialog
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2C2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(
          'Error',
          style: GoogleFonts.poppins(
            color: Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          message,
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: GoogleFonts.poppins(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 768;
    final isMediumScreen = screenWidth >= 768 && screenWidth < 1024;

    return Scaffold(
      backgroundColor: const Color(0xFF1E201E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2C2A),
        title: Column(
          children: [
            Text(
              'Quick Activity Generator',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (_saveStatus.isNotEmpty)
              Text(
                _saveStatus,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: _saveStatus.contains('✓') 
                      ? Colors.green 
                      : _saveStatus.contains('Failed')
                          ? Colors.red
                          : Colors.orange,
                ),
              ),
          ],
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Mode selector tabs
          _buildModeSelector(),
          
          // Main content area
          Expanded(
            child: selectedMode == 'edit'
                ? _buildEditMode(isSmallScreen, isMediumScreen)
                : _buildPromptMode(isSmallScreen, isMediumScreen),
          ),
        ],
      ),
    );
  }

  // Mode selector (Edit / Prompt)
  Widget _buildModeSelector() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2C2A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => selectedMode = 'edit'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: selectedMode == 'edit'
                      ? Colors.deepPurple
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.edit,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Edit Mode',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: selectedMode == 'edit'
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => selectedMode = 'prompt'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: selectedMode == 'prompt'
                      ? Colors.deepPurple
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Prompt Mode',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: selectedMode == 'prompt'
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Edit mode UI
  Widget _buildEditMode(bool isSmallScreen, bool isMediumScreen) {
    return Center(
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
        ),
        child: GestureDetector(
          onPanUpdate: (details) {
            _scrollController.position.moveTo(
              _scrollController.offset - details.delta.dy,
            );
          },
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: EdgeInsets.all(isSmallScreen ? 16.0 : 32.0),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: isSmallScreen ? double.infinity : (isMediumScreen ? 700 : 900),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildDragDropSection(isSmallScreen),
                  const SizedBox(height: 30),
                  _buildGameTypeSection(isSmallScreen),
                  const SizedBox(height: 30),
                  _buildDifficultySection(isSmallScreen),
                  const SizedBox(height: 30),
                  _buildGameRulesSection(isSmallScreen),
                  const SizedBox(height: 30),
                  _buildTotalPageSection(isSmallScreen),
                  const SizedBox(height: 40),
                  _buildGenerateButton(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Prompt mode UI (ChatGPT-like)
  Widget _buildPromptMode(bool isSmallScreen, bool isMediumScreen) {
    return Container(
      margin: EdgeInsets.all(isSmallScreen ? 16.0 : 32.0),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2C2A),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
      ),
      child: Column(
        children: [
          // Chat messages area
          Expanded(
            child: chatMessages.isEmpty
                ? _buildEmptyPromptState()
                : _buildChatMessages(),
          ),
          
          // Input area
          _buildPromptInput(isSmallScreen),
        ],
      ),
    );
  }

  // Empty state for prompt mode
  Widget _buildEmptyPromptState() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_awesome,
              size: 80,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 20),
            Text(
              'AI-Powered Activity Generator',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Describe the activity you want to create, and I\'ll generate it for you!',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.white.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            
            // Document upload section for prompt mode
            const SizedBox(height: 30),
            _buildPromptDocumentUpload(),
            
            const SizedBox(height: 30),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                _buildSuggestionChip('Create a math activity for grade 3'),
                _buildSuggestionChip('Generate 10 fill-in-the-blank questions'),
                _buildSuggestionChip('Make an image matching game'),
                _buildSuggestionChip('Create a vocabulary quiz'),
                if (extractedDocumentContent != null)
                  _buildSuggestionChip('Create activity from uploaded document'),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  // Document upload widget for prompt mode
  Widget _buildPromptDocumentUpload() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.description,
                color: Colors.deepPurple.withOpacity(0.7),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Upload a document for AI to analyze',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          if (uploadedDocumentBytes == null)
            GestureDetector(
              onTap: _isAnalyzingDocument ? null : _pickDocument,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.deepPurple.withOpacity(0.5)),
                ),
                child: _isAnalyzingDocument
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Analyzing...',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.upload_file, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Upload PDF, DOCX, or PPT',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getDocumentIcon(uploadedDocumentExtension),
                    color: Colors.green,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    uploadedDocumentName ?? 'Document uploaded',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _removeDocument,
                    child: const Icon(Icons.close, color: Colors.red, size: 16),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Suggestion chip
  Widget _buildSuggestionChip(String text) {
    return GestureDetector(
      onTap: () {
        promptController.text = text;
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ),
    );
  }

  // Chat messages display
  Widget _buildChatMessages() {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
      ),
      child: ListView.builder(
        controller: _chatScrollController,
        padding: const EdgeInsets.all(20),
        itemCount: chatMessages.length,
        itemBuilder: (context, index) {
          final message = chatMessages[index];
          final isUser = message['role'] == 'user';
          final isError = message['isError'] == true;
          
          return Align(
            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: isUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isUser
                          ? Colors.deepPurple
                          : isError
                              ? Colors.red.withOpacity(0.2)
                              : Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: isError 
                          ? Border.all(color: Colors.red, width: 1)
                          : null,
                    ),
                    child: Text(
                      message['content'],
                      style: isError
                          ? GoogleFonts.robotoMono(
                              fontSize: 13,
                              color: Colors.white,
                            )
                          : GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.white,
                            ),
                    ),
                  ),
                  if (message['activityPlan'] != null) ...[
                    const SizedBox(height: 12),
                    _buildActivityPlanPreview(message['activityPlan']),
                  ],
                  if (message['activity'] != null) ...[
                    const SizedBox(height: 12),
                    _buildActivityPreview(message['activity']),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  
  // Activity plan preview with confirmation buttons
  Widget _buildActivityPlanPreview(Map<String, dynamic> plan) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Text(
                'Activity Plan',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildPlanInfoRow('Title', plan['title'] ?? 'N/A'),
          _buildPlanInfoRow('Description', plan['description'] ?? 'N/A'),
          _buildPlanInfoRow('Game Types', (plan['gameTypes'] as List?)?.join(', ') ?? 'N/A'),
          _buildPlanInfoRow('Difficulty', plan['difficulty'] ?? 'N/A'),
          _buildPlanInfoRow('Game Rule', plan['gameRule'] ?? 'N/A'),
          _buildPlanInfoRow('Total Pages', plan['totalPages']?.toString() ?? 'N/A'),
          
          if (plan['reasoning'] != null && plan['reasoning'].toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reasoning:',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade200,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    plan['reasoning'],
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    promptController.text = 'yes, create this activity';
                    _generateFromPromptMode();
                  },
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: Text(
                    'Confirm & Create',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Focus on prompt input for modifications
                    setState(() {
                      promptController.text = '';
                    });
                  },
                  icon: const Icon(Icons.edit, size: 18),
                  label: Text(
                    'Modify Plan',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange, width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  // Plan info row helper
  Widget _buildPlanInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade200,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Activity preview card
  Widget _buildActivityPreview(Map<String, dynamic> activity) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              Text(
                'Activity Generated',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Title', activity['title'] ?? 'N/A'),
          _buildInfoRow('Difficulty', activity['difficulty'] ?? 'N/A'),
          _buildInfoRow('Total Pages', activity['totalPages']?.toString() ?? 'N/A'),
          _buildInfoRow('Game Types', (activity['gameTypes'] as List?)?.join(', ') ?? 'N/A'),
          const SizedBox(height: 12),
          AnimatedButton(
            width: double.infinity,
            height: 45,
            color: Colors.green,
            onPressed: () {
              _showSuccessDialog('Activity ready to use!');
            },
            child: Text(
              'Use This Activity',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Info row helper
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Prompt input area
  Widget _buildPromptInput(bool isSmallScreen) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: promptController,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.white,
                ),
                maxLines: null,
                decoration: InputDecoration(
                  hintText: 'Describe the activity you want to create...',
                  hintStyle: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  // Trigger rebuild when text changes
                  setState(() {});
                },
                onSubmitted: (_) {
                  if (_isFormValid && !_isGenerating) {
                    _generateActivity();
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          AnimatedButton(
            width: 50,
            height: 50,
            color: _isFormValid && !_isGenerating
                ? Colors.deepPurple
                : Colors.grey,
            onPressed: _isFormValid && !_isGenerating
                ? _generateActivity
                : () {},
            child: _isGenerating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(
                    Icons.send,
                    color: Colors.white,
                    size: 24,
                  ),
          ),
        ],
      ),
    );
  }

  // Drag and Drop Section
  Widget _buildDragDropSection(bool isSmallScreen) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2C2A),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Images Section
          Text(
            'Upload Images',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 15),
          
          GestureDetector(
            onTap: _pickImages,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      uploadedImages.isEmpty ? Icons.image : Icons.check_circle,
                      size: 40,
                      color: uploadedImages.isEmpty ? Colors.white.withOpacity(0.5) : Colors.green,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      uploadedImages.isEmpty
                          ? 'Click to upload images'
                          : selectedFolder ?? 'Images uploaded',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          if (uploadedImages.isNotEmpty) ...[
            const SizedBox(height: 15),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: List.generate(
                uploadedImages.length > 5 ? 5 : uploadedImages.length,
                (index) => Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      uploadedImages[index],
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
            if (uploadedImages.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  '+${uploadedImages.length - 5} more images',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
              ),
          ],
          
          const SizedBox(height: 25),
          Divider(color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 20),
          
          // Document Section
          Row(
            children: [
              Text(
                'Upload Document',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'AI Powered',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.deepPurple.shade200,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Upload PDF, DOCX, or PPT files. AI will analyze the content to create activities.',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 15),
          
          GestureDetector(
            onTap: _isAnalyzingDocument ? null : _pickDocument,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: uploadedDocumentBytes != null 
                    ? Colors.green.withOpacity(0.1)
                    : Colors.deepPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: uploadedDocumentBytes != null 
                      ? Colors.green.withOpacity(0.5)
                      : Colors.deepPurple.withOpacity(0.5),
                  width: 2,
                ),
              ),
              child: _isAnalyzingDocument
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 30,
                            height: 30,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Analyzing document...',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            uploadedDocumentBytes == null 
                                ? Icons.description 
                                : Icons.check_circle,
                            size: 40,
                            color: uploadedDocumentBytes == null 
                                ? Colors.deepPurple.withOpacity(0.7)
                                : Colors.green,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            uploadedDocumentBytes == null
                                ? 'Click to upload PDF, DOCX, or PPT'
                                : uploadedDocumentName ?? 'Document uploaded',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                          if (uploadedDocumentBytes == null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Supported: .pdf, .doc, .docx, .ppt, .pptx',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.white.withOpacity(0.4),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ),
          
          // Document info and remove button
          if (uploadedDocumentBytes != null && !_isAnalyzingDocument) ...[
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    _getDocumentIcon(uploadedDocumentExtension),
                    color: Colors.green,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          uploadedDocumentName ?? 'Document',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          extractedDocumentContent != null 
                              ? 'Content extracted successfully'
                              : 'Processing...',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.green.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _removeDocument,
                    icon: const Icon(Icons.close, color: Colors.red, size: 20),
                    tooltip: 'Remove document',
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Get icon based on document type
  IconData _getDocumentIcon(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.article;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      default:
        return Icons.description;
    }
  }

  // Game Type Section
  Widget _buildGameTypeSection(bool isSmallScreen) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2C2A),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Game Types *',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 15),
          
          Container(
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButton<String>(
              value: null,
              hint: Text(
                'Select a game type to add',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
              dropdownColor: Colors.white,
              underline: const SizedBox(),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.black,
                fontWeight: FontWeight.w500,
              ),
              isExpanded: true,
              items: [
                const DropdownMenuItem(value: 'Fill in the blank', child: Text('Fill in the blank')),
                DropdownMenuItem(
                  value: 'Fill in the blank 2',
                  child: Row(
                    children: [
                      const Text('Fill in the blank 2'),
                      const SizedBox(width: 8),
                      Icon(Icons.image, size: 16, color: Colors.orange.withOpacity(0.7)),
                    ],
                  ),
                ),
                const DropdownMenuItem(value: 'Guess the answer', child: Text('Guess the answer')),
                DropdownMenuItem(
                  value: 'Guess the answer 2',
                  child: Row(
                    children: [
                      const Text('Guess the answer 2'),
                      const SizedBox(width: 8),
                      Icon(Icons.image, size: 16, color: Colors.orange.withOpacity(0.7)),
                    ],
                  ),
                ),
                const DropdownMenuItem(value: 'Read the sentence', child: Text('Read the sentence')),
                DropdownMenuItem(
                  value: 'What is it called',
                  child: Row(
                    children: [
                      const Text('What is it called'),
                      const SizedBox(width: 8),
                      Icon(Icons.image, size: 16, color: Colors.orange.withOpacity(0.7)),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'Listen and Repeat',
                  child: Row(
                    children: [
                      const Text('Listen and Repeat'),
                      const SizedBox(width: 8),
                      Icon(Icons.image, size: 16, color: Colors.orange.withOpacity(0.7)),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'Image Match',
                  child: Row(
                    children: [
                      const Text('Image Match'),
                      const SizedBox(width: 8),
                      Icon(Icons.image, size: 16, color: Colors.orange.withOpacity(0.7)),
                    ],
                  ),
                ),
                const DropdownMenuItem(value: 'Math', child: Text('Math')),
                const DropdownMenuItem(value: 'Stroke', child: Text('Stroke')),
              ],
              onChanged: (String? value) {
                if (value != null) {
                  _addGameType(value);
                }
              },
            ),
          ),
          
          const SizedBox(height: 15),
          
          if (selectedGameTypes.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Center(
                child: Text(
                  'No game types selected',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: selectedGameTypes.map((gameType) {
                    final requiresImage = _imageRequiredGameTypes.contains(gameType);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: requiresImage 
                            ? Colors.orange.withOpacity(0.2)
                            : Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: requiresImage ? Colors.orange : Colors.green,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (requiresImage) ...[
                            Icon(
                              Icons.image,
                              size: 16,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            gameType,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _removeGameType(gameType),
                            child: const Icon(
                              Icons.close,
                              size: 18,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                
                // Show warning if any selected game type requires images
                if (selectedGameTypes.any((type) => _imageRequiredGameTypes.contains(type))) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.orange, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Game types with 🖼️ icon require manual image upload after generation',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.orange.shade200,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  // Difficulty Section
  Widget _buildDifficultySection(bool isSmallScreen) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2C2A),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Difficulty',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 15),
          Container(
            width: double.infinity,
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
              icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.black,
                fontWeight: FontWeight.w500,
              ),
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'easy', child: Text('Easy')),
                DropdownMenuItem(value: 'easy-normal', child: Text('Easy-Normal')),
                DropdownMenuItem(value: 'normal', child: Text('Normal')),
                DropdownMenuItem(value: 'hard', child: Text('Hard')),
                DropdownMenuItem(value: 'insane', child: Text('Insane')),
                DropdownMenuItem(value: 'brainstorm', child: Text('Brainstorm')),
                DropdownMenuItem(value: 'hard-brainstorm', child: Text('Hard Brainstorm')),
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
        ],
      ),
    );
  }

  // Game Rules Section
  Widget _buildGameRulesSection(bool isSmallScreen) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2C2A),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Game Rules',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 15),
          Container(
            width: double.infinity,
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
              icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
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
        ],
      ),
    );
  }

  // Total Page Section
  Widget _buildTotalPageSection(bool isSmallScreen) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2C2A),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Page Count *',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 15),
          Container(
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: totalPageController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.black,
              ),
              decoration: InputDecoration(
                hintText: 'Enter number of pages (e.g., 5)',
                hintStyle: GoogleFonts.poppins(
                  color: Colors.black54,
                  fontSize: 14,
                ),
                border: InputBorder.none,
              ),
              onChanged: (value) {
                setState(() {});
              },
            ),
          ),
        ],
      ),
    );
  }

  // Generate Button with Animation
  Widget _buildGenerateButton() {
    final bool isEnabled = _isFormValid && !_isGenerating;
    
    return Center(
      child: AnimatedOpacity(
        opacity: isEnabled ? 1.0 : 0.5,
        duration: const Duration(milliseconds: 300),
        child: ScaleTransition(
          scale: isEnabled ? _scaleAnimation : const AlwaysStoppedAnimation(1.0),
          child: AnimatedButton(
            width: 200,
            height: 60,
            color: isEnabled ? Colors.deepPurple : Colors.grey,
            onPressed: isEnabled ? _generateActivity : () {},
            child: _isGenerating
                ? const SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        color: isEnabled ? Colors.white : Colors.white.withOpacity(0.5),
                        size: 28,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Generate',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isEnabled ? Colors.white : Colors.white.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
