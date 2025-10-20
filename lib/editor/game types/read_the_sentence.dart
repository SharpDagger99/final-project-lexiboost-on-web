// ignore_for_file: avoid_print, deprecated_member_use

import 'package:animated_button/animated_button.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

// First widget (Column 2)
class MyReadTheSentence extends StatefulWidget {
  final TextEditingController sentenceController; // ✅ controller from game_edit
  final TextEditingController?
  userAnswerController; // ✅ controller for user's spoken answer

  const MyReadTheSentence({
    super.key,
    required this.sentenceController,
    this.userAnswerController,
  });

  @override
  State<MyReadTheSentence> createState() => _MyReadTheSentenceState();
}

class _MyReadTheSentenceState extends State<MyReadTheSentence> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _speechEnabled = false;
  late TextEditingController _answerController;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _answerController = widget.userAnswerController ?? TextEditingController();
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
    // Only dispose if it's our internal controller
    if (widget.userAnswerController == null) {
      _answerController.dispose();
    }
    super.dispose();
  }

  // ✅ Toggle listening (only user can turn it off)
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
            print('Final result: ${result.finalResult}');
            if (mounted) {
              setState(() {
                // Use finalResult for more accurate text
                _answerController.text = result.finalResult
                    ? result.recognizedWords
                    : result.recognizedWords;
              });
            }
          },
          listenFor: const Duration(
            minutes: 5,
          ), // ✅ longer time, won't auto stop quickly
          pauseFor: const Duration(seconds: 5),
          partialResults: true,
          onSoundLevelChange: (level) => print('Sound level: $level'),
          cancelOnError: true,
          listenMode: stt.ListenMode.confirmation,
          localeId: 'en_US', // Add explicit locale
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
      // ✅ Stop only when button pressed
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
          "Read the sentence:",
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),

        Text(
          "Read the sentence in correct pronunciation to answer.",
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),

        const SizedBox(height: 20),

        // Read-only "Read this" field
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Center(
            child: Text(
              "Read this:",
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
            controller: widget.sentenceController, // ✅ display live text
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

        const SizedBox(height: 20),

        // Read-only "Your answer" field
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
class MyReadTheSentenceSettings extends StatelessWidget {
  final TextEditingController sentenceController;

  const MyReadTheSentenceSettings({
    super.key,
    required this.sentenceController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Sentence:",
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 450,
          height: 150,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: TextField(
            controller: sentenceController,
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
      ],
    );
  }
}
