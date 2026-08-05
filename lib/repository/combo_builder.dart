import '../models/combo.dart';
import '../models/preference.dart';
import '../services/gemini_extractor.dart';

/// AI가 릴스에서 뽑아낸 정보([ExtractionResult])로 `POST v1/analyses` 응답을 흉내낸다.
///
/// **백엔드가 붙으면 이 파일은 통째로 사라진다.** `.env` 의 `API_BASE_URL` 이 비어
/// 있을 때만 쓰인다 — 서버가 없어도 시연이 돌아가게 하려는 것이다.
///
/// 명세를 그대로 흉내내는 게 목적이라 두 블록을 나눠 만든다.
/// - `exactMatches` — **브랜드마다 하나**. 영상에 가게가 두 곳 나오면 두 개가 나온다.
///   다중 매장 묶음 주문을 서버 없이도 시연할 수 있는 건 이것 때문이다.
/// - `combos` — 비슷한 다른 가게. `comboScore` 내림차순.
///
/// 가격·평점·거리는 **실제 데이터가 아니라 추정치**다. 음식 종류별 기준가에서
/// 매장 이름을 시드로 흔들어 만든다. 같은 영상이면 항상 같은 값이 나오도록
/// 난수 대신 해시를 쓴다.
class ComboBuilder {
  const ComboBuilder._();

  /// 사진이 없을 때 쓰는 중립 이미지.
  /// 두찜 로고나 로제닭발 사진을 쓰면 교촌치킨 카드에 엉뚱한 음식이 붙는다.
  static const _placeholder = 'assets/images/platter.png';

  /// 카테고리별 대표 메뉴 기준가(원). 요기요 실거래가 대역을 참고한 어림값이다.
  static const _basePrice = <FoodCategory, int>{
    FoodCategory.chicken: 20000,
    FoodCategory.chinese: 12000,
    FoodCategory.korean: 14000,
    FoodCategory.japanese: 16000,
    FoodCategory.western: 18000,
    FoodCategory.snack: 11000,
    FoodCategory.pizza: 22000,
    FoodCategory.asian: 15000,
    FoodCategory.cafeDessert: 8000,
  };

  /// 카테고리별 사이드 메뉴 (이름, 가격, 설명).
  static const _sideMenu = <FoodCategory, (String, int, String)>{
    FoodCategory.chicken: ('감자튀김', 4000, '바삭하게 튀긴 감자튀김'),
    FoodCategory.chinese: ('군만두', 5000, '속이 꽉 찬 군만두'),
    FoodCategory.korean: ('계란찜', 3000, '부드러운 뚝배기 계란찜'),
    FoodCategory.japanese: ('미소된장국', 2000, '따뜻한 미소된장국'),
    FoodCategory.western: ('갈릭브레드', 4000, '마늘향 가득한 갈릭브레드'),
    FoodCategory.snack: ('튀김만두', 3500, '겉바속촉 튀김만두'),
    FoodCategory.pizza: ('치즈스틱', 5000, '늘어나는 모짜렐라 치즈스틱'),
    FoodCategory.asian: ('스프링롤', 5000, '바삭한 스프링롤'),
    FoodCategory.cafeDessert: ('아메리카노', 3500, '산미 적은 원두'),
  };

  /// 메뉴에 붙일 옵션. 명세대로 **사리·토핑·소스만** 담는다.
  ///
  /// 맵기는 더 이상 옵션이 아니다 — `spiceLevel` + `spiceAdjustable` 이 따로 있고,
  /// 회의(2026-08-04)에서 3단계로 통일했다. 시안의 "매운맛 5단계" 옵션 그룹은 없앴다.
  static const _genericOptions = [
    MenuOption(group: '사리 추가', name: '분모자', price: 2000),
    MenuOption(group: '사리 추가', name: '납작당면', price: 3000),
    MenuOption(group: '사리 추가', name: '우동사리', price: 2000),
    MenuOption(group: '토핑 추가', name: '치즈 추가', price: 2000),
    MenuOption(group: '양 선택', name: '곱빼기', price: 3000),
  ];

