import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'extraction.dart';

/// OpenAI Chat Completions 를 raw HTTP 로 호출한다.
///
/// Gemini 무료 등급의 하루 20건 한도 때문에 들였다. 계약([ExtractionResult])과
/// 지시문([extractionPrompt])은 [GeminiExtractor] 와 공유하고, 다른 것은 셋뿐이다.
///
///   · 인증이 `Authorization: Bearer` 다 (Gemini 는 `x-goog-api-key`)
///   · 스키마 방언이 표준 JSON Schema 다 — 타입이 **소문자**고, strict 모드는
///     `additionalProperties: false` 와 "모든 필드가 required" 를 요구한다
///   · 응답이 `choices[0].message.content` 에 문자열로 온다
class OpenAiExtractor implements DishExtractor {
  const OpenAiExtractor({
    required this.apiKey,
    this.model = defaultModel,
    this.client,
  });

  /// `.env` 가 `OPENAI_MODEL` 을 비워 두면 이걸 쓴다.
  static const String defaultModel = 'gpt-4.1-mini';

  final String apiKey;

  /// 구조화 출력(`response_format: json_schema`)을 지원하는 모델이어야 한다.
  /// `.env` 의 `OPENAI_MODEL` 로 바꿀 수 있다.
  final String model;

  /// 테스트가 응답을 대신 주기 위한 자리. null 이면 실제 네트워크로 나간다.
  final http.Client? client;

  /// strict 모드는 `required` 에 모든 속성이 있어야 하고 선택 필드를 허용하지
  /// 않는다. 마침 우리 계약도 전 필드 필수라 그대로 맞는다 — 값을 못 정한 경우는
  /// 빈 문자열(과 카테고리는 `UNKNOWN`)로 오고 파서가 null 로 되돌린다.
  @visibleForTesting
  static const Map<String, dynamic> dishSchema = {
    'type': 'object',
    'properties': {
      'name': {'type': 'string'},
      'brandName': {'type': 'string'},
      'restaurantName': {'type': 'string'},
      'foodCategory': {'type': 'string', 'enum': extractionCategoryEnum},
      'description': {'type': 'string'},
      'options': {
        'type': 'array',
        'items': {'type': 'string'},
      },
    },
    'required': extractionDishFields,
    'additionalProperties': false,
  };

  @visibleForTesting
  static const Map<String, dynamic> responseSchema = {
    'type': 'object',
    'properties': {
      'dishes': {'type': 'array', 'items': dishSchema},
      'keywords': {
        'type': 'array',
        'items': {'type': 'string'},
      },
    },
    'required': ['dishes', 'keywords'],
    'additionalProperties': false,
  };

  @override
  Future<ExtractionResult> extract(String text) async {
    final uri = Uri.parse('https://api.openai.com/v1/chat/completions');

    final response = await (client ?? http.Client())
        .post(
          uri,
          headers: {
            'content-type': 'application/json',
            'authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            'model': model,
            'messages': [
              {'role': 'user', 'content': extractionPrompt(text)},
            ],
            'temperature': 0,
            'response_format': {
              'type': 'json_schema',
              'json_schema': {
                'name': 'extraction',
                'strict': true,
                'schema': responseSchema,
              },
            },
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      final detail = extractorErrorMessage(response.bodyBytes);

      // 키가 거부됐다. OpenAI 는 Gemini 와 달리 제대로 401 을 준다.
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw ExtractorAuthException(response.statusCode);
      }
      if (response.statusCode == 400) {
        throw ExtractorRequestException(response.statusCode, detail);
      }
      // 429 두 가지를 갈라야 한다. 분당 한도는 곧 풀리지만 잔액이 없으면
      // (`insufficient_quota`) 결제 전까지 닫힌 채다. "잠시 후 다시" 라고
      // 안내하면 계속 누르게 만든다.
      if (response.statusCode == 429) {
        throw ExtractorQuotaException(
          response.statusCode,
          detail,
          isDaily: _isOutOfCredit(response.bodyBytes, detail),
        );
      }
      throw Exception('OpenAI HTTP ${response.statusCode} — $detail');
    }

    final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final choice = (json['choices'] as List).first as Map<String, dynamic>;
    final message = choice['message'] as Map<String, dynamic>;

    // 구조화 출력은 모델이 거절할 수 있다. 그때 content 는 null 이고 사유가
    // refusal 로 온다 — 그대로 파싱하면 의미 없는 FormatException 이 된다.
    final refusal = message['refusal'];
    if (refusal != null && '$refusal'.trim().isNotEmpty) {
      throw ExtractorRequestException(200, '모델이 응답을 거절했습니다: $refusal');
    }

    // 토큰이 모자라 잘리면 JSON 이 반쪽이라 파싱만 실패한다. 원인을 남긴다.
    if (choice['finish_reason'] == 'length') {
      throw ExtractorRequestException(200, '응답이 토큰 한도에서 잘렸습니다');
    }

    return parseExtraction('${message['content'] ?? ''}');
  }

  /// 잔액 소진인지 분당 한도인지. 전자는 오늘 안에 풀리지 않는다.
  static bool _isOutOfCredit(List<int> bodyBytes, String detail) {
    try {
      final decoded = jsonDecode(utf8.decode(bodyBytes));
      if (decoded is Map && decoded['error'] is Map) {
        final error = decoded['error'] as Map;
        if ('${error['type']}' == 'insufficient_quota') return true;
        if ('${error['code']}' == 'insufficient_quota') return true;
      }
    } catch (_) {
      // 본문을 못 읽으면 아래 문구로 본다.
    }
    return detail.toLowerCase().contains('insufficient_quota');
  }
}
