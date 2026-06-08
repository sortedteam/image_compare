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
    expect(options.skipOcrIfAverageAbove50, isTrue);
    expect(options.maxImageDimension, isNull);
    expect(options.openCvBidirectional, isTrue);
    expect(options.openCvReuseInstance, isFalse);
    expect(options.logCompareSteps, isFalse);
  });
}
