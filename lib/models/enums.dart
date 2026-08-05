/// 명세가 정한 enum 들. wire 값은 대문자 스네이크다 (`docs/api-spec.md` 공통).
///
/// 서버 DB 가 이 값들만 허용한다 — `food_category` 는 9개 밖의 값이면 INSERT 가
/// 거절되고, `spice_level` 은 NULL 을 허용하지 않는다. 앱도 같은 제약을 지킨다.
library;

/// `restaurant.food_category` — 이 9개만.
enum FoodCategory {
  chicken('CHICKEN', '치킨'),
  snack('SNACK', '분식'),
  korean('KOREAN', '한식'),
  chinese('CHINESE', '중식'),
  japanese('JAPANESE', '일식'),
  western('WESTERN', '양식'),
  pizza('PIZZA', '피자'),
  asian('ASIAN', '아시안'),
  cafeDessert('CAFE_DESSERT', '카페·디저트');

  const FoodCategory(this.wire, this.label);

  /// 서버로 보내고 받는 값.
  final String wire;

  /// 화면에 그리는 한글 이름.
  final String label;

  static FoodCategory? fromWire(String? value) {
    if (value == null) return null;
    final upper = value.trim().toUpperCase();
    for (final c in values) {
      if (c.wire == upper) return c;
    }
    return null;
  }

  /// 한글 이름으로 찾는다. AI 가 한글 카테고리를 뱉었을 때 되돌리는 용도다.
  static FoodCategory? fromLabel(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    for (final c in values) {
      if (c.label == trimmed) return c;
    }
    return null;
  }
}

/// `menu.menu_type` — 메뉴 조회 응답이 MAIN → SIDE → DRINK 순으로 정렬돼 온다.
/// 프론트는 이 순서대로 섹션을 나눠 그린다.
enum MenuType {
  main('MAIN', '대표메뉴'),
  side('SIDE', '사이드'),
  drink('DRINK', '음료');

  const MenuType(this.wire, this.label);

  final String wire;

  /// 매장 메뉴 화면의 섹션 제목.
  final String label;

  static MenuType fromWire(String? value) {
    final upper = (value ?? '').trim().toUpperCase();
    for (final t in values) {
      if (t.wire == upper) return t;
    }
    // DB 기본값이 MAIN 이다. 모르는 값이 와도 메뉴가 사라지지 않게 한다.
    return MenuType.main;
  }
}

/// 맵기 3단계. 회의(2026-08-04)에서 디자인 명세에 맞춰 3단계로 통일했다.
///
/// 세 자리에 함께 쓰인다.
/// - `menu.spiceLevel` — 그 메뉴가 원래 얼마나 매운지 (MEDIUM/HOT 이면 고추 뱃지)
/// - `items[].selectedSpice` — 주문에 담긴 맵기 (nullable)
/// - `preferences.maxSpiceLevel` — 취향 설정의 상한 (nullable)
enum SpiceLevel {
  none('NONE', 0, '순한맛', 'assets/images/spice_mild.png'),
  medium('MEDIUM', 1, '보통맛', 'assets/images/spice_medium.png'),
  hot('HOT', 2, '매운맛', 'assets/images/spice_hot.png');

  const SpiceLevel(this.wire, this.rank, this.title, this.imagePath);

  final String wire;

  /// DB 가상 컬럼 `spice_rank` 와 같은 값. 상한 비교에 쓴다.
  final int rank;

  /// 취향 설정·맵기 버튼에 쓰는 이름.
  final String title;

  final String imagePath;

  /// 명세에 없는 값(예전 5단계의 `EXTREME`)이 와도 터지지 않고 null 이 된다.
  static SpiceLevel? fromWire(String? value) {
    if (value == null) return null;
    final upper = value.trim().toUpperCase();
    for (final s in values) {
      if (s.wire == upper) return s;
    }
    return null;
  }

  /// `spice_level` 은 NULL 을 허용하지 않는다. 메뉴를 파싱할 때 쓰는 폴백이다.
  static SpiceLevel fromWireOrNone(String? value) => fromWire(value) ?? SpiceLevel.none;
}
