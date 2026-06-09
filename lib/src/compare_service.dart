import 'package:flutter/foundation.dart';
import 'package:flutter_pixelmatching/flutter_pixelmatching.dart';
import 'package:image/image.dart' as img;
import 'package:image_hash/image_hash.dart';

import 'compare_input_meta.dart';
import 'compare_logger.dart';
import 'compare_options.dart';
import 'image_normalize.dart';
import 'ocr_service.dart';

class CompareTimings {
  const CompareTimings({
    required this.openCvForward,
    required this.openCvReverse,
    required this.imageDecode,
    required this.perceptualHash,
    required this.differenceHash,
    required this.averageHash,
    required this.ocrImage1,
    required this.ocrImage2,
    required this.total,
  });

  final Duration openCvForward;
  final Duration openCvReverse;
  final Duration imageDecode;
  final Duration perceptualHash;
  final Duration differenceHash;
  final Duration averageHash;
  final Duration ocrImage1;
  final Duration ocrImage2;
  final Duration total;

  Duration get openCvTotal => openCvForward + openCvReverse;

  Duration get imageHashTotal =>
      imageDecode + perceptualHash + differenceHash + averageHash;

  Duration get ocrTotal => ocrImage1 + ocrImage2;
}

class CompareScores {
  const CompareScores({
    required this.options,
    required this.openCvForward,
    required this.openCvReverse,
    required this.openCvBest,
    required this.perceptualHashPercent,
    required this.differenceHashPercent,
    required this.averageHashPercent,
    required this.ocrPercent,
    required this.ocrText1,
    required this.ocrText2,
    required this.sharedOcrTokens,
    required this.visualPercent,
    required this.overallPercent,
    required this.timings,
    this.inputMeta,
  });

  final ImageCompareOptions options;
  final double openCvForward;
  final double openCvReverse;
  final double openCvBest;
  final double perceptualHashPercent;
  final double differenceHashPercent;
  final double averageHashPercent;
  final double ocrPercent;
  final String ocrText1;
  final String ocrText2;
  final List<String> sharedOcrTokens;
  final double visualPercent;
  final double overallPercent;
  final CompareTimings timings;
  final CompareInputMeta? inputMeta;
}

/// Compare two images. Use [ImageCompareOptions] to enable/disable algorithms.
Future<CompareScores> compareTwoImages(
  Uint8List image1,
  Uint8List image2, {
  ImageCompareOptions options = ImageCompareOptions.defaults,
}) async {
  if (!options.anyEnabled) {
    throw ArgumentError('At least one compare option must be enabled.');
  }

  CompareLogger.log('── compare start ──', options: options);
  CompareLogger.logOptions(options);

  final referenceOriginal = describeImageBytes(image1);
  final queryOriginal = describeImageBytes(image2);
  CompareLogger.logInputStage(
    stage: 'STEP 1 — original upload bytes (pre-resize)',
    options: options,
    meta: CompareInputMeta(
      referenceOriginal: referenceOriginal,
      queryOriginal: queryOriginal,
      referencePrepared: referenceOriginal,
      queryPrepared: queryOriginal,
      resized: false,
      maxImageDimension: options.maxImageDimension,
    ),
  );

  final normalized = normalizeImagePair(
    image1,
    image2,
    maxDimension: options.maxImageDimension,
  );
  if (normalized == null) {
    throw ArgumentError('Failed to decode one or both images for compare.');
  }

  final referencePrepared = describeImageBytes(normalized.image1);
  final queryPrepared = describeImageBytes(normalized.image2);
  final resized = options.maxImageDimension != null &&
      (referencePrepared.width != referenceOriginal.width ||
          referencePrepared.height != referenceOriginal.height ||
          referencePrepared.bytesLength != referenceOriginal.bytesLength ||
          queryPrepared.width != queryOriginal.width ||
          queryPrepared.height != queryOriginal.height ||
          queryPrepared.bytesLength != queryOriginal.bytesLength);

  final inputMeta = CompareInputMeta(
    referenceOriginal: referenceOriginal,
    queryOriginal: queryOriginal,
    referencePrepared: referencePrepared,
    queryPrepared: queryPrepared,
    resized: resized,
    maxImageDimension: options.maxImageDimension,
  );

  CompareLogger.logInputStage(
    stage: resized
        ? 'STEP 2 — after resize/normalize'
        : 'STEP 2 — no resize (using original bytes)',
    options: options,
    meta: inputMeta,
  );

  if (options.openCv) {
    CompareLogger.logStep(
      step: 'STEP 3 — OpenCV '
          '${options.openCvBidirectional ? "forward+reverse" : "forward-only"} '
          '${options.openCvReuseInstance ? "(reuse instance)" : "(new instance per pass)"}',
      options: options,
    );
  }
  if (options.anyHash) {
    CompareLogger.logStep(
      step: 'STEP 4 — perceptual hash compare',
      options: options,
    );
  }
  if (options.ocr) {
    CompareLogger.logStep(step: 'STEP 5 — OCR compare', options: options);
  }

  final scores = await _comparePreparedImages(
    normalized.image1,
    normalized.image2,
    options: options,
    inputMeta: inputMeta,
  );

  _logPairScoreSummary(scores);
  CompareLogger.log('── compare end ──', options: options);

  return scores;
}

