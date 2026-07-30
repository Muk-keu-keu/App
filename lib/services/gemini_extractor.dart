import 'dart:convert';

import 'package:http/http.dart' as http;

/// 영상에 나온 음식 하나.
/// 요기요 메뉴에 매칭하려면 이름만으론 부족하고 옵션(순살/뼈, 맵기, 사리 추가)이 필요하다.
class ExtractedDish {
  const ExtractedDish({
    required this.name,
    this.description = '',
    this.options = const [],
  });

  /// 메뉴명. "레드콤보", "로제 닭발"
  final String name;

  /// 영상에서 묘사된 내용. "매콤한 소스에 순살로 나온 반반 치킨"
  final String description;

  /// 주문 시 골라야 하는 값들. ["순살", "매운맛", "치즈 추가"]
  /// 요기요 메뉴 옵션과 그대로 대응시키는 것이 목표다.
  final List<String> options;

  factory ExtractedDish.fromJson(Map<String, dynamic> json) => ExtractedDish(
        name: (json['name'] ?? '') as String,
        description: (json['description'] ?? '') as String,
        options: ((json['options'] ?? const []) as List).map((e) => '$e').toList(),
      );

  Map<String, dynamic> toJson() =>
      {'name': name, 'description': description, 'options': options};
}

/// AI 추출 결과. 알 수 없는 필드는 빈 값.
///
/// **이 구조가 백엔드와 주고받을 계약이다.** 모델을 Gemini 에서 다른 것으로 바꾸더라도
/// 스키마만 유지하면 앱과 서버는 손댈 필요가 없다.
class ExtractionResult {
  const ExtractionResult({
    required this.restaurantName,
    this.brandName = '',
    this.branchName = '',
    required this.foodCategory,
    required this.area,
    this.dishes = const [],
    this.keywords = const [],
    this.spiceLevel = '',
    this.servingCount = 0,
    this.isFranchise = false,
    this.summary = '',
    required this.confidence,
  });

  /// 상호명 전체. "교촌치킨 강남점"
  final String restaurantName;

  /// 브랜드만. "교촌치킨" — 프랜차이즈면 근처 지점 검색에 쓴다.
  final String brandName;

  /// 지점만. "강남점"
  final String branchName;

  /// 한식/중식/일식/양식/분식/치킨/피자/아시안/카페·디저트
  final String foodCategory;

  /// 동네 이름. "성수동", "강남"
  final String area;

  /// 영상에 나온 음식들. 등장 순서대로.
  final List<ExtractedDish> dishes;

  /// 매칭·검색에 쓸 모든 키워드. 음식명, 재료, 조리법, 식감, 상황("야식", "혼술")까지.
  final List<String> keywords;

  /// NONE | MILD | MEDIUM | HOT | EXTREME. 취향 설정 화면 기본값으로 쓴다.
  /// 판단 불가면 빈 문자열. (`NONE` 은 "안 매움"이라 판단 불가와 구분한다)
  ///
  /// 대문자인 이유는 `docs/api-yogijokbo.md` 의 공통 규칙 "enum 은 대문자 스네이크"다.
  /// 서버와 값을 그대로 주고받으려면 앱이 먼저 그 표기를 지켜야 한다.
  final String spiceLevel;

  /// 영상에서 몇 인분으로 보이는지. 0이면 판단 불가.
  final int servingCount;

  /// 프랜차이즈 여부. true 면 브랜드명으로 근처 지점을 찾으면 된다.
  final bool isFranchise;

  /// 한 줄 요약. "이 영상 이렇게 이해했어요"를 사용자에게 보여줄 때 쓴다.
  final String summary;

  /// 상호명 추출 확신도 0.0~1.0
  final double confidence;

  /// 메뉴 이름만 쉼표로 이어붙인 값.
  String get menu => dishes.map((d) => d.name).join(', ');

