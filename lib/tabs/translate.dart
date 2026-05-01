import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:meow_lang/backend/translation_engine.dart';
import '../models/user.dart';
import '../models/cat.dart';
import '../snackbar_helper.dart';
import 'package:meow_lang/backend/firebase_service.dart';

class TranslateMenu extends StatefulWidget {
  const TranslateMenu({super.key});

  @override
  State<TranslateMenu> createState() => _TranslateMenuState();
}

class _TranslateMenuState extends State<TranslateMenu> {
  final FirebaseService _firebase = FirebaseService();
  final TranslationEngine _engine = TranslationEngine();
  final player = AudioPlayer();
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  DateTime? _recordStartTime;

  bool holding = false;
  bool processing = false;
  String _processingStatus = "Translating...";
  String translatedText = "";
  double _scale = 1.0;
  List<Cat> _cats = [];
  Cat? _selectedCat;
  double _lastConfidence = 0.0;
  String _lastLabel = "";
  String? _lastTranslationId;
  String? _lastSpectrogramPath;

  final List<String> _classLabels = [
    'food',
    'isolation',
    'motherCall',
    'Resting',
    'angry',
  ];

  @override
  void initState() {
    super.initState();
    if (User.isLoggedIn) {
      _loadCats();
    }
  }

  @override
  void dispose() {
    player.dispose();
    _audioRecorder.dispose();
    _engine.dispose();
    super.dispose();
  }

  Future<void> _loadCats() async {
    try {
      final user = User.currentUser;
      if (user == null) {
        return;
      }

      final cats = await _firebase.getCats(user.userId);
      if (mounted) {
        setState(() {
          _cats = cats;
          // Set selected cat to the first one if available, otherwise null (for "Unassigned")
          _selectedCat = _cats.isNotEmpty ? _cats.first : null;
        });
      }
    } catch (e) {
      print('[Translate] Error loading cats: $e');
      if (mounted) {
        setState(() {
          _cats = [];
          _selectedCat = null; // Ensure selectedCat is null on error or no cats
        });
      }
    }
  }

  Future<void> _submitFeedback(String newLabel) async {
    if (_lastTranslationId == null || _lastSpectrogramPath == null) {
      SnackBarHelper.showError(
          context, 'Could not submit feedback: Missing translation data.');
      return;
    }

    final user = User.currentUser;
    if (user == null) {
      SnackBarHelper.showError(
          context, 'You must be logged in to submit feedback.');
      return;
    }

    try {
      await _engine.submitFeedback(
        translationId: _lastTranslationId!,
        newLabel: newLabel,
        userId: user.userId.toString(),
        catId: _selectedCat?.catId,
      );
      print('[Feedback] Correction submitted successfully.');
      if (mounted) {
        User.currentUser?.incrementCorrections();
        SnackBarHelper.showSuccess(context, 'Thank you for your feedback!');
      }
    } catch (e) {
      print('[Feedback] Error submitting feedback: $e');
      if (mounted) {
        SnackBarHelper.showError(context, 'Failed to submit feedback: $e');
      }
    }
  }

