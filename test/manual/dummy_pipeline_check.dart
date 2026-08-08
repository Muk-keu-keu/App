/// 더미 모드 파이프라인을 실제 링크로 통과시켜 보는 수동 점검 스크립트.
///
/// 자동 테스트가 아니다 — 파일명이 `_test.dart` 가 아니라 `flutter test` 의 기본
/// 수집에 걸리지 않는다. 네트워크(인스타·유튜브·Gemini)를 타므로 CI 에 넣을 수 없다.
///
///     flutter test test/manual/dummy_pipeline_check.dart
///
/// 확인하는 것: 링크 → 메타데이터 → Gemini 추출 → MockComboRepository 조합.
/// 서버 없이 도는 시연 경로 전체다.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mukbang_ttaradamgi/models/analysis_source.dart';
import 'package:mukbang_ttaradamgi/models/preference.dart';
import 'package:mukbang_ttaradamgi/repository/combo_repository.dart';
import 'package:mukbang_ttaradamgi/services/gemini_extractor.dart';
import 'package:mukbang_ttaradamgi/services/metadata_fetcher.dart';

/// 시연에 쓸 링크들. 각 줄의 주석이 기대하는 결과다.
const _links = <String, String>{
  'https://www.instagram.com/reel/DIBHSZrSkZe/': '엽기떡볶이(로제떡볶이) + 교촌(허니콤보)',
  'https://www.instagram.com/reel/C_hHk7iSnKU/': '엽기떡볶이 + bhc(콜팝)',
  'https://www.youtube.com/watch?v=nqK6NmofbxY': '보배반점(크림짬뽕 + 탕수육)',
  'https://www.youtube.com/shorts/qxzgAMV4Cik': '두찜(로제찜닭 + 치즈볼)',
};

/// `.env` 를 직접 읽는다. 테스트는 에셋 번들이 없어 flutter_dotenv 를 못 쓴다.
String _geminiKey() {
  final file = File('.env');
  if (!file.existsSync()) return '';
  for (final line in file.readAsLinesSync()) {
    if (line.startsWith('GEMINI_API_KEY=')) return line.split('=').skip(1).join('=').trim();
  }
  return '';
}

void main() {
  final key = _geminiKey();

  test('4개 링크가 더미 조합까지 통과한다', () async {
    if (key.isEmpty) {
      stdout.writeln('.env 에 GEMINI_API_KEY 가 없어 건너뜀');
      return;
    }

    final extractor = GeminiExtractor(apiKey: key);
    const repo = MockComboRepository(delay: Duration.zero);
    final failures = <String>[];

    for (final entry in _links.entries) {
      final uri = Uri.parse(entry.key);
      stdout.writeln('\n${'=' * 72}\n${entry.value}\n$uri');

      // 1) 메타데이터
      final PageMetadata meta;
      try {
        meta = await const MetadataFetcher().fetch(uri);
      } on Object catch (e) {
        failures.add('${entry.value} — 메타데이터 실패: $e');
        stdout.writeln('  ❌ 메타데이터 실패: $e');
        continue;
      }
      final text = meta.combinedText;
      stdout.writeln('  본문 ${text.length}자  썸네일 ${meta.imageUrl == null ? "없음" : "있음"}');
      if (text.trim().isEmpty) {
        failures.add('${entry.value} — 본문이 비었다');
        stdout.writeln('  ❌ 본문이 비어 Gemini 가 뽑을 게 없다');
        continue;
      }

      // 2) Gemini 추출
      final ExtractionResult extraction;
      try {
        extraction = await extractor.extract(text);
      } on Object catch (e) {
        failures.add('${entry.value} — Gemini 실패: $e');
        stdout.writeln('  ❌ Gemini 실패: $e');
        continue;
      }
      stdout.writeln('  추출 ${extraction.dishes.length}개:');
      for (final d in extraction.dishes) {
        stdout.writeln(
            '    · ${d.name}  brand=${d.brandName ?? "-"}  cat=${d.foodCategory?.wire ?? "-"}  opts=${d.options}');
      }
      if (extraction.dishes.isEmpty) {
        failures.add('${entry.value} — 추출 0개');
        stdout.writeln('  ❌ 메뉴를 하나도 못 뽑았다');
        continue;
      }

      // 3) 더미 조합
      final result = await repo.analyze(
        source: AnalysisSource.fromUrl(url: uri, rawText: text),
        extraction: extraction,
        thumbnailUrl: meta.imageUrl,
        preference: TastePreference(),
      );

      stdout.writeln('  exactMatches ${result.exactMatches.length} / combos ${result.combos.length}');
      for (final m in result.exactMatches) {
        stdout.writeln('    [영상] ${m.restaurant.name}  메뉴 ${m.items.length}개  '
            '${m.items.map((i) => i.name).join(", ")}');
      }
      for (final c in result.combos.take(2)) {
        stdout.writeln('    [비슷] ${c.restaurant.name}  메뉴 ${c.items.length}개');
      }

      if (result.isEmpty) {
        failures.add('${entry.value} — 조합 0개');
        stdout.writeln('  ❌ 조합이 하나도 안 나왔다');
      } else if (result.exactMatches.isEmpty) {
        // 브랜드를 못 잡으면 "영상 속 그 가게" 카드가 없다. 시연의 핵심이 빠진다.
        failures.add('${entry.value} — exactMatches 0개 (브랜드 매칭 실패)');
        stdout.writeln('  ⚠️ exactMatches 가 없다 — 브랜드를 못 잡았다');
      } else {
        stdout.writeln('  ✅ 통과');
      }
    }

    stdout.writeln('\n${'=' * 72}');
    if (failures.isEmpty) {
      stdout.writeln('4개 링크 모두 통과');
    } else {
      stdout.writeln('문제 ${failures.length}건:');
      for (final f in failures) {
        stdout.writeln('  - $f');
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  }, timeout: const Timeout(Duration(minutes: 5)));
}
