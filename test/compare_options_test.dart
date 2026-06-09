import 'package:flutter_test/flutter_test.dart';
import 'package:handpickd_image_compare/src/compare_options.dart';

void main() {
  test('defaults preserve legacy behavior', () {
    const options = ImageCompareOptions.defaults;

    expect(options.openCv, isTrue);
    expect(options.perceptualHash, isTrue);
    expect(options.differenceHash, isTrue);
    expect(options.averageHash, isTrue);
    expect(options.ocr, isFalse);
    expect(options.skipOcrIfAverageAbove50, isFalse);
    expect(options.maxImageDimension, isNull);
    expect(options.openCvBidirectional, isTrue);
    expect(options.openCvReuseInstance, isFalse);
    expect(options.logCompareSteps, isFalse);
  });

  test('shouldSkipOcr requires strong openCv when average hash is high', () {
    const options = ImageCompareOptions(
      ocr: true,
      skipOcrIfAverageAbove50: true,
    );

    expect(
      options.shouldSkipOcr(averageHashPercent: 67, openCvBest: 0.6),
      isTrue,
    );
    expect(
      options.shouldSkipOcr(averageHashPercent: 67, openCvBest: 0.0),
      isFalse,
    );
    expect(
      options.shouldSkipOcr(averageHashPercent: 40, openCvBest: 0.8),
      isFalse,
    );
    expect(
      options.shouldSkipOcr(averageHashPercent: 67, openCvBest: 0.5),
      isFalse,
    );
  });
}
