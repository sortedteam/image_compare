import 'package:flutter/foundation.dart';

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

/// OCR is disabled in this build to avoid GoogleMLKit pod conflicts with
/// mobile_scanner. OpenCV + perceptual hashes remain available.
Future<OcrCompareResult> compareTextInImages(
  Uint8List bytes1,
  Uint8List bytes2,
) async {
  return const OcrCompareResult(
    text1: '',
    text2: '',
    similarityPercent: 0,
    sharedTokens: [],
    image1Duration: Duration.zero,
    image2Duration: Duration.zero,
  );
}
