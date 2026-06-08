import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:handpickd_image_compare/src/compare_options.dart';
import 'package:handpickd_image_compare/src/compare_service.dart';
import 'package:image/image.dart' as img;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Uint8List referenceLarge;
  late Uint8List querySmallSameScene;
  late Uint8List queryDifferentScene;
  late Uint8List? demoBytes;

  setUpAll(() {
    final pattern = _patternImage(2400, 1800, seed: 11);
    referenceLarge = Uint8List.fromList(img.encodeJpg(pattern, quality: 90));

    final smallSame = img.copyResize(
      pattern,
      width: 800,
      height: 600,
      interpolation: img.Interpolation.linear,
    );
    querySmallSameScene = Uint8List.fromList(img.encodeJpg(smallSame, quality: 90));

    final different = _patternImage(2400, 1800, seed: 97);
    queryDifferentScene = Uint8List.fromList(img.encodeJpg(different, quality: 90));

    final demoFile = File(
      'packages/flutter_pixelmatching/resources/demo_sample.png',
    );
    if (demoFile.existsSync()) {
      demoBytes = demoFile.readAsBytesSync();
    }
  });

  test('hash benchmark reports best resize + OpenCV flags', () async {
    final configs = <_BenchmarkConfig>[
      const _BenchmarkConfig(
        name: 'legacy_default',
        options: ImageCompareOptions(
          openCv: false,
          maxImageDimension: null,
          openCvBidirectional: true,
          openCvReuseInstance: false,
        ),
      ),
      const _BenchmarkConfig(
        name: 'resize_1024',
        options: ImageCompareOptions(
          openCv: false,
          maxImageDimension: 1024,
          openCvBidirectional: true,
          openCvReuseInstance: false,
        ),
      ),
      const _BenchmarkConfig(
        name: 'resize_1280',
        options: ImageCompareOptions(
          openCv: false,
          maxImageDimension: 1280,
          openCvBidirectional: true,
          openCvReuseInstance: false,
        ),
      ),
      const _BenchmarkConfig(
        name: 'resize_512',
        options: ImageCompareOptions(
          openCv: false,
          maxImageDimension: 512,
          openCvBidirectional: true,
          openCvReuseInstance: false,
        ),
      ),
      const _BenchmarkConfig(
        name: 'recommended_prod',
        options: ImageCompareOptions(
          openCv: false,
          maxImageDimension: 1024,
          openCvBidirectional: false,
          openCvReuseInstance: true,
        ),
      ),
    ];

    final results = <String, _BenchmarkResult>{};
    for (final config in configs) {
      final sameScene = await compareTwoImages(
        referenceLarge,
        querySmallSameScene,
        options: config.options,
      );
      final differentScene = await compareTwoImages(
        referenceLarge,
        queryDifferentScene,
        options: config.options,
      );

      results[config.name] = _BenchmarkResult(
        sameSceneScore: sameScene.overallPercent,
        differentSceneScore: differentScene.overallPercent,
        sameSceneMs: sameScene.timings.total.inMilliseconds,
        separation: sameScene.overallPercent - differentScene.overallPercent,
      );
    }

    if (demoBytes != null) {
      final identical = await compareTwoImages(
        demoBytes!,
        demoBytes!,
        options: const ImageCompareOptions(
          openCv: false,
          maxImageDimension: 1024,
        ),
      );
      expect(identical.overallPercent, greaterThan(95));
    }

    final bestResize = _pickBestResize(results);
    final legacy = results['legacy_default']!;
    final resized1024 = results['resize_1024']!;

    // ignore: avoid_print
    print(_formatBenchmarkReport(results, bestResize: bestResize));

    expect(legacy.separation, greaterThan(20));
    expect(resized1024.separation, greaterThan(20));
    expect(
      (resized1024.sameSceneScore - legacy.sameSceneScore).abs(),
      lessThan(5),
      reason: '1024 resize should stay close to legacy on same scene',
    );
    expect(
      resized1024.sameSceneScore,
      greaterThan(80),
      reason: '1024 resize should still detect same scene',
    );
  });

  test('OpenCV benchmark when native runtime is available', () async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      // OpenCV native bindings are not available in desktop VM tests.
      return;
    }

    final configs = <_BenchmarkConfig>[
      const _BenchmarkConfig(
        name: 'legacy_opencv',
        options: ImageCompareOptions(
          openCv: true,
          perceptualHash: false,
          differenceHash: false,
          averageHash: false,
          maxImageDimension: null,
          openCvBidirectional: true,
          openCvReuseInstance: false,
        ),
      ),
      const _BenchmarkConfig(
        name: 'optimized_opencv',
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
    ];

    final results = <String, _BenchmarkResult>{};
    for (final config in configs) {
      final sw = Stopwatch()..start();
      final score = await compareTwoImages(
        referenceLarge,
        querySmallSameScene,
        options: config.options,
      );
      sw.stop();
      results[config.name] = _BenchmarkResult(
        sameSceneScore: score.openCvBest * 100,
        differentSceneScore: 0,
        sameSceneMs: sw.elapsedMilliseconds,
        separation: 0,
      );
    }

    // ignore: avoid_print
    print(_formatOpenCvReport(results));
  });
}

String _formatBenchmarkReport(
  Map<String, _BenchmarkResult> results, {
  required String bestResize,
}) {
  final buffer = StringBuffer('Compare parameter benchmark (hash-only)\n');
  for (final entry in results.entries) {
    final result = entry.value;
    buffer.writeln(
      '${entry.key}: same=${result.sameSceneScore.toStringAsFixed(1)} '
      'diff=${result.differentSceneScore.toStringAsFixed(1)} '
      'gap=${result.separation.toStringAsFixed(1)} '
      '${result.sameSceneMs}ms',
    );
  }
  buffer.writeln('Suggested resize: $bestResize');
  buffer.writeln(
    'Suggested production flags: maxImageDimension=1024, '
    'openCvBidirectional=false, openCvReuseInstance=true',
  );
  return buffer.toString();
}

String _formatOpenCvReport(Map<String, _BenchmarkResult> results) {
  final buffer = StringBuffer('OpenCV benchmark\n');
  for (final entry in results.entries) {
    final result = entry.value;
    buffer.writeln(
      '${entry.key}: openCv=${result.sameSceneScore.toStringAsFixed(1)} '
      '${result.sameSceneMs}ms',
    );
  }
  return buffer.toString();
}

String _pickBestResize(Map<String, _BenchmarkResult> results) {
  const candidates = ['resize_1024', 'resize_1280', 'resize_512'];
  var best = candidates.first;
  var bestScore = -1.0;

  for (final name in candidates) {
    final result = results[name];
    if (result == null) continue;
    final ranking = result.separation + (result.sameSceneScore * 0.1);
    if (ranking > bestScore) {
      bestScore = ranking;
      best = name;
    }
  }
  return best;
}

img.Image _patternImage(int width, int height, {required int seed}) {
  final image = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelRgb(
        x,
        y,
        (x * 7 + seed) % 256,
        (y * 11 + seed) % 256,
        ((x + y) * 5 + seed) % 256,
      );
    }
  }
  return image;
}

class _BenchmarkConfig {
  const _BenchmarkConfig({required this.name, required this.options});

  final String name;
  final ImageCompareOptions options;
}

class _BenchmarkResult {
  const _BenchmarkResult({
    required this.sameSceneScore,
    required this.differentSceneScore,
    required this.sameSceneMs,
    required this.separation,
  });

  final double sameSceneScore;
  final double differentSceneScore;
  final int sameSceneMs;
  final double separation;
}