/// Compare many query images against one reference and return the highest score.
Future<double> compareQueriesToReference(
  Uint8List reference,
  List<Uint8List> queries, {
  ImageCompareOptions options = ImageCompareOptions.defaults,
}) async {
  if (queries.isEmpty) return 0;

  CompareLogger.logBatchStart(queryCount: queries.length, options: options);

  final normalizedReference = normalizeImageBytes(
    reference,
    maxDimension: options.maxImageDimension,
  );
  if (normalizedReference == null) {
    CompareLogger.log(
      'batch aborted | failed to normalize reference image',
      options: options,
    );
    return 0;
  }

  double? bestScore;
  PixelMatching? sharedMatching;

  if (options.openCv && options.openCvReuseInstance) {
    CompareLogger.logStep(
      step: 'OpenCV | initializing shared PixelMatching on reference',
      options: options,
    );
    sharedMatching = PixelMatching();
    final ok = await sharedMatching.initialize(image: normalizedReference);
    if (!ok) {
      CompareLogger.log(
        'OpenCV | shared PixelMatching init failed, will retry per query',
        options: options,
      );
      sharedMatching.dispose();
      sharedMatching = null;
    }
  }

  try {
    var queryIndex = 0;
    for (final query in queries) {
      CompareLogger.logBatchQuery(
        queryIndex: queryIndex,
        queryCount: queries.length,
        refBytes: normalizedReference.length,
        queryBytes: query.length,
        options: options,
      );

      final normalizedQuery = normalizeImageBytes(
        query,
        maxDimension: options.maxImageDimension,
      );
      if (normalizedQuery == null) {
        CompareLogger.log(
          'query ${queryIndex + 1}/${queries.length} | skipped (decode/normalize failed)',
          options: options,
        );
        queryIndex++;
        continue;
      }

      final score = await _scorePreparedPair(
        normalizedReference,
        normalizedQuery,
        options: options,
        sharedMatching: sharedMatching,
        queryIndex: queryIndex,
        queryCount: queries.length,
      );
      _logPairScoreSummary(score);

      if (bestScore == null || score.overallPercent > bestScore) {
        CompareLogger.log(
          'query ${queryIndex + 1}/${queries.length} | new best='
          '${score.overallPercent.toStringAsFixed(1)}%',
          options: options,
        );
        bestScore = score.overallPercent;
      }

      queryIndex++;
    }
  } finally {
    sharedMatching?.dispose();
  }

  final result = bestScore ?? 0;
  CompareLogger.logBatchBest(bestScore: result, options: options);
  return result;
}

Future<CompareScores> _comparePreparedImages(
  Uint8List image1,
  Uint8List image2, {
  required ImageCompareOptions options,
  CompareInputMeta? inputMeta,
  PixelMatching? sharedMatching,
}) {
  return _scorePreparedPair(
    image1,
    image2,
    options: options,
    inputMeta: inputMeta,
    sharedMatching: sharedMatching,
  );
}

