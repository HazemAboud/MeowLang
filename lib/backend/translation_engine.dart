import 'dart:io';
import 'dart:math';
import 'package:meow_lang/backend/audio_spectrogram.dart';
import 'package:flutter/foundation.dart';
import 'package:meow_lang/backend/firebase_service.dart';
import 'package:meow_lang/models/historyRecord.dart';
import 'package:meow_lang/models/translation.dart';
import 'package:meow_lang/backend/tflite_service.dart';
import 'package:meow_lang/models/user.dart' as app_user;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:image/image.dart' as img_lib;

/// Helper for offloading spectrogram generation to an isolate.
// helper for spectrogram generation
Future<void> _generateSpectrogramIsolate(Map<String, dynamic> args) async {
  await saveSpectrogramPng(
    args['wavPath'] as String,
    args['imagePath'] as String,
    sampleRate: args['sampleRate'] as int,
    nMels: args['nMels'] as int,
    nFft: args['nFft'] as int,
    hopLength: args['hopLength'] as int,
  );
}
// helper for image processing
/// must be top-level for compute
/// This must be a top-level function to be used with [compute].
Future<void> _processSpectrogramImage(String imagePath) async {
  final imageFile = File(imagePath);
  if (!await imageFile.exists()) return;

  final bytes = await imageFile.readAsBytes();
  final img_lib.Image? image = img_lib.decodePng(bytes);
  
  if (image != null && image.width > 0 && image.height > 0) {
    // The model is trained on images with margins and axes, so the cropping step is removed.
    // model trained on images with margins
    // resizing improves performance
    final img_lib.Image resized = img_lib.copyResize(
      image, 
      width: 512, 
      height: 512,
      interpolation: img_lib.Interpolation.linear);
    // overwrites file with resized version
    await imageFile.writeAsBytes(img_lib.encodePng(resized), flush: true);
  }
}

class TranslationEngine {
  final FirebaseService _db = FirebaseService();
  final TfliteService _tfliteService = TfliteService();
  final Random _random = Random();

  final Map<String, List<String>> _classMessages = {
    'angry': [
      "Back off! I'm not in the mood.",
      "I'm really annoyed right now.",
      "Don't touch me, human!",
      "I'll KILL YOU!!!",
      "MEOOOW! Stay away."
    ],
    'food': [
      "I am hungry...",
      "Is it dinner time yet?",
      "I'm starving! Feed me now.",
      "Human! I want to eat!",
      "Can't you hear my stomach?"
    ],
    'isolation': [
      "Where did everyone go?",
      "I'm feeling a bit lonely over here.",
      "Is anybody home?",
      "I need some company.",
      "Don't leave me all by myself."
    ],
    'motherCall': [
      "MAMA, MAMA, MAMA!",
      "I need my mom",
      "Where's my mom?",
      "I am looking for my mom",
      "Mama, are you there?"
    ],
    'Resting': [
      "I'm just chilling out.",
      "I'm feeling comfy",
      "I am happy and relaxed.",
      "I'm cozy rn.",
      "Keep scratching human"
    ],
  };

  TranslationEngine();

