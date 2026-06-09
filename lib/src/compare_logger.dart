import 'compare_input_meta.dart';
import 'compare_options.dart';

/// Debug logging for compare pipeline steps.
class CompareLogger {
  const CompareLogger._();

  static bool shouldLog(ImageCompareOptions options) =>
      options.logCompareSteps || options.ocr;

  static void log(String message, {required ImageCompareOptions options}) {
    if (!shouldLog(options)) return;
    // ignore: avoid_print
    print('[ImageCompare] $message');
  }

  static void logOptions(ImageCompareOptions options) {
    if (!shouldLog(options)) return;
    log(
      'options: openCv=${options.openCv}, hashes='
      'p${options.perceptualHash}/d${options.differenceHash}/a${options.averageHash}, '
      'ocr=${options.ocr}, ocrMatch=${options.ocrMatchMode.name}, '
      'skipOcrIfAvgAbove50=${options.skipOcrIfAverageAbove50}, '
      'maxDim=${options.maxImageDimension ?? "none"}, '
      'bidirectional=${options.openCvBidirectional}, reuse=${options.openCvReuseInstance}, '
      'verbose=${options.logCompareSteps}',
      options: options,
    );
  }

  static void logInputStage({
    required String stage,
    required CompareInputMeta meta,
    required ImageCompareOptions options,
  }) {
    if (!options.logCompareSteps) return;
    log('$stage | ref original=${meta.referenceOriginal}', options: options);
    log('$stage | query original=${meta.queryOriginal}', options: options);
    log('$stage | ref prepared=${meta.referencePrepared}', options: options);
    log('$stage | query prepared=${meta.queryPrepared}', options: options);
    log('$stage | pipeline=${meta.stageLabel}', options: options);
  }

  static void logBatchStart({
    required int queryCount,
    required ImageCompareOptions options,
  }) {
    log(
      '── batch compare start | queries=$queryCount ──',
      options: options,
    );
    logOptions(options);
  }

  static void logBatchQuery({
    required int queryIndex,
    required int queryCount,
    required int refBytes,
    required int queryBytes,
    required ImageCompareOptions options,
  }) {
    log(
      'query ${queryIndex + 1}/$queryCount | refBytes=$refBytes queryBytes=$queryBytes',
      options: options,
    );
  }

  static void logStep({
    required String step,
    required ImageCompareOptions options,
  }) {
    log(step, options: options);
  }

  static void logOpenCvDone({
    required double forward,
    required double reverse,
    required double best,
    required bool bidirectional,
    required int ms,
    required ImageCompareOptions options,
  }) {
    log(
      'OpenCV done | fwd=${(forward * 100).toStringAsFixed(1)}% '
      'rev=${(reverse * 100).toStringAsFixed(1)}% '
      'best=${(best * 100).toStringAsFixed(1)}% '
      'bidirectional=$bidirectional ${ms}ms',
      options: options,
    );
  }

  static void logHashesDone({
    required double perceptual,
    required double difference,
    required double average,
    required int ms,
    required ImageCompareOptions options,
  }) {
    log(
      'hashes done | pHash=${perceptual.toStringAsFixed(1)}% '
      'dHash=${difference.toStringAsFixed(1)}% '
      'aHash=${average.toStringAsFixed(1)}% ${ms}ms',
      options: options,
    );
  }

  static void logOcrSkipped({
    required double averageHashPercent,
    required double openCvBestPercent,
    required ImageCompareOptions options,
  }) {
    log(
      'OCR SKIPPED | aHash=${averageHashPercent.toStringAsFixed(1)}% > 50% '
      'and openCv=${openCvBestPercent.toStringAsFixed(1)}% > 50% '
      '(skipOcrIfAverageAbove50=${options.skipOcrIfAverageAbove50})',
      options: options,
    );
  }

  static void logOcrStart({required ImageCompareOptions options}) {
    log('OCR START | running ML Kit text recognition...', options: options);
  }

  static void logOcrResult({
    required String text1,
    required String text2,
    required double ocrPercent,
    required List<String> sharedTokens,
    required int image1Ms,
    required int image2Ms,
    required ImageCompareOptions options,
  }) {
    log(
      'OCR DONE | image1=${image1Ms}ms image2=${image2Ms}ms '
      'similarity=${ocrPercent.toStringAsFixed(1)}% '
      'sharedTokens=$sharedTokens',
      options: options,
    );
    log('OCR text1 (${text1.length} chars): ${_preview(text1)}', options: options);
    log('OCR text2 (${text2.length} chars): ${_preview(text2)}', options: options);
  }

  static void logMerge({
    required double visual,
    required double ocrPercent,
    required List<String> sharedTokens,
    required bool ocrRan,
    required double overall,
    required ImageCompareOptions options,
  }) {
    if (!ocrRan) {
      log(
        'MERGE | ocrRan=false → overall=visual=${visual.toStringAsFixed(1)}%',
        options: options,
      );
      return;
    }

    final deadZone = sharedTokens.isEmpty && ocrPercent < 30;
    log(
      'MERGE | visual=${visual.toStringAsFixed(1)}% '
      'ocr=${ocrPercent.toStringAsFixed(1)}% '
      'shared=$sharedTokens '
      'deadZoneIgnored=$deadZone '
      '→ overall=${overall.toStringAsFixed(1)}%',
      options: options,
    );
  }

  static void logScoreSummary({
    required double overallPercent,
    required double visualPercent,
    required double openCvBest,
    required double openCvForward,
    required double openCvReverse,
    required double perceptualHashPercent,
    required double differenceHashPercent,
    required double averageHashPercent,
    required double ocrPercent,
    required bool ocrRan,
    required List<String> sharedOcrTokens,
    required int totalMs,
    required int openCvMs,
    required int hashMs,
    required int ocrMs,
    required ImageCompareOptions options,
  }) {
    log(
      'scores: overall=${overallPercent.toStringAsFixed(1)}% '
      'visual=${visualPercent.toStringAsFixed(1)}% '
      'openCvBest=${(openCvBest * 100).toStringAsFixed(1)}% '
      'fwd=${(openCvForward * 100).toStringAsFixed(1)}% '
      'rev=${(openCvReverse * 100).toStringAsFixed(1)}% '
      'pHash=${perceptualHashPercent.toStringAsFixed(1)}% '
      'dHash=${differenceHashPercent.toStringAsFixed(1)}% '
      'aHash=${averageHashPercent.toStringAsFixed(1)}% '
      'ocr=${ocrPercent.toStringAsFixed(1)}% ocrRan=$ocrRan '
      'shared=$sharedOcrTokens',
      options: options,
    );
    log(
      'timings: total=${totalMs}ms openCv=${openCvMs}ms hash=${hashMs}ms ocr=${ocrMs}ms',
      options: options,
    );
  }

  static void logBatchBest({
    required double bestScore,
    required ImageCompareOptions options,
  }) {
    log(
      '── batch compare end | best=${bestScore.toStringAsFixed(1)}% ──',
      options: options,
    );
  }

  static String _preview(String text, {int maxLen = 120}) {
    final trimmed = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (trimmed.isEmpty) return '(empty)';
    if (trimmed.length <= maxLen) return trimmed;
    return '${trimmed.substring(0, maxLen)}...';
  }
}
