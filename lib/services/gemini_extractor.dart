import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/enums.dart';

/// 영상에 나온 음식 하나. `POST v1/analyses` 의 `extracted.dishes[]` 와 1:1이다.
///
/// **브랜드는 영상 전체가 아니라 메뉴마다 붙는다.** 엽떡 떡볶이 + 명랑핫도그처럼
/// 두 가게가 나오는 영상이 있기 때문이다 (명세 비고). 전부 같은 브랜드면 같은 값이
/// 반복될 뿐이고, 그게 다중 매장 묶음 주문의 출발점이 된다.
class ExtractedDish {
  const ExtractedDish({
    required this.name,
    this.brandName,
    this.restaurantName,
    this.foodCategory,
    this.description = '',
    this.options = const [],
  });

  /// 메뉴명. `오리지널 떡볶이` — 필수다.
  final String name;

  /// 브랜드명만. **지점명을 붙이면 안 된다** — 서버가 `restaurant.brand_name`
  /// (지점 제외 정제 브랜드명)과 맞춰 보기 때문에 `교촌치킨 성수점` 은 매칭이 깨진다.
  /// 영상에 가게가 안 나오면 null.
  final String? brandName;

  /// 화면 표시용 상호명. `엽기떡볶이 강남점` 처럼 지점이 붙어도 된다.
  final String? restaurantName;

  /// 9개 카테고리 중 하나. 판단 불가면 null.
  final FoodCategory? foodCategory;

  /// 맛·식감만 한 줄 30~50자. 홍보 문구 금지 (명세).
  final String description;

  /// 영상에서 들린 말 그대로. 정규화하지 않는다. `["분모자 넣어서"]`
  final List<String> options;

  factory ExtractedDish.fromJson(Map<String, dynamic> json) => ExtractedDish(
        name: (json['name'] ?? '') as String,
        brandName: _nullIfBlank(json['brandName']),
        restaurantName: _nullIfBlank(json['restaurantName']),
        // AI 가 한글 카테고리를 뱉을 수 있어 wire 와 한글 양쪽으로 찾는다.
        foodCategory: FoodCategory.fromWire(json['foodCategory'] as String?) ??
            FoodCategory.fromLabel(json['foodCategory'] as String?),
        description: (json['description'] ?? '') as String,
        options: [for (final e in (json['options'] ?? const []) as List) '$e'],
      );

  /// nullable 필드는 빈 문자열이 아니라 null 로 보낸다. 명세가 "영상에 가게가 안
  /// 나오면 생략" 이라고 했고, 빈 문자열을 보내면 서버가 브랜드 `''` 로 검색한다.
  static String? _nullIfBlank(Object? raw) {
    final value = '${raw ?? ''}'.trim();
    return value.isEmpty ? null : value;
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'brandName': brandName,
        'restaurantName': restaurantName,
        'foodCategory': foodCategory?.wire,
        'description': description,
        'options': options,
      };
}

/// AI 추출 결과. `POST v1/analyses` 의 `extracted` 블록 그대로다.
///
/// **이 구조가 백엔드와 주고받을 계약이다.** 모델을 Gemini 에서 다른 것으로 바꾸더라도
/// 스키마만 유지하면 앱과 서버는 손댈 필요가 없다.
class ExtractionResult {
  const ExtractionResult({this.dishes = const [], this.keywords = const []});

  const ExtractionResult.empty() : dishes = const [], keywords = const [];

  /// 영상에 나온 음식들. 등장 순서대로.
  final List<ExtractedDish> dishes;

  /// 검색 보조. 명세상 당분간 미사용이지만 계약에 있어 채워 보낸다.
  final List<String> keywords;

  bool get isEmpty => dishes.isEmpty;

  /// 메뉴 이름만 쉼표로 이어붙인 값. 분석 중 화면에 보여준다.
  String get menu => dishes.map((d) => d.name).join(', ');

  /// 영상에 나온 브랜드들. 중복을 없애고 순서를 지킨다.
  /// 이 개수가 곧 `exactMatches` 로 돌아올 브랜드 수다.
  List<String> get brandNames {
    final seen = <String>[];
    for (final d in dishes) {
      final brand = d.brandName;
      if (brand != null && !seen.contains(brand)) seen.add(brand);
    }
    return seen;
  }

  /// 화면 표시용 상호명 하나. 첫 메뉴의 것을 쓰고, 없으면 브랜드명으로 대신한다.
  String get primaryRestaurantName {
    for (final d in dishes) {
      final name = d.restaurantName ?? d.brandName;
      if (name != null && name.isNotEmpty) return name;
    }
    return '';
  }

