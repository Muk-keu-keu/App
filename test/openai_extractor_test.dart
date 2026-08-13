import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mukbang_ttaradamgi/models/enums.dart';
import 'package:mukbang_ttaradamgi/services/extraction.dart';
import 'package:mukbang_ttaradamgi/services/openai_extractor.dart';

/// 본문을 UTF-8 바이트로 넣는다.
///
/// `http.Response(String, ...)` 는 charset 이 없으면 latin1 로 인코딩해서 한글이
/// 들어간 본문에 `ArgumentError` 를 던진다. 실제 응답은 UTF-8 이고 어댑터도
/// `bodyBytes` 를 UTF-8 로 읽으므로 테스트도 같은 모양으로 맞춘다.
http.Response _raw(String body, int status) =>
    http.Response.bytes(utf8.encode(body), status);

/// 성공 응답 한 벌. `choices[0].message.content` 에 JSON 문자열이 들어온다.
http.Response _ok(String content) => _raw(
      '{"choices":[{"finish_reason":"stop",'
      '"message":{"role":"assistant","content":${_quote(content)}}}]}',
      200,
    );

/// JSON 안에 JSON 을 넣어야 해서 문자열 하나를 이스케이프한다.
String _quote(String raw) =>
    '"${raw.replaceAll(r'\', r'\\').replaceAll('"', r'\"').replaceAll('\n', r'\n')}"';

