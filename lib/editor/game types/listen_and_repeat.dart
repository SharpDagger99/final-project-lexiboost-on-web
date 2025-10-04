// ignore_for_file: avoid_print, deprecated_member_use

import 'package:animated_button/animated_button.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:audioplayers/audioplayers.dart';

class MyListenAndRepeat extends StatefulWidget {
  final TextEditingController sentenceController;

  const MyListenAndRepeat({
    super.key,
    required this.sentenceController,
  });

  @override
  State<MyListenAndRepeat> createState() => _MyListenAndRepeatState();
}

class _MyListenAndRepeatState extends State<MyListenAndRepeat> {
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Listen and Repeat",
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        Text(
          "Repeat the sentence aloud.",
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 50),
        Center(
          child: AnimatedButton(
            width: 150,
            height: 150,
            color: Colors.lightGreenAccent,
            onPressed: () {},
            child: const Icon(Icons.hearing_rounded, color: Colors.black, size: 80),
          ),
        ),
        const SizedBox(height: 20),
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
class MyListenAndRepeatSettings extends StatefulWidget {
  final TextEditingController sentenceController;

  const MyListenAndRepeatSettings({
    super.key,
    required this.sentenceController,
  });

  @override
  State<MyListenAndRepeatSettings> createState() =>
      _MyListenAndRepeatSettingsState();
}

class _MyListenAndRepeatSettingsState extends State<MyListenAndRepeatSettings> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isMicActive = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();

    _audioPlayer.onPlayerStateChanged.listen((state) {
      setState(() => _isPlaying = state == PlayerState.playing);
    });

    _audioPlayer.onDurationChanged.listen((newDuration) {
      setState(() => _duration = newDuration);
    });

    _audioPlayer.onPositionChanged.listen((newPosition) {
      setState(() => _position = newPosition);
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play(AssetSource('audio/sample.mp3'));
    }
  }

  void _toggleMic() {
    setState(() => _isMicActive = !_isMicActive);
    print(_isMicActive ? "Mic activated" : "Mic deactivated");
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Upload Voice",
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),

        // ✅ Upload + Audio Player in same row
        Row(
          children: [
            AnimatedButton(
              width: 150,
              height: 50,
              color: Colors.green,
              onPressed: () {
                print("Send audio pressed");
              },
              child: Text(
                "Send Audio",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // 🎵 Inline player controls
            Expanded(
              child: Row(
                children: [
                  AnimatedButton(
                    width: 60,
                    height: 60,
                    color: _isPlaying ? Colors.orange : Colors.blue,
                    onPressed: _playPause,
                    child: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.black,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Slider(
                      min: 0,
                      max: _duration.inSeconds.toDouble(),
                      value: _position.inSeconds
                          .toDouble()
                          .clamp(0, _duration.inSeconds.toDouble()),
                      onChanged: (value) async {
                        final newPosition = Duration(seconds: value.toInt());
                        await _audioPlayer.seek(newPosition);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),
        Divider(color: Colors.white),

        Text(
          "Speech Player",
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),

        Row(
          children: [
            AnimatedButton(
              width: 70,
              height: 70,
              color: _isMicActive ? Colors.redAccent : Colors.greenAccent,
              onPressed: _toggleMic,
              child: Icon(
                _isMicActive ? Icons.mic : Icons.mic_none_rounded,
                color: Colors.black,
                size: 40,
              ),
            ),
            const SizedBox(width: 12),
            AnimatedButton(
              width: 70,
              height: 70,
              color: _isPlaying ? Colors.orange : Colors.blue,
              onPressed: _playPause,
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.black,
                size: 40,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Slider(
                    min: 0,
                    max: _duration.inSeconds.toDouble(),
                    value: _position.inSeconds
                        .toDouble()
                        .clamp(0, _duration.inSeconds.toDouble()),
                    onChanged: (value) async {
                      final newPosition = Duration(seconds: value.toInt());
                      await _audioPlayer.seek(newPosition);
                    },
                  ),
                  Text(
                    "${_position.inMinutes}:${(_position.inSeconds % 60).toString().padLeft(2, '0')} / "
                    "${_duration.inMinutes}:${(_duration.inSeconds % 60).toString().padLeft(2, '0')}",
                    style: GoogleFonts.poppins(fontSize: 14, color: Colors.white),
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