  /// 사이드용 옵션. 그룹 라벨이 없는 경우(`group: null`)를 함께 시연한다.
  static const _sideOptions = [MenuOption(name: '곱빼기로', price: 1500)];

  /// AI 로 만든 매장의 판매 메뉴. [build] 가 채우고 MockComboRepository 가 읽는다.
  ///
  /// AI 가 만든 매장은 고정 목록에 없어서, 이 캐시가 없으면 "메뉴 추가하기" 화면이
  /// 빈 목록으로 열린다. 서버가 붙으면 함께 사라진다.
  static final Map<int, List<Menu>> _builtMenus = {};

  /// 매장 캐시. 다시 주문처럼 매장 정보만 필요한 경우에 쓴다.
  static final Map<int, Restaurant> _builtRestaurants = {};

  static List<Menu> menuFor(int restaurantId) => _builtMenus[restaurantId] ?? const [];

  static Restaurant? restaurantFor(int restaurantId) => _builtRestaurants[restaurantId];

  /// 추출 결과 하나로 분석 응답을 만든다.
  static AnalysisResult build({
    required ExtractionResult extraction,
    required String? thumbnailUrl,
    required TastePreference preference,
  }) {
    final groups = _groupByBrand(extraction);
    final category = extraction.primaryCategory ?? FoodCategory.korean;

    final exactMatches = <ComboSuggestion>[
      for (final group in groups)
        _make(
          storeName: group.storeName,
          brandName: group.brandName,
          category: group.category ?? category,
          dishes: group.dishes,
          // 영상에서 본 그 음식이라 첫 브랜드 카드에만 릴스 썸네일을 쓴다.
          thumbnailUrl: group == groups.first ? thumbnailUrl : null,
          comboScore: null,
          preference: preference,
        ),
    ];

    // 대안 매장 2곳. 이름만 바꾸고 나머지는 같은 규칙으로 흔든다.
    // 브랜드를 못 찾았어도(exactMatches 가 비었어도) 여기는 채워야 화면이 빈다.
    final area = _areaOf(extraction);
    final combos = <ComboSuggestion>[];
    final alternatives = ['$area ${category.label} 전문점', '$area ${category.label} 배달맛집'];
    for (var i = 0; i < alternatives.length; i++) {
      combos.add(
        _make(
          storeName: alternatives[i],
          brandName: null,
          category: category,
          dishes: extraction.dishes,
          thumbnailUrl: null,
          // 명세대로 내림차순이 되도록 고정 간격으로 낮춘다.
          comboScore: (0.82 - i * 0.11).clamp(0.5, 1.0),
          preference: preference,
        ),
      );
    }

    return AnalysisResult(exactMatches: exactMatches, combos: combos);
  }

  /// 브랜드마다 하나씩 묶는다. 명세 비고 "브랜드는 영상 전체가 아니라 메뉴마다 붙는다".
  ///
  /// 브랜드를 못 찾은 메뉴들은 하나의 묶음으로 모은다 — 메뉴마다 가게를 따로
  /// 만들면 이름 없는 카드가 잔뜩 생긴다.
  static List<_BrandGroup> _groupByBrand(ExtractionResult extraction) {
    final order = <String?>[];
    final buckets = <String?, List<ExtractedDish>>{};

    for (final dish in extraction.dishes) {
      if (dish.name.isEmpty) continue;
      final key = dish.brandName;
      if (!buckets.containsKey(key)) {
        order.add(key);
        buckets[key] = [];
      }
      buckets[key]!.add(dish);
    }

    // 메뉴를 하나도 못 뽑았으면 브랜드 묶음도 없다. combos 만 남는다.
    if (order.isEmpty) return const [];

    return [
      for (final key in order)
        _BrandGroup(
          brandName: key,
          dishes: buckets[key]!,
          category: buckets[key]!
              .map((d) => d.foodCategory)
              .firstWhere((c) => c != null, orElse: () => null),
          storeName: _storeNameOf(key, buckets[key]!),
        ),
    ];
  }

