// ignore_for_file: avoid_print, deprecated_member_use

import 'dart:typed_data';
import 'package:animated_button/animated_button.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;

// Main widget for Column 2 (Game Play)
class MyStroke extends StatefulWidget {
  final TextEditingController sentenceController;
  final TextEditingController? userAnswerController;
  final Uint8List? pickedImage;
  final String? imageUrl;

  const MyStroke({
    super.key,
    required this.sentenceController,
    this.userAnswerController,
    this.pickedImage,
    this.imageUrl,
  });

  @override
  State<MyStroke> createState() => _MyStrokeState();
}

class _MyStrokeState extends State<MyStroke> {
  final List<DrawingPoint?> _points = [];
  late TextEditingController _answerController;

  @override
  void initState() {
    super.initState();
    _answerController = widget.userAnswerController ?? TextEditingController();
  }

  @override
  void dispose() {
    // Only dispose if it's our internal controller
    if (widget.userAnswerController == null) {
      _answerController.dispose();
    }
    super.dispose();
  }

  void _clearDrawing() {
    setState(() {
      _points.clear();
      _answerController.text = 'Drawing cleared';
    });
  }

  void _undoLastStroke() {
    if (_points.isEmpty) return;

    setState(() {
      // Remove the last null separator if it exists
      if (_points.isNotEmpty && _points.last == null) {
        _points.removeLast();
      }

      // Remove all points until we find the previous null separator or reach the beginning
      while (_points.isNotEmpty && _points.last != null) {
        _points.removeLast();
      }

      // Update answer controller
      if (_points.isEmpty) {
        _answerController.text = 'Drawing cleared';
      } else {
        _answerController.text =
            'Drawing updated (${_points.length} points)';
      }
    });
  }

