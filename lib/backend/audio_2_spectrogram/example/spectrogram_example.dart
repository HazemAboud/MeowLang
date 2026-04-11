import 'dart:io';
import '../lib/audio_spectrogram.dart';

/// A simple example showing how to generate a spectrogram from a WAV file.
///
/// Usage:
///   dart example/spectrogram_example.dart <path/to/audio.wav>
void main(List<String> args) async {
  if (args.isEmpty) {
    print('Please provide a path to a .wav file.');
    print('Usage: dart example/spectrogram_example.dart <input.wav>');
    exit(1);
  }

  final inputPath = args[0];
  final file = File(inputPath);
  if (!file.existsSync()) {
    print('Error: File "$inputPath" does not exist.');
    exit(1);
  }

  // Define output path (e.g., input.wav -> input.png)
  final outputPath = inputPath.replaceAll(RegExp(r'\.wav$', caseSensitive: false), '.png');

  if (outputPath == inputPath) {
    print('Error: Input file must have a .wav extension.');
    exit(1);
  }

  print('Processing: $inputPath');
  print('Target:     $outputPath');

  try {
    // 1. Generate and save the spectrogram image directly.
    // This function handles loading, STFT, Mel-filterbank, dB conversion, and plotting.
    final stopwatch = Stopwatch()..start();

    await saveSpectrogramPng(
      inputPath,
      outputPath,
      sampleRate: 22050, // Resample audio to 22.05kHz
      nFft: 2048,        // FFT window size
      hopLength: 512,    // Hop length (frames overlap)
      nMels: 128,        // Number of Mel bands
      fMin: 20.0,        // Min frequency
      fMax: 8000.0,      // Max frequency
      topDb: 80.0,       // Dynamic range for dB
      title: 'Spectrogram: ${file.uri.pathSegments.last}',
    );

    print('Spectrogram saved in ${stopwatch.elapsedMilliseconds}ms.');

    // 2. (Optional) Access the raw spectrogram data.
    // This is useful if you need the numerical data for analysis or ML.
    final melSpectrogramMatrix = await melSpectrogram(
      inputPath,
      sampleRate: 22050,
      nFft: 2048,
      nMels: 128,
    );

    print('\nRaw Data Statistics:');
    print('Frames: ${melSpectrogramMatrix.isEmpty ? 0 : melSpectrogramMatrix[0].length}');
    print('Mel Bands: ${melSpectrogramMatrix.length}');

  } catch (e, stack) {
    print('An error occurred: $e');
    print(stack);
    exit(1);
  }
}