import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:handpickd_image_compare/src/ocr_service.dart';

void main() {
  test('compareTextInImages returns empty result for empty bytes', () async {
    final result = await compareTextInImages(Uint8List(0), Uint8List(0));

    expect(result.text1, '');
    expect(result.text2, '');
    expect(result.similarityPercent, 0);
    expect(result.sharedTokens, isEmpty);
  });
}
