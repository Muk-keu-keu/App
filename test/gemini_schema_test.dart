import 'package:flutter_test/flutter_test.dart';
import 'package:mukbang_ttaradamgi/models/enums.dart';
import 'package:mukbang_ttaradamgi/services/gemini_extractor.dart';

/// responseSchema 가 Gemini 에 거절당하지 않는 모양인지 지킨다.
///
/// 스키마가 거부되면 `POST generateContent` 가 400 을 주고 먹방요기 분석 화면이
/// 통째로 죽는다. 서버까지 가야만 드러나는 실패라 단위 테스트로 앞을 막는다.
///
/// 실제로 `foodCategory` enum 에 빈 문자열이 들어가 이 화면이 죽어 있었다
/// (`400 INVALID_ARGUMENT — enum[9]: cannot be empty`).
void main() {
  group('Gemini responseSchema', () {
    /// 스키마 어디에 있든 모든 `enum` 배열을 찾아낸다.
    List<List<Object?>> enumsIn(Object? node) {
      final found = <List<Object?>>[];
      void walk(Object? n) {
        if (n is Map) {
          for (final entry in n.entries) {
            if (entry.key == 'enum' && entry.value is List) {
              found.add(entry.value as List<Object?>);
            }
            walk(entry.value);
          }
        } else if (n is List) {
          for (final e in n) {
            walk(e);
          }
        }
      }

      walk(node);
      return found;
    }

    test('enum 에 빈 문자열이 없다', () {
      final all = enumsIn(GeminiExtractor.responseSchema);
      expect(all, isNotEmpty, reason: 'enum 이 하나도 없으면 이 테스트가 무의미하다');

      for (final values in all) {
        for (final v in values) {
          expect(
            '$v'.trim(),
            isNotEmpty,
            reason: 'Gemini 는 빈 enum 값을 거부한다 (enum: $values)',
          );
        }
      }
    });

    test('판단 불가 값은 FoodCategory 로 해석되지 않는다', () {
      final category = (GeminiExtractor.dishSchema['properties']
          as Map)['foodCategory'] as Map;
      final values = (category['enum'] as List).cast<String>();

      expect(values, contains('UNKNOWN'));

      // 나머지는 전부 실제 카테고리여야 한다. 오타가 있으면 그 값이 오는 순간
      // 카테고리가 조용히 null 이 된다.
      for (final v in values.where((v) => v != 'UNKNOWN')) {
        expect(
          FoodCategory.fromWire(v),
          isNotNull,
          reason: '$v 는 FoodCategory 에 없는 값이다',
        );
      }

      // UNKNOWN 은 일부러 카테고리가 아니다 — 파서가 null 로 되돌린다.
      expect(FoodCategory.fromWire('UNKNOWN'), isNull);
    });

    test('required 필드가 properties 에 모두 있다', () {
      void check(Map<String, dynamic> schema, String where) {
        final props = schema['properties'] as Map;
        for (final key in (schema['required'] as List).cast<String>()) {
          expect(props.containsKey(key), isTrue,
              reason: '$where 의 required "$key" 가 properties 에 없다');
        }
      }

      check(GeminiExtractor.responseSchema, 'responseSchema');
      check(GeminiExtractor.dishSchema, 'dishSchema');
    });
  });
}
