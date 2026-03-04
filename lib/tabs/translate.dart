import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:meow_lang/models/cat.dart';
import 'package:meow_lang/server_config.dart';
import 'package:meow_lang/models/user.dart';


class TranslateMenu extends StatefulWidget {
  const TranslateMenu({super.key});

  @override
  State<TranslateMenu> createState() => _TranslateMenuState();
}

class _TranslateMenuState extends State<TranslateMenu> {
  final player = AudioPlayer();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final http.Client _client = http.Client();

  bool holding = false;
  bool processing = false;
  String translatedText = "";
  double _scale = 1.0;
  List<Cat> _cats = [];
  Cat? _selectedCat;
  double _lastConfidence = 0.0;
  String _lastLabel = "";
  int? _lastTranslationId;
  String? _lastSpectrogramPath;

  final List<String> _classLabels = [
    'Food',
    'Isolation',
    'MotherCall',
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
    _client.close();
    super.dispose();
  }

  Future<void> _loadCats() async {
    try {
      final user = User.currentUser;
      if (user == null) {
        return;
      }

      final response = await _client.get(
        Uri.parse(serverUrl('/cats?userId=${user.userId}')),
        headers: {'Connection': 'Keep-Alive'},
      );
      if (response.statusCode == 200) {
        final List<dynamic> catMaps = jsonDecode(response.body);
        final cats = catMaps.map((catMap) => Cat.fromJson(catMap)).toList();
        if (mounted) {
          setState(() {
            _cats = cats;
            if (_cats.isNotEmpty) {
              _selectedCat = _cats.first;
            } else {
              _selectedCat = null;
            }
          });
        }
      } else {
        throw Exception('Failed to load cats: ${response.body}');
      }
    } catch (e) {
      print('[Translate] Error loading cats: $e');
      if (mounted) {
        setState(() {
          _cats = [];
          _selectedCat = null;
        });
      }
    }
  }

  Future<void> _saveTranslationResult(String label, String? spectrogramPath,
      double confidence, int translationId) async {
    if (_selectedCat == null) {
      print('[Translate] No cat selected, not saving history.');
      return;
    }

    try {
      final response = await _client.post(
        Uri.parse(serverUrl('/history')),
        headers: {
          'Content-Type': 'application/json',
          'Connection': 'Keep-Alive',
        },
        body: jsonEncode({
          'textTranslation': label,
          'translationId': translationId,
          'catId': _selectedCat!.catId,
        }),
      );
      if (response.statusCode == 200) {
        print('[Translate] History saved successfully.');
      } else {
        print('[Translate] Failed to save history: ${response.body}');
      }
    } catch (e) {
      print('[Translate] Error saving history: $e');
    }
  }

  Future<void> _submitFeedback(String newLabel) async {
    if (_lastTranslationId == null || _lastSpectrogramPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Could not submit feedback: Missing translation data.')),
      );
      return;
    }

