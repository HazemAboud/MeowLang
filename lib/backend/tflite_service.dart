import 'dart:developer';
import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';

class TFLiteService {
  Interpreter? _interpreter;
  bool _isModelLoaded = false;

  final List<String> _classLabels = [
    'Food',
    'Isolation',
    'MotherCall',
    'Resting',
    'Angry',
  ];

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/deployed/model.tflite');
      _isModelLoaded = true;
      log('TFLite model loaded successfully.');
    } catch (e) {
      log('Failed to load TFLite model: $e');
      _isModelLoaded = false;
    }
  }

  bool get isModelLoaded => _isModelLoaded;

  Future<Map<String, dynamic>> runInference(List<Float64List> melSpectrogramData) async {
    if (!_isModelLoaded || _interpreter == null) {
      log('Model not loaded. Cannot run inference.');
      return {'label': 'Error', 'confidence': 0.0};
    }

    try {
      // Flatten the List<Float64List> into a single Float32List
      final inputTensorShape = _interpreter!.getInputTensor(0).shape;

      // Determine the expected total size of the input
      int expectedSize = inputTensorShape.reduce((a, b) => a * b);
      // If batch size is 1, remove it from expected size for flattening
      if (inputTensorShape.isNotEmpty && inputTensorShape[0] == 1) {
        expectedSize = inputTensorShape.sublist(1).reduce((a, b) => a * b);
      }

      final input = Float32List(expectedSize);
      int currentIndex = 0;
      for (var frame in melSpectrogramData) {
        for (var value in frame) {
          if (currentIndex < expectedSize) { // Prevent overflow if data is too large
            input[currentIndex++] = value; 
          }
        }
      }

      // Reshape the input to match the model's expected input shape (e.g., [1, 128, num_frames, 1])
      final reshapedInput = input.reshape(inputTensorShape);

      // Output tensor
      var output = List<double>.filled(_classLabels.length, 0).reshape([1, _classLabels.length]);

      _interpreter!.run(reshapedInput, output);

      // Argmax logic
      List<double> probabilities = List<double>.from(output[0]);
      int maxIdx = 0;
      double maxProb = -1.0;
      for (int i = 0; i < probabilities.length; i++) {
        if (probabilities[i] > maxProb) {
          maxProb = probabilities[i];
          maxIdx = i;
        }
      }

      return {'label': _classLabels[maxIdx], 'confidence': maxProb};
    } catch (e) {
      log('Error during TFLite inference: $e');
      return {'label': 'Error', 'confidence': 0.0};
    }
  }

  void close() {
    _interpreter?.close();
    _interpreter = null;
    _isModelLoaded = false;
  }
}