Future<CompareScores> _scorePreparedPair(
  Uint8List image1,
  Uint8List image2, {
  required ImageCompareOptions options,
  CompareInputMeta? inputMeta,
  PixelMatching? sharedMatching,
  int? queryIndex,
  int? queryCount,
}) async {
  final totalSw = Stopwatch()..start();
  final pairLabel = queryIndex != null && queryCount != null
      ? 'query ${queryIndex + 1}/$queryCount'
      : 'pair';

  var openCvForward = 0.0;
  var openCvReverse = 0.0;
  var openCvFwdDuration = Duration.zero;
  var openCvRevDuration = Duration.zero;
  PixelMatching? ownedMatching;

  if (options.openCv) {
    CompareLogger.logStep(
      step: '$pairLabel | OpenCV START',
      options: options,
    );
    final openCvResult = await _runOpenCvCompare(
      image1,
      image2,
      options: options,
      sharedMatching: sharedMatching,
      ownedMatching: ownedMatching,
    );
    openCvForward = openCvResult.forward;
    openCvReverse = openCvResult.reverse;
    openCvFwdDuration = openCvResult.forwardDuration;
    openCvRevDuration = openCvResult.reverseDuration;
    ownedMatching = openCvResult.ownedMatching;
  }

  try {
    final openCvBest = options.openCvBidirectional
        ? (openCvForward > openCvReverse ? openCvForward : openCvReverse)
        : openCvForward;

    if (options.openCv) {
      CompareLogger.logOpenCvDone(
        forward: openCvForward,
        reverse: openCvReverse,
        best: openCvBest,
        bidirectional: options.openCvBidirectional,
        ms: openCvFwdDuration.inMilliseconds + openCvRevDuration.inMilliseconds,
        options: options,
      );
    }

    CompareLogger.logStep(step: '$pairLabel | hashes START', options: options);
    final hashScores = options.anyHash
        ? _perceptualScores(
            image1,
            image2,
            perceptual: options.perceptualHash,
            difference: options.differenceHash,
            average: options.averageHash,
          )
        : _emptyHashScores();

    if (options.anyHash) {
      final hashMs = hashScores.decodeDuration.inMilliseconds +
          hashScores.perceptualDuration.inMilliseconds +
          hashScores.differenceDuration.inMilliseconds +
          hashScores.averageDuration.inMilliseconds;
      CompareLogger.logHashesDone(
        perceptual: hashScores.perceptual,
        difference: hashScores.difference,
        average: hashScores.average,
        ms: hashMs,
        options: options,
      );
    }

    OcrCompareResult ocr = const OcrCompareResult(
      text1: '',
      text2: '',
      similarityPercent: 0,
      sharedTokens: [],
      image1Duration: Duration.zero,
      image2Duration: Duration.zero,
    );
    var ocrRan = false;
    if (options.ocr) {
      final skipOcr = options.shouldSkipOcr(
        averageHashPercent: hashScores.average,
        openCvBest: openCvBest,
      );
      if (skipOcr) {
        CompareLogger.logOcrSkipped(
          averageHashPercent: hashScores.average,
          openCvBestPercent: openCvBest * 100,
          options: options,
        );
      } else {
        ocr = await compareTextInImages(
          image1,
          image2,
          options: options,
        );
        ocrRan = true;
      }
    }

    final visual = _visualPercent(
      options: options,
      openCvBest: openCvBest,
      perceptual: hashScores.perceptual,
      difference: hashScores.difference,
      average: hashScores.average,
    );

    final overall = ocrRan
        ? _mergeWithOcr(
            visual: visual,
            ocrPercent: ocr.similarityPercent,
            sharedTokens: ocr.sharedTokens,
          )
        : visual;

    CompareLogger.logMerge(
      visual: visual,
      ocrPercent: ocr.similarityPercent,
      sharedTokens: ocr.sharedTokens,
      ocrRan: ocrRan,
      overall: overall,
      options: options,
    );

    totalSw.stop();

    final timings = CompareTimings(
      openCvForward: openCvFwdDuration,
      openCvReverse: openCvRevDuration,
      imageDecode: hashScores.decodeDuration,
      perceptualHash: hashScores.perceptualDuration,
      differenceHash: hashScores.differenceDuration,
      averageHash: hashScores.averageDuration,
      ocrImage1: ocr.image1Duration,
      ocrImage2: ocr.image2Duration,
      total: totalSw.elapsed,
    );

    return CompareScores(
      options: options,
      openCvForward: openCvForward,
      openCvReverse: openCvReverse,
      openCvBest: openCvBest,
      perceptualHashPercent: hashScores.perceptual,
      differenceHashPercent: hashScores.difference,
      averageHashPercent: hashScores.average,
      ocrPercent: ocr.similarityPercent,
      ocrText1: ocr.text1,
      ocrText2: ocr.text2,
      sharedOcrTokens: ocr.sharedTokens,
      visualPercent: visual,
      overallPercent: overall,
      timings: timings,
      inputMeta: inputMeta,
    );
  } finally {
    ownedMatching?.dispose();
  }
}