  // Build the appropriate image widget based on available data
  Widget _buildImageWidget() {
    // Priority: pickedImage (local) > imageUrl (from Firebase)
    if (widget.pickedImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: Image.memory(
          widget.pickedImage!,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return _buildErrorWidget('Failed to display picked image');
          },
        ),
      );
    } else if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
      // Use FutureBuilder to load image with Firebase Storage SDK
      return FutureBuilder<Uint8List?>(
        future: _loadImageFromFirebaseStorage(widget.imageUrl!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 8),
                  Text('Loading image...'),
                ],
              ),
            );
          }

          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            // Fallback to CachedNetworkImage if Firebase Storage fails
            return ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: CachedNetworkImage(
                imageUrl: widget.imageUrl!,
                fit: BoxFit.contain,
                placeholder: (context, url) => const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 8),
                      Text('Loading image...'),
                    ],
                  ),
                ),
                errorWidget: (context, url, error) {
                  return _buildErrorWidget(
                    'Failed to load image from Firebase Storage',
                  );
                },
              ),
            );
          }

          // Successfully loaded image bytes
          return ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: Image.memory(
              snapshot.data!,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return _buildErrorWidget('Failed to display loaded image');
              },
            ),
          );
        },
      );
    } else {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.grey.shade300, width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image_outlined, size: 40, color: Colors.grey.shade600),
              const SizedBox(height: 8),
              Text(
                "Image Hint",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Upload an image to start",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  // Helper widget for error display
  Widget _buildErrorWidget(String message) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.red.shade300, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 40),
            const SizedBox(height: 8),
            Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Load image from Firebase Storage using the SDK
  Future<Uint8List?> _loadImageFromFirebaseStorage(String imageUrl) async {
    try {
      // Check if it's a Firebase Storage path (gs://)
      if (imageUrl.startsWith('gs://')) {
        final uri = Uri.parse(imageUrl);
        final path = uri.path;

        final storage = FirebaseStorage.instanceFor(
          bucket: 'gs://lexiboost-36801.firebasestorage.app',
        );
        final ref = storage.ref().child(path);
        final imageBytes = await ref.getData();
        return imageBytes;
      } else if (imageUrl.contains('firebasestorage.googleapis.com')) {
        // Try to extract path from download URL
        final uri = Uri.parse(imageUrl);
        final pathSegments = uri.pathSegments;
        int oIndex = pathSegments.indexOf('o');
        if (oIndex != -1 && oIndex + 1 < pathSegments.length) {
          String filePath = Uri.decodeComponent(pathSegments[oIndex + 1]);
          final storage = FirebaseStorage.instanceFor(
            bucket: 'gs://lexiboost-36801.firebasestorage.app',
          );
          final ref = storage.ref().child(filePath);
          final imageBytes = await ref.getData();
          if (imageBytes != null) return imageBytes;
        }
        // Fallback to HTTP
        final response = await http.get(Uri.parse(imageUrl));
        if (response.statusCode == 200) {
          return response.bodyBytes;
        }
      } else {
        // Regular HTTP URL
        final response = await http.get(Uri.parse(imageUrl));
        if (response.statusCode == 200) {
          return response.bodyBytes;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Stroke:",
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        Text(
          "Write in the white pad to answer.",
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 20),

        // Show image hint if available, otherwise show sentence field
        if (widget.pickedImage != null || (widget.imageUrl != null && widget.imageUrl!.isNotEmpty))
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
          )
        else ...[
          // Read-only sentence field
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: Text(
                "Write this:",
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
              maxLines: 3,
              controller: widget.sentenceController,
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.black),
              decoration: InputDecoration(
                hintText: "No sentence has been implemented yet...",
                hintStyle: GoogleFonts.poppins(
                  color: Colors.black54,
                  fontSize: 14,
                ),
                filled: true,
                fillColor: Colors.white,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                ),
              ),
            ),
          ),
        ],

        const SizedBox(height: 10),

        // White drawing pad
        Expanded(
          child: Center(
            child: Container(
              width: 400,
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 2,
                    blurRadius: 5,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: GestureDetector(
                  onPanStart: (details) {
                    setState(() {
                      _points.add(
                        DrawingPoint(
                          details.localPosition,
                          Paint()
                            ..color = Colors.black
                            ..strokeWidth = 3
                            ..strokeCap = StrokeCap.round,
                        ),
                      );
                      // Update answer controller to indicate drawing has started
                      if (_answerController.text.isEmpty ||
                          _answerController.text == 'Drawing cleared') {
                        _answerController.text = 'Drawing in progress...';
                      }
                    });
                  },
                  onPanUpdate: (details) {
                    setState(() {
                      _points.add(
                        DrawingPoint(
                          details.localPosition,
                          Paint()
                            ..color = Colors.black
                            ..strokeWidth = 3
                            ..strokeCap = StrokeCap.round,
                        ),
                      );
                    });
                  },
                  onPanEnd: (details) {
                    setState(() {
                      _points.add(null);
                      _answerController.text =
                          'Drawing completed (${_points.length} points)';
                    });
                  },
                  child: CustomPaint(
                    painter: DrawingPainter(_points),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
          ),
        ),

        // Drawing pad title (at the bottom of the pad)
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Center(
            child: Text(
              "Drawing Pad:",
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
        ),

        // Control buttons
        Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedButton(
                  width: 150,
                  height: 50,
                  color: Colors.blue,
                  onPressed: _undoLastStroke,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.undo_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Undo",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                AnimatedButton(
                  width: 150,
                  height: 50,
                  color: Colors.pinkAccent,
                  onPressed: _clearDrawing,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.restart_alt_rounded,
                        color: Colors.black,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Clear",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
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
    );
  }
}

// Settings widget for Column 3
class MyStrokeSettings extends StatefulWidget {
  final TextEditingController sentenceController;
  final TextEditingController? answerController; // Answer controller for image mode
  final Function(Uint8List)? onImagePicked;
  final VoidCallback? onImageCleared; // Callback to clear the image

  const MyStrokeSettings({
    super.key,
    required this.sentenceController,
    this.answerController,
    this.onImagePicked,
    this.onImageCleared,
  });

  @override
  State<MyStrokeSettings> createState() => _MyStrokeSettingsState();
}

class _MyStrokeSettingsState extends State<MyStrokeSettings> {
  bool _isImageMode = false;

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.isNotEmpty) {
      final fileBytes = result.files.first.bytes;
      if (fileBytes != null && widget.onImagePicked != null) {
        widget.onImagePicked!(fileBytes);
      }
    }
  }

  Future<void> _showSwitchToTextConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF2A2C2A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width.clamp(0.0, 400.0),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 50,
                ),
                const SizedBox(height: 20),
                Text(
                  'Switch to Text Mode?',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Switching to text mode will remove the uploaded image. Do you want to continue?',
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
                      width: 100,
                      height: 40,
                      color: Colors.grey,
                      onPressed: () => Navigator.of(context).pop(false),
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
                      width: 100,
                      height: 40,
                      color: Colors.orange,
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text(
                        'Continue',
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

    if (confirmed == true) {
      setState(() {
        _isImageMode = false;
      });
      
      // Clear the image by calling the callback
      if (widget.onImageCleared != null) {
        widget.onImageCleared!();
      }
      
      // Clear the answer controller
      if (widget.answerController != null) {
        widget.answerController!.clear();
      }
      
      // Don't clear sentenceController as it's used for text mode
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isImageMode ? "Image:" : "Sentence:",
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        if (_isImageMode) ...[
          AnimatedButton(
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
          const SizedBox(height: 20),
          // Answer field for image mode (similar to what_called.dart)
          Text(
            "Answer:",
            style: GoogleFonts.poppins(
              fontSize: 18,
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
              border: Border.all(color: Colors.black, width: 1),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: TextField(
              controller: widget.answerController ?? widget.sentenceController,
              maxLength: 50,
              style: GoogleFonts.poppins(fontSize: 16, color: Colors.black),
              decoration: InputDecoration(
                hintText: "The Answer...",
                hintStyle: GoogleFonts.poppins(
                  color: Colors.black54,
                  fontSize: 14,
                ),
                border: InputBorder.none,
                counterText: "", // hides default counter below field
              ),
            ),
          ),
        ] else
          Container(
            width: 450,
            height: 150,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: TextField(
              controller: widget.sentenceController,
              maxLines: 6,
              style: GoogleFonts.poppins(fontSize: 16, color: Colors.black),
              decoration: InputDecoration(
                hintText: "Write a sentence here...",
                hintStyle: GoogleFonts.poppins(
                  color: Colors.black54,
                  fontSize: 14,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
        const SizedBox(height: 20),
        // Switch button
        Row(
          children: [
            Text(
              "Mode:",
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            AnimatedButton(
              width: 150,
              height: 50,
              color: _isImageMode ? Colors.blue : Colors.green,
              onPressed: () async {
                // If switching from image mode to text mode, show confirmation
                if (_isImageMode) {
                  await _showSwitchToTextConfirmation();
                } else {
                  // Switching from text to image mode - no confirmation needed
                  setState(() {
                    _isImageMode = true;
                  });
                }
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isImageMode ? Icons.image : Icons.text_fields,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isImageMode ? "Image" : "Text",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// Drawing point class
class DrawingPoint {
  final Offset offset;
  final Paint paint;

  DrawingPoint(this.offset, this.paint);
}

// Custom painter for drawing
class DrawingPainter extends CustomPainter {
  final List<DrawingPoint?> points;

  DrawingPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(
          points[i]!.offset,
          points[i + 1]!.offset,
          points[i]!.paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(DrawingPainter oldDelegate) => true;
}

