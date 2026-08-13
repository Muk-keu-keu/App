/// 매장. 명세의 `restaurant` 오브젝트와 1:1이다.
///
/// 분석 응답(`exactMatches[].restaurant`, `combos[].restaurant`)과 메뉴 조회
/// 응답(`restaurant`)이 같은 모양을 쓴다. 필드를 고치면 `docs/api-spec.md` 도 고친다.
library;

import 'enums.dart';

class Restaurant {
  const Restaurant({
    required this.restaurantId,
    required this.name,
    required this.foodCategory,
    required this.area,
    required this.rating,
    required this.etaMin,
    required this.deliveryFee,
    required this.minOrderPrice,
    required this.distanceKm,
    this.imageUrl = '',
    this.reviewCount,
    this.imagePath = 'assets/images/store_dujjim.png',
    this.heroImagePath = '',
    this.pickupMinutes = 0,
  });

  final int restaurantId;

  /// 지점까지 붙은 원본 상호명. `엽기떡볶이 성수점`
  final String name;

  final FoodCategory foodCategory;

  /// 동 단위 지역명. `성수동`
  final String area;

  /// 평점. **리뷰가 없으면 null 이다** — 서버가 일부러 0.0 으로 채우지 않는다.
  /// 0.0 으로 받아 그리면 리뷰가 없는 새 가게가 최악의 평점처럼 보인다.
  final double? rating;

  /// 이동시간 + 조리시간. "실제로 몇 분 걸리는지" 다.
  /// DB `delivery_min` 은 배달 시간 **필터**용이고 이 값과 다르다.
  final int etaMin;

  /// 가게별 배달비. 주문 시 가게마다 한 번 부과된다.
  final int deliveryFee;

  /// 음식값이 이 값보다 낮으면 "N원 더 담아주세요" 를 띄운다.
  final int minOrderPrice;

  final double distanceKm;

  /// 대표 이미지 URL 1장. 서버가 빈 값을 줄 수 있어 [imagePath] 로 폴백한다.
  final String imageUrl;

  /// 리뷰 수. `GET v1/restaurants/{id}/menus` 의 `restaurant` 블록이 내려준다
  /// (2026-08-09 부터). 분석 응답에는 아직 없어서 nullable 로 둔다 — 없는 값을
  /// 0으로 그리면 "리뷰 0개" 로 읽힌다.
  final int? reviewCount;

  /// 원격 이미지를 못 받았을 때 쓰는 번들 에셋. 시연용이고 서버 필드가 아니다.
  final String imagePath;

  /// 매장 상세 상단에 깔리는 큰 사진. 비면 [imagePath] 를 쓴다. 서버 필드가 아니다.
  final String heroImagePath;

  /// 포장 예상 시간(분). 응답에 없어 0이면 포장 탭을 비활성으로 그린다.
  final int pickupMinutes;

  /// 리뷰 수가 없으면 평점만 보여준다 — 없는 값을 0으로 그리면 "리뷰 0개" 로 읽힌다.
  ///
  /// 평점 자체가 없으면(리뷰가 하나도 없는 가게) "0.0/5" 대신 아무것도 없다고 말한다.
  /// 0.0 은 "최악" 으로 읽혀서, 아직 평가가 없는 가게에 없는 사실을 씌운다.
  String get ratingText {
    final r = rating;
    if (r == null) return '평가 없음';
    return reviewCount == null
        ? '${r.toStringAsFixed(1)}/5'
        : '${r.toStringAsFixed(1)}/5 ($reviewCount)';
  }

  String get heroPath => heroImagePath.isEmpty ? imagePath : heroImagePath;
  String get distanceText => '${distanceKm.toStringAsFixed(1)} km';
  String get deliveryTabText => '배달 $etaText';
  String get pickupTabText => pickupMinutes == 0 ? '포장' : '포장 $pickupMinutes분';

  /// 60분을 넘으면 "1시간 10분" 으로 읽기 쉽게 끊는다.
  String get etaText {
    if (etaMin >= 60) {
      final h = etaMin ~/ 60;
      final m = etaMin % 60;
      return m == 0 ? '$h시간' : '$h시간 $m분';
    }
    return '$etaMin분';
  }

  /// 최소 주문 금액까지 얼마 남았는지. 넘겼으면 0.
  int shortfallFrom(int itemsTotal) =>
      itemsTotal >= minOrderPrice ? 0 : minOrderPrice - itemsTotal;

  factory Restaurant.fromJson(Map<String, dynamic> json) => Restaurant(
        restaurantId: ((json['restaurantId'] ?? 0) as num).toInt(),
        name: (json['name'] ?? '') as String,
        // 9개 밖의 값이 오면 매장을 버리는 대신 한식으로 떨어뜨린다.
        // 카테고리는 칩 라벨에만 쓰여서 틀려도 주문을 막지 않는다.
        foodCategory:
            FoodCategory.fromWire(json['foodCategory'] as String?) ?? FoodCategory.korean,
        area: (json['area'] ?? '') as String,
        // null 을 0.0 으로 바꾸지 않는다. 서버가 "리뷰가 없다" 는 뜻으로 null 을 준다.
        rating: (json['rating'] as num?)?.toDouble(),
        etaMin: ((json['etaMin'] ?? 0) as num).toInt(),
        deliveryFee: ((json['deliveryFee'] ?? 0) as num).toInt(),
        minOrderPrice: ((json['minOrderPrice'] ?? 0) as num).toInt(),
        distanceKm: ((json['distanceKm'] ?? 0) as num).toDouble(),
        imageUrl: (json['imageUrl'] ?? '') as String,
        // 분석 응답에도 온다 (2026-08-13 명세). 없으면 null 이다.
        reviewCount: (json['reviewCount'] as num?)?.toInt(),
      );

  /// 주문 상세와 게시글의 `order` 블록은 매장 정보를 세 개만 준다. 다시 주문·족보
  /// 작성이 그 자리에서 매장 카드를 그려야 해서, 아는 값만으로 최소한의 객체를 만든다.
  ///
  /// 평점·리뷰 수·거리·예상 시간·최소 주문 금액은 0이다. **결제까지 가는 화면은
  /// 그대로 쓰면 안 된다** — 최소 주문 금액이 0이면 미달 판정이 무력해진다.
  /// `AppFlow._hydrateStores` 가 GET menus 로 갈아끼운다.
  factory Restaurant.partial({
    required int restaurantId,
    required String name,
    required int deliveryFee,
  }) =>
      Restaurant(
        restaurantId: restaurantId,
        name: name,
        foodCategory: FoodCategory.korean,
        area: '',
        // 모르는 값이다. 0 으로 두면 "0.0/5" 로 그려져 없는 사실을 만든다.
        rating: null,
        etaMin: 0,
        deliveryFee: deliveryFee,
        minOrderPrice: 0,
        distanceKm: 0,
      );
}