    final user = User.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('You must be logged in to submit feedback.')),
      );
      return;
    }

    final url = serverUrl('/feedback');
    print('[Feedback] Submitting correction to $url');

    try {
      final response = await _client.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Connection': 'Keep-Alive',
        },
        body: jsonEncode({
          'translationId': _lastTranslationId,
          'new_label': newLabel,
          'userId': user.userId,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 201) {
        print('[Feedback] Correction submitted successfully.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Thank you for your feedback!')),
          );
        }
      } else {
        print(
            '[Feedback] Failed to submit correction. Status ${response.statusCode}: ${response.body}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('Failed to submit feedback: ${response.reasonPhrase} (${response.statusCode})')),
          );
        }
      }
    } catch (e) {
      print('[Feedback] Error submitting feedback: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('An error occurred while submitting feedback.')),
        );
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
                          child: Text(label),
                        );
                      }).toList(),
                      onChanged: (value) => setDialogState(() => selectedCorrection = value),
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
                    setState(() {
                      holding = true;
                      _scale = 0.9;
                    });
                    _startRecording();
                  },
                  onTapUp: (_) {
                    setState(() {
                      holding = false;
                      _scale = 1.0;
                    });
                    _stopRecording();
                  },
                  onTapCancel: () {
                    setState(() {
                      holding = false;
                      _scale = 1.0;
                    });
                    _stopRecording();
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
                        ? 'Translating...'
                        : (holding ? 'Capturing Meows...' : 'Hold To Capture'),
                    key: ValueKey(processing ? 2 : (holding ? 1 : 0)),
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
        if (_cats.isNotEmpty)
          Positioned(
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
                  
                  DropdownButtonHideUnderline(
                    child: DropdownButton<Cat>(
                      value: _selectedCat,
                      isDense: true,
                      icon: const Icon(Icons.arrow_drop_down),
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      onChanged: (Cat? newValue) {
                        setState(() {
                          _selectedCat = newValue!;
                        });
                      },
                      items: _cats.map<DropdownMenuItem<Cat>>((Cat value) {
                        return DropdownMenuItem<Cat>(
                          value: value,
                          child: Text(value.name),
                        );
                      }).toList(),
                    ),
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
      if (await Permission.microphone.request().isGranted) {
        final directory = await getApplicationDocumentsDirectory();
        final path =
            '${directory.path}/meow_recording_${DateTime.now().millisecondsSinceEpoch}.wav';

        if (await _audioRecorder.isRecording()) return;

        await _audioRecorder
            .start(const RecordConfig(encoder: AudioEncoder.wav), path: path);
        debugPrint('Recording started at $path');
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      debugPrint('Recording stopped. Saved to: $path');

      if (path != null) {
        final file = File(path);
        if (!await file.exists() || file.length() == 0) {
          debugPrint('[Translate] Audio file is empty or missing.');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Recording too short. Please hold longer.')),
            );
          }
          return;
        }

        if (mounted) {
          setState(() {
            processing = true;
            translatedText = "";
          });
        }

        final String url = serverUrl('/convert');

        print('[Translate] Uploading audio to $url...');

        try {
          var request = http.MultipartRequest('POST', Uri.parse(url));
          request.headers['Connection'] = 'Keep-Alive';
          request.files.add(await http.MultipartFile.fromPath('file', path));

          var streamedResponse =
              await _client.send(request).timeout(const Duration(seconds: 60));
          var response = await http.Response.fromStream(streamedResponse);

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final String label = data['label'];
            final int translationId = data['id'];
            print("[Translate] Server response: $label");
            final double confidence =
                (data['confidence'] as num?)?.toDouble() ?? 0.0;
            final String base64Image = data['spectrogram'];

            final dir = await getApplicationDocumentsDirectory();
            final outputPath =
                '${dir.path}/spectrogram_${DateTime.now().millisecondsSinceEpoch}.png';
            final file = File(outputPath);
            await file.writeAsBytes(base64Decode(base64Image));
            print('[Translate] Spectrogram saved to: $outputPath');

            if (mounted) {
              setState(() {
                translatedText = label;
                _lastLabel = label;
                _lastConfidence = confidence;
                _lastSpectrogramPath = outputPath;
                _lastTranslationId = translationId;
                processing = false;
              });
              player.play(AssetSource('audio/pop.mp3'));
              print('[Translate] Calling _saveTranslationResult...');
              await _saveTranslationResult(label, outputPath, confidence, translationId);
              print('[Translate] Translation result saved');
            }
          } else {
            final message =
                'Server returned ${response.statusCode}: ${response.body}';
            print('[Translate] $message');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Translation failed: $message')),
              );
              setState(() => processing = false);
            }

            // Delete the temporary audio file
            final audioFile = File(path);
            if (await audioFile.exists()) {
              await audioFile.delete();
              print('[Translate] Temporary audio file deleted.');
            }
          }
        } catch (e) {
          // capture network errors so users know why the tap didn't work
          print('[Translate] Error uploading audio: $e');
          if (mounted) {
            setState(() => processing = false);
            String msg = e.toString();
            if (e is SocketException) {
              msg =
                  'Could not reach translation server. Make sure it is running and accessible.';
            }
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(msg)));
          }
        }
      }
    } catch (e) {
      print('[Translate] Error stopping recording: $e');
      if (mounted) setState(() => processing = false);
    }
  }
}