Future<
    ({
      double forward,
      double reverse,
      Duration forwardDuration,
      Duration reverseDuration,
      PixelMatching? ownedMatching,
    })> _runOpenCvCompare(
  Uint8List image1,
  Uint8List image2, {
  required ImageCompareOptions options,
  PixelMatching? sharedMatching,
  PixelMatching? ownedMatching,
}) async {
  if (options.openCvReuseInstance) {
    final matching = sharedMatching ?? (ownedMatching ??= PixelMatching());
    final forwardSw = Stopwatch()..start();
    final forward = await _openCvScoreWithMatching(
      matching,
      target: image1,
      query: image2,
      initializeTarget: sharedMatching == null,
    );
    forwardSw.stop();

    if (!options.openCvBidirectional) {
      return (
        forward: forward,
        reverse: 0.0,
        forwardDuration: forwardSw.elapsed,
        reverseDuration: Duration.zero,
        ownedMatching: ownedMatching,
      );
    }

    final reverseSw = Stopwatch()..start();
    final reverse = await _openCvScoreWithMatching(
      matching,
      target: image2,
      query: image1,
      initializeTarget: true,
    );
    reverseSw.stop();

    return (
      forward: forward,
      reverse: reverse,
      forwardDuration: forwardSw.elapsed,
      reverseDuration: reverseSw.elapsed,
      ownedMatching: ownedMatching,
    );
  }

  final forwardSw = Stopwatch()..start();
  final forward = await _openCvScore(image1, image2);
  forwardSw.stop();

  if (!options.openCvBidirectional) {
    return (
      forward: forward,
      reverse: 0.0,
      forwardDuration: forwardSw.elapsed,
      reverseDuration: Duration.zero,
      ownedMatching: ownedMatching,
    );
  }

  final reverseSw = Stopwatch()..start();
  final reverse = await _openCvScore(image2, image1);
  reverseSw.stop();

  return (
    forward: forward,
    reverse: reverse,
    forwardDuration: forwardSw.elapsed,
    reverseDuration: reverseSw.elapsed,
    ownedMatching: ownedMatching,
  );
}

Future<double> _openCvScore(Uint8List target, Uint8List query) async {
  PixelMatching? matching;
  try {
    matching = PixelMatching();
    return await _openCvScoreWithMatching(
      matching,
      target: target,
      query: query,
      initializeTarget: true,
    );
  } finally {
    matching?.dispose();
  }
}

Future<double> _openCvScoreWithMatching(
  PixelMatching matching, {
  required Uint8List target,
  required Uint8List query,
  required bool initializeTarget,
}) async {
  if (initializeTarget) {
    final ok = await matching.initialize(image: target);
    if (!ok) return 0;
  }
  return matching.similarity(query);
}

double _visualPercent({
  required ImageCompareOptions options,
  required double openCvBest,
  required double perceptual,
  required double difference,
  required double average,
}) {
  var weightedSum = 0.0;
  var weightTotal = 0.0;

  if (options.openCv) {
    weightedSum += openCvBest * 100 * 0.35;
    weightTotal += 0.35;
  }
  if (options.perceptualHash) {
    weightedSum += perceptual * 0.3;
    weightTotal += 0.3;
  }
  if (options.differenceHash) {
    weightedSum += difference * 0.2;
    weightTotal += 0.2;
  }
  if (options.averageHash) {
    weightedSum += average * 0.15;
    weightTotal += 0.15;
  }

  if (weightTotal == 0) return 0;
  return (weightedSum / weightTotal).clamp(0.0, 100.0);
}

double _mergeWithOcr({
  required double visual,
  required double ocrPercent,
  required List<String> sharedTokens,
}) {
  if (sharedTokens.isEmpty && ocrPercent < 30) {
    return visual;
  }

  var merged = (visual * 0.6 + ocrPercent * 0.4).clamp(0.0, 100.0);

  if (sharedTokens.isNotEmpty) {
    merged = (merged + 12).clamp(0.0, 100.0);
    if (ocrPercent < 30) {
      merged = merged > visual ? merged : (visual + 8).clamp(0.0, 100.0);
    }
  }
  if (ocrPercent >= 75) {
    merged = merged > ocrPercent * 0.9 ? merged : ocrPercent * 0.9;
  }
  if (ocrPercent >= 90 && sharedTokens.isNotEmpty) {
    merged = 100;
  }

  return merged.clamp(0.0, 100.0);
}

