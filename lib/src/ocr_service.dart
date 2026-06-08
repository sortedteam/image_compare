import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

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
  Uint8List bytes2,
) async {
  final sw1 = Stopwatch()..start();
  final text1 = await _recognizeText(bytes1);
  sw1.stop();

  final sw2 = Stopwatch()..start();
  final text2 = await _recognizeText(bytes2);
  sw2.stop();

  final tokens1 = _tokenize(text1);
  final tokens2 = _tokenize(text2);
  final shared = tokens1.intersection(tokens2).toList()..sort();

  return OcrCompareResult(
    text1: text1,
    text2: text2,
    similarityPercent: _tokenSimilarityPercent(tokens1, tokens2),
    sharedTokens: shared,
    image1Duration: sw1.elapsed,
    image2Duration: sw2.elapsed,
  );
}

Future<String> _recognizeText(Uint8List bytes) async {
  if (bytes.isEmpty) return '';

  File? tempFile;
  try {
    tempFile = File(
      '${Directory.systemTemp.path}/ocr_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await tempFile.writeAsBytes(bytes, flush: true);

    final recognizer = await _textRecognizer();
    final result = await recognizer.processImage(
      InputImage.fromFilePath(tempFile.path),
    );
    return result.text.trim();
  } catch (_) {
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