  void _showTranslationDetails() {
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;
    String? selectedCorrection;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          // To update the dialog state (e.g., loading indicator)
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Submit Correction'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Original: $_lastLabel'),
                    Text('Confidence: ${_lastConfidence.toStringAsFixed(1)}%'),
                    const SizedBox(height: 24),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Correct Label',
                        border: OutlineInputBorder(),
                      ),
                      value: selectedCorrection,
                      items: _classLabels.map((String label) {
                        return DropdownMenuItem<String>(
                          value: label,
                          // Display labels nicely but keep values consistent with backend
                          child: Text(label == 'motherCall'
                              ? 'Mother Call'
                              : label[0].toUpperCase() + label.substring(1)),
                        );
                      }).toList(),
                      onChanged: (value) =>
                          setDialogState(() => selectedCorrection = value),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a correction.';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            setDialogState(() => isSubmitting = true);
                            await _submitFeedback(selectedCorrection!);
                            setDialogState(() => isSubmitting = false);
                            if (mounted) Navigator.pop(context);
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTapDown: (_) {
                    if (processing || holding) return;
                    setState(() {
                      holding = true;
                      _scale = 0.9;
                    });
                    _startRecording();
                  },
                  onTapUp: (_) {
                    if (holding) {
                      setState(() {
                        holding = false;
                        _processingStatus = "Initializing...";
                        processing = true; // Bridge the gap immediately
                        _scale = 1.0;
                      });
                      _stopRecording();
                    }
                  },
                  onTapCancel: () {
                    if (holding) {
                      setState(() {
                        holding = false;
                        _processingStatus = "Initializing...";
                        processing = true;
                        _scale = 1.0;
                      });
                      _stopRecording();
                    }
                  },
                  child: AnimatedScale(
                    scale: _scale,
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOutBack,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.all(50),
                      decoration: BoxDecoration(
                        color: holding
                            ? Theme.of(context)
                                .colorScheme
                                .secondaryContainer
                                .withOpacity(0.2)
                            : Theme.of(context).colorScheme.surface,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                          BoxShadow(
                            color: holding
                                ? Theme.of(context)
                                    .primaryColor
                                    .withOpacity(0.4)
                                : Colors.transparent,
                            blurRadius: holding ? 60 : 0,
                            spreadRadius: holding ? 10 : 0,
                          ),
                        ],
                      ),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 150),
                        opacity: holding ? 0.8 : 1.0,
                        child: Image.asset(
                          'assets/images/translate.png',
                          width: 150,
                          height: 150,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 60),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    processing
                        ? _processingStatus
                        : (holding ? 'Capturing Meows...' : 'Hold To Capture'),
                    key: ValueKey(processing ? _processingStatus : (holding ? 1 : 0)),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color:
                              holding ? Theme.of(context).primaryColor : null,
                        ),
                  ),
                ),
                const SizedBox(height: 40),
                if (translatedText.isNotEmpty)
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .secondaryContainer
                          .withOpacity(0.5),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Text(
                                'Your Cat Says:',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .secondary,
                                      letterSpacing: 1.2,
                                    ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                translatedText,
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: IconButton(
                            icon: const Icon(Icons.priority_high),
                            onPressed: _showTranslationDetails,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        Positioned(
          // The dropdown menu will always appear
          top: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.pets,
                    size: 18, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  // Added "Cat:" label
                  'Cat:',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 12), // Adjusted spacing

                DropdownButtonHideUnderline(
                  child: DropdownButton<Cat?>(
                      // Changed to Cat? to allow null value
                      value: _selectedCat,
                      isDense: true,
                      icon: const Icon(Icons.arrow_drop_down),
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      onChanged: (Cat? newValue) {
                        setState(() {
                          _selectedCat =
                              newValue; // newValue can be null for "Unassigned"
                        });
                      },
                      items: [
                        // Always include "Unassigned" option
                        DropdownMenuItem<Cat?>(
                          value: null,
                          child: Text('Unassigned'),
                        ),
                        // Add actual cats if available
                        ..._cats.map<DropdownMenuItem<Cat?>>((Cat value) {
                          return DropdownMenuItem<Cat?>(
                            value: value,
                            child: Text(value.name),
                          );
                        }).toList(),
                      ]),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _startRecording() async {
    try {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        if (mounted) {
          SnackBarHelper.showError(context, 'Microphone permission is required to translate.');
          setState(() {
            holding = false;
            _scale = 1.0;
          });
        }
        return;
      }

      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/meow_recording_${DateTime.now().millisecondsSinceEpoch}.wav';

      if (await _audioRecorder.isRecording()) return;

      await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: 22050, // Force 22050Hz to match the engine expectations
            numChannels: 1, // Mono is preferred for DSP processing
          ),
          path: path);
      
      _recordStartTime = DateTime.now();
      _isRecording = true;
      debugPrint('Recording started at $path');

      // If the user released the button while we were awaiting permission/setup
      if (!holding) {
        _stopRecording();
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      if (!_isRecording) {
        if (mounted) {
          setState(() => processing = false);
        }
        return;
      }

      // Guard against ultra-short taps that break the recorder
      final duration = DateTime.now().difference(_recordStartTime ?? DateTime.now());
      if (duration.inMilliseconds < 500) {
        await Future.delayed(Duration(milliseconds: 500 - duration.inMilliseconds));
      }

      _isRecording = false;
      final path = await _audioRecorder.stop();
      // Small delay to allow the OS to finish writing the file handle
      await Future.delayed(const Duration(milliseconds: 100));
      debugPrint('Recording stopped. Saved to: $path');

      if (path == null) {
        if (mounted) SnackBarHelper.showError(context, 'Failed to capture audio.');
        return;
      }

      final file = File(path);
      if (!await file.exists() || await file.length() == 0) {
        debugPrint('[Translate] Audio file is empty or missing.');
        if (mounted) SnackBarHelper.showError(context, 'Recording too short. Please hold longer.');
        return;
      }

      if (mounted) setState(() => translatedText = "");

      final result = await _engine
          .processMeow(
            path,
            _selectedCat?.catId ?? 'unassigned',
            _selectedCat?.name ?? 'Unknown',
            onStatusUpdate: (status) {
              if (mounted) setState(() => _processingStatus = status);
            },
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw TimeoutException("The engine took too long."),
          );

      if (mounted) {
        // If the model failed to load, notify the user instead of showing "Offline" in the bubble
        if (result['label'] == 'Offline') {
          SnackBarHelper.showError(context, 'Translation Engine is Offline. Check model asset paths.');
        } else {
          setState(() {
            // Use the random cat message for the UI, fallback to label if missing
            translatedText = result['text'] ?? result['label'];
            _lastLabel = result['label'];
            _lastConfidence = result['confidence']; // Already multiplied by 100 in engine
            _lastSpectrogramPath = result['imgPath'];
            _lastTranslationId = result['id'];
          });

          if (User.isLoggedIn) {
            User.currentUser!.incrementTranslations();
          }
          player.play(AssetSource('audio/pop.mp3'));
        }
      }
    } on TimeoutException catch (_) {
      if (mounted) SnackBarHelper.showError(context, 'Translation timed out. Please try again.');
    } catch (e) {
      print('[Translate] Error: $e');
      if (mounted) SnackBarHelper.showError(context, 'Translation failed: $e');
    } finally {
      if (mounted) setState(() => processing = false);
    }
  }
}
