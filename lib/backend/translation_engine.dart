import 'package:audio_2_spectrogram/audio_spectrogram.dart';
import 'package:meow_lang/backend/firebase_service.dart';
import 'package:meow_lang/models/historyRecord.dart';
import 'package:meow_lang/models/translation.dart';
import 'package:meow_lang/backend/tflite_service.dart';

class TranslationEngine {
  final FirebaseService _db = FirebaseService();
  final TFLiteService _tfliteService = TFLiteService();

  TranslationEngine() {
    _tfliteService.loadModel(); // Load model when engine is initialized
  }

  Future<Map<String, dynamic>> processMeow(String wavPath, String catId, String catName) async {
    if (!_tfliteService.isModelLoaded) {
      print('TFLite model not loaded. Cannot process meow.');
      return {'label': 'Offline', 'confidence': 0.0};
    }

    // 1. Generate the Spectrogram data (Replacing librosa.feature.melspectrogram)
    final spectrogramData = await melSpectrogram(
      wavPath,
      nMels: 128,
    );

    // 2. Generate the image for the History UI
    final String imagePath = wavPath.replaceAll('.wav', '.png');
    await saveSpectrogramPng(wavPath, imagePath);

    // 3. Run your Inference using TFLite
    final result = await _tfliteService.runInference(spectrogramData);
    String prediction = result['label'];
    double confidence = result['confidence'];

    // 4. Save to Firebase using your new service
    final translation = Translation(
      audioPath: wavPath,
      imgPath: imagePath,
      className: prediction,
      confidence: confidence,
      dateTime: DateTime.now(),
    );

    String transId = await _db.saveTranslation(translation);

    final history = HistoryRecord(
      translationId: transId,
      catId: catId,
      textTranslation: "I am feeling $prediction", // Update based on actual prediction
      translationDatetime: DateTime.now(),
    );
    // Fetch the cat to get the userId
    final catDoc = await _db.collection('cats').doc(catId).get();
    final catUserId = catDoc.data()?['userId'] as String?;
    if (catUserId == null) throw Exception("Cat not found or missing userId for history record.");
    await _db.saveHistory(history, catName: catName, imgPath: imagePath, userId: catUserId);
    
    return {'label': prediction, 'confidence': confidence, 'imgPath': imagePath, 'id': transId};
  }

  void dispose() {
    _tfliteService.close();
  }
}