  Future<Map<String, dynamic>> processMeow(String wavPath, String catId, String catName, {void Function(String)? onStatusUpdate}) async {
    final stopwatch = Stopwatch()..start(); // starts stopwatch for logging
    // ensures model is loaded
    // loads model if not already
    if (!_tfliteService.isModelLoaded) {
      try {
        onStatusUpdate?.call("Loading AI model...");
        await _tfliteService.loadModel();
        print('[Engine] TFLite model loaded on-demand.'); 
        if (!_tfliteService.isModelLoaded) {
          throw Exception('Model reported as not loaded after initialization.');
        }
      } catch (e) {
        print('TFLite model failed to load: $e');
        return {'label': 'Error', 'text': 'Translation service unavailable', 'confidence': 0.0};
      }
    }
    
    // verifies audio exists
    // recorder flush delay on some phones
    final wavFile = File(wavPath);
    onStatusUpdate?.call("Verifying audio...");
    print('[Engine] Checking for audio at: $wavPath');
    int audioRetry = 0;
    while (audioRetry < 5 && (!await wavFile.exists() || await wavFile.length() == 0)) {
      await Future.delayed(const Duration(milliseconds: 300));
      audioRetry++;
    }

    if (!await wavFile.exists() || await wavFile.length() == 0) {
      return {'label': 'Error', 'text': 'Audio file not found', 'confidence': 0.0};
    }

    // generates spectrogram image
    // uses direct path on mobile
    // avoids sandbox-restricted directories
    final String imagePath = p.setExtension(wavPath, '.png');
    
    try {
      // ensures directory exists
      final directory = Directory(p.dirname(imagePath));
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // 1.1 Generate the visual spectrogram image.
      onStatusUpdate?.call("Generating spectrogram...");
      await compute(_generateSpectrogramIsolate, {
        'wavPath': wavPath,
        'imagePath': imagePath,
        'sampleRate': 22050,
        'nMels': 128,
        'nFft': 2048,
        'hopLength': 512,
      });

      int imgRetry = 0;
      // ensures image is written
      while (imgRetry < 15 && (!await File(imagePath).exists() || await File(imagePath).length() == 0)) {
        await Future.delayed(const Duration(milliseconds: 200));
        imgRetry++;
      }

      if (!await File(imagePath).exists()) {
        throw Exception('Spectrogram file was not created or is empty.');
      }
      
      // crops and resaves spectrogram
      try {
        onStatusUpdate?.call("Optimizing image...");
        print('[Engine] Processing spectrogram isolate...');
        await compute(_processSpectrogramImage, imagePath);
      } catch (cropError) {
        print('Warning: Spectrogram cropping failed (using original): $cropError');
      }
    } catch (e) {
      // Log full stack trace for spectrogram issues
      print('Spectrogram Generation Critical Error: $e');
      debugPrintStack();
      return {'label': 'Error', 'text': 'Visualizing meow failed...', 'confidence': 0.0};
    }

    final String imageName = p.basename(imagePath);

    Map<String, dynamic> result;
    // runs inference
    try {
      onStatusUpdate?.call("Running inference...");
      result = await _tfliteService.runInference(imagePath);
    } catch (e) {
      print('Inference Error: $e');
      return {'label': 'Error', 'text': 'Failed to process audio', 'confidence': 0.0};
    }
    
    stopwatch.stop();

    // Log AI performance with device info
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    String phoneModel = "Unknown";
    if (Platform.isAndroid) {
      phoneModel = (await deviceInfo.androidInfo).model;
    } else if (Platform.isIOS) {
      phoneModel = (await deviceInfo.iosInfo).utsname.machine;
    }
    await _db.logInferencePerformance(stopwatch.elapsedMilliseconds.toDouble(), phoneModel);

    // confidence calculation
    final double confidence = (result['confidence'] ?? 0.0) * 100;
    final String prediction = result['label'] ?? 'Unknown';

    // picks random message
    final options = _classMessages[prediction] ?? ["I am feeling $prediction"];
    final String randomText = options[_random.nextInt(options.length)];

    // uses current user's id
    // allows saving meows without assigned cat
    final catUserId = app_user.User.currentUser?.userId;
    String? transId;
    // saves to firebase if user logged in
    if (catUserId != null) {
      // 4. Save to Firebase only if user is logged in
      onStatusUpdate?.call("Saving to cloud...");
      final translation = Translation(
        audioPath: wavPath,
        imgPath: imageName, // Save filename instead of absolute path
        className: prediction,
        confidence: confidence, // saves filename
        dateTime: DateTime.now(),
      );

      transId = await _db.saveTranslation(translation);

      final history = HistoryRecord(
        translationId: transId,
        catId: catId,
        textTranslation: randomText,
        translationDatetime: DateTime.now(),
      );

      await _db.saveHistory(history, catName: catName, userId: catUserId);
    }
    
    return {
      'label': prediction,
      'text': randomText, // Return the human-readable intent for the UI
      'confidence': confidence,
      'imgPath': imagePath,
      'id': transId
    };
  }

  void dispose() {
    _tfliteService.close();
  }
}