import 'compare_input_meta.dart';
import 'compare_options.dart';

/// Debug logging for compare pipeline steps. No-op when [enabled] is false.
class CompareLogger {
  const CompareLogger._();

  static void log(String message, {bool enabled = false}) {
    if (!enabled) return;
    // ignore: avoid_print
    print('[ImageCompare] $message');
  }

  static void logOptions(ImageCompareOptions options, {bool enabled = false}) {
    if (!enabled) return;
    log(
      'options: openCv=${options.openCv}, hashes='
      'p${options.perceptualHash}/d${options.differenceHash}/a${options.averageHash}, '
      'ocr=${options.ocr}, maxDim=${options.maxImageDimension ?? "none"}, '
      'bidirectional=${options.openCvBidirectional}, reuse=${options.openCvReuseInstance}',
      enabled: true,
    );
  }

  static void logInputStage({
    required bool enabled,
    required String stage,
    required CompareInputMeta meta,
  }) {
    if (!enabled) return;
    log('$stage | ref original=${meta.referenceOriginal}', enabled: true);
    log('$stage | query original=${meta.queryOriginal}', enabled: true);
    log('$stage | ref prepared=${meta.referencePrepared}', enabled: true);
    log('$stage | query prepared=${meta.queryPrepared}', enabled: true);
    log('$stage | pipeline=${meta.stageLabel}', enabled: true);
  }

  static void logScoreSummary({
    required bool enabled,
    required double overallPercent,
    required double visualPercent,
    required double openCvBest,
    required double openCvForward,
    required double openCvReverse,
    required double perceptualHashPercent,
    required double differenceHashPercent,
    required double averageHashPercent,
    required double ocrPercent,
    required int totalMs,
    required int openCvMs,
    required int hashMs,
  }) {
    if (!enabled) return;
    log(
      'scores: overall=${overallPercent.toStringAsFixed(1)}% '
      'visual=${visualPercent.toStringAsFixed(1)}% '
      'openCvBest=${(openCvBest * 100).toStringAsFixed(1)}% '
      'fwd=${(openCvForward * 100).toStringAsFixed(1)}% '
      'rev=${(openCvReverse * 100).toStringAsFixed(1)}% '
      'pHash=${perceptualHashPercent.toStringAsFixed(1)}% '
      'dHash=${differenceHashPercent.toStringAsFixed(1)}% '
      'aHash=${averageHashPercent.toStringAsFixed(1)}% '
      'ocr=${ocrPercent.toStringAsFixed(1)}%',
      enabled: true,
    );
    log(
      'timings: total=${totalMs}ms openCv=${openCvMs}ms hash=${hashMs}ms',
      enabled: true,
    );
  }
}
