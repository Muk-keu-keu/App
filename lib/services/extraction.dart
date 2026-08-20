import 'dart:convert';

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
/// **이 구조가 백엔드와 주고받을 계약이다.** 어떤 모델로 뽑든 이 모양만 지키면
/// 앱과 서버는 손댈 필요가 없다. [DishExtractor] 구현이 그 약속을 지키는 자리다.
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

/// 텍스트에서 [ExtractionResult] 를 뽑아내는 것. 구현이 곧 모델 선택이다.
///
/// 호출부는 이 타입만 알면 되고, 아래 예외 세 종류만 구분하면 된다. 어느 모델을
/// 쓰는지는 [AppFlow] 가 키를 보고 고른다.
abstract class DishExtractor {
  Future<ExtractionResult> extract(String text);
}

/// API 키가 잘못됐을 때. 재시도 대상이 아니다.
///
/// 상태 코드는 제공자마다 다르다. Gemini 는 키가 틀리면 401 이 아니라
/// `400 INVALID_ARGUMENT — API key not valid` 를 주고, OpenAI 는 401 을 준다.
/// 어느 쪽이든 재시도가 소용없다는 사실은 같아 하나로 묶는다.
class ExtractorAuthException implements Exception {
  const ExtractorAuthException(this.statusCode);

  final int statusCode;

  @override
  String toString() => 'ExtractorAuthException(HTTP $statusCode) — API 키를 확인하세요';
}

/// 우리가 보낸 요청이 잘못됐을 때 (400).
///
/// 키와 무관한 400 이다. 재시도해도 같은 결과라는 점은 [ExtractorAuthException] 과
/// 같지만 고칠 곳이 다르다 — 이쪽은 우리 코드의 버그다.
///
/// 이 예외를 나눈 이유가 있다. 응답 스키마의 enum 에 빈 문자열이 들어가 요청이
/// 통째로 거부되던 때, 400 을 전부 키 문제로 보고하는 바람에 화면이 "AI 분석을 쓸
/// 수 없어요" 만 띄웠다. 키는 멀쩡했는데 키를 의심하느라 원인을 찾는 데 한참
/// 걸렸다. 서버가 준 설명을 [message] 에 그대로 들고 온다.
class ExtractorRequestException implements Exception {
  const ExtractorRequestException(this.statusCode, this.message);

  final int statusCode;

  /// 제공자가 준 `error.message` 원문.
  final String message;

  @override
  String toString() => 'ExtractorRequestException(HTTP $statusCode) — $message';
}

/// 할당량 초과(429).
///
/// 네트워크 오류와 반드시 구분해야 한다. 재시도로 처리하면 남은 한도를 그만큼
/// 더 빨리 태우면서 화면에는 "잠시 후 다시 시도" 만 뜬다 — 원인을 못 찾는다.
///
/// 같은 429 라도 성격이 둘이다. Gemini 무료 등급은 **하루** 20건이라 그날은 무엇을
/// 해도 열리지 않고, OpenAI 는 분당 한도면 곧 풀리지만 잔액이 없으면
/// (`insufficient_quota`) 결제 전까지 닫힌 채다. [isDaily] 로 갈라 문구를 고른다.
class ExtractorQuotaException implements Exception {
  const ExtractorQuotaException(this.statusCode, this.message, {this.isDaily = true});

  final int statusCode;
  final String message;

  /// 오늘 안에는 풀리지 않는 한도인지. 사용자에게 "내일 다시" 라고 할지 "잠시 후"
  /// 라고 할지가 갈린다.
  final bool isDaily;

  @override
  String toString() => 'ExtractorQuotaException(HTTP $statusCode) — $message';
}

/// 모델에 넣는 지시문. 제공자가 바뀌어도 이 문구는 같다.
///
/// 스키마가 모양을 강제하고 이 문구가 내용을 정한다. 둘 중 하나만 바꾸면
/// 결과가 조용히 어긋나므로 함께 본다.
String extractionPrompt(String text) => '''
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
      ASIAN, CAFE_DESSERT 중 하나. 판단 불가면 UNKNOWN.
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

/// dishes[] 각 항목의 필드. 스키마의 `required` 와 순서를 함께 만든다.
const List<String> extractionDishFields = [
  'name', 'brandName', 'restaurantName', 'foodCategory', 'description', 'options',
];

/// `foodCategory` 가 가질 수 있는 값.
///
/// 판단 불가는 빈 문자열이 아니라 UNKNOWN 이다. 스키마의 enum 에 빈 문자열을 넣으면
/// Gemini 가 요청 자체를 거부한다 (`400 INVALID_ARGUMENT — enum[9]: cannot be empty`).
/// 다른 필드처럼 빈 문자열로 통일하려다 이 화면 전체가 죽어 있었다.
///
/// UNKNOWN 은 [FoodCategory] 에 없는 값이라 `fromWire` 가 null 로 돌려준다.
const List<String> extractionCategoryEnum = [
  ...['KOREAN', 'CHINESE', 'JAPANESE', 'WESTERN', 'SNACK'],
  ...['CHICKEN', 'PIZZA', 'ASIAN', 'CAFE_DESSERT', 'UNKNOWN'],
];

/// 응답 본문에서 [ExtractionResult] 를 꺼낸다.
///
/// 스키마로 유효한 JSON 이 보장되지만, 방어적으로 앞뒤 잡음을 제거하고 파싱한다.
ExtractionResult parseExtraction(String answer) {
  final start = answer.indexOf('{');
  final end = answer.lastIndexOf('}');
  if (start < 0 || end <= start) {
    throw const FormatException('JSON 을 찾지 못했습니다');
  }
  final map = jsonDecode(answer.substring(start, end + 1)) as Map<String, dynamic>;
  return ExtractionResult.fromJson(map);
}

/// 오류 본문에서 `error.message` 를 꺼낸다. JSON 이 아니어도 터지지 않는다.
/// Gemini 와 OpenAI 가 같은 `{"error":{"message":...}}` 모양을 쓴다.
String extractorErrorMessage(List<int> bodyBytes) {
  try {
    final decoded = jsonDecode(utf8.decode(bodyBytes));
    if (decoded is Map && decoded['error'] is Map) {
      final message = (decoded['error'] as Map)['message'];
      if (message != null) return '$message'.trim();
    }
  } catch (_) {
    // 본문이 JSON 이 아니면 아래에서 원문을 짧게 준다.
  }
  try {
    return utf8.decode(bodyBytes).trim();
  } catch (_) {
    return '';
  }
}
