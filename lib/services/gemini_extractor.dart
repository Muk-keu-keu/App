import 'dart:convert';

import 'package:http/http.dart' as http;

/// AI 추출 결과. 알 수 없는 필드는 빈 문자열.
class ExtractionResult {
  const ExtractionResult({
    required this.restaurantName,
    required this.foodCategory,
    required this.area,
    required this.menu,
    required this.confidence,
  });

  final String restaurantName;
  final String foodCategory;
  final String area;
  final String menu;
  final double confidence;

  factory ExtractionResult.fromJson(Map<String, dynamic> json) => ExtractionResult(
        restaurantName: (json['restaurantName'] ?? '') as String,
        foodCategory: (json['foodCategory'] ?? '') as String,
        area: (json['area'] ?? '') as String,
        menu: (json['menu'] ?? '') as String,
        confidence: ((json['confidence'] ?? 0) as num).toDouble(),
      );
}

/// Google Gemini generateContent 를 raw HTTP 로 호출한다.
/// responseMimeType + responseSchema 로 응답이 항상 스키마에 맞는 JSON 이 되도록 강제한다.
/// iOS 앱 GeminiExtractor.swift 와 같은 프롬프트·스키마를 쓴다. 한쪽을 바꾸면 다른 쪽도 맞춘다.
class GeminiExtractor {
  const GeminiExtractor({required this.apiKey, this.model = 'gemini-2.5-flash'});

  final String apiKey;
  final String model;

  static const Map<String, dynamic> _responseSchema = {
    'type': 'OBJECT',
    'properties': {
      'restaurantName': {'type': 'STRING'},
      'foodCategory': {'type': 'STRING'},
      'area': {'type': 'STRING'},
      'menu': {'type': 'STRING'},
      'confidence': {'type': 'NUMBER'},
    },
    'required': ['restaurantName', 'foodCategory', 'area', 'menu', 'confidence'],
    'propertyOrdering': ['restaurantName', 'foodCategory', 'area', 'menu', 'confidence'],
  };

  String _prompt(String text) => '''
다음은 SNS 게시물(릴스/영상/카드뉴스)의 제목·설명·계정명 텍스트입니다. 여기서 음식점 정보를 최대한 구체적으로 추출하세요.
- restaurantName: 음식점 상호명. 지점명이 있으면 지점까지 포함 (예: "청년다방 송도점"). 계정명이 음식점이면 그걸 상호명으로. 정말 모를 때만 빈 문자열.
- foodCategory: 음식 종류. 다음 중 하나로만: 한식, 중식, 일식, 양식, 분식, 치킨, 피자, 아시안, 카페·디저트. 알 수 없으면 빈 문자열.
- area: 동네/지역 이름 (예: "성수동", "송도", "강남"). 알 수 없으면 빈 문자열.
- menu: 영상에 나오거나 그 음식점의 대표 메뉴 1~3개를 쉼표로 (예: "흑당버블티, 크로플"). 알 수 없으면 빈 문자열.
- confidence: 상호명 추출 확신도 0.0~1.0.

텍스트:
$text
''';

  Future<ExtractionResult> extract(String text) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
    );

    final response = await http
        .post(
          uri,
          headers: {'content-type': 'application/json', 'x-goog-api-key': apiKey},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': _prompt(text)},
                ],
              },
            ],
            'generationConfig': {
              'responseMimeType': 'application/json',
              'responseSchema': _responseSchema,
              'temperature': 0,
            },
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('Gemini HTTP ${response.statusCode}');
    }

    final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final answer = (((json['candidates'] as List).first as Map)['content']
            as Map)['parts'] as List;
    final raw = (answer.first as Map)['text'] as String;

    return parseResponse(raw);
  }

  /// responseSchema 로 유효한 JSON 이 보장되지만, 방어적으로 앞뒤 잡음을 제거하고 파싱한다.
  static ExtractionResult parseResponse(String answer) {
    final start = answer.indexOf('{');
    final end = answer.lastIndexOf('}');
    if (start < 0 || end <= start) {
      throw const FormatException('JSON 을 찾지 못했습니다');
    }
    final map = jsonDecode(answer.substring(start, end + 1)) as Map<String, dynamic>;
    return ExtractionResult.fromJson(map);
  }
}
