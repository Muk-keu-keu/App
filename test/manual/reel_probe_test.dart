@Tags(['manual'])
library;

// 결과를 눈으로 보는 것이 목적인 스크립트라 print 를 그대로 쓴다.
// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
// gemini_extractor 가 계약(extraction.dart)을 함께 내보낸다 — DishExtractor 포함.
import 'package:mukbang_ttaradamgi/services/gemini_extractor.dart';
import 'package:mukbang_ttaradamgi/services/metadata_fetcher.dart';
import 'package:mukbang_ttaradamgi/services/openai_extractor.dart';

/// 실제 링크 한 건으로 메타데이터 → 추출까지 돌려 본다.
/// 실제 호출이 나가므로 수동 실행 전용이다.
///   flutter test test/manual/reel_probe_test.dart --dart-define=OPENAI_KEY=...
///   flutter test test/manual/reel_probe_test.dart --dart-define=GEMINI_KEY=...
///
/// 제공자를 바꿀 때 같은 입력으로 before/after 를 비교하는 자리이기도 하다.
/// 모델은 `--dart-define=MODEL=`, 링크는 `URL=` 로 바꾼다.
///
/// **인스타는 로그인 없이 캡션을 안 주는 경우가 많다.** 그때 메타데이터가
/// `Instagram / null` 로만 와서 추출이 빈 결과가 되는데, 이건 추출이 아니라
/// 메타데이터 문제다. 둘을 가르려면 캡션을 직접 넣어 본다:
///   --dart-define=TEXT='엽떡 오리지널 맛에 분모자 추가해서 먹었어요'
void main() {
  const openAiKey = String.fromEnvironment('OPENAI_KEY');
  const geminiKey = String.fromEnvironment('GEMINI_KEY');
  const model = String.fromEnvironment('MODEL');
  const text = String.fromEnvironment('TEXT');
  const url = String.fromEnvironment(
    'URL',
    defaultValue: 'https://www.instagram.com/reels/DbvLQkeBZjB/',
  );
  final key = openAiKey.isNotEmpty ? openAiKey : geminiKey;

  test('릴스에서 뽑은 요리와 카테고리', () async {
    final DishExtractor extractor = openAiKey.isNotEmpty
        ? OpenAiExtractor(
            apiKey: openAiKey,
            model: model.isEmpty ? OpenAiExtractor.defaultModel : model,
          )
        : GeminiExtractor(apiKey: geminiKey);
    print('── 추출기: ${extractor.runtimeType} ──');

    String input = text;
    if (input.isEmpty) {
      final meta = await const MetadataFetcher().fetch(Uri.parse(url));
      print('── 메타데이터 ──');
      print('title      : ${meta.title}');
      print('siteName   : ${meta.siteName}');
      print('description: ${meta.description}');
      input = meta.combinedText;
    } else {
      print('── 입력(직접 넣은 텍스트) ──');
      print(input);
    }

    final result = await extractor.extract(input);
    print('── 추출 ──');
    for (final d in result.dishes) {
      print('요리: ${d.name} | 카테고리: ${d.foodCategory?.wire ?? "(없음)"} '
          '| 브랜드: ${d.brandName ?? "-"} | 설명: ${d.description}');
    }
    print('keywords: ${result.keywords}');
  },
      timeout: const Timeout(Duration(seconds: 90)),
      // 키를 넘기지 않으면 건너뛴다. 평소 `flutter test` 가 실제 한도·요금을
      // 태우면 안 된다.
      skip: key.isEmpty
          ? 'OPENAI_KEY 또는 GEMINI_KEY 를 --dart-define 으로 넘겨야 실행된다'
          : null);
}
