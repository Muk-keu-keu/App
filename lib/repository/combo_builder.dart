import '../models/combo.dart';
import '../models/preference.dart';
import '../services/gemini_extractor.dart';

/// AI가 릴스에서 뽑아낸 정보(ExtractionResult)로 조합 추천을 만든다.
/// iOS 앱 ComboBuilder.swift 와 같은 규칙이다. 한쪽을 바꾸면 다른 쪽도 맞춘다.
///
/// 백엔드가 붙으면 이 파일은 통째로 사라진다. 서버가 실제 요기요 매장·메뉴·가격을
/// 내려주면 되기 때문이다.
///
/// 가격·평점·거리는 **실제 데이터가 아니라 추정치**다. 음식 종류별 기준가에서
/// 매장 이름을 시드로 흔들어 만든다. 같은 영상이면 항상 같은 값이 나오도록
/// 난수 대신 해시를 쓴다.
class ComboBuilder {
  const ComboBuilder._();

  /// 사진이 없을 때 쓰는 중립 이미지.
  /// 두찜 로고나 로제닭발 사진을 쓰면 교촌치킨 카드에 엉뚱한 음식이 붙는다.
  static const _placeholder = 'assets/images/platter.png';

  /// 음식 종류별 대표 메뉴 기준가(원). 요기요 실거래가 대역을 참고한 어림값이다.
  static const _basePrice = <String, int>{
    '치킨': 20000,
    '중식': 12000,
    '한식': 14000,
    '일식': 16000,
    '양식': 18000,
    '분식': 11000,
    '피자': 22000,
    '아시안': 15000,
    '카페·디저트': 8000,
  };

  /// 음식 종류별 사이드 메뉴. 조합에 곁들일 항목으로 하나 붙인다.
  static const _sideMenu = <String, (String, int, String)>{
    '치킨': ('[사이드] 감자튀김', 4000, '바삭하게 튀긴 감자튀김'),
    '중식': ('[사이드] 군만두', 5000, '속이 꽉 찬 군만두'),
    '한식': ('[사이드] 계란찜', 3000, '부드러운 뚝배기 계란찜'),
    '일식': ('[사이드] 미소된장국', 2000, '따뜻한 미소된장국'),
    '양식': ('[사이드] 갈릭브레드', 4000, '마늘향 가득한 갈릭브레드'),
    '분식': ('[사이드] 튀김만두', 3500, '겉바속촉 튀김만두'),
    '피자': ('[사이드] 콜라 1.25L', 3000, '시원한 콜라'),
    '아시안': ('[사이드] 스프링롤', 5000, '바삭한 스프링롤'),
    '카페·디저트': ('[사이드] 아메리카노', 3500, '산미 적은 원두'),
  };

  /// 추출 결과 하나로 조합 후보들을 만든다.
  /// 첫 번째가 영상 속 그 매장이고, 뒤는 같은 지역·같은 종류의 대안이다.
  static List<ComboRecommendation> build({
    required ExtractionResult extraction,
    required String? thumbnailUrl,
    required TastePreference preference,
  }) {
    final category = extraction.foodCategory.isEmpty ? '한식' : extraction.foodCategory;
    final area = extraction.area;

    final results = <ComboRecommendation>[
      _make(
        storeName: _storeName(extraction, category, area),
        category: category,
        dishes: extraction.dishes,
        thumbnailUrl: thumbnailUrl,
        similarity: extraction.confidence.clamp(0.72, 0.98),
        preference: preference,
      ),
    ];

    // 대안 매장 2곳. 이름만 바꾸고 나머지는 같은 규칙으로 흔든다.
    final place = area.isEmpty ? '우리동네' : area;
    final alternatives = ['$place $category 전문점', '$place $category 배달맛집'];

    for (var i = 0; i < alternatives.length; i++) {
      results.add(
        _make(
          storeName: alternatives[i],
          category: category,
          dishes: extraction.dishes,
          thumbnailUrl: thumbnailUrl,
          // 유사도는 첫 번째가 가장 높고 뒤로 갈수록 낮아지게 고정한다.
          similarity:
              (results.first.store.similarity - (i + 1) * 0.09).clamp(0.3, 0.98),
          preference: preference,
        ),
      );
    }

    return results;
  }