void main() {
  group('OpenAI 스키마 — strict 모드가 요구하는 모양', () {
    // strict:true 는 조건 하나만 어긋나도 400 을 준다. 서버까지 가야 드러나는
    // 실패라 단위 테스트로 앞을 막는다. Gemini 쪽에서 같은 일을 겪었다.
    test('모든 properties 가 required 에 있다', () {
      void check(Map<String, dynamic> schema, String where) {
        final props = (schema['properties'] as Map).keys.cast<String>().toSet();
        final required = (schema['required'] as List).cast<String>().toSet();
        expect(required, props,
            reason: '$where — strict 모드는 선택 필드를 허용하지 않는다');
      }

      check(OpenAiExtractor.responseSchema, 'responseSchema');
      check(OpenAiExtractor.dishSchema, 'dishSchema');
    });

    test('additionalProperties 가 false 다', () {
      expect(OpenAiExtractor.responseSchema['additionalProperties'], isFalse);
      expect(OpenAiExtractor.dishSchema['additionalProperties'], isFalse);
    });

    test('타입이 소문자다', () {
      // Gemini 는 OBJECT, OpenAI 는 object 다. 스키마를 복사해 오다 방언이
      // 섞이면 400 이 난다.
      expect(OpenAiExtractor.responseSchema['type'], 'object');
      expect(OpenAiExtractor.dishSchema['type'], 'object');
      final props = OpenAiExtractor.dishSchema['properties'] as Map;
      for (final entry in props.entries) {
        final type = (entry.value as Map)['type'] as String;
        expect(type, type.toLowerCase(), reason: '${entry.key} 의 타입이 대문자다');
      }
    });

    test('카테고리 enum 은 Gemini 와 같은 값을 쓴다', () {
      final category =
          (OpenAiExtractor.dishSchema['properties'] as Map)['foodCategory'] as Map;
      final values = (category['enum'] as List).cast<String>();

      expect(values, extractionCategoryEnum);
      expect(values, contains('UNKNOWN'));
      for (final v in values.where((v) => v != 'UNKNOWN')) {
        expect(FoodCategory.fromWire(v), isNotNull, reason: '$v 는 FoodCategory 에 없다');
      }
      // UNKNOWN 은 일부러 카테고리가 아니다 — 파서가 null 로 되돌린다.
      expect(FoodCategory.fromWire('UNKNOWN'), isNull);
    });
  });

  group('OpenAI 응답 처리', () {
    test('content 의 JSON 을 계약대로 읽는다', () async {
      final client = MockClient((_) async => _ok(
            '{"dishes":[{"name":"오리지널 떡볶이","brandName":"엽기떡볶이",'
            '"restaurantName":"","foodCategory":"KOREAN",'
            '"description":"매콤한 국물 떡볶이","options":["분모자 넣어서"]}],'
            '"keywords":["떡볶이","야식"]}',
          ));

      final result = await OpenAiExtractor(apiKey: 'k', client: client)
          .extract('엽떡 먹방');

      expect(result.dishes, hasLength(1));
      expect(result.dishes.single.name, '오리지널 떡볶이');
      expect(result.dishes.single.brandName, '엽기떡볶이');
      // 빈 문자열은 null 로 되돌아야 한다. 그대로 보내면 서버가 상호명 '' 로 찾는다.
      expect(result.dishes.single.restaurantName, isNull);
      expect(result.dishes.single.foodCategory, FoodCategory.korean);
      expect(result.dishes.single.options, ['분모자 넣어서']);
      expect(result.keywords, ['떡볶이', '야식']);
    });

    test('요청이 Bearer 인증과 json_schema 로 나간다', () async {
      late http.Request sent;
      final client = MockClient((request) async {
        sent = request;
        return _ok('{"dishes":[],"keywords":[]}');
      });

      await OpenAiExtractor(apiKey: 'sk-test', model: 'gpt-4.1-mini', client: client)
          .extract('떡볶이');

      expect(sent.url.toString(), 'https://api.openai.com/v1/chat/completions');
      expect(sent.headers['authorization'], 'Bearer sk-test');
      expect(sent.body, contains('"model":"gpt-4.1-mini"'));
      expect(sent.body, contains('"type":"json_schema"'));
      expect(sent.body, contains('"strict":true'));
    });

    test('모델이 거절하면 요청 예외로 나간다', () async {
      // 구조화 출력은 content 대신 refusal 을 준다. 그대로 파싱하면 의미 없는
      // FormatException 이 되어 원인을 못 찾는다.
      final client = MockClient((_) async => _raw(
            '{"choices":[{"finish_reason":"stop",'
            '"message":{"refusal":"거절합니다","content":null}}]}',
            200,
          ));

      await expectLater(
        OpenAiExtractor(apiKey: 'k', client: client).extract('떡볶이'),
        throwsA(isA<ExtractorRequestException>()
            .having((e) => e.message, 'message', contains('거절'))),
      );
    });

    test('토큰 한도에서 잘리면 잘렸다고 알린다', () async {
      final client = MockClient((_) async => _raw(
            '{"choices":[{"finish_reason":"length",'
            '"message":{"content":"{\\"dishes\\":[{\\"name\\":\\"떡"}}]}',
            200,
          ));

      await expectLater(
        OpenAiExtractor(apiKey: 'k', client: client).extract('떡볶이'),
        throwsA(isA<ExtractorRequestException>()
            .having((e) => e.message, 'message', contains('잘렸'))),
      );
    });
  });

  group('OpenAI 오류 매핑', () {
    test('401 은 인증 예외다', () async {
      final client = MockClient((_) async => _raw(
            '{"error":{"message":"Incorrect API key provided",'
            '"code":"invalid_api_key"}}',
            401,
          ));

      await expectLater(
        OpenAiExtractor(apiKey: 'bad', client: client).extract('떡볶이'),
        throwsA(isA<ExtractorAuthException>()
            .having((e) => e.statusCode, 'statusCode', 401)),
      );
    });

    test('429 는 전용 예외로 나가고 호출은 한 번뿐이다', () async {
      // Gemini 때와 같은 이유다. 429 를 네트워크 오류로 보고 재시도하면 한도를
      // 실패 한 번에 두 개씩 태운다.
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return _raw(
          '{"error":{"message":"Rate limit reached","type":"requests"}}',
          429,
        );
      });

      await expectLater(
        OpenAiExtractor(apiKey: 'k', client: client).extract('떡볶이'),
        throwsA(isA<ExtractorQuotaException>()
            // 분당 한도는 곧 풀린다 — "내일 다시" 라고 하면 안 된다.
            .having((e) => e.isDaily, 'isDaily', isFalse)),
      );
      expect(calls, 1);
    });

    test('잔액 소진(insufficient_quota)은 오늘 안에 안 풀린다고 본다', () async {
      final client = MockClient((_) async => _raw(
            '{"error":{"message":"You exceeded your current quota",'
            '"type":"insufficient_quota"}}',
            429,
          ));

      await expectLater(
        OpenAiExtractor(apiKey: 'k', client: client).extract('떡볶이'),
        throwsA(isA<ExtractorQuotaException>()
            .having((e) => e.isDaily, 'isDaily', isTrue)
            .having((e) => e.message, 'message', contains('quota'))),
      );
    });

    test('400 은 우리 요청 문제로 본다', () async {
      final client = MockClient((_) async => _raw(
            '{"error":{"message":"Invalid schema for response_format"}}',
            400,
          ));

      await expectLater(
        OpenAiExtractor(apiKey: 'k', client: client).extract('떡볶이'),
        throwsA(isA<ExtractorRequestException>()
            .having((e) => e.message, 'message', contains('Invalid schema'))),
      );
    });
  });
}
