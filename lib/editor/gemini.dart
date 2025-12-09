// ignore_for_file: avoid_print, prefer_interpolation_to_compose_strings, unnecessary_import

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdf/pdf.dart';

class GeminiService {
  static const String apiKey = 'AIzaSyAf2aDVAN2PPf1Xpjb_JXuV_LAgPBwrAFc';
  // Using latest Gemini 2.0 Flash model (fastest and most cost-effective)
  static const String baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent';
  static const String visionUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent';

  /// Extract text from PDF file
  Future<String> extractTextFromPdf(Uint8List pdfBytes) async {
    try {
      final PdfDocument document = PdfDocument(inputBytes: pdfBytes);
      String extractedText = '';
      
      for (int i = 0; i < document.pages.count; i++) {
        final PdfTextExtractor extractor = PdfTextExtractor(document);
        extractedText += extractor.extractText(startPageIndex: i, endPageIndex: i);
        extractedText += '\n\n--- Page ${i + 1} ---\n\n';
      }
      
      document.dispose();
      return extractedText.trim();
    } catch (e) {
      print('Error extracting PDF text: $e');
      return '';
    }
  }

  /// Extract text from DOCX file (basic extraction)
  Future<String> extractTextFromDocx(Uint8List docxBytes) async {
    try {
      // DOCX is a ZIP file containing XML
      // For basic extraction, we'll try to get the document.xml content
      final String content = utf8.decode(docxBytes, allowMalformed: true);
      
      // Extract text between XML tags (simplified approach)
      final RegExp textPattern = RegExp(r'<w:t[^>]*>([^<]*)</w:t>');
      final matches = textPattern.allMatches(content);
      
      String extractedText = '';
      for (final match in matches) {
        if (match.group(1) != null) {
          extractedText += match.group(1)! + ' ';
        }
      }
      
      return extractedText.trim().isEmpty 
          ? 'Document content could not be fully extracted. Please provide additional context.'
          : extractedText.trim();
    } catch (e) {
      print('Error extracting DOCX text: $e');
      return '';
    }
  }

  /// Extract text from PPT/PPTX file (basic extraction)
  Future<String> extractTextFromPpt(Uint8List pptBytes) async {
    try {
      final String content = utf8.decode(pptBytes, allowMalformed: true);
      
      // Extract text from PowerPoint XML
      final RegExp textPattern = RegExp(r'<a:t>([^<]*)</a:t>');
      final matches = textPattern.allMatches(content);
      
      String extractedText = '';
      for (final match in matches) {
        if (match.group(1) != null) {
          extractedText += match.group(1)! + ' ';
        }
      }
      
      return extractedText.trim().isEmpty 
          ? 'Presentation content could not be fully extracted. Please provide additional context.'
          : extractedText.trim();
    } catch (e) {
      print('Error extracting PPT text: $e');
      return '';
    }
  }

  /// Analyze document and extract content for activity generation
  Future<Map<String, dynamic>> analyzeDocument({
    required Uint8List fileBytes,
    required String fileName,
    required String fileExtension,
  }) async {
    try {
      String extractedText = '';
      
      // Extract text based on file type
      switch (fileExtension.toLowerCase()) {
        case 'pdf':
          extractedText = await extractTextFromPdf(fileBytes);
          break;
        case 'docx':
        case 'doc':
          extractedText = await extractTextFromDocx(fileBytes);
          break;
        case 'pptx':
        case 'ppt':
          extractedText = await extractTextFromPpt(fileBytes);
          break;
        default:
          return {
            'success': false,
            'error': 'Unsupported file type: $fileExtension',
          };
      }

      if (extractedText.isEmpty) {
        return {
          'success': false,
          'error': 'Could not extract text from the document',
        };
      }

      // Limit text length to avoid token limits
      if (extractedText.length > 10000) {
        extractedText = extractedText.substring(0, 10000) + '... [truncated]';
      }

      return {
        'success': true,
        'text': extractedText,
        'fileName': fileName,
        'fileType': fileExtension,
      };
    } catch (e) {
      print('Error analyzing document: $e');
      return {
        'success': false,
        'error': 'Failed to analyze document: $e',
      };
    }
  }