  static String _storeName(ExtractionResult e, String category, String area) {
    if (e.restaurantName.isNotEmpty) return e.restaurantName;
    if (area.isNotEmpty) return '$area $category 맛집';
    return '$category 맛집';
  }

  static ComboRecommendation _make({
    required String storeName,
    required String category,
    required List<ExtractedDish> dishes,
    required String? thumbnailUrl,
    required double similarity,
    required TastePreference preference,
  }) {
    final seed = _seed(storeName);

    final store = StoreSummary(
      id: 'ai-$seed',
      name: storeName,
      rating: 3.6 + (seed % 13) / 10.0, // 3.6 ~ 4.8
      reviewCount: 60 + seed % 900,
      distanceKm: 0.6 + (seed % 40) / 10.0, // 0.6 ~ 4.5 km
      deliveryMinutes: 25 + (seed % 8) * 5, // 25 ~ 60분
      imagePath: _placeholder,
      imageUrl: thumbnailUrl,
      minimumOrderAmount: 12000 + (seed % 4) * 2000,
      deliveryFee: 1000 + (seed % 4) * 500,
      similarity: similarity.toDouble(),
    );

    var items = _mainItems(
      dishes: dishes,
      category: category,
      spice: preference.spice,
      thumbnailUrl: thumbnailUrl,
      seed: seed,
    );

    // 1인 모드면 메뉴를 핵심 하나로 줄인다.
    if (preference.mode == ServingMode.solo && items.length > 1) {
      items = items.take(1).toList();
    }

    final side = _sideMenu[category];
    if (side != null) {
      items.add(
        ComboItem(
          id: 'side-$seed',
          name: side.$1,
          options: side.$3,
          unitPrice: _roundedPrice(side.$2),
          quantity: 1,
          imagePath: _placeholder,
        ),
      );
    }

    return ComboRecommendation(store: store, items: items);
  }

  /// 영상에서 뽑은 음식은 전부 메인 취급이다. 사이드는 별도로 붙는다.
  /// AI 가 뽑은 옵션(순살, 매운맛, 치즈 추가…)을 그대로 메뉴 설명으로 쓴다.
  /// 옵션이 없으면 영상 묘사를, 그것도 없으면 맵기만 적는다.
  static List<ComboItem> _mainItems({
    required List<ExtractedDish> dishes,
    required String category,
    required SpiceLevel spice,
    required String? thumbnailUrl,
    required int seed,
  }) {
    final base = _basePrice[category] ?? 14000;
    final sources = dishes.where((d) => d.name.isNotEmpty).take(2).toList();

    if (sources.isEmpty) {
      return [
        ComboItem(
          id: 'main-$seed-0',
          name: category.isEmpty ? '대표 메뉴' : '$category 대표 메뉴',
          options: spice.title,
          unitPrice: _roundedPrice(base + (seed % 6) * 1000),
          quantity: 1,
          imagePath: _placeholder,
          imageUrl: thumbnailUrl,
        ),
      ];
    }

    return [
      for (var i = 0; i < sources.length; i++)
        ComboItem(
          id: 'main-$seed-$i',
          name: sources[i].name,
          options: _optionText(sources[i], spice),
          unitPrice: _roundedPrice(base + ((seed ~/ (i + 1)) % 6) * 1000),
          quantity: 1,
          imagePath: _placeholder,
          // 첫 메뉴만 릴스 썸네일을 쓴다. 그게 영상에서 본 그 음식이다.
          imageUrl: i == 0 ? thumbnailUrl : null,
        ),
    ];
  }

  static String _optionText(ExtractedDish dish, SpiceLevel spice) {
    if (dish.options.isNotEmpty) return dish.options.join(', ');
    if (dish.description.isNotEmpty) return dish.description;
    return spice.title;
  }

  /// 500원 단위로 끊는다. 20000/3 = 6666 같은 값이 화면에 나오면 안 된다.
  static int _roundedPrice(int value) {
    final rounded = (value ~/ 500) * 500;
    return rounded < 1000 ? 1000 : rounded;
  }

  /// 문자열을 안정적인 양수로. Dart 의 hashCode 는 실행마다 달라질 수 있어 직접 계산한다.
  static int _seed(String text) {
    var hash = 7;
    for (final unit in text.codeUnits) {
      hash = (hash * 31 + unit) & 0x7FFFFFFF;
    }
    return hash;
  }
}
