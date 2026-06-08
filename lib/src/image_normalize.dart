import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Downscales [image] so its longest edge is at most [maxDimension].
/// Returns a copy when no resize is needed.
img.Image resizeImageToMaxDimension(img.Image image, int maxDimension) {
  if (maxDimension <= 0) {
    throw ArgumentError.value(maxDimension, 'maxDimension', 'must be positive');
  }

  final longest = image.width > image.height ? image.width : image.height;
  if (longest <= maxDimension) return image.clone();

  final scale = maxDimension / longest;
  final targetWidth = (image.width * scale).round().clamp(1, maxDimension);
  final targetHeight = (image.height * scale).round().clamp(1, maxDimension);

  return img.copyResize(
    image,
    width: targetWidth,
    height: targetHeight,
    interpolation: img.Interpolation.linear,
  );
}

/// Encodes JPEG bytes after optional downscale. Returns null when decode fails.
Uint8List? normalizeImageBytes(
  Uint8List bytes, {
  int? maxDimension,
  int jpegQuality = 85,
}) {
  if (maxDimension == null) return bytes;

  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;

  final normalized = resizeImageToMaxDimension(decoded, maxDimension);
  return Uint8List.fromList(img.encodeJpg(normalized, quality: jpegQuality));
}

/// Normalizes both inputs when [maxDimension] is set.
({Uint8List image1, Uint8List image2})? normalizeImagePair(
  Uint8List image1,
  Uint8List image2, {
  int? maxDimension,
  int jpegQuality = 85,
}) {
  if (maxDimension == null) {
    return (image1: image1, image2: image2);
  }

  final normalized1 = normalizeImageBytes(
    image1,
    maxDimension: maxDimension,
    jpegQuality: jpegQuality,
  );
  final normalized2 = normalizeImageBytes(
    image2,
    maxDimension: maxDimension,
    jpegQuality: jpegQuality,
  );

  if (normalized1 == null || normalized2 == null) return null;
  return (image1: normalized1, image2: normalized2);
}