  /// spiceLevel 을 대문자로 맞춘다.
  ///
  /// 프롬프트로 대문자를 요구하지만 LLM 이 늘 지킨다는 보장은 없다. 값이 그대로
  /// 서버로 넘어가는 자리라 여기서 한 번 정규화해 계약을 지킨다.
  /// 알 수 없는 값은 억지로 매핑하지 않고 빈 문자열(판단 불가)로 떨어뜨린다.
  static const List<String> spiceLevels = ['NONE', 'MILD', 'MEDIUM', 'HOT', 'EXTREME'];

  static String normalizeSpiceLevel(Object? raw) {
    final value = '${raw ?? ''}'.trim().toUpperCase();
    return spiceLevels.contains(value) ? value : '';
  }

  factory ExtractionResult.fromJson(Map<String, dynamic> json) => ExtractionResult(
        restaurantName: (json['restaurantName'] ?? '') as String,
        brandName: (json['brandName'] ?? '') as String,
        branchName: (json['branchName'] ?? '') as String,
        foodCategory: (json['foodCategory'] ?? '') as String,
        area: (json['area'] ?? '') as String,
        dishes: ((json['dishes'] ?? const []) as List)
            .map((e) => ExtractedDish.fromJson(e as Map<String, dynamic>))
            .toList(),
        keywords: ((json['keywords'] ?? const []) as List).map((e) => '$e').toList(),
        spiceLevel: normalizeSpiceLevel(json['spiceLevel']),
        servingCount: ((json['servingCount'] ?? 0) as num).toInt(),
        isFranchise: (json['isFranchise'] ?? false) as bool,
        summary: (json['summary'] ?? '') as String,
        confidence: ((json['confidence'] ?? 0) as num).toDouble(),
      );
}

/// API 키가 잘못됐을 때. 재시도 대상이 아니다.
///
/// Gemini 는 키가 틀리면 `400 INVALID_ARGUMENT — API key not valid` 를 돌려준다.
/// 401 이 아니라 400 이라 일반 오류와 섞이기 쉬워 따로 표시해 둔다.
class GeminiAuthException implements Exception {
  const GeminiAuthException(this.statusCode);

  final int statusCode;

  @override
  String toString() => 'GeminiAuthException(HTTP $statusCode) — API 키를 확인하세요';
}

/// Google Gemini generateContent 를 raw HTTP 로 호출한다.
/// responseMimeType + responseSchema 로 응답이 항상 스키마에 맞는 JSON 이 되도록 강제한다.
/// iOS 앱 GeminiExtractor.swift 와 같은 프롬프트·스키마를 쓴다. 한쪽을 바꾸면 다른 쪽도 맞춘다.
class GeminiExtractor {
  const GeminiExtractor({required this.apiKey, this.model = 'gemini-2.5-flash'});

  final String apiKey;
  final String model;

  static const Map<String, dynamic> _dishSchema = {
    'type': 'OBJECT',
    'properties': {
      'name': {'type': 'STRING'},
      'description': {'type': 'STRING'},
      'options': {
        'type': 'ARRAY',
        'items': {'type': 'STRING'},
      },
    },
    'required': ['name', 'description', 'options'],
    'propertyOrdering': ['name', 'description', 'options'],
  };

  static const List<String> _fields = [
    'restaurantName', 'brandName', 'branchName', 'foodCategory', 'area',
    'dishes', 'keywords', 'spiceLevel', 'servingCount', 'isFranchise',
    'summary', 'confidence',
  ];

