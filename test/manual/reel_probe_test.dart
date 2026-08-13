@Tags(['manual'])
library;

// 결과를 눈으로 보는 것이 목적인 스크립트라 print 를 그대로 쓴다.
// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:mukbang_ttaradamgi/services/gemini_extractor.dart';
import 'package:mukbang_ttaradamgi/services/metadata_fetcher.dart';

/// 실제 릴스 한 건으로 메타데이터 → 추출까지 돌려 본다.
/// Gemini 하루 한도를 쓰므로 수동 실행 전용이다.
///   flutter test test/manual/reel_probe_test.dart --dart-define=GEMINI_KEY=...
void main() {
  const key = String.fromEnvironment('GEMINI_KEY');

  test('릴스에서 뽑은 요리와 카테고리', () async {
    final url = Uri.parse('https://www.instagram.com/reels/DbvLQkeBZjB/');
    final meta = await const MetadataFetcher().fetch(url);
    print('── 메타데이터 ──');
    print('title      : ${meta.title}');
    print('siteName   : ${meta.siteName}');
    print('description: ${meta.description}');

    final result = await GeminiExtractor(apiKey: key).extract(meta.combinedText);
    print('── 추출 ──');
    for (final d in result.dishes) {
      print('요리: ${d.name} | 카테고리: ${d.foodCategory?.wire ?? "(없음)"} '
          '| 브랜드: ${d.brandName ?? "-"} | 설명: ${d.description}');
    }
    print('keywords: ${result.keywords}');
  },
      timeout: const Timeout(Duration(seconds: 90)),
      // 키를 넘기지 않으면 건너뛴다. 평소 `flutter test` 가 Gemini 한도를
      // 태우면 안 된다.
      skip: key.isEmpty ? 'GEMINI_KEY 를 --dart-define 으로 넘겨야 실행된다' : null);
}
