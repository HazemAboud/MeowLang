import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:audio_2_spectrogram/audio_spectrogram.dart';
import 'package:meow_lang/backend/firebase_service.dart';
import 'package:meow_lang/models/historyRecord.dart';
import 'package:meow_lang/models/translation.dart';
import 'package:meow_lang/backend/tflite_service.dart';
import 'package:meow_lang/models/user.dart' as app_user;
import 'package:path/path.dart' as p;

class TranslationEngine {
  final FirebaseService _db = FirebaseService();
  final LiteRTService _tfliteService = LiteRTService();
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
      "I need smy mom",
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

  Future<Map<String, dynamic>> processMeow(String wavPath, String catId, String catName) async {
    // Ensure the model is loaded before processing. 
    // If not loaded, attempt to load it now to avoid returning "Offline".
    if (!_tfliteService.isModelLoaded) {
      try {
        await _tfliteService.loadModel();
        if (!_tfliteService.isModelLoaded) {
          throw Exception('Model reported as not loaded after initialization.');
        }
      } catch (e) {
        print('LiteRT model failed to load: $e');
        return {'label': 'Error', 'text': 'Translation service unavailable', 'confidence': 0.0};
      }
    }

    // 1. Generate the visual spectrogram image.
    // The AI model now processes the image file directly to match the 
    // preprocessing logic (resize and normalization) used during training.
    final String imagePath = p.setExtension(wavPath, '.png');
    await saveSpectrogramPng(wavPath, imagePath);

    final String imageName = p.basename(imagePath);

    // 2. Run Inference. The image is resized and normalized inside the service.
    Map<String, dynamic> result;
    try {
      result = await _tfliteService.runInference(imagePath);
    } catch (e) {
      print('Inference failed: $e');
      return {'label': 'Error', 'text': 'Failed to process audio', 'confidence': 0.0};
    }

    // Confidence calculation matching Python (Probability * 100)
    final double confidence = (result['confidence'] ?? 0.0) * 100;
    final String prediction = result['label'] ?? 'Unknown';

    // Pick a random message for the detected class
    final options = _classMessages[prediction] ?? ["I am feeling $prediction"];
    final String randomText = options[_random.nextInt(options.length)];

    // Use the current logged-in user's ID directly. 
    // This allows meows to be saved even if the cat is 'unassigned'.
    final catUserId = app_user.User.currentUser?.userId;
    String? transId;

    if (catUserId != null) {
      // 4. Save to Firebase only if user is logged in
      final translation = Translation(
        audioPath: wavPath,
        imgPath: imageName, // Save filename instead of absolute path
        className: prediction,
        confidence: confidence,
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

  /// Submits user feedback (corrections) to the database.
  /// This replicates the logic from server.py's /feedback endpoint for Firebase.
  Future<void> submitFeedback({
    required String translationId,
    required String newLabel,
    required String userId,
    String? catId,
  }) async {
    // 1. Fetch original translation to capture 'old' state
    final transDoc = await _db.collection('translations').doc(translationId).get();
    
    if (!transDoc.exists) {
      throw Exception("Cannot submit feedback: Original translation $translationId not found.");
    }

    final data = transDoc.data()!;

    // Read the actual image file and convert to Base64 to save the image itself
    String? base64Image;
    try {
      final String audioPath = data['audioPath'] ?? '';
      final String imageName = data['imgPath'] ?? '';
      // Reconstruct the full path based on the directory of the original audio
      final String fullPath = p.join(p.dirname(audioPath), imageName);
      final file = File(fullPath);
      
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        base64Image = base64.encode(bytes);
      } else {
        print("DEBUG: Image path for translation $translationId is no longer accessible: $fullPath");
      }
    } catch (e) {
      print("DEBUG: Failed to encode image for feedback (ID: $translationId): $e");
    }

    // 2. Save the correction to the 'corrections' collection
    await _db.collection('corrections').add({
      'translationId': translationId,
      'userId': userId,
      'catId': catId,
      'oldLabel': data['className'],
      'oldConfidence': data['confidence'],
      'newLabel': newLabel,
      'imageName': data['imgPath'],
      'imageData': base64Image, // Saving the actual binary data (Base64)
      'timestamp': DateTime.now(),
    });
  }

  void dispose() {
    _tfliteService.close();
  }
}