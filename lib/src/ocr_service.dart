import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'compare_logger.dart';
import 'compare_options.dart';

class OcrCompareResult {
  const OcrCompareResult({
    required this.text1,
    required this.text2,
    required this.similarityPercent,
    required this.sharedTokens,
    required this.image1Duration,
    required this.image2Duration,
  });

  final String text1;
  final String text2;
  final double similarityPercent;
  final List<String> sharedTokens;
  final Duration image1Duration;
  final Duration image2Duration;
}

TextRecognizer? _recognizer;

Future<TextRecognizer> _textRecognizer() async {
  return _recognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
}

/// OCR text extraction + token overlap compare via Google ML Kit.
Future<OcrCompareResult> compareTextInImages(
  Uint8List bytes1,
  Uint8List bytes2, {
  ImageCompareOptions options = ImageCompareOptions.defaults,
}) async {
  CompareLogger.logOcrStart(options: options);

  final sw1 = Stopwatch()..start();
  final text1 = await _recognizeText(bytes1, label: 'image1', options: options);
  sw1.stop();

  final sw2 = Stopwatch()..start();
  final text2 = await _recognizeText(bytes2, label: 'image2', options: options);
  sw2.stop();

  final tokens1 = _tokenize(text1);
  final tokens2 = _tokenize(text2);
  final shared = tokens1.intersection(tokens2).toList()..sort();
  final similarity = _tokenSimilarityPercent(tokens1, tokens2);

  CompareLogger.log(
    'OCR tokens | image1=$tokens1 image2=$tokens2',
    options: options,
  );

  final result = OcrCompareResult(
    text1: text1,
    text2: text2,
    similarityPercent: similarity,
    sharedTokens: shared,
    image1Duration: sw1.elapsed,
    image2Duration: sw2.elapsed,
  );

  CompareLogger.logOcrResult(
    text1: text1,
    text2: text2,
    ocrPercent: similarity,
    sharedTokens: shared,
    image1Ms: sw1.elapsedMilliseconds,
    image2Ms: sw2.elapsedMilliseconds,
    options: options,
  );

  return result;
}

Future<String> _recognizeText(
  Uint8List bytes, {
  required String label,
  required ImageCompareOptions options,
}) async {
  if (bytes.isEmpty) {
    CompareLogger.log('OCR $label | skipped (empty bytes)', options: options);
    return '';
  }

  File? tempFile;
  try {
    tempFile = File(
      '${Directory.systemTemp.path}/ocr_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await tempFile.writeAsBytes(bytes, flush: true);

    CompareLogger.log(
      'OCR $label | tempFile=${tempFile.path} bytes=${bytes.length}',
      options: options,
    );

    final recognizer = await _textRecognizer();
    final result = await recognizer.processImage(
      InputImage.fromFilePath(tempFile.path),
    );
    final text = result.text.trim();
    CompareLogger.log(
      'OCR $label | recognized ${text.length} chars',
      options: options,
    );
    return text;
  } catch (e, st) {
    CompareLogger.log(
      'OCR $label | ERROR: $e',
      options: options,
    );
    if (options.logCompareSteps) {
      // ignore: avoid_print
      print('[ImageCompare] OCR $label stack: $st');
    }
    return '';
  } finally {
    if (tempFile != null) {
      try {
        if (await tempFile.exists()) await tempFile.delete();
      } catch (_) {}
    }
  }
}

Set<String> _tokenize(String text) {
  if (text.isEmpty) return {};

  final tokens = <String>{};
  for (final match in RegExp(r'[a-z0-9]+').allMatches(text.toLowerCase())) {
    final token = match.group(0)!;
    if (token.length >= 2) tokens.add(token);
  }
  return tokens;
}

double _tokenSimilarityPercent(Set<String> left, Set<String> right) {
  if (left.isEmpty && right.isEmpty) return 0;
  if (left.isEmpty || right.isEmpty) return 0;

  final shared = left.intersection(right);
  final union = left.union(right);
  if (union.isEmpty) return 0;

  return (shared.length / union.length) * 100.0;
}
