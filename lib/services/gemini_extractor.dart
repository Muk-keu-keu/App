import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'extraction.dart';

// 계약(ExtractedDish·ExtractionResult·예외)은 provider 중립인 extraction.dart 에
// 있다. 이 파일을 import 하던 곳이 그대로 돌도록 함께 내보낸다.
export 'extraction.dart';

/// 이전 이름. 예외는 이제 제공자와 무관해 [ExtractorAuthException] 로 합쳤다.
typedef GeminiAuthException = ExtractorAuthException;

/// 이전 이름. [ExtractorRequestException] 을 보라.
typedef GeminiRequestException = ExtractorRequestException;

/// 이전 이름. [ExtractorQuotaException] 을 보라.
typedef GeminiQuotaException = ExtractorQuotaException;

/// Google Gemini generateContent 를 raw HTTP 로 호출한다.
/// responseMimeType + responseSchema 로 응답이 항상 스키마에 맞는 JSON 이 되도록 강제한다.
///
/// 무료 등급은 모델·프로젝트당 **하루 20건**이다
/// (`GenerateRequestsPerDayPerProjectPerModel-FreeTier`). 시연 준비로 몇 번만
/// 돌려도 닫히고, 그러면 하루가 지나기 전에는 무엇을 해도 열리지 않는다. 이 한도
/// 때문에 [OpenAiExtractor] 를 함께 두고 키로 고른다.
class GeminiExtractor implements DishExtractor {
  const GeminiExtractor({
    required this.apiKey,
    this.model = 'gemini-3.6-flash',
    this.client,
  });

  final String apiKey;
  final String model;

  /// 테스트가 응답을 대신 주기 위한 자리. null 이면 실제 네트워크로 나간다.
  /// 429·5xx 처리는 실제로 그 응답을 받아 봐야 확인할 수 있어 열어 둔다.
  final http.Client? client;

  /// Gemini 는 OpenAPI 서브셋을 쓴다 — 타입이 `OBJECT` 처럼 **대문자**고
  /// `propertyOrdering` 이 따로 있다. OpenAI 의 JSON Schema 와 방언이 달라
  /// 스키마를 공유하지 않고 제공자별로 둔다.
  @visibleForTesting
  static const Map<String, dynamic> dishSchema = {
    'type': 'OBJECT',
    'properties': {
      'name': {'type': 'STRING'},
      // nullable 이지만 responseSchema 의 nullable 대신 빈 문자열을 허용한다.
      // 모델이 값을 못 정할 때 응답 자체가 실패하는 것보다 낫고,
      // 빈 문자열은 ExtractedDish._nullIfBlank 가 null 로 되돌린다.
      'brandName': {'type': 'STRING'},
      'restaurantName': {'type': 'STRING'},
      'foodCategory': {'type': 'STRING', 'enum': extractionCategoryEnum},
      'description': {'type': 'STRING'},
      'options': {
        'type': 'ARRAY',
        'items': {'type': 'STRING'},
      },
    },
    'required': extractionDishFields,
    'propertyOrdering': extractionDishFields,
  };

  /// 서버가 이 스키마를 거부하면 화면 전체가 죽는다. 테스트가 모양을 지킨다.
  @visibleForTesting
  static const Map<String, dynamic> responseSchema = {
    'type': 'OBJECT',
    'properties': {
      'dishes': {'type': 'ARRAY', 'items': dishSchema},
      'keywords': {
        'type': 'ARRAY',
        'items': {'type': 'STRING'},
      },
    },
    'required': ['dishes', 'keywords'],
    'propertyOrdering': ['dishes', 'keywords'],
  };

  @override
  Future<ExtractionResult> extract(String text) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
    );

    final response = await (client ?? http.Client())
        .post(
          uri,
          headers: {'content-type': 'application/json', 'x-goog-api-key': apiKey},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': extractionPrompt(text)},
                ],
              },
            ],
            'generationConfig': {
              'responseMimeType': 'application/json',
              'responseSchema': responseSchema,
              'temperature': 0,
            },
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      final detail = extractorErrorMessage(response.bodyBytes);

      // 키 문제는 재시도해도 절대 안 된다. 호출한 쪽이 구분해서 바로 포기하도록
      // 별도 예외로 던진다. 그냥 재시도하면 실패까지 걸리는 시간만 두 배가 된다.
      if (_isAuthFailure(response.statusCode, detail)) {
        throw ExtractorAuthException(response.statusCode);
      }
      // 400 인데 키 문제가 아니면 우리가 보낸 요청이 잘못된 것이다. 이것도
      // 재시도가 소용없지만 고칠 곳이 다르므로 다른 예외로 던진다.
      if (response.statusCode == 400) {
        throw ExtractorRequestException(response.statusCode, detail);
      }
      // 429 는 할당량이다. **재시도하면 안 된다** — 무료 등급은 모델당 하루
      // 20건이라 실패 한 번에 두 건을 태우고, 그만큼 한도가 더 빨리 닫힌다.
      if (response.statusCode == 429) {
        throw ExtractorQuotaException(response.statusCode, detail);
      }
      throw Exception('Gemini HTTP ${response.statusCode} — $detail');
    }

    final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final answer =
        (((json['candidates'] as List).first as Map)['content'] as Map)['parts'] as List;
    final raw = (answer.first as Map)['text'] as String;

    return parseResponse(raw);
  }

  /// 권한 문제면 401·403 이다. 400 은 본문을 봐야 안다.
  ///
  /// Gemini 는 키가 틀려도 400 을 준다(`API key not valid`). 그런데 우리가 보낸
  /// 요청이 잘못됐을 때도 400 이라, 상태 코드만 보고 키 탓을 하면 멀쩡한 키를
  /// 의심하게 된다. 실제로 그런 일이 있었다 — 아래 문구가 있을 때만 키 문제로 본다.
  static bool _isAuthFailure(int statusCode, String detail) {
    if (statusCode == 401 || statusCode == 403) return true;
    if (statusCode != 400) return false;
    final lower = detail.toLowerCase();
    return lower.contains('api key') || lower.contains('api_key');
  }

  /// 이전 이름. 지금은 [parseExtraction] 이 한다.
  static ExtractionResult parseResponse(String answer) => parseExtraction(answer);
}