  /// 화면에 그릴 상호명. 지점까지 있는 `restaurantName` 을 먼저 쓴다.
  static String _storeNameOf(String? brandName, List<ExtractedDish> dishes) {
    for (final d in dishes) {
      final name = d.restaurantName;
      if (name != null && name.isNotEmpty) return name;
    }
    if (brandName != null && brandName.isNotEmpty) return brandName;
    final category = dishes
        .map((d) => d.foodCategory)
        .firstWhere((c) => c != null, orElse: () => null);
    return '${(category ?? FoodCategory.korean).label} 맛집';
  }

  /// 지역명. 추출 결과에 지역 필드가 없어졌으므로 상호명에서 유추한다.
  ///
  /// 명세의 `extracted` 에는 `area` 가 없다 — 서버가 사용자 좌표 기준 5km 로 찾기
  /// 때문에 영상 속 지역은 쓰지 않는다. 대안 매장 이름을 만들 때만 필요한 값이다.
  static String _areaOf(ExtractionResult extraction) {
    final name = extraction.primaryRestaurantName;
    final match = RegExp(r'(\S+?)(점|동|구)\b').firstMatch(name);
    return match == null ? '우리동네' : '${match.group(1)}${match.group(2) == '점' ? '' : match.group(2)}';
  }

  static ComboSuggestion _make({
    required String storeName,
    required String? brandName,
    required FoodCategory category,
    required List<ExtractedDish> dishes,
    required String? thumbnailUrl,
    required double? comboScore,
    required TastePreference preference,
  }) {
    final seed = _seed(storeName);
    final restaurantId = seed % 900000 + 100000;

    final restaurant = Restaurant(
      restaurantId: restaurantId,
      name: storeName,
      foodCategory: category,
      area: '',
      rating: 3.6 + (seed % 13) / 10.0, // 3.6 ~ 4.8
      reviewCount: 60 + seed % 900,
      etaMin: 25 + (seed % 8) * 5, // 25 ~ 60분
      deliveryFee: 1000 + (seed % 4) * 500,
      minOrderPrice: 12000 + (seed % 4) * 2000,
      distanceKm: 0.6 + (seed % 40) / 10.0, // 0.6 ~ 4.5 km
      imageUrl: thumbnailUrl ?? '',
      imagePath: _placeholder,
      pickupMinutes: 15 + (seed % 3) * 5,
    );

    var items = _mainLines(
      dishes: dishes,
      category: category,
      preference: preference,
      thumbnailUrl: thumbnailUrl,
      seed: seed,
    );

    // 1인 모드면 메뉴를 핵심 하나로 줄인다.
    if (preference.mode == ServingMode.solo && items.length > 1) {
      items = items.take(1).toList();
    }

    final side = _sideMenu[category];
    final sideMenu = side == null
        ? null
        : Menu(
            menuId: restaurantId * 100 + 50,
            name: '[사이드] ${side.$1}',
            menuType: MenuType.side,
            price: _roundedPrice(side.$2),
            description: side.$3,
            imagePath: _placeholder,
            options: _sideOptions,
          );
    if (sideMenu != null) items = [...items, sideMenu.toCartLine()];

    // "메뉴 추가하기" 가 읽을 판매 메뉴를 만들어 둔다.
    // 담긴 것 + 아직 안 담긴 사이드·음료를 합쳐 목록이 비지 않게 한다.
    // 명세대로 MAIN → SIDE → DRINK 순으로 넣는다.
    _builtRestaurants[restaurantId] = restaurant;
    _builtMenus[restaurantId] = [
      for (final line in items)
        if (line.menuType == MenuType.main)
          Menu(
            menuId: line.menuId,
            name: line.name,
            menuType: MenuType.main,
            price: line.price,
            description: line.optionsText,
            imageUrl: line.imageUrl,
            imagePath: line.imagePath,
            spiceLevel: line.spiceLevel,
            spiceAdjustable: line.spiceAdjustable,
            options: line.options,
          ),
      ?sideMenu,
      Menu(
        menuId: restaurantId * 100 + 60,
        name: '[사이드] 치즈볼',
        menuType: MenuType.side,
        price: 3000,
        description: '모짜렐라 치즈 가득한 쫀득 치즈볼',
        imagePath: _placeholder,
        options: _sideOptions,
      ),
      Menu(
        menuId: restaurantId * 100 + 70,
        name: '코카콜라 500ml',
        menuType: MenuType.drink,
        price: 2500,
        description: '시원하게 마시는 콜라',
        imagePath: _placeholder,
      ),
    ];

    return ComboSuggestion(
      brandName: brandName,
      comboScore: comboScore,
      restaurant: restaurant,
      items: items,
    );
  }

