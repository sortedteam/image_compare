import 'package:flutter/foundation.dart';

import 'compare_options.dart';
import 'compare_service.dart' as impl;

export 'compare_service.dart' show CompareScores, CompareTimings;

/// Compare two images and return overall similarity (0–100).
///
/// Pass ready JPEG/PNG bytes. Use [maxImageDimension] to normalize size first.
Future<double> compareTwoImages(
  Uint8List image1,
  Uint8List image2, {
  bool openCv = true,
  bool perceptualHash = true,
  bool differenceHash = true,
  bool averageHash = true,
  bool ocr = false,
  bool skipOcrIfAverageAbove50 = false,
  int? maxImageDimension,
  bool openCvBidirectional = true,
  bool openCvReuseInstance = false,
}) async {
  final scores = await impl.compareTwoImages(
    image1,
    image2,
    options: ImageCompareOptions(
      openCv: openCv,
      perceptualHash: perceptualHash,
      differenceHash: differenceHash,
      averageHash: averageHash,
      ocr: ocr,
      skipOcrIfAverageAbove50: skipOcrIfAverageAbove50,
      maxImageDimension: maxImageDimension,
      openCvBidirectional: openCvBidirectional,
      openCvReuseInstance: openCvReuseInstance,
    ),
  );
  return scores.overallPercent;
}

/// Compare with an explicit [ImageCompareOptions] and return full score details.
Future<impl.CompareScores> compareWithOptions(
  Uint8List image1,
  Uint8List image2,
  ImageCompareOptions options,
) {
  return impl.compareTwoImages(image1, image2, options: options);
}

/// Same as [compareTwoImages] but returns the full score breakdown and timings.
Future<impl.CompareScores> compareTwoImagesDetailed(
  Uint8List image1,
  Uint8List image2, {
  bool openCv = true,
  bool perceptualHash = true,
  bool differenceHash = true,
  bool averageHash = true,
  bool ocr = false,
  bool skipOcrIfAverageAbove50 = false,
  int? maxImageDimension,
  bool openCvBidirectional = true,
  bool openCvReuseInstance = false,
}) {
  return impl.compareTwoImages(
    image1,
    image2,
    options: ImageCompareOptions(
      openCv: openCv,
      perceptualHash: perceptualHash,
      differenceHash: differenceHash,
      averageHash: averageHash,
      ocr: ocr,
      skipOcrIfAverageAbove50: skipOcrIfAverageAbove50,
      maxImageDimension: maxImageDimension,
      openCvBidirectional: openCvBidirectional,
      openCvReuseInstance: openCvReuseInstance,
    ),
  );
}

/// Compare many query images against one reference; returns the highest score.
Future<double> compareQueriesToReference(
  Uint8List reference,
  List<Uint8List> queries, {
  bool openCv = true,
  bool perceptualHash = true,
  bool differenceHash = true,
  bool averageHash = true,
  bool ocr = false,
  bool skipOcrIfAverageAbove50 = false,
  int? maxImageDimension,
  bool openCvBidirectional = true,
  bool openCvReuseInstance = false,
  bool logCompareSteps = false,
}) {
  return impl.compareQueriesToReference(
    reference,
    queries,
    options: ImageCompareOptions(
      openCv: openCv,
      perceptualHash: perceptualHash,
      differenceHash: differenceHash,
      averageHash: averageHash,
      ocr: ocr,
      skipOcrIfAverageAbove50: skipOcrIfAverageAbove50,
      maxImageDimension: maxImageDimension,
      openCvBidirectional: openCvBidirectional,
      openCvReuseInstance: openCvReuseInstance,
      logCompareSteps: logCompareSteps,
    ),
  );
}
