import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Decoded size + raw byte length for one image payload.
class ImageByteInfo {
  const ImageByteInfo({
    required this.bytesLength,
    this.width,
    this.height,
  });

  final int bytesLength;
  final int? width;
  final int? height;

  String get dimensionsLabel {
    if (width == null || height == null) return 'unknown';
    return '${width}x$height';
  }

  @override
  String toString() => '$dimensionsLabel (${_formatBytes(bytesLength)})';

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)}KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

/// Original upload bytes vs bytes actually fed into compare algorithms.
class CompareInputMeta {
  const CompareInputMeta({
    required this.referenceOriginal,
    required this.queryOriginal,
    required this.referencePrepared,
    required this.queryPrepared,
    required this.resized,
    this.maxImageDimension,
  });

  final ImageByteInfo referenceOriginal;
  final ImageByteInfo queryOriginal;
  final ImageByteInfo referencePrepared;
  final ImageByteInfo queryPrepared;
  final bool resized;
  final int? maxImageDimension;

  String get stageLabel =>
      resized ? 'post-resize (${maxImageDimension}px)' : 'pre-resize (original)';
}

ImageByteInfo describeImageBytes(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  return ImageByteInfo(
    bytesLength: bytes.length,
    width: decoded?.width,
    height: decoded?.height,
  );
}