  /// 대표 카테고리. 가장 많이 나온 것을 고른다. 없으면 null.
  FoodCategory? get primaryCategory {
    final counts = <FoodCategory, int>{};
    for (final d in dishes) {
      final c = d.foodCategory;
      if (c != null) counts[c] = (counts[c] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;
    var best = counts.keys.first;
    for (final entry in counts.entries) {
      if (entry.value > counts[best]!) best = entry.key;
    }
    return best;
  }

  factory ExtractionResult.fromJson(Map<String, dynamic> json) => ExtractionResult(
        dishes: [
          for (final e in (json['dishes'] ?? const []) as List)
            if (e is Map<String, dynamic>) ExtractedDish.fromJson(e),
        ],
        keywords: [for (final e in (json['keywords'] ?? const []) as List) '$e'],
      );

  Map<String, dynamic> toJson() => {
        'dishes': [for (final d in dishes) d.toJson()],
        'keywords': keywords,
      };
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
class GeminiExtractor {
  const GeminiExtractor({required this.apiKey, this.model = 'gemini-2.5-flash'});

  final String apiKey;
  final String model;

  static const List<String> _dishFields = [
    'name', 'brandName', 'restaurantName', 'foodCategory', 'description', 'options',
  ];

  static const Map<String, dynamic> _dishSchema = {
    'type': 'OBJECT',
    'properties': {
      'name': {'type': 'STRING'},
      // nullable 이지만 responseSchema 의 nullable 대신 빈 문자열을 허용한다.
      // 모델이 값을 못 정할 때 응답 자체가 실패하는 것보다 낫고,
      // 빈 문자열은 ExtractedDish._nullIfBlank 가 null 로 되돌린다.
      'brandName': {'type': 'STRING'},
      'restaurantName': {'type': 'STRING'},
      'foodCategory': {
        'type': 'STRING',
        'enum': [
          ...['KOREAN', 'CHINESE', 'JAPANESE', 'WESTERN', 'SNACK'],
          ...['CHICKEN', 'PIZZA', 'ASIAN', 'CAFE_DESSERT', ''],
        ],
      },
      'description': {'type': 'STRING'},
      'options': {
        'type': 'ARRAY',
        'items': {'type': 'STRING'},
      },
    },
    'required': _dishFields,
    'propertyOrdering': _dishFields,
  };

  static const Map<String, dynamic> _responseSchema = {
    'type': 'OBJECT',
    'properties': {
      'dishes': {'type': 'ARRAY', 'items': _dishSchema},
      'keywords': {
        'type': 'ARRAY',
        'items': {'type': 'STRING'},
      },
    },
    'required': ['dishes', 'keywords'],
    'propertyOrdering': ['dishes', 'keywords'],
  };

  String _prompt(String text) => '''
아래는 SNS 게시물(릴스/영상/카드뉴스)의 제목·설명·계정명 텍스트입니다.
이 사람이 먹은 음식을 요기요에서 그대로 주문할 수 있도록 정보를 뽑아주세요.
근거가 있으면 추론해도 되지만, 전혀 없으면 빈 문자열로 두세요.

dishes: 영상에 나온 음식들을 등장 순서대로. 각 항목은
  · name: 메뉴 이름 (예: "오리지널 떡볶이", "레드콤보"). 필수입니다.
  · brandName: 그 메뉴를 파는 브랜드/체인명만. **지점명은 절대 붙이지 마세요.**
      맞는 예: "교촌치킨", "엽기떡볶이"
      틀린 예: "교촌치킨 성수점", "엽기떡볶이 강남점"
      영상에 가게가 안 나오면 빈 문자열.
  · restaurantName: 지점까지 붙은 상호명 (예: "엽기떡볶이 강남점"). 모르면 빈 문자열.
  · foodCategory: KOREAN, CHINESE, JAPANESE, WESTERN, SNACK, CHICKEN, PIZZA,
      ASIAN, CAFE_DESSERT 중 하나. 판단 불가면 빈 문자열.
  · description: 그 음식의 맛과 식감만 한 줄로, 30~50자.
      "쫄깃한 밀떡에 매운 양념을 넉넉히 버무린 떡볶이" 처럼 쓰세요.
      "인생 맛집", "꼭 드세요" 같은 홍보·감상 문구는 넣지 마세요.
  · options: 영상에서 말한 추가·변경 사항을 **들린 말 그대로** 배열로.
      예: ["분모자 넣어서"], ["순살로", "치즈 추가"]
      영상에 언급이 없으면 빈 배열.

★ 브랜드는 영상 전체가 아니라 메뉴마다 붙습니다.
  한 영상에 가게가 두 곳 나오면(예: 엽떡 떡볶이 + 명랑핫도그) 메뉴별로 다른
  brandName 을 쓰세요. 전부 같은 가게면 같은 값을 반복하면 됩니다.

keywords: 매칭·검색에 쓸 단어를 중복 없이 3~15개. 음식명, 재료, 조리법, 식감,
  먹는 상황("야식", "혼술", "해장")까지.

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
