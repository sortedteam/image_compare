import 'ocr_match_mode.dart';

class OcrTextCompareResult {
  const OcrTextCompareResult({
    required this.similarityPercent,
    required this.sharedTokens,
    required this.matchMode,
    required this.substringMatched,
  });

  final double similarityPercent;
  final List<String> sharedTokens;
  final OcrMatchMode matchMode;
  final bool substringMatched;
}

OcrTextCompareResult compareOcrTexts(
  String text1,
  String text2, {
  OcrMatchMode mode = OcrMatchMode.exact,
}) {
  final tokens1 = _tokenize(text1);
  final tokens2 = _tokenize(text2);

  if (mode == OcrMatchMode.exact) {
    final shared = tokens1.intersection(tokens2).toList()..sort();
    return OcrTextCompareResult(
      similarityPercent: _exactTokenSimilarity(tokens1, tokens2),
      sharedTokens: shared,
      matchMode: mode,
      substringMatched: false,
    );
  }

  final substringScore = _substringContainmentScore(text1, text2);
  final substringMatched = substringScore > 0;
  final partialShared = _partialSharedTokens(tokens1, tokens2).toList()..sort();
  final partialTokenScore = _partialTokenSimilarity(tokens1, tokens2);
  final exactTokenScore = _exactTokenSimilarity(tokens1, tokens2);

  var similarity = substringScore;
  if (partialTokenScore > similarity) similarity = partialTokenScore;
  if (exactTokenScore > similarity) similarity = exactTokenScore;

  if (substringMatched && partialShared.isEmpty) {
    final compact = _compactMatch(text1, text2);
    if (compact != null) partialShared.add(compact);
  }

  return OcrTextCompareResult(
    similarityPercent: similarity.clamp(0.0, 100.0),
    sharedTokens: partialShared,
    matchMode: mode,
    substringMatched: substringMatched,
  );
}

String? _compactMatch(String text1, String text2) {
  final c1 = _compactAlphanumeric(text1);
  final c2 = _compactAlphanumeric(text2);
  if (c1.isEmpty || c2.isEmpty) return null;

  final short = c1.length <= c2.length ? c1 : c2;
  final long = c1.length <= c2.length ? c2 : c1;
  if (short.length < 3 || !long.contains(short)) return null;
  return short;
}

double _substringContainmentScore(String text1, String text2) {
  final match = _compactMatch(text1, text2);
  if (match == null) return 0;

  final c1 = _compactAlphanumeric(text1);
  final c2 = _compactAlphanumeric(text2);
  final short = c1.length <= c2.length ? c1 : c2;
  final long = c1.length <= c2.length ? c2 : c1;

  return (90.0 + (short.length / long.length) * 10.0).clamp(90.0, 100.0);
}

String _compactAlphanumeric(String text) {
  return text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}

Set<String> _tokenize(String text) {
  if (text.isEmpty) return {};

  final tokens = <String>{};
  for (final match in RegExp(r'[a-z0-9]+').allMatches(text.toLowerCase())) {
    final token = match.group(0)!;
    if (token.length >= 2) tokens.add(token);
  }
  return tokens;
}

Set<String> _partialSharedTokens(Set<String> left, Set<String> right) {
  final shared = <String>{...left.intersection(right)};

  for (final a in left) {
    for (final b in right) {
      if (a == b) {
        shared.add(a);
        continue;
      }
      if (a.length < 3 || b.length < 3) continue;
      if (a.contains(b)) {
        shared.add(b);
      } else if (b.contains(a)) {
        shared.add(a);
      }
    }
  }

  return shared;
}

double _exactTokenSimilarity(Set<String> left, Set<String> right) {
  if (left.isEmpty && right.isEmpty) return 0;
  if (left.isEmpty || right.isEmpty) return 0;

  final shared = left.intersection(right);
  final union = left.union(right);
  if (union.isEmpty) return 0;

  return (shared.length / union.length) * 100.0;
}

double _partialTokenSimilarity(Set<String> left, Set<String> right) {
  if (left.isEmpty && right.isEmpty) return 0;
  if (left.isEmpty || right.isEmpty) return 0;

  final shared = _partialSharedTokens(left, right);
  if (shared.isEmpty) return 0;

  final union = left.union(right);
  return (shared.length / union.length) * 100.0;
}
