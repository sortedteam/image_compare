/// Which algorithms run when comparing two images.
class ImageCompareOptions {
  const ImageCompareOptions({
    this.openCv = true,
    this.perceptualHash = true,
    this.differenceHash = true,
    this.averageHash = true,
    this.ocr = false,
    this.skipOcrIfAverageAbove50 = true,
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

  /// When [ocr] is on and [averageHash] score is already above 50%, skip OCR.
  final bool skipOcrIfAverageAbove50;

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

  ImageCompareOptions copyWith({
    bool? openCv,
    bool? perceptualHash,
    bool? differenceHash,
    bool? averageHash,
    bool? ocr,
    bool? skipOcrIfAverageAbove50,
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
      maxImageDimension: clearMaxImageDimension
          ? null
          : (maxImageDimension ?? this.maxImageDimension),
      openCvBidirectional: openCvBidirectional ?? this.openCvBidirectional,
      openCvReuseInstance: openCvReuseInstance ?? this.openCvReuseInstance,
      logCompareSteps: logCompareSteps ?? this.logCompareSteps,
    );
  }
}
