import 'dart:io';
import 'dart:developer';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img_lib;

class LiteRTService {
  Interpreter? _interpreter;
  bool _isModelLoaded = false;

  final List<String> _classLabels = [
    'angry',
    'food',
    'isolation',
    'motherCall',
    'Resting', // Ensure this matches the keys in TranslationEngine._classMessages
  ];

  Future<void> loadModel() async {
    try {
      // Using multiple threads can help Flex kernels initialize more reliably.
      final options = InterpreterOptions()..threads = 4;

      _interpreter = await Interpreter.fromAsset(
        'models/deployed/model.tflite',
        options: options,
      );
      _isModelLoaded = true;
      log('LiteRT model loaded successfully.');
    } catch (e) {
      log('Failed to load LiteRT model: $e');
      _isModelLoaded = false;
    }
  }

  bool get isModelLoaded => _isModelLoaded;

  Future<Map<String, dynamic>> runInference(String imagePath) async {
    if (!_isModelLoaded || _interpreter == null) {
      log('LiteRT Model not loaded. Cannot run inference.');
      return {'label': 'Error', 'confidence': 0.0};
    }

    try {
      // Get the model's expected input shape (e.g., [1, 512, 512, 3])
      final inputTensor = _interpreter!.getInputTensor(0);
      final List<int> shape = inputTensor.shape;
      final int height = shape[1];
      final int width = shape[2];
      final int channels = shape[3];

      // 1. Load and decode the image from the saved spectrogram file
      final bytes = await File(imagePath).readAsBytes();
      img_lib.Image? image = img_lib.decodeImage(bytes);
      if (image == null) throw Exception("Failed to decode spectrogram image");

      // 2. Resize to expected model dimensions (e.g. 512x512)
      // Matching your requirement: img.resize((512, 512))
      img_lib.Image resized = img_lib.copyResize(
        image,
        width: width,
        height: height,
        interpolation: img_lib.Interpolation.cubic,
      );

      // 3. Normalize pixel values and create flat buffer
      // Preprocessing matching (img_array / 127.5) - 1.0 used in training
      final inputBuffer = Float32List(1 * height * width * channels);
      
      int index = 0;
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          final pixel = resized.getPixel(x, y);
          inputBuffer[index++] = (pixel.r / 127.5) - 1.0;
          if (channels >= 3) {
            inputBuffer[index++] = (pixel.g / 127.5) - 1.0;
            inputBuffer[index++] = (pixel.b / 127.5) - 1.0;
          }
        }
      }
      final input = inputBuffer.reshape(shape);

      // Use Float32List for the output buffer for better performance with LiteRT
      final output = Float32List(_classLabels.length).reshape([1, _classLabels.length]);

      _interpreter!.run(input, output);

      // Apply Softmax to convert raw logits to probabilities (matches Python functional.softmax)
      final List<double> logits = List<double>.from(output[0]);
      final double maxLogit = logits.reduce(math.max);
      final List<double> exps = logits.map((l) => math.exp(l - maxLogit)).toList();
      final double sumExps = exps.reduce((a, b) => a + b);
      final List<double> probabilities = exps.map((e) => e / sumExps).toList();

      // Find the class with the highest probability
      int maxIdx = 0;
      double maxProb = -1.0;
      for (int i = 0; i < probabilities.length; i++) {
        if (probabilities[i] > maxProb) {
          maxProb = probabilities[i];
          maxIdx = i;
        }
      }

    return {'label': _classLabels[maxIdx], 'confidence': maxProb, 'index': maxIdx};
    } catch (e) {
      log('Error during LiteRT inference: $e');
      return {'label': 'Error', 'confidence': 0.0};
    }
  }

  void close() {
    _interpreter?.close();
    _interpreter = null;
    _isModelLoaded = false;
  }
}