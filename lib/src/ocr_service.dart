import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'compare_logger.dart';
import 'compare_options.dart';
import 'ocr_text_compare.dart';

class OcrCompareResult {
  const OcrCompareResult({
    required this.text1,
    required this.text2,
    required this.similarityPercent,
    required this.sharedTokens,
    required this.image1Duration,
    required this.image2Duration,
    required this.substringMatched,
  });

  final String text1;
  final String text2;
  final double similarityPercent;
  final List<String> sharedTokens;
  final Duration image1Duration;
  final Duration image2Duration;
  final bool substringMatched;
}

TextRecognizer? _recognizer;

Future<TextRecognizer> _textRecognizer() async {
  return _recognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
}

/// OCR text extraction + compare via Google ML Kit.
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

  final compared = compareOcrTexts(
    text1,
    text2,
    mode: options.ocrMatchMode,
  );

  CompareLogger.log(
    'OCR compare | mode=${options.ocrMatchMode.name} '
    'substringMatched=${compared.substringMatched} '
    'tokens=${
      compared.sharedTokens
    }',
    options: options,
  );

  final result = OcrCompareResult(
    text1: text1,
    text2: text2,
    similarityPercent: compared.similarityPercent,
    sharedTokens: compared.sharedTokens,
    image1Duration: sw1.elapsed,
    image2Duration: sw2.elapsed,
    substringMatched: compared.substringMatched,
  );

  CompareLogger.logOcrResult(
    text1: text1,
    text2: text2,
    ocrPercent: compared.similarityPercent,
    sharedTokens: compared.sharedTokens,
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