  /// 영상에서 뽑은 음식은 전부 MAIN 취급이다. 사이드는 별도로 붙는다.
  ///
  /// AI 가 뽑은 옵션(`["분모자 넣어서"]`)은 정규화되지 않은 자연어라 옵션 목록과
  /// 그대로 맞출 수 없다. 이름이 겹치는 옵션만 체크된 상태로 만든다 —
  /// 서버가 하는 "옵션 일치 비율" 가산을 눈에 보이게 흉내낸 것이다.
  static List<CartLine> _mainLines({
    required List<ExtractedDish> dishes,
    required FoodCategory category,
    required TastePreference preference,
    required String? thumbnailUrl,
    required int seed,
  }) {
    final base = _basePrice[category] ?? 14000;
    final sources = [
      for (final d in dishes)
        if (d.name.isNotEmpty) d,
    ].take(2).toList();

    if (sources.isEmpty) {
      return [
        _line(
          menuId: seed % 900000 + 100000 + 1,
          name: '${category.label} 대표 메뉴',
          price: _roundedPrice(base + (seed % 6) * 1000),
          spice: preference.spice,
          imageUrl: thumbnailUrl,
          spoken: const [],
        ),
      ];
    }

    return [
      for (var i = 0; i < sources.length; i++)
        _line(
          menuId: seed % 900000 + 100000 + i + 1,
          name: sources[i].name,
          price: _roundedPrice(base + ((seed ~/ (i + 1)) % 6) * 1000),
          spice: preference.spice,
          // 첫 메뉴만 릴스 썸네일을 쓴다. 그게 영상에서 본 그 음식이다.
          imageUrl: i == 0 ? thumbnailUrl : null,
          spoken: sources[i].options,
        ),
    ];
  }

  static CartLine _line({
    required int menuId,
    required String name,
    required int price,
    required SpiceLevel spice,
    required String? imageUrl,
    required List<String> spoken,
  }) =>
      CartLine(
        menuId: menuId,
        name: name,
        menuType: MenuType.main,
        price: price,
        quantity: 1,
        imageUrl: imageUrl ?? '',
        imagePath: _placeholder,
        spiceLevel: spice,
        spiceAdjustable: true,
        selectedSpice: spice,
        options: [
          for (final option in _genericOptions)
            option.copyWith(selected: _mentioned(spoken, option.name)),
        ],
      );

  /// 영상에서 그 옵션을 말했는지. "분모자 넣어서" 안에 "분모자" 가 있으면 맞다고 본다.
  static bool _mentioned(List<String> spoken, String optionName) {
    final key = optionName.replaceAll(' ', '');
    for (final line in spoken) {
      if (line.replaceAll(' ', '').contains(key)) return true;
    }
    return false;
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

/// 같은 브랜드의 메뉴들을 모은 묶음. 하나가 곧 `exactMatches` 한 칸이다.
class _BrandGroup {
  const _BrandGroup({
    required this.brandName,
    required this.dishes,
    required this.category,
    required this.storeName,
  });

  final String? brandName;
  final List<ExtractedDish> dishes;
  final FoodCategory? category;
  final String storeName;
}
