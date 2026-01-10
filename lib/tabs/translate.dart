import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:meow_lang/DB/database_helper.dart';
import 'package:meow_lang/models/cat.dart';
import 'package:meow_lang/models/historyRecord.dart';
import 'package:meow_lang/models/translation.dart';

class TranslateMenu extends StatefulWidget {
  const TranslateMenu({super.key});

  @override
  State<TranslateMenu> createState() => _TranslateMenuState();
}

class _TranslateMenuState extends State<TranslateMenu> {
  final player = AudioPlayer();
  final AudioRecorder _audioRecorder = AudioRecorder();

  bool holding = false;
  bool processing = false;
  String translatedText = "";
  double _scale = 1.0;
  List<Cat> _cats = [];
  Cat? _selectedCat;

  @override
  void initState() {
    super.initState();
    _loadCats();
  }

  @override
  void dispose() {
    player.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _loadCats() async {
    final cats = await DatabaseHelper.instance.getCats();
    if (mounted) {
      setState(() {
        _cats = cats;
        if (_cats.isNotEmpty) {
          _selectedCat = _cats.first;
        }
      });
    }
  }

  Future<void> _saveTranslationResult(String label, String? audioPath, double confidence) async {
    if (_cats.isEmpty) return;

    try {
      final translation = Translation(
        audioPath: audioPath,
        className: label,
        confidence: confidence,
        dateTime: DateTime.now(),
      );

      // 1. Insert Translation and get ID
      final translationId = await DatabaseHelper.instance.insertTranslation(translation);

      // 2. Create History Record with matching IDs
      final record = HistoryRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        textTranslation: label,
        translationId: translationId,
        catId: _selectedCat?.catId,
      );

      // 3. Store in DB
      await DatabaseHelper.instance.insertHistory(record);
    } catch (e) {
      debugPrint('Error saving translation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save history: $e')),
        );
      }
    }
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
                _stopRecording();},
              child: AnimatedScale(
                scale: _scale,
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOutBack,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(50),
                  decoration: BoxDecoration(
                    color: holding
                        ? Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.2)
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
                            ? Theme.of(context).primaryColor.withOpacity(0.4)
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
                processing ? 'Translating...' : (holding ? 'Capturing Meows...' : 'Hold To Capture'),
                key: ValueKey(processing ? 2 : (holding ? 1 : 0)),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: holding ? Theme.of(context).primaryColor : null,
                    ),
              ),
            ),
            const SizedBox(height: 40),
            if (translatedText.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'Your Cat Says:',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Theme.of(context).colorScheme.secondary,
                            letterSpacing: 1.2,
                          ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      translatedText,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w600,
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
                  Icon(Icons.pets, size: 18, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 8),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<Cat>(
                      value: _selectedCat,
                      isDense: true,
                      icon: const Icon(Icons.arrow_drop_down),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
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
        final path = '${directory.path}/meow_recording_${DateTime.now().millisecondsSinceEpoch}.wav';

        if (await _audioRecorder.isRecording()) return;

        await _audioRecorder.start(const RecordConfig(encoder: AudioEncoder.wav), path: path);
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
        if (mounted) {
          setState(() {
            processing = true;
            translatedText = "";
          });
        }

        // --- SERVER CONFIGURATION ---
        // If using Android Emulator: Use '10.0.2.2'
        // If using Physical Device: Use your PC's LAN IP (e.g., '192.168.1.35')
        const String androidServerIp = '192.168.1.104'; 
        const String serverPort = '5000';

        final String serverUrl = Platform.isAndroid 
            ? 'http://$androidServerIp:$serverPort/convert' 
            : 'http://127.0.0.1:$serverPort/convert';

        debugPrint('Uploading to $serverUrl...');

        try {
          var request = http.MultipartRequest('POST', Uri.parse(serverUrl));
          request.persistentConnection = false; // Fix: Prevent premature connection closure
          request.files.add(await http.MultipartFile.fromPath('file', path));

          var streamedResponse = await request.send().timeout(const Duration(seconds: 30));
          var response = await http.Response.fromStream(streamedResponse);

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final String label = data['label'];
            debugPrint("Response class: $label");
            final double confidence = (data['confidence'] as num?)?.toDouble() ?? 0.0;
            final String base64Image = data['spectrogram'];

            final dir = await getApplicationDocumentsDirectory();
            final outputPath = '${dir.path}/spectrogram_${DateTime.now().millisecondsSinceEpoch}.png';
            final file = File(outputPath);
            await file.writeAsBytes(base64Decode(base64Image));
            debugPrint('Spectrogram received and saved to: $outputPath');

            if (mounted) {
              setState(() {
                translatedText = "Label: $label";
                processing = false;
              });
              player.play(AssetSource('audio/pop.mp3'));
              _saveTranslationResult(label, path, confidence);
            }
          } else {
            debugPrint('Server Error: ${response.statusCode} ${response.body}');
            
            String errorMsg = "Server Error: ${response.statusCode}";
            try {
              final errData = jsonDecode(response.body);
              if (errData is Map && errData.containsKey('error')) {
                errorMsg = errData['error'];
              }
            } catch (_) {}

            if (mounted) setState(() {
              processing = false;
              translatedText = errorMsg;
            });
          }
        } on SocketException catch (e) {
          debugPrint('Socket Error: $e');
          if (mounted) setState(() {
            processing = false;
            translatedText = "Connection Failed: Check IP & Firewall.\n$e";
          });
        } on http.ClientException catch (e) {
          debugPrint('Client Error: $e');
          if (mounted) setState(() {
            processing = false;
            translatedText = "Network Error: Server closed connection.\nTry again.";
          });
        } catch (e) {
          debugPrint('General Error: $e');
          debugPrint('Ensure python server is running: python server.py');
          if (mounted) setState(() {
            processing = false;
            translatedText = "Error (${e.runtimeType}): $e";
          });
        }

        // Delete the temporary audio file
        final audioFile = File(path);
        if (await audioFile.exists()) {
          await audioFile.delete();
          debugPrint('Temporary audio file deleted.');
        }
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      if (mounted) setState(() => processing = false);
    }
  }
}