({
  double perceptual,
  double difference,
  double average,
  Duration decodeDuration,
  Duration perceptualDuration,
  Duration differenceDuration,
  Duration averageDuration,
}) _emptyHashScores() {
  return (
    perceptual: 0,
    difference: 0,
    average: 0,
    decodeDuration: Duration.zero,
    perceptualDuration: Duration.zero,
    differenceDuration: Duration.zero,
    averageDuration: Duration.zero,
  );
}

({
  double perceptual,
  double difference,
  double average,
  Duration decodeDuration,
  Duration perceptualDuration,
  Duration differenceDuration,
  Duration averageDuration,
}) _perceptualScores(
  Uint8List bytes1,
  Uint8List bytes2, {
  required bool perceptual,
  required bool difference,
  required bool average,
}) {
  final decodeSw = Stopwatch()..start();
  final decoded1 = img.decodeImage(bytes1);
  final decoded2 = img.decodeImage(bytes2);
  decodeSw.stop();

  if (decoded1 == null || decoded2 == null) {
    return (
      perceptual: 0,
      difference: 0,
      average: 0,
      decodeDuration: decodeSw.elapsed,
      perceptualDuration: Duration.zero,
      differenceDuration: Duration.zero,
      averageDuration: Duration.zero,
    );
  }

  const hashSize = 8;

  var perceptualScore = 0.0;
  var perceptualDuration = Duration.zero;
  if (perceptual) {
    final pSw = Stopwatch()..start();
    final p1 = HashFn.perceptual.hashImg(decoded1, size: hashSize);
    final p2 = HashFn.perceptual.hashImg(decoded2, size: hashSize);
    perceptualScore = p1.similarity(p2) * 100;
    pSw.stop();
    perceptualDuration = pSw.elapsed;
  }

  var differenceScore = 0.0;
  var differenceDuration = Duration.zero;
  if (difference) {
    final dSw = Stopwatch()..start();
    final d1 = HashFn.difference.hashImg(decoded1, size: hashSize);
    final d2 = HashFn.difference.hashImg(decoded2, size: hashSize);
    differenceScore = d1.similarity(d2) * 100;
    dSw.stop();
    differenceDuration = dSw.elapsed;
  }

  var averageScore = 0.0;
  var averageDuration = Duration.zero;
  if (average) {
    final aSw = Stopwatch()..start();
    final a1 = HashFn.average.hashImg(decoded1, size: hashSize);
    final a2 = HashFn.average.hashImg(decoded2, size: hashSize);
    averageScore = a1.similarity(a2) * 100;
    aSw.stop();
    averageDuration = aSw.elapsed;
  }

  return (
    perceptual: perceptualScore,
    difference: differenceScore,
    average: averageScore,
    decodeDuration: decodeSw.elapsed,
    perceptualDuration: perceptualDuration,
    differenceDuration: differenceDuration,
    averageDuration: averageDuration,
  );
}

void _logPairScoreSummary(CompareScores scores) {
  final options = scores.options;
  final ocrRan = options.ocr && scores.timings.ocrTotal > Duration.zero;

  CompareLogger.logScoreSummary(
    overallPercent: scores.overallPercent,
    visualPercent: scores.visualPercent,
    openCvBest: scores.openCvBest,
    openCvForward: scores.openCvForward,
    openCvReverse: scores.openCvReverse,
    perceptualHashPercent: scores.perceptualHashPercent,
    differenceHashPercent: scores.differenceHashPercent,
    averageHashPercent: scores.averageHashPercent,
    ocrPercent: scores.ocrPercent,
    ocrRan: ocrRan,
    sharedOcrTokens: scores.sharedOcrTokens,
    totalMs: scores.timings.total.inMilliseconds,
    openCvMs: scores.timings.openCvTotal.inMilliseconds,
    hashMs: scores.timings.imageHashTotal.inMilliseconds,
    ocrMs: scores.timings.ocrTotal.inMilliseconds,
    options: options,
  );
}
