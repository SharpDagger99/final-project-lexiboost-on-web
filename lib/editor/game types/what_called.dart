// ignore_for_file: avoid_print, deprecated_member_use

import 'dart:typed_data';
import 'package:animated_button/animated_button.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class MyWhatItIsCalled extends StatefulWidget {
  final TextEditingController sentenceController;
  final Uint8List? pickedImage; // 🔹 added image hint

  const MyWhatItIsCalled({
    super.key,
    required this.sentenceController,
    this.pickedImage,
  });

  @override
  State<MyWhatItIsCalled> createState() => _MyWhatItIsCalledState();
}

class _MyWhatItIsCalledState extends State<MyWhatItIsCalled> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _speechEnabled = false;
  final TextEditingController _answerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initSpeech();
  }

  void _initSpeech() async {
    _speechEnabled = await _speech.initialize(
      onStatus: (status) => print('Speech status: $status'),
      onError: (error) => print('Speech error: $error'),
    );
    setState(() {});
    print('Speech enabled: $_speechEnabled');
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  void _toggleListening() async {
    if (!_isListening) {
      if (!_speechEnabled) {
        _speechEnabled = await _speech.initialize(
          onStatus: (status) => print('Speech status: $status'),
          onError: (error) => print('Speech error: $error'),
        );
      }

      if (_speechEnabled) {
        setState(() => _isListening = true);
        print('Starting to listen...');

        await _speech.listen(
          onResult: (result) {
            print('Recognized words: ${result.recognizedWords}');
            if (mounted) {
              setState(() {
                _answerController.text = result.recognizedWords;
              });
            }
          },
          listenFor: const Duration(minutes: 5),
          pauseFor: const Duration(seconds: 5),
          partialResults: true,
          onSoundLevelChange: (level) => print('Sound level: $level'),
          cancelOnError: true,
          listenMode: stt.ListenMode.confirmation,
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Speech recognition not available. Please check microphone permissions.',
              ),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } else {
      print('Stopping listening...');
      setState(() => _isListening = false);
      await _speech.stop();
    }
  }

  void _clearAnswer() {
    setState(() {
      _answerController.clear();
    });
  }

  // Firebase storage method

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "What is it called?",
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),

        Text(
          "Guess the image by saying something.",
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),

        const SizedBox(height: 10),

        // 🔵 Image Hint Box
        Center(
          child: Container(
            width: 400,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(25),
              
            ),
            child: widget.pickedImage == null
                ? Center(
                    child: Text(
                      "Image Hint",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    child: Image.memory(
                      widget.pickedImage!,
                      fit: BoxFit.contain,
                    ),
                  ),
          ),
        ),

        const SizedBox(height: 20),

        // ✅ Only "Your answer" remains
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Center(
            child: Text(
              "Your answer:",
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
            maxLines: 6,
            controller: _answerController,
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.black),
            decoration: InputDecoration(
              hintText: "Say something first...",
              hintStyle: GoogleFonts.poppins(
                color: Colors.black54,
                fontSize: 14,
              ),
              filled: true,
              fillColor: Colors.white,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.green, width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.blue, width: 2),
              ),
            ),
          ),
        ),

        Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                AnimatedButton(
                  width: 70,
                  height: 70,
                  color: Colors.pinkAccent,
                  onPressed: _clearAnswer,
                  child: const Icon(
                    Icons.restart_alt_rounded,
                    color: Colors.black,
                    size: 50,
                  ),
                ),
                AnimatedButton(
                  width: 70,
                  height: 70,
                  color: _isListening ? Colors.orange : Colors.green,
                  onPressed: _toggleListening,
                  child: Icon(
                    _isListening ? Icons.mic : Icons.mic_none_rounded,
                    color: Colors.black,
                    size: 50,
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

// ================================
// Column 3 - Settings Widget
// ================================
class MyWhatItIsCalledSettings extends StatefulWidget {
  final TextEditingController sentenceController;
  final TextEditingController
  hintController; // 🔹 hint controller from game_edit
  final Function(Uint8List) onImagePicked; // 🔹 callback for image

  const MyWhatItIsCalledSettings({
    super.key,
    required this.sentenceController,
    required this.hintController,
    required this.onImagePicked,
  });

  TextEditingController? get answerController => null;

  @override
  State<MyWhatItIsCalledSettings> createState() =>
      _MyWhatItIsCalledSettingsState();
}

class _MyWhatItIsCalledSettingsState extends State<MyWhatItIsCalledSettings> {
  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.isNotEmpty) {
      final fileBytes = result.files.first.bytes;
      if (fileBytes != null) {
        widget.onImagePicked(fileBytes); // pass image back
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Upload Image Row
        Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 10.0, top: 10, bottom: 10),
              child: Text(
                "Image:",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: AnimatedButton(
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
            ),
          ],
        ),

        const SizedBox(height: 20),

        Text(
          "Answer:",
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 10),
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
            controller: widget.answerController,
            maxLength: 25, // 🔹 limit to 25 characters
            style: GoogleFonts.poppins(fontSize: 16, color: Colors.black),
            decoration: InputDecoration(
              hintText: "The Answer...",
              hintStyle: GoogleFonts.poppins(
                color: Colors.black54,
                fontSize: 14,
              ),
              border: InputBorder.none,
              counterText: "", // 🔹 hides default counter below field
            ),
          ),
        ),

        const SizedBox(height: 20),

        Text(
          "Game Hint:",
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 10),
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
            controller: widget.hintController,
            maxLength: 50, // 🔹 limit to 50 characters
            style: GoogleFonts.poppins(fontSize: 16, color: Colors.black),
            decoration: InputDecoration(
              hintText: "Enter game hint...",
              hintStyle: GoogleFonts.poppins(
                color: Colors.black54,
                fontSize: 14,
              ),
              border: InputBorder.none,
              counterText: "", // 🔹 hides default counter below field
            ),
          ),
        ),
      ],
    );
  }
}
