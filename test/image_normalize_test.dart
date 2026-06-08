import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:handpickd_image_compare/src/image_normalize.dart';
import 'package:image/image.dart' as img;

void main() {
  test('resizeImageToMaxDimension keeps image when already within limit', () {
    final image = img.Image(width: 800, height: 600);
    final resized = resizeImageToMaxDimension(image, 1024);
    expect(resized.width, 800);
    expect(resized.height, 600);
  });

  test('resizeImageToMaxDimension scales longest edge down', () {
    final image = img.Image(width: 2000, height: 1500);
    final resized = resizeImageToMaxDimension(image, 1024);
    expect(resized.width, 1024);
    expect(resized.height, 768);
  });

  test('normalizeImageBytes returns original bytes when maxDimension is null', () {
    final bytes = Uint8List.fromList(img.encodeJpg(img.Image(width: 10, height: 10)));
    expect(normalizeImageBytes(bytes), same(bytes));
  });
}