  static const Map<String, dynamic> _responseSchema = {
    'type': 'OBJECT',
    'properties': {
      'restaurantName': {'type': 'STRING'},
      'brandName': {'type': 'STRING'},
      'branchName': {'type': 'STRING'},
      'foodCategory': {'type': 'STRING'},
      'area': {'type': 'STRING'},
      'dishes': {'type': 'ARRAY', 'items': _dishSchema},
      'keywords': {
        'type': 'ARRAY',
        'items': {'type': 'STRING'},
      },
      // NONE|MILD|MEDIUM|HOT|EXTREME 를 기대하지만 responseSchema 의 enum 으로는
      // 묶지 않는다. 판단 불가를 빈 문자열로 두기로 했고, 빈 문자열은 enum 값에
      // 넣을 수 없어 모델이 값을 못 정할 때 응답이 실패한다.
      // 대문자 요구는 프롬프트로 하고, 어긴 응답은 normalizeSpiceLevel 이 바로잡는다.
      'spiceLevel': {'type': 'STRING'},
      'servingCount': {'type': 'INTEGER'},
      'isFranchise': {'type': 'BOOLEAN'},
      'summary': {'type': 'STRING'},
      'confidence': {'type': 'NUMBER'},
    },
    'required': _fields,
    'propertyOrdering': _fields,
  };

  String _prompt(String text) => '''
아래는 SNS 게시물(릴스/영상/카드뉴스)의 제목·설명·계정명 텍스트입니다.
이 사람이 먹은 음식을 요기요에서 그대로 주문할 수 있도록 정보를 빠짐없이 뽑아주세요.
근거가 있으면 추론해도 되지만, 전혀 없으면 빈 값으로 두세요.

- restaurantName: 상호명. 지점이 있으면 지점까지 (예: "청년다방 송도점").
  계정명이 음식점이면 그걸 상호명으로. 정말 모를 때만 빈 문자열.
- brandName: 브랜드/체인명만 (예: "청년다방"). 개인 가게면 상호명과 같게.
- branchName: 지점명만 (예: "송도점"). 없으면 빈 문자열.
- foodCategory: 다음 중 하나로만. 한식, 중식, 일식, 양식, 분식, 치킨, 피자, 아시안, 카페·디저트
- area: 동네/지역 이름 (예: "성수동", "송도", "강남"). 모르면 빈 문자열.
- dishes: 영상에 나온 음식들을 등장 순서대로. 각 항목은
    · name: 메뉴 이름 (예: "레드콤보", "로제 닭발")
    · description: 영상에서 묘사된 내용을 한 문장으로
    · options: 주문할 때 골라야 하는 값들의 배열.
      뼈/순살, 맵기 단계, 사리·토핑 추가, 양 선택처럼
      요기요 메뉴 옵션에 해당하는 것을 모두 넣으세요.
      예: ["순살", "매운맛", "중국당면 추가", "치즈 추가"]
- keywords: 매칭·검색에 쓸 단어를 최대한 많이. 음식명, 재료, 조리법, 식감,
  먹는 상황("야식", "혼술", "해장")까지. 중복 없이 3~15개.
- spiceLevel: NONE, MILD, MEDIUM, HOT, EXTREME 중 하나. 대문자로 그대로 쓰세요.
  판단 불가면 빈 문자열. (안 매운 음식은 NONE, 매운지 모르겠으면 빈 문자열)
- servingCount: 몇 인분으로 보이는지 정수. 판단 불가면 0.
- isFranchise: 프랜차이즈면 true.
- summary: "이 영상을 이렇게 이해했다"를 한 문장으로. 사용자에게 그대로 보여줄 문장.
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
      // 키 문제는 재시도해도 절대 안 된다. 호출한 쪽이 구분해서 바로 포기하도록
      // 별도 예외로 던진다. 그냥 재시도하면 실패까지 걸리는 시간만 두 배가 된다.
      if (_isAuthFailure(response.statusCode)) {
        throw GeminiAuthException(response.statusCode);
      }
      throw Exception('Gemini HTTP ${response.statusCode}');
    }

    final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final answer =
        (((json['candidates'] as List).first as Map)['content'] as Map)['parts'] as List;
    final raw = (answer.first as Map)['text'] as String;

    return parseResponse(raw);
  }

  /// Gemini 는 키가 틀리면 400, 권한 문제면 401·403 을 준다.
  static bool _isAuthFailure(int statusCode) =>
      statusCode == 400 || statusCode == 401 || statusCode == 403;

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
