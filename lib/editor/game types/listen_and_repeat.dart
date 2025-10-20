// ignore_for_file: avoid_print, deprecated_member_use, unused_field, prefer_final_fields, unused_import, unnecessary_import, use_build_context_synchronously

import 'package:animated_button/animated_button.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

class MyListenAndRepeat extends StatefulWidget {
  final TextEditingController sentenceController;
  final String? audioPath; // Audio path from settings
  final String audioSource; // "uploaded" or "recorded"
  final String? audioUrl; // Firebase Storage URL for audio

  const MyListenAndRepeat({
    super.key,
    required this.sentenceController,
    this.audioPath,
    this.audioSource = "",
    this.audioUrl,
  });

  @override
  State<MyListenAndRepeat> createState() => _MyListenAndRepeatState();
}

class _MyListenAndRepeatState extends State<MyListenAndRepeat> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _speechEnabled = false;
  final TextEditingController _answerController = TextEditingController();
  
  // Audio playback only (recording is handled in settings)
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _audioPlayer = AudioPlayer();
    _initSpeech();
    _initAudioPlayer();
  }

  void _initAudioPlayer() {
    // Listen for audio completion
    _audioPlayer.onPlayerComplete.listen((event) {
      print("Audio playback completed");
      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
      }
    });

    // Listen for player state changes
    _audioPlayer.onPlayerStateChanged.listen((state) {
      print("Player state changed: $state");
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });
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
    _audioPlayer.dispose();
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
          listenFor: const Duration(minutes: 5),
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


  Future<void> _playAudio() async {
    // Check if we have audio URL from Firebase Storage first
    if (widget.audioUrl != null && widget.audioUrl!.isNotEmpty) {
      print('Playing audio from Firebase Storage URL: ${widget.audioUrl}');
      if (_isPlaying) {
        await _audioPlayer.pause();
        setState(() => _isPlaying = false);
      } else {
        try {
          await _audioPlayer.play(UrlSource(widget.audioUrl!));
          setState(() => _isPlaying = true);
        } catch (e) {
          print('Error playing audio from URL: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error playing audio: $e'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
      return;
    }

    // Fallback to local audio path
    if (widget.audioPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No audio available. Please record or upload first.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_isPlaying) {
      await _audioPlayer.pause();
      setState(() => _isPlaying = false);
    } else {
      await _audioPlayer.play(DeviceFileSource(widget.audioPath!));
      setState(() => _isPlaying = true);
    }
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
            color: _isPlaying ? Colors.orange : Colors.lightGreenAccent,
            onPressed: _playAudio,
            child: Icon(
              _isPlaying ? Icons.pause : Icons.hearing_rounded,
              color: Colors.black,
              size: 80,
            ),
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
  final Function(String?, String, Uint8List?)
  onAudioChanged; // Callback for audio changes with bytes

  const MyListenAndRepeatSettings({
    super.key,
    required this.sentenceController,
    required this.onAudioChanged,
  });

  @override
  State<MyListenAndRepeatSettings> createState() =>
      _MyListenAndRepeatSettingsState();
}

class _MyListenAndRepeatSettingsState extends State<MyListenAndRepeatSettings> {
  late AudioPlayer _audioPlayer;
  late AudioRecorder _audioRecorder;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isRecording = false;
  String? _audioPath;
  String _audioSource = ""; // Stores "uploaded" or "recorded"
  Uint8List? _audioBytes; // Store actual audio file bytes

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _audioRecorder = AudioRecorder();

    _audioPlayer.onPlayerStateChanged.listen((state) {
      setState(() => _isPlaying = state == PlayerState.playing);
    });

    _audioPlayer.onDurationChanged.listen((newDuration) {
      setState(() => _duration = newDuration);
    });

    _audioPlayer.onPositionChanged.listen((newPosition) {
      setState(() => _position = newPosition);
    });

    // Listen for audio completion
    _audioPlayer.onPlayerComplete.listen((event) {
      print("Settings audio playback completed");
      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  /// Validate and prepare audio file for storage
  Future<bool> _validateAudioFile(String? filePath) async {
    if (filePath == null) {
      print("No audio file path provided");
      return false;
    }

    try {
      if (kIsWeb) {
        // For web, we can't check file existence, so assume it's valid if path exists
        print("Web audio file validation: $filePath");
        return filePath.isNotEmpty;
      } else {
        // For mobile/desktop, check if file exists
        final file = File(filePath);
        bool exists = await file.exists();
        print("Audio file exists: $exists, path: $filePath");
        return exists;
      }
    } catch (e) {
      print("Error validating audio file: $e");
      return false;
    }
  }

  Future<void> _pickAudioFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        // Stop any playing audio
        await _audioPlayer.stop();
        
        // Get the file path and validate it
        String? filePath = result.files.single.path;
        print("Selected audio file: $filePath");

        if (filePath != null) {
          // Validate the audio file
          bool isValid = await _validateAudioFile(filePath);

          if (isValid) {
            try {
              // Read the audio file bytes
              Uint8List? audioBytes;
              if (kIsWeb) {
                // For web, read bytes from the file picker result
                audioBytes = result.files.single.bytes;
                print("Web audio bytes: ${audioBytes?.length} bytes");
              } else {
                // For mobile/desktop, read from file
                final file = File(filePath);
                if (await file.exists()) {
                  try {
                    audioBytes = await file.readAsBytes();
                    print(
                      "Mobile/Desktop audio bytes: ${audioBytes.length} bytes",
                    );
                  } catch (e) {
                    print("Error reading audio file: $e");
                    audioBytes = null;
                  }
                } else {
                  print("Audio file does not exist: $filePath");
                  audioBytes = null;
                }
              }

              if (audioBytes != null && audioBytes.isNotEmpty) {
                setState(() {
                  _audioPath = filePath;
                  _audioSource = "uploaded";
                  _audioBytes = audioBytes;
                  _position = Duration.zero;
                  _duration = Duration.zero;
                  // Clear any previous recording
                  _isRecording = false;
                });
                
                // Notify parent widget about audio change with bytes
                widget.onAudioChanged(_audioPath, _audioSource, _audioBytes);

                print(
                  "Audio file validated and selected: $_audioPath, bytes: ${_audioBytes?.length}",
                );

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Audio file selected successfully! It will be uploaded to gs://lexiboost-36801.firebasestorage.app/gameAudio when you save the game.',
                      ),
                      duration: Duration(seconds: 4),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Failed to read audio file. Please try again.',
                      ),
                      duration: Duration(seconds: 2),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            } catch (e) {
              print("Error reading audio file: $e");
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error reading audio file: $e'),
                    duration: const Duration(seconds: 2),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Invalid audio file. Please select a valid audio file.',
                  ),
                  duration: Duration(seconds: 2),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      print("Error picking audio file: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting audio: $e'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleRecording() async {
    try {
      if (_isRecording) {
        // Stop recording
        print("Stopping recording...");
        final path = await _audioRecorder.stop();

        if (path != null) {
          print("Recording completed: $path");

          try {
            // Read the recorded audio file bytes
            Uint8List? audioBytes;
            if (kIsWeb) {
              // For web, we might not be able to read the file directly
              // The audio bytes will be handled by the audio player
              print("Web recording - audio path: $path");
              audioBytes = null; // Will be handled differently for web
              print("Web recording: Audio bytes not available for upload");
            } else {
              // For mobile/desktop, read the recorded file
              final file = File(path);
              if (await file.exists()) {
                try {
                  audioBytes = await file.readAsBytes();
                  print("Recorded audio bytes: ${audioBytes.length} bytes");
                } catch (e) {
                  print("Error reading recorded audio file: $e");
                  audioBytes = null;
                }
              } else {
                print("Recorded audio file does not exist: $path");
                audioBytes = null;
              }
            }
            
            setState(() {
              _audioPath = path;
              _audioSource = "recorded";
              _audioBytes = audioBytes;
              _isRecording = false;
              _position = Duration.zero;
              _duration = Duration.zero;
            });
            
            // Notify parent widget about audio change with bytes
            widget.onAudioChanged(_audioPath, _audioSource, _audioBytes);

            print("Recording saved: $path, bytes: ${_audioBytes?.length}");

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Recording completed! It will be uploaded to gs://lexiboost-36801.firebasestorage.app/gameAudio when you save the game.',
                  ),
                  duration: Duration(seconds: 4),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            print("Error reading recorded audio: $e");
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error processing recording: $e'),
                  duration: const Duration(seconds: 2),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to save recording. Please try again.'),
                duration: Duration(seconds: 2),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        // Start recording
        print("Starting recording...");

        // Check permissions first
        bool hasPermission = await _audioRecorder.hasPermission();
        print("Has permission: $hasPermission");

        if (hasPermission) {
          // Stop any playing audio
          await _audioPlayer.stop();

          String filePath;
          if (kIsWeb) {
            // For web, use a simple filename without directory
            filePath = 'recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
            print("Web recording path: $filePath");
          } else {
            // For mobile/desktop, use the documents directory
            try {
              final Directory appDir = await getApplicationDocumentsDirectory();
              filePath =
                  '${appDir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
              print("Mobile/Desktop recording path: $filePath");
            } catch (e) {
              print("Error getting documents directory: $e");
              // Fallback to simple filename
              filePath =
                  'recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
              print("Fallback recording path: $filePath");
            }
          }

          print("Starting recording to: $filePath");

          await _audioRecorder.start(const RecordConfig(), path: filePath);
          print("Recording started successfully");

          // Check if recording is actually active
          bool isRecording = await _audioRecorder.isRecording();
          print("Is recording active: $isRecording");

          if (isRecording) {
            setState(() {
              _isRecording = true;
              _audioPath = null; // Clear previous audio
            });
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Recording started! Press the button again to stop.',
                  ),
                  duration: Duration(seconds: 2),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Failed to start recording. Please try again.'),
                  duration: Duration(seconds: 2),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Microphone permission denied. Please enable microphone access in settings.',
                ),
                duration: Duration(seconds: 3),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      print("Error in _toggleRecording: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
              onPressed: _pickAudioFile,
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

            Text(
              "or",
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),

            const SizedBox(width: 12),

            AnimatedButton(
              width: 150,
              height: 50,
              color: _isRecording ? Colors.orange : Colors.green,
              onPressed: () {
                print(
                  "Record button pressed! Current state: _isRecording = $_isRecording",
                );
                _toggleRecording();
              },
              child: Text(
                _isRecording ? "Stop" : "Record",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),

            
          ],
        ),

        const SizedBox(height: 20),

        // Answer TextField
        Text(
          "Answer:",
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),

        Container(
          width: 400,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.black, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: TextField(
            controller: widget.sentenceController,
            style: GoogleFonts.poppins(fontSize: 16, color: Colors.black),
            decoration: InputDecoration(
              hintText: "Enter the correct answer...",
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