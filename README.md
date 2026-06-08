# handpickd_image_compare

Flutter image similarity package — OpenCV pixel matching, perceptual hashes, and OCR (Google ML Kit Text Recognition).

Uses `google_mlkit_text_recognition` pinned to GoogleMLKit **3.2.0** so it resolves alongside `mobile_scanner` 2.x without iOS pod conflicts.

## Install

```yaml
dependencies:
  handpickd_image_compare:
    git:
      url: https://github.com/sortedteam/image_compare.git
      ref: main
```

## Public API

```dart
import 'package:handpickd_image_compare/handpickd_image_compare.dart';

final percent = await compareTwoImages(bytes1, bytes2);

// Multiple captures vs one reference (production path)
final best = await compareQueriesToReference(
  referenceBytes,
  capturedBytesList,
  maxImageDimension: 1024,
  openCvBidirectional: false,
  openCvReuseInstance: true,
  ocr: true,
);
```

## Compare lab (example app)

```bash
cd example
flutter pub get
flutter run
```
