import 'compare_options.dart';

/// Named option bundles for side-by-side lab / debug runs.
class ComparePreset {
  const ComparePreset({
    required this.id,
    required this.label,
    required this.description,
    required this.options,
    required this.stage,
  });

  final String id;
  final String label;
  final String description;
  final ImageCompareOptions options;

  /// `pre-resize` = original upload bytes. `post-resize` = after [maxImageDimension].
  final String stage;
}

const List<ComparePreset> comparePresets = [
  // ── Pre-resize: original full-resolution bytes (before 1024 normalize) ──
  ComparePreset(
    id: 'pre_full_legacy',
    label: '[Pre] Legacy full-res',
    description: 'Original bytes, forward+reverse OpenCV, new isolate each pass.',
    stage: 'pre-resize',
    options: ImageCompareOptions.defaults,
  ),
  ComparePreset(
    id: 'pre_full_forward',
    label: '[Pre] Full-res forward OpenCV',
    description: 'Original bytes, reference→query only.',
    stage: 'pre-resize',
    options: ImageCompareOptions(openCvBidirectional: false),
  ),
  ComparePreset(
    id: 'pre_full_reuse',
    label: '[Pre] Full-res reuse OpenCV',
    description: 'Original bytes, reuse one PixelMatching instance.',
    stage: 'pre-resize',
    options: ImageCompareOptions(openCvReuseInstance: true),
  ),
  ComparePreset(
    id: 'pre_full_forward_reuse',
    label: '[Pre] Full-res forward + reuse',
    description: 'Original bytes, forward-only + reuse instance.',
    stage: 'pre-resize',
    options: ImageCompareOptions(
      openCvBidirectional: false,
      openCvReuseInstance: true,
    ),
  ),
  ComparePreset(
    id: 'pre_full_opencv_only',
    label: '[Pre] OpenCV only full-res',
    description: 'Original bytes, OpenCV forward+reuse, hashes off.',
    stage: 'pre-resize',
    options: ImageCompareOptions(
      perceptualHash: false,
      differenceHash: false,
      averageHash: false,
      openCvBidirectional: false,
      openCvReuseInstance: true,
    ),
  ),
  ComparePreset(
    id: 'pre_full_hash_only',
    label: '[Pre] Hash only full-res',
    description: 'Original bytes, OpenCV off.',
    stage: 'pre-resize',
    options: ImageCompareOptions(openCv: false),
  ),

  // ── Post-resize: after 1024px normalize ──
  ComparePreset(
    id: 'post_1024_legacy',
    label: '[Post] Resize 1024 legacy',
    description: 'After 1024 normalize, forward+reverse, new isolate each pass.',
    stage: 'post-resize',
    options: ImageCompareOptions(maxImageDimension: 1024),
  ),
  ComparePreset(
    id: 'post_1024_forward',
    label: '[Post] Resize 1024 forward',
    description: 'After 1024 normalize, forward-only OpenCV.',
    stage: 'post-resize',
    options: ImageCompareOptions(
      maxImageDimension: 1024,
      openCvBidirectional: false,
    ),
  ),
  ComparePreset(
    id: 'post_1024_reuse',
    label: '[Post] Resize 1024 reuse',
    description: 'After 1024 normalize, reuse PixelMatching instance.',
    stage: 'post-resize',
    options: ImageCompareOptions(
      maxImageDimension: 1024,
      openCvReuseInstance: true,
    ),
  ),
  ComparePreset(
    id: 'post_1024_forward_reuse',
    label: '[Post] Recommended production',
    description: 'After 1024 normalize, forward-only + reuse.',
    stage: 'post-resize',
    options: ImageCompareOptions(
      maxImageDimension: 1024,
      openCvBidirectional: false,
      openCvReuseInstance: true,
    ),
  ),
  ComparePreset(
    id: 'post_1024_opencv_only',
    label: '[Post] OpenCV only @ 1024',
    description: 'After 1024 normalize, OpenCV forward+reuse, hashes off.',
    stage: 'post-resize',
    options: ImageCompareOptions(
      openCv: true,
      perceptualHash: false,
      differenceHash: false,
      averageHash: false,
      maxImageDimension: 1024,
      openCvBidirectional: false,
      openCvReuseInstance: true,
    ),
  ),
  ComparePreset(
    id: 'post_1024_hash_only',
    label: '[Post] Hash only @ 1024',
    description: 'After 1024 normalize, OpenCV off.',
    stage: 'post-resize',
    options: ImageCompareOptions(
      openCv: false,
      maxImageDimension: 1024,
    ),
  ),
];

ComparePreset? findComparePreset(String id) {
  for (final preset in comparePresets) {
    if (preset.id == id) return preset;
  }
  return null;
}
