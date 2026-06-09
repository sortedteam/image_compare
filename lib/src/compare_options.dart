import 'ocr_match_mode.dart';

/// Which algorithms run when comparing two images.
class ImageCompareOptions {
  const ImageCompareOptions({
    this.openCv = true,
    this.perceptualHash = true,
    this.differenceHash = true,
    this.averageHash = true,
    this.ocr = false,
    this.skipOcrIfAverageAbove50 = false,
    this.ocrMatchMode = OcrMatchMode.exact,
    this.maxImageDimension,
    this.openCvBidirectional = true,
    this.openCvReuseInstance = false,
    this.logCompareSteps = false,
  });

  /// OpenCV + perceptual hashes on; OCR off; legacy OpenCV behavior.
  static const ImageCompareOptions defaults = ImageCompareOptions();

  final bool openCv;
  final bool perceptualHash;
  final bool differenceHash;
  final bool averageHash;
  final bool ocr;

  /// When [ocr] is on, [averageHash] is enabled, average hash > 50%, **and**
  /// OpenCV best score > 50%, skip OCR as an optimization. If OpenCV is weak,
  /// OCR still runs so text can rescue the score.
  final bool skipOcrIfAverageAbove50;

  /// [OcrMatchMode.exact] = identical tokens only.
  /// [OcrMatchMode.partial] = substring / token-substring overlap (either way).
  final OcrMatchMode ocrMatchMode;

  /// Downscale both images so the longest edge is at most this value before
  /// compare. `null` keeps original bytes (current behavior).
  final int? maxImageDimension;

  /// When true, OpenCV runs forward and reverse and keeps the higher score.
  final bool openCvBidirectional;

  /// When true, reuses one OpenCV `PixelMatching` instance for calls in a
  /// single compare (and for batch reference compares).
  final bool openCvReuseInstance;

  /// Prints step-by-step compare logs to console (lab / debug only).
  final bool logCompareSteps;

  bool get anyHash => perceptualHash || differenceHash || averageHash;

  bool get anyEnabled => openCv || anyHash || ocr;

  /// Whether OCR should be skipped for this pair (see [skipOcrIfAverageAbove50]).
  bool shouldSkipOcr({
    required double averageHashPercent,
    required double openCvBest,
  }) {
    if (!ocr || !skipOcrIfAverageAbove50 || !averageHash) return false;
    if (averageHashPercent <= 50) return false;
    // Hashes alone are not enough when pixels don't align.
    if (openCvBest * 100 <= 50) return false;
    return true;
  }

  ImageCompareOptions copyWith({
    bool? openCv,
    bool? perceptualHash,
    bool? differenceHash,
    bool? averageHash,
    bool? ocr,
    bool? skipOcrIfAverageAbove50,
    OcrMatchMode? ocrMatchMode,
    int? maxImageDimension,
    bool? openCvBidirectional,
    bool? openCvReuseInstance,
    bool? logCompareSteps,
    bool clearMaxImageDimension = false,
  }) {
    return ImageCompareOptions(
      openCv: openCv ?? this.openCv,
      perceptualHash: perceptualHash ?? this.perceptualHash,
      differenceHash: differenceHash ?? this.differenceHash,
      averageHash: averageHash ?? this.averageHash,
      ocr: ocr ?? this.ocr,
      skipOcrIfAverageAbove50:
          skipOcrIfAverageAbove50 ?? this.skipOcrIfAverageAbove50,
      ocrMatchMode: ocrMatchMode ?? this.ocrMatchMode,
      maxImageDimension: clearMaxImageDimension
          ? null
          : (maxImageDimension ?? this.maxImageDimension),
      openCvBidirectional: openCvBidirectional ?? this.openCvBidirectional,
      openCvReuseInstance: openCvReuseInstance ?? this.openCvReuseInstance,
      logCompareSteps: logCompareSteps ?? this.logCompareSteps,
    );
  }
}
