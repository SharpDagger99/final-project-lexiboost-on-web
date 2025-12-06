// ignore_for_file: avoid_print, prefer_interpolation_to_compose_strings

import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdf/pdf.dart';

class GeminiService {
  static const String apiKey = 'AIzaSyAf2aDVAN2PPf1Xpjb_JXuV_LAgPBwrAFc';
  static const String baseUrl = 'https://generativelanguage.googleapis.com/v1/models/gemini-1.5-pro-latest:generateContent';
  static const String visionUrl = 'https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash-latest:generateContent';

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

  /// Generate game activity content based on user prompt
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

RESPONSE FORMAT (JSON):
{
  "title": "Activity title",
  "description": "Brief description of the activity",
  "gameTypes": ["Game Type 1", "Game Type 2"],
  "difficulty": "difficulty level",
  "gameRule": "rule type",
  "totalPages": number,
  "pages": [
    {
      "pageNumber": 1,
      "gameType": "specific game type for this page",
      "content": "page-specific content or question",
      "answer": "correct answer if applicable",
      "hint": "helpful hint if applicable",
      "choices": ["choice1", "choice2", "choice3"] // for multiple choice games
    }
  ],
  "reasoning": "Brief explanation of your choices"
}

Generate a complete, educational, and engaging activity based on the user's request${documentContent != null ? ' and the provided document content' : ''}.
''';

      final response = await http.post(
        Uri.parse('$baseUrl?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
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
            'responseMimeType': 'application/json',
          },
          'safetySettings': [
            {
              'category': 'HARM_CATEGORY_HARASSMENT',
              'threshold': 'BLOCK_NONE'
            },
            {
              'category': 'HARM_CATEGORY_HATE_SPEECH',
              'threshold': 'BLOCK_NONE'
            },
            {
              'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
              'threshold': 'BLOCK_NONE'
            },
            {
              'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
              'threshold': 'BLOCK_NONE'
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final generatedText = data['candidates'][0]['content']['parts'][0]['text'];
        
        // Extract JSON from the response
        final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(generatedText);
        if (jsonMatch != null) {
          final jsonString = jsonMatch.group(0)!;
          final result = jsonDecode(jsonString);
          return {
            'success': true,
            'data': result,
          };
        } else {
          return {
            'success': false,
            'error': 'Failed to parse AI response',
            'rawResponse': generatedText,
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
      print('Error generating game activity: $e');
      return {
        'success': false,
        'error': 'Exception occurred: $e',
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
Return the complete updated activity in JSON format.
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
            'responseMimeType': 'application/json',
          },
          'safetySettings': [
            {
              'category': 'HARM_CATEGORY_HARASSMENT',
              'threshold': 'BLOCK_NONE'
            },
            {
              'category': 'HARM_CATEGORY_HATE_SPEECH',
              'threshold': 'BLOCK_NONE'
            },
            {
              'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
              'threshold': 'BLOCK_NONE'
            },
            {
              'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
              'threshold': 'BLOCK_NONE'
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final generatedText = data['candidates'][0]['content']['parts'][0]['text'];
        
        final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(generatedText);
        if (jsonMatch != null) {
          final jsonString = jsonMatch.group(0)!;
          final result = jsonDecode(jsonString);
          return {
            'success': true,
            'data': result,
          };
        } else {
          return {
            'success': false,
            'error': 'Failed to parse AI response',
          };
        }
      } else {
        return {
          'success': false,
          'error': 'API request failed: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('Error refining activity: $e');
      return {
        'success': false,
        'error': 'Exception occurred: $e',
      };
    }
  }
}
