import 'package:flutter_test/flutter_test.dart';
import 'package:handpickd_image_compare/src/ocr_match_mode.dart';
import 'package:handpickd_image_compare/src/ocr_text_compare.dart';

void main() {
  test('exact mode requires identical tokens', () {
    final result = compareOcrTexts(
      'Dscdscsdcdscdc',
      'Aa 9 June 2026 at 3:36 PM Dscdscsdcdscdc',
      mode: OcrMatchMode.exact,
    );

    expect(result.sharedTokens, contains('dscdscsdcdscdc'));
    expect(result.similarityPercent, greaterThan(0));
  });

  test('partial mode matches reference text inside longer capture', () {
    final result = compareOcrTexts(
      'Dscdscsdcdscdc',
      'Aa 9 June 2026 at 3:36 PM Dscdscsdcdscdc',
      mode: OcrMatchMode.partial,
    );

    expect(result.substringMatched, isTrue);
    expect(result.similarityPercent, greaterThanOrEqualTo(90));
    expect(result.sharedTokens, isNotEmpty);
  });

  test('partial mode works when capture is shorter (vice versa)', () {
    final result = compareOcrTexts(
      'Aa 9 June 2026 at 3:36 PM Dscdscsdcdscdc',
      'Dscdscsdcdscdc',
      mode: OcrMatchMode.partial,
    );

    expect(result.substringMatched, isTrue);
    expect(result.similarityPercent, greaterThanOrEqualTo(90));
  });

  test('partial mode matches overlapping flat-style tokens', () {
    final result = compareOcrTexts(
      '902',
      'P9021 K DII',
      mode: OcrMatchMode.partial,
    );

    expect(result.similarityPercent, greaterThan(0));
    expect(result.sharedTokens, isNotEmpty);
  });
}