  /// Generate activity plan (first step - for confirmation)
  Future<Map<String, dynamic>> generateActivityPlan({
    required String userPrompt,
    List<String>? imageDescriptions,
    String? documentContent,
    String? documentFileName,
  }) async {
    try {
      final String systemPrompt = '''
You are an educational game activity planner. Based on the user's request, create a HIGH-LEVEL PLAN for a game activity.

IMPORTANT: This is just a PLAN for the user to review and confirm. Do NOT create detailed page content yet.

USER REQUEST: $userPrompt

${imageDescriptions != null && imageDescriptions.isNotEmpty ? 'AVAILABLE IMAGES: ${imageDescriptions.length} images provided' : ''}

${documentContent != null && documentContent.isNotEmpty ? '''
DOCUMENT SOURCE:
File: ${documentFileName ?? 'Unknown'}
Content: $documentContent

Use this document as the primary source for the activity content.
''' : ''}

CRITICAL RULES - FOLLOW USER COMMANDS EXACTLY:
1. **Game Types**: 
   - ONLY use game types explicitly mentioned by the user
   - If user specifies game types, use ONLY those types - DO NOT add others
   - If user doesn't specify, ask them to specify or suggest 1-2 appropriate types
   - Available types: [Fill in the blank, Fill in the blank 2, Guess the answer, Guess the answer 2, Read the sentence, What is it called, Listen and Repeat, Image Match, Math, Stroke]

2. **Difficulty**: 
   - Use the difficulty level specified by the user
   - If not specified, default to "easy"
   - Options: [easy, easy-normal, normal, hard, insane, brainstorm, hard-brainstorm]

3. **Game Rules**: 
   - Use the game rule specified by the user
   - If not specified, default to "none"
   - Options: [none, heart, timer, score]

4. **Total Pages**: 
   - Use the exact number of pages specified by the user
   - If not specified, default to 5 pages

5. **Game Metadata (Column 1)**:
   - Generate appropriate title and description based on the activity content
   - These will be used to update the game editor's Column 1 fields
   - Title should be concise and descriptive (max 50 characters)
   - Description should explain what the activity teaches (max 200 characters)

6. **Optional Advanced Settings** (ONLY if user explicitly requests):
   - **prizeCoins**: Number of coins to award (e.g., 100, 500, 1000)
   - **gameSet**: "public" or "private" (default: "public")
   - **gameCode**: 6-digit code for private games (e.g., "123456")
   - **heart**: true/false for heart deduction rule
   - **timer**: Number of seconds for timer countdown (e.g., 60, 120, 300)

IMPORTANT: 
- DO NOT randomly add game types or change user specifications
- ONLY include advanced settings if user explicitly mentions them
- Follow user commands exactly!

You MUST respond with ONLY valid JSON (no markdown, no code blocks):
{
  "title": "Activity title",
  "description": "Brief description of what this activity will teach",
  "gameTypes": ["Type1", "Type2"],
  "difficulty": "difficulty level",
  "gameRule": "rule type",
  "totalPages": 5,
  "prizeCoins": 100,
  "gameSet": "public",
  "gameCode": "",
  "heart": false,
  "timer": 0,
  "reasoning": "Explain why you chose these settings and what the activity will cover"
}

FIELD RULES:
- prizeCoins: ONLY include if user mentions rewards/coins/points (default: omit)
- gameSet: ONLY include if user mentions public/private (default: omit)
- gameCode: ONLY include if gameSet is "private" (6-digit number as string)
- heart: ONLY include if user mentions lives/hearts/health (default: omit)
- timer: ONLY include if user mentions time limit/countdown (in seconds, default: omit)

Create a clear, educational plan that the user can review before we generate the full activity.
''';

      debugPrint('=== Generating Activity Plan ===');
      
      final requestUrl = '$baseUrl?key=$apiKey';
      final requestBody = {
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': systemPrompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.7,
          'topK': 40,
          'topP': 0.95,
          'maxOutputTokens': 2048,
        },
        'safetySettings': [
          {
            'category': 'HARM_CATEGORY_HARASSMENT',
            'threshold': 'BLOCK_ONLY_HIGH'
          },
          {
            'category': 'HARM_CATEGORY_HATE_SPEECH',
            'threshold': 'BLOCK_ONLY_HIGH'
          },
          {
            'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
            'threshold': 'BLOCK_ONLY_HIGH'
          },
          {
            'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
            'threshold': 'BLOCK_ONLY_HIGH'
          }
        ]
      };
      
      final response = await http.post(
        Uri.parse(requestUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timed out');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['candidates'] == null || (data['candidates'] as List).isEmpty) {
          return {
            'success': false,
            'error': 'AI did not generate a response.',
            'details': response.body,
          };
        }
        
        final candidate = data['candidates'][0];
        final content = candidate['content'];
        if (content == null || content['parts'] == null) {
          return {
            'success': false,
            'error': 'Empty response from AI.',
          };
        }
        
        String generatedText = content['parts'][0]['text'] as String;
        
        // Clean markdown
        generatedText = generatedText.trim();
        if (generatedText.startsWith('```json')) {
          generatedText = generatedText.substring(7);
        } else if (generatedText.startsWith('```')) {
          generatedText = generatedText.substring(3);
        }
        if (generatedText.endsWith('```')) {
          generatedText = generatedText.substring(0, generatedText.length - 3);
        }
        generatedText = generatedText.trim();
        
        try {
          final result = jsonDecode(generatedText);
          debugPrint('✅ Activity plan generated successfully');
          return {
            'success': true,
            'data': result,
          };
        } catch (e) {
          final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(generatedText);
          if (jsonMatch != null) {
            try {
              final result = jsonDecode(jsonMatch.group(0)!);
              return {
                'success': true,
                'data': result,
              };
            } catch (parseError) {
              return {
                'success': false,
                'error': 'Failed to parse plan',
                'details': 'Parse error: $parseError',
              };
            }
          }
          return {
            'success': false,
            'error': 'Failed to parse plan',
          };
        }
      } else {
        return {
          'success': false,
          'error': 'API request failed: ${response.statusCode}',
          'details': response.body,
        };
      }
    } catch (e) {
      debugPrint('❌ Exception in generateActivityPlan: $e');
      return {
        'success': false,
        'error': 'Failed to generate plan: $e',
      };
    }
  }

  /// Generate full activity from confirmed plan (second step)
  Future<Map<String, dynamic>> generateFullActivity({
    required Map<String, dynamic> activityPlan,
  }) async {
    try {
      final String systemPrompt = '''
You are an educational game activity generator. The user has confirmed this activity plan:

CONFIRMED PLAN:
${jsonEncode(activityPlan)}

Now generate the COMPLETE activity with detailed content for each page.

CRITICAL RULES - FOLLOW THE PLAN EXACTLY:
1. Use ONLY the game types specified in the plan: ${jsonEncode(activityPlan['gameTypes'])}
2. Create exactly ${activityPlan['totalPages']} pages
3. Cycle through the specified game types in order
4. DO NOT add or substitute different game types

You MUST respond with ONLY valid JSON (no markdown, no code blocks):
{
  "title": "${activityPlan['title']}",
  "description": "${activityPlan['description']}",
  "gameTypes": ${jsonEncode(activityPlan['gameTypes'])},
  "difficulty": "${activityPlan['difficulty']}",
  "gameRule": "${activityPlan['gameRule']}",
  "totalPages": ${activityPlan['totalPages']},
  ${activityPlan['prizeCoins'] != null ? '"prizeCoins": ${activityPlan['prizeCoins']},' : ''}
  ${activityPlan['gameSet'] != null ? '"gameSet": "${activityPlan['gameSet']}",' : ''}
  ${activityPlan['gameCode'] != null ? '"gameCode": "${activityPlan['gameCode']}",' : ''}
  ${activityPlan['heart'] != null ? '"heart": ${activityPlan['heart']},' : ''}
  ${activityPlan['timer'] != null ? '"timer": ${activityPlan['timer']},' : ''}
  "pages": [
    {
      "pageNumber": 1,
      "gameType": "specific game type for this page",
      "content": "detailed question or content",
      "answer": "correct answer (string for text, number for math)",
      "hint": "helpful hint",
      "choices": ["choice1", "choice2", "choice3", "choice4"],
      "correctAnswerIndex": 0,
      "showImageHint": false,
      "visibleLetters": [true, false, true, false],
      "totalBoxes": 2,
      "boxValues": [5, 3],
      "operators": ["+"],
      "imageCount": 2
    }
  ],
  "reasoning": "${activityPlan['reasoning']}"
}

IMPORTANT: Include prizeCoins, gameSet, gameCode, heart, and timer fields ONLY if they were specified in the confirmed plan.

PAGE FIELD REQUIREMENTS BY GAME TYPE:
- Fill in the blank: answer, hint, visibleLetters (array of booleans)
- Fill in the blank 2: answer, hint, visibleLetters
- Guess the answer: content, hint, choices, correctAnswerIndex, showImageHint (SET TO FALSE!)
- Guess the answer 2: content, hint, choices, correctAnswerIndex
- Read the sentence: content (the sentence)
- What is it called: answer, hint
- Listen and Repeat: answer
- Image Match: imageCount (2, 4, 6, or 8)
- Math: totalBoxes, boxValues, operators, answer (number)
- Stroke: content (description)

GAME TYPE REQUIREMENTS (follow these EXACTLY for each game type):

1. "Fill in the blank":
   - answer: The word to fill in (string)
   - hint: A helpful hint for the player (string)
   - visibleLetters: Array of booleans indicating which letters are visible (e.g., [true, false, true, false] for a 4-letter word)
   - AI should hide 30-70% of letters based on difficulty

2. "Fill in the blank 2":
   - answer: The word to fill in (string)
   - hint: A helpful hint for the player (string)
   - visibleLetters: Array of booleans for letter visibility
   - requiresImage: true (image must be added manually later)

3. "Guess the answer":
   - content: The question text (string)
   - hint: A helpful hint (string)
   - choices: Array of exactly 4 choices ["choice1", "choice2", "choice3", "choice4"]
   - correctAnswerIndex: Index of correct answer (0-3)
   - showImageHint: boolean - SET TO FALSE if the question is text-based and doesn't need an image hint
   - AI should set showImageHint to false for most text-based questions

4. "Guess the answer 2":
   - content: The question text (string)
   - hint: A helpful hint (string)
   - choices: Array of exactly 4 choices
   - correctAnswerIndex: Index of correct answer (0-3)
   - requiresImage: true (3 images must be added manually)

5. "Read the sentence":
   - content: The sentence to read aloud (string)
   - No additional configuration needed

6. "What is it called":
   - answer: The word/name to identify (string)
   - hint: A helpful hint (string)
   - requiresImage: true (image must be added manually)

7. "Listen and Repeat":
   - answer: The word/phrase to repeat (string)
   - requiresAudio: true (audio must be added manually)

8. "Image Match":
   - imageCount: Number of image pairs (2, 4, 6, or 8)
   - requiresImage: true (images must be added manually)
   - imageMappings: Will be configured manually

9. "Math":
   - totalBoxes: Number of operand boxes (1-10)
   - boxValues: Array of NUMBERS ONLY (e.g., [5, 3, 2] for 3 boxes) - NO STRINGS!
   - operators: Array of operators - ONLY use ["+", "-", "×", "÷"] or ["*", "/"] (will be converted)
   - answer: The calculated result (MUST be a number, not a string)
   - CRITICAL: boxValues must contain ONLY numeric values, no text or strings!
   - Example: {"totalBoxes": 3, "boxValues": [10, 2, 5], "operators": ["÷", "+"], "answer": 10}

10. "Stroke":
    - content: Description of what to trace (string)
    - requiresImage: true (stroke image must be added manually)

IMPORTANT AI DECISIONS:
- For "Guess the answer": Always set showImageHint to FALSE unless the question specifically requires visual context
- For "Fill in the blank": Hide more letters for harder difficulties
- For "Math": 
  * Use simpler operations (+, -) for easy difficulty, include (×, ÷) for harder
  * boxValues MUST be numbers: [5, 3] NOT ["5", "3"]
  * operators array length must equal totalBoxes - 1
  * Calculate answer correctly and provide as a number
  * AI can freely change operators to create different math problems
- Set correctAnswerIndex randomly between 0-3 to avoid patterns

Generate exactly ${activityPlan['totalPages']} pages with educational, engaging content.
Use ONLY the game types from the plan, cycling through them in order.
''';

      debugPrint('=== Generating Full Activity ===');
      
      final requestUrl = '$baseUrl?key=$apiKey';
      final requestBody = {
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': systemPrompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.8,
          'topK': 40,
          'topP': 0.95,
          'maxOutputTokens': 8192,
        },
        'safetySettings': [
          {
            'category': 'HARM_CATEGORY_HARASSMENT',
            'threshold': 'BLOCK_ONLY_HIGH'
          },
          {
            'category': 'HARM_CATEGORY_HATE_SPEECH',
            'threshold': 'BLOCK_ONLY_HIGH'
          },
          {
            'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
            'threshold': 'BLOCK_ONLY_HIGH'
          },
          {
            'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
            'threshold': 'BLOCK_ONLY_HIGH'
          }
        ]
      };
      
      final response = await http.post(
        Uri.parse(requestUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw Exception('Request timed out');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['candidates'] == null || (data['candidates'] as List).isEmpty) {
          return {
            'success': false,
            'error': 'AI did not generate activity.',
          };
        }
        
        final candidate = data['candidates'][0];
        final content = candidate['content'];
        if (content == null || content['parts'] == null) {
          return {
            'success': false,
            'error': 'Empty response from AI.',
          };
        }
        
        String generatedText = content['parts'][0]['text'] as String;
        
        // Clean markdown
        generatedText = generatedText.trim();
        if (generatedText.startsWith('```json')) {
          generatedText = generatedText.substring(7);
        } else if (generatedText.startsWith('```')) {
          generatedText = generatedText.substring(3);
        }
        if (generatedText.endsWith('```')) {
          generatedText = generatedText.substring(0, generatedText.length - 3);
        }
        generatedText = generatedText.trim();
        
        try {
          final result = jsonDecode(generatedText);
          debugPrint('✅ Full activity generated successfully');
          return {
            'success': true,
            'data': result,
          };
        } catch (e) {
          final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(generatedText);
          if (jsonMatch != null) {
            try {
              final result = jsonDecode(jsonMatch.group(0)!);
              return {
                'success': true,
                'data': result,
              };
            } catch (parseError) {
              return {
                'success': false,
                'error': 'Failed to parse activity',
              };
            }
          }
          return {
            'success': false,
            'error': 'Failed to parse activity',
          };
        }
      } else {
        return {
          'success': false,
          'error': 'API request failed: ${response.statusCode}',
          'details': response.body,
        };
      }
    } catch (e) {
      debugPrint('❌ Exception in generateFullActivity: $e');
      return {
        'success': false,
        'error': 'Failed to generate activity: $e',
      };
    }
  }

  /// Generate game activity content based on user prompt (LEGACY - kept for compatibility)
  Future<Map<String, dynamic>> generateGameActivity({
    required String userPrompt,
    List<String>? imageDescriptions,
    String? documentContent,
    String? documentFileName,
  }) async {
    try {
      // Construct the prompt with specific requirements
      final String systemPrompt = '''
You are an educational game activity generator. Based on the user's request, generate a structured game activity with the following requirements:

REQUIRED FIELDS (if not specified by user, make intelligent defaults):
1. Game Types: Choose from [Fill in the blank, Fill in the blank 2, Guess the answer, Guess the answer 2, Read the sentence, What is it called, Listen and Repeat, Image Match, Math, Stroke]
2. Difficulty: Choose from [easy, easy-normal, normal, hard, insane, brainstorm, hard-brainstorm]
3. Game Rules: Choose from [none, heart, timer, score]
4. Total Pages: Number of activity pages (default: 5)

USER REQUEST: $userPrompt

${imageDescriptions != null && imageDescriptions.isNotEmpty ? 'AVAILABLE IMAGES: ${imageDescriptions.length} images provided' : ''}

${documentContent != null && documentContent.isNotEmpty ? '''
DOCUMENT SOURCE (Use this content as the primary source for creating the activity):
File: ${documentFileName ?? 'Unknown'}
Content:
$documentContent

IMPORTANT: Create the activity based on the topics, concepts, and information found in this document. Extract key learning points, vocabulary, facts, or problems from the document to create engaging educational activities.
''' : ''}

You MUST respond with ONLY valid JSON in this exact format (no markdown, no code blocks, just pure JSON):
{
  "title": "Activity title",
  "description": "Brief description of the activity",
  "gameTypes": ["Game Type 1", "Game Type 2"],
  "difficulty": "difficulty level",
  "gameRule": "rule type",
  "totalPages": 5,
  "pages": [
    {
      "pageNumber": 1,
      "gameType": "specific game type for this page",
      "content": "page-specific content or question",
      "answer": "correct answer (string for text, number for math)",
      "hint": "helpful hint if applicable",
      "choices": ["choice1", "choice2", "choice3", "choice4"],
      "correctAnswerIndex": 0,
      "showImageHint": false,
      "visibleLetters": [true, false, true],
      "totalBoxes": 2,
      "boxValues": [5, 3],
      "operators": ["+"],
      "imageCount": 2
    }
  ],
  "reasoning": "Brief explanation of your choices"
}

IMPORTANT FIELD RULES:
- For "Guess the answer": ALWAYS set showImageHint to FALSE (no image needed for text questions)
- For "Fill in the blank": visibleLetters array must match answer length
- For "Math": answer must be a number (the calculated result)
- correctAnswerIndex: randomly choose 0-3 to avoid patterns

Generate a complete, educational, and engaging activity based on the user's request${documentContent != null ? ' and the provided document content' : ''}.
''';

      final requestUrl = '$baseUrl?key=$apiKey';
      debugPrint('=== Gemini API Request ===');
      debugPrint('URL: ${requestUrl.replaceAll(apiKey, 'API_KEY_HIDDEN')}');
      debugPrint('Prompt length: ${systemPrompt.length} characters');
      
      final requestBody = {
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': systemPrompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.7,
          'topK': 40,
          'topP': 0.95,
          'maxOutputTokens': 8192,
        },
        'safetySettings': [
          {
            'category': 'HARM_CATEGORY_HARASSMENT',
            'threshold': 'BLOCK_ONLY_HIGH'
          },
          {
            'category': 'HARM_CATEGORY_HATE_SPEECH',
            'threshold': 'BLOCK_ONLY_HIGH'
          },
          {
            'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
            'threshold': 'BLOCK_ONLY_HIGH'
          },
          {
            'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
            'threshold': 'BLOCK_ONLY_HIGH'
          }
        ]
      };
      
      debugPrint('Request body size: ${jsonEncode(requestBody).length} bytes');
      
      final response = await http.post(
        Uri.parse(requestUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw Exception('Request timed out. Please try again.');
        },
      );

      debugPrint('=== Gemini API Response ===');
      debugPrint('Status: ${response.statusCode}');
      debugPrint('Response body length: ${response.body.length} bytes');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('Response parsed successfully');
        
        // Check if candidates exist
        if (data['candidates'] == null || (data['candidates'] as List).isEmpty) {
          debugPrint('❌ No candidates in response');
          debugPrint('Full response: ${response.body}');
          return {
            'success': false,
            'error': 'AI did not generate a response. Please try again.',
            'details': response.body,
          };
        }
        
        // Check for blocked content
        final candidate = data['candidates'][0];
        final finishReason = candidate['finishReason'];
        debugPrint('Finish reason: $finishReason');
        
        if (finishReason == 'SAFETY') {
          final safetyRatings = candidate['safetyRatings'];
          debugPrint('❌ Content blocked by safety filters');
          debugPrint('Safety ratings: $safetyRatings');
          return {
            'success': false,
            'error': 'Content was blocked by safety filters. Please modify your request.',
            'details': 'Safety ratings: $safetyRatings',
          };
        }
        
        // Get the generated text
        final content = candidate['content'];
        if (content == null || content['parts'] == null || (content['parts'] as List).isEmpty) {
          debugPrint('❌ Empty content in response');
          debugPrint('Candidate data: $candidate');
          return {
            'success': false,
            'error': 'Empty response from AI. Please try again.',
            'details': 'Candidate: $candidate',
          };
        }
        
        final generatedText = content['parts'][0]['text'] as String;
        debugPrint('✅ Generated text length: ${generatedText.length} characters');
        debugPrint('First 200 chars: ${generatedText.substring(0, generatedText.length > 200 ? 200 : generatedText.length)}');
        
        // Clean the response - remove markdown code blocks if present
        String cleanedText = generatedText.trim();
        if (cleanedText.startsWith('```json')) {
          cleanedText = cleanedText.substring(7);
        } else if (cleanedText.startsWith('```')) {
          cleanedText = cleanedText.substring(3);
        }
        if (cleanedText.endsWith('```')) {
          cleanedText = cleanedText.substring(0, cleanedText.length - 3);
        }
        cleanedText = cleanedText.trim();
        
        // Extract JSON from the response
        try {
          // Try to parse directly first
          debugPrint('Attempting to parse JSON directly...');
          final result = jsonDecode(cleanedText);
          debugPrint('✅ JSON parsed successfully!');
          return {
            'success': true,
            'data': result,
          };
        } catch (e) {
          debugPrint('❌ Direct JSON parse failed: $e');
          debugPrint('Attempting to extract JSON from text...');
          
          // If direct parse fails, try to find JSON object in the text
          final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(cleanedText);
          if (jsonMatch != null) {
            try {
              final jsonString = jsonMatch.group(0)!;
              debugPrint('Found JSON match, length: ${jsonString.length}');
              final result = jsonDecode(jsonString);
              debugPrint('✅ Extracted JSON parsed successfully!');
              return {
                'success': true,
                'data': result,
              };
            } catch (parseError) {
              debugPrint('❌ JSON extraction parse error: $parseError');
              debugPrint('Cleaned text preview: ${cleanedText.substring(0, cleanedText.length > 500 ? 500 : cleanedText.length)}');
              return {
                'success': false,
                'error': 'Failed to parse AI response. The response format was invalid.',
                'details': 'Parse error: $parseError',
                'rawResponse': cleanedText.length > 1000 ? '${cleanedText.substring(0, 1000)}...' : cleanedText,
              };
            }
          } else {
            debugPrint('❌ No JSON object found in response');
            debugPrint('Cleaned text: $cleanedText');
            return {
              'success': false,
              'error': 'AI response was not in expected JSON format.',
              'details': 'No JSON object found in response',
              'rawResponse': cleanedText.length > 1000 ? '${cleanedText.substring(0, 1000)}...' : cleanedText,
            };
          }
        }
      } else if (response.statusCode == 400) {
        debugPrint('❌ API Error 400 - Bad Request');
        try {
          final errorData = jsonDecode(response.body);
          final errorMessage = errorData['error']?['message'] ?? 'Bad request';
          final errorDetails = errorData['error']?['details'] ?? '';
          debugPrint('Error message: $errorMessage');
          debugPrint('Error details: $errorDetails');
          return {
            'success': false,
            'error': 'Invalid request: $errorMessage',
            'details': response.body,
          };
        } catch (e) {
          return {
            'success': false,
            'error': 'Invalid request (400)',
            'details': response.body,
          };
        }
      } else if (response.statusCode == 403) {
        debugPrint('❌ API Error 403 - Forbidden');
        debugPrint('Response: ${response.body}');
        return {
          'success': false,
          'error': 'API key is invalid or has insufficient permissions.',
          'details': response.body,
        };
      } else if (response.statusCode == 429) {
        debugPrint('❌ API Error 429 - Too Many Requests');
        return {
          'success': false,
          'error': 'Too many requests. Please wait a moment and try again.',
          'details': response.body,
        };
      } else if (response.statusCode == 500 || response.statusCode == 503) {
        debugPrint('❌ API Error ${response.statusCode} - Server Error');
        return {
          'success': false,
          'error': 'AI service is temporarily unavailable. Please try again later.',
          'details': response.body,
        };
      } else {
        debugPrint('❌ API Error ${response.statusCode}');
        debugPrint('Response: ${response.body}');
        return {
          'success': false,
          'error': 'API request failed with status ${response.statusCode}',
          'details': response.body,
        };
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Exception in generateGameActivity: $e');
      debugPrint('Stack trace: $stackTrace');
      return {
        'success': false,
        'error': e.toString().contains('timed out') 
            ? 'Request timed out. Please try again.'
            : 'Failed to connect to AI service: $e',
        'details': 'Exception: $e\nStack: ${stackTrace.toString().substring(0, stackTrace.toString().length > 500 ? 500 : stackTrace.toString().length)}',
      };
    }
  }

  /// Analyze images and generate descriptions
  Future<List<String>> analyzeImages(List<String> base64Images) async {
    // Note: Gemini Pro Vision would be used here for image analysis
    // For now, return placeholder descriptions
    return List.generate(
      base64Images.length,
      (index) => 'Image ${index + 1}',
    );
  }

  /// Refine or regenerate specific aspects of the activity
  Future<Map<String, dynamic>> refineActivity({
    required String originalActivity,
    required String refinementRequest,
  }) async {
    try {
      final String prompt = '''
Original Activity:
$originalActivity

User Refinement Request:
$refinementRequest

Please modify the activity according to the user's request while maintaining the JSON structure.
Return ONLY valid JSON (no markdown, no code blocks) with the complete updated activity.
''';

      final response = await http.post(
        Uri.parse('$baseUrl?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'topK': 40,
            'topP': 0.95,
            'maxOutputTokens': 8192,
          },
          'safetySettings': [
            {
              'category': 'HARM_CATEGORY_HARASSMENT',
              'threshold': 'BLOCK_ONLY_HIGH'
            },
            {
              'category': 'HARM_CATEGORY_HATE_SPEECH',
              'threshold': 'BLOCK_ONLY_HIGH'
            },
            {
              'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
              'threshold': 'BLOCK_ONLY_HIGH'
            },
            {
              'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
              'threshold': 'BLOCK_ONLY_HIGH'
            }
          ]
        }),
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw Exception('Request timed out. Please try again.');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['candidates'] == null || (data['candidates'] as List).isEmpty) {
          return {
            'success': false,
            'error': 'AI did not generate a response. Please try again.',
          };
        }
        
        final candidate = data['candidates'][0];
        if (candidate['finishReason'] == 'SAFETY') {
          return {
            'success': false,
            'error': 'Content was blocked by safety filters.',
          };
        }
        
        final content = candidate['content'];
        if (content == null || content['parts'] == null) {
          return {
            'success': false,
            'error': 'Empty response from AI.',
          };
        }
        
        String generatedText = content['parts'][0]['text'] as String;
        
        // Clean markdown code blocks
        generatedText = generatedText.trim();
        if (generatedText.startsWith('```json')) {
          generatedText = generatedText.substring(7);
        } else if (generatedText.startsWith('```')) {
          generatedText = generatedText.substring(3);
        }
        if (generatedText.endsWith('```')) {
          generatedText = generatedText.substring(0, generatedText.length - 3);
        }
        generatedText = generatedText.trim();
        
        try {
          final result = jsonDecode(generatedText);
          return {
            'success': true,
            'data': result,
          };
        } catch (e) {
          final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(generatedText);
          if (jsonMatch != null) {
            try {
              final jsonString = jsonMatch.group(0)!;
              final result = jsonDecode(jsonString);
              return {
                'success': true,
                'data': result,
              };
            } catch (parseError) {
              return {
                'success': false,
                'error': 'Failed to parse AI response',
              };
            }
          }
          return {
            'success': false,
            'error': 'Failed to parse AI response',
          };
        }
      } else {
        debugPrint('Refine API Error ${response.statusCode}: ${response.body}');
        return {
          'success': false,
          'error': 'API request failed: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('Error refining activity: $e');
      return {
        'success': false,
        'error': 'Exception occurred: $e',
      };
    }
  }

  /// Generate activity for Edit Mode (without AI prompt, just structure)
  Future<Map<String, dynamic>> generateEditModeActivity({
    required List<String> gameTypes,
    required String difficulty,
    required String gameRule,
    required int totalPages,
    String? documentContent,
    String? documentFileName,
  }) async {
    try {
      final String prompt = '''
You are an educational game activity generator. Create a structured game activity with the following specifications:

SPECIFICATIONS:
- Game Types to use: ${gameTypes.join(', ')}
- Difficulty: $difficulty
- Game Rule: $gameRule
- Total Pages: $totalPages

${documentContent != null && documentContent.isNotEmpty ? '''
DOCUMENT SOURCE (Use this content as the primary source for creating the activity):
File: ${documentFileName ?? 'Unknown'}
Content:
$documentContent

IMPORTANT: Create the activity based on the topics, concepts, and information found in this document.
''' : 'Create educational content appropriate for the selected game types and difficulty level.'}

CRITICAL RULES - FOLLOW SPECIFICATIONS EXACTLY:
1. Use ONLY these game types: ${gameTypes.join(', ')}
2. Create exactly $totalPages pages
3. Cycle through the specified game types in order
4. DO NOT add or substitute different game types
5. Each page must use one of the specified game types

GAME TYPE REQUIREMENTS (follow these EXACTLY):

1. "Fill in the blank":
   - answer: The word to fill in (string)
   - hint: A helpful hint (string)
   - visibleLetters: Array of booleans [true/false] for each letter visibility
   - Hide 30-70% of letters based on difficulty

2. "Fill in the blank 2":
   - answer: The word to fill in (string)
   - hint: A helpful hint (string)
   - visibleLetters: Array of booleans for letter visibility
   - Note: Image required (will be added manually)

3. "Guess the answer":
   - content: The question text (string)
   - hint: A helpful hint (string)
   - choices: Array of exactly 4 choices
   - correctAnswerIndex: Index 0-3 of correct answer
   - showImageHint: SET TO FALSE for text-based questions (no image needed)

4. "Guess the answer 2":
   - content: The question text (string)
   - hint: A helpful hint (string)
   - choices: Array of exactly 4 choices
   - correctAnswerIndex: Index 0-3 of correct answer
   - Note: 3 images required (will be added manually)

5. "Read the sentence":
   - content: The sentence to read aloud (string)

6. "What is it called":
   - answer: The word/name to identify (string)
   - hint: A helpful hint (string)
   - Note: Image required (will be added manually)

7. "Listen and Repeat":
   - answer: The word/phrase to repeat (string)
   - Note: Audio required (will be added manually)

8. "Image Match":
   - imageCount: Number of image pairs (2, 4, 6, or 8)
   - Note: Images required (will be added manually)

9. "Math":
   - totalBoxes: Number of operand boxes (1-10)
   - boxValues: Array of NUMBERS ONLY (e.g., [5, 3, 2] for 3 boxes)
   - operators: Array of operators - ONLY use ["+", "-", "×", "÷"] or ["*", "/"] (will be converted)
   - answer: The calculated result (MUST be a number, not a string)
   - CRITICAL: boxValues must contain ONLY numeric values, no text or strings!

10. "Stroke":
    - content: Description of what to trace (string)
    - Note: Stroke image required (will be added manually)

IMPORTANT: For "Guess the answer", set showImageHint to FALSE unless visual context is essential!

You MUST respond with ONLY valid JSON (no markdown, no code blocks):
{
  "title": "Activity title based on content",
  "description": "Brief description",
  "gameTypes": ${jsonEncode(gameTypes)},
  "difficulty": "$difficulty",
  "gameRule": "$gameRule",
  "totalPages": $totalPages,
  "pages": [
    {
      "pageNumber": 1,
      "gameType": "one of the specified game types",
      "content": "question or content for this page",
      "answer": "correct answer (string for text, number for math)",
      "hint": "helpful hint",
      "choices": ["choice1", "choice2", "choice3", "choice4"],
      "correctAnswerIndex": 0,
      "showImageHint": false,
      "visibleLetters": [true, false, true, false],
      "totalBoxes": 2,
      "boxValues": [5, 3],
      "operators": ["+"],
      "imageCount": 2
    }
  ],
  "reasoning": "Brief explanation"
}

PAGE FIELD REQUIREMENTS BY GAME TYPE:
- Fill in the blank: answer, hint, visibleLetters (array of booleans matching answer length)
- Fill in the blank 2: answer, hint, visibleLetters
- Guess the answer: content, hint, choices (4 items), correctAnswerIndex (0-3), showImageHint (SET TO FALSE for text questions!)
- Guess the answer 2: content, hint, choices (4 items), correctAnswerIndex (0-3)
- Read the sentence: content (the sentence to read)
- What is it called: answer, hint
- Listen and Repeat: answer (word/phrase to repeat)
- Image Match: imageCount (2, 4, 6, or 8)
- Math: totalBoxes (1-10), boxValues (array of NUMBERS ONLY like [5, 3, 2]), operators (array like ["+", "-", "×", "÷"]), answer (calculated result as number)
- Stroke: content (description of what to trace)

DIFFICULTY-BASED RULES:
- easy: For "Fill in the blank", show 70% of letters. For "Math", use only + and - with small numbers (1-10)
- normal: For "Fill in the blank", show 50% of letters. For "Math", use +, -, × with numbers up to 20
- hard: For "Fill in the blank", show 30% of letters. For "Math", use all operators (+, -, ×, ÷) with larger numbers

MATH GAME TYPE EXAMPLES:
- Easy: {"totalBoxes": 2, "boxValues": [5, 3], "operators": ["+"], "answer": 8}
- Normal: {"totalBoxes": 3, "boxValues": [10, 5, 2], "operators": ["-", "×"], "answer": 10}
- Hard: {"totalBoxes": 4, "boxValues": [20, 4, 3, 2], "operators": ["÷", "+", "×"], "answer": 11}

CRITICAL FOR MATH: 
- boxValues MUST be an array of numbers: [5, 3, 2] NOT ["5", "3", "2"]
- operators MUST match totalBoxes - 1 (e.g., 3 boxes need 2 operators)
- answer MUST be the correct calculated result as a number

Generate exactly $totalPages pages, cycling through ONLY these game types in order: ${gameTypes.join(', ')}
DO NOT use any game types not in this list!
''';

      debugPrint('Generating Edit Mode activity with Gemini...');
      
      final response = await http.post(
        Uri.parse('$baseUrl?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.8,
            'topK': 40,
            'topP': 0.95,
            'maxOutputTokens': 8192,
          },
          'safetySettings': [
            {
              'category': 'HARM_CATEGORY_HARASSMENT',
              'threshold': 'BLOCK_ONLY_HIGH'
            },
            {
              'category': 'HARM_CATEGORY_HATE_SPEECH',
              'threshold': 'BLOCK_ONLY_HIGH'
            },
            {
              'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
              'threshold': 'BLOCK_ONLY_HIGH'
            },
            {
              'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
              'threshold': 'BLOCK_ONLY_HIGH'
            }
          ]
        }),
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw Exception('Request timed out. Please try again.');
        },
      );

      debugPrint('Edit Mode API response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['candidates'] == null || (data['candidates'] as List).isEmpty) {
          return {
            'success': false,
            'error': 'AI did not generate a response.',
          };
        }
        
        final candidate = data['candidates'][0];
        if (candidate['finishReason'] == 'SAFETY') {
          return {
            'success': false,
            'error': 'Content was blocked by safety filters.',
          };
        }
        
        final content = candidate['content'];
        if (content == null || content['parts'] == null) {
          return {
            'success': false,
            'error': 'Empty response from AI.',
          };
        }
        
        String generatedText = content['parts'][0]['text'] as String;
        
        // Clean markdown
        generatedText = generatedText.trim();
        if (generatedText.startsWith('```json')) {
          generatedText = generatedText.substring(7);
        } else if (generatedText.startsWith('```')) {
          generatedText = generatedText.substring(3);
        }
        if (generatedText.endsWith('```')) {
          generatedText = generatedText.substring(0, generatedText.length - 3);
        }
        generatedText = generatedText.trim();
        
        try {
          final result = jsonDecode(generatedText);
          return {
            'success': true,
            'data': result,
          };
        } catch (e) {
          final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(generatedText);
          if (jsonMatch != null) {
            try {
              final result = jsonDecode(jsonMatch.group(0)!);
              return {
                'success': true,
                'data': result,
              };
            } catch (parseError) {
              debugPrint('JSON parse error: $parseError');
            }
          }
          return {
            'success': false,
            'error': 'Failed to parse AI response.',
          };
        }
      } else {
        debugPrint('Edit Mode API Error: ${response.statusCode} - ${response.body}');
        return {
          'success': false,
          'error': 'API request failed: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('Error in generateEditModeActivity: $e');
      return {
        'success': false,
        'error': e.toString().contains('timed out')
            ? 'Request timed out. Please try again.'
            : 'Failed to generate activity: $e',
      };
    }
  }
}
