/// 분석 결과 도메인 모델. `POST v1/analyses` 응답과 1:1이다.
///
/// 응답이 두 블록으로 나뉘어 있는 것 자체가 설명이다 (명세 비고).
/// - `exactMatches` — **영상에 나온 그 브랜드**. 브랜드 수만큼 온다. 없으면 빈 배열.
/// - `combos` — **비슷한 다른 가게**. `comboScore` 내림차순, 개수 제한 없음.
///
/// 둘 다 같은 모양이라 [ComboSuggestion] 하나로 받는다. `brandName` 이 있으면
/// exactMatch, `comboScore` 가 있으면 combo 다.
///
/// 이 파일은 화면들이 쓰는 배럴이기도 하다 — 매장·메뉴·장바구니를 함께 내보낸다.
library;

import 'cart.dart';
import 'menu.dart';
import 'restaurant.dart';

export 'cart.dart';
export 'enums.dart';
export 'menu.dart';
export 'menu_option.dart';
export 'restaurant.dart';

/// 매장 하나 + 그 매장에서 담을 메뉴들. 카드 한 장이 이것 하나다.
class ComboSuggestion {
  ComboSuggestion({
    required this.restaurant,
    required this.items,
    this.brandName,
    this.comboScore,
    this.totalPrice,
  });

  /// 어느 브랜드 결과인지. `exactMatches` 에만 있다.
  final String? brandName;

  /// 0~1. `combos` 에만 있고, 이 순서로 정렬되어 온다.
  ///
  /// `평균 유사도 × 0.9 + 옵션 일치 비율 × 0.1` 이다. 커버리지(몇 개를 커버했나)는
  /// 점수에 안 들어간다 — `combos` 는 "한 집에서 다 되는 곳" 이 아니라 관련도 순 목록이다.
  final double? comboScore;

  final Restaurant restaurant;

  /// 그 매장에서 담을 메뉴들. 한 줄이 장바구니 한 칸이다.
  /// 못 찾은 메뉴는 여기서 그냥 빠진다 — 별도 안내 필드가 없다.
  List<CartLine> items;

  /// 서버가 계산한 결제 예상액(`lineTotal` 합 + `deliveryFee`).
  /// 화면은 수량이 바뀌는 즉시 [payableTotal] 로 다시 계산해 쓴다.
  final int? totalPrice;

  /// 영상에 나온 그 브랜드인지.
  bool get isExactMatch => brandName != null;

  /// 카드 식별자. 서버가 조합 id 를 주지 않아 매장 id 를 그대로 쓴다.
  /// 한 브랜드당 가장 가까운 지점 하나만 오므로 목록 안에서 겹치지 않는다.
  int get id => restaurant.restaurantId;

  int get itemsTotal => items.fold(0, (sum, item) => sum + item.lineTotal);

  /// 결제 예상액. 배달비는 가게마다 한 번 붙는다.
  int get payableTotal => itemsTotal + restaurant.deliveryFee;

  bool get meetsMinimum => itemsTotal >= restaurant.minOrderPrice;

  CartLine? lineOf(int menuId) {
    for (final line in items) {
      if (line.menuId == menuId) return line;
    }
    return null;
  }

  /// 이 카드를 장바구니 한 칸으로 바꾼다. 다중 매장 결제는 이걸 여러 개 모은다.
  StoreCart toStoreCart() =>
      StoreCart(restaurant: restaurant, lines: [for (final i in items) i.copy()]);

  ComboSuggestion copy() => ComboSuggestion(
        brandName: brandName,
        comboScore: comboScore,
        restaurant: restaurant,
        items: [for (final i in items) i.copy()],
        totalPrice: totalPrice,
      );

  factory ComboSuggestion.fromJson(Map<String, dynamic> json) => ComboSuggestion(
        brandName: json['brandName'] as String?,
        comboScore: (json['comboScore'] as num?)?.toDouble(),
        restaurant: Restaurant.fromJson(
          (json['restaurant'] ?? const <String, dynamic>{}) as Map<String, dynamic>,
        ),
        items: [
          for (final e in (json['items'] ?? const []) as List)
            if (e is Map<String, dynamic>) CartLine.fromJson(e),
        ],
        totalPrice: (json['totalPrice'] as num?)?.toInt(),
      );
}

/// `POST v1/analyses` 응답 전체.
class AnalysisResult {
  const AnalysisResult({this.exactMatches = const [], this.combos = const []});

  const AnalysisResult.empty() : exactMatches = const [], combos = const [];

  /// 영상에 나온 브랜드들. 여러 가게가 나오는 영상이면 여러 개다 —
  /// 다중 매장 묶음 주문의 출발점이 이 목록이다.
  final List<ComboSuggestion> exactMatches;

  /// 비슷한 다른 가게들. 이미 `comboScore` 내림차순으로 정렬돼 온다.
  final List<ComboSuggestion> combos;

  /// 결과가 하나도 없는지. 명세는 이때도 에러가 아니라 200 + 빈 배열을 준다.
  bool get isEmpty => exactMatches.isEmpty && combos.isEmpty;
  bool get isNotEmpty => !isEmpty;

  /// 영상에 나온 것을 앞에, 비슷한 곳을 뒤에. 카드를 한 줄로 넘겨 볼 때 쓴다.
  List<ComboSuggestion> get all => [...exactMatches, ...combos];

  /// 영상에 나온 브랜드 전부를 장바구니에 담은 초기 상태.
  /// 떡볶이+핫도그 영상이면 가게 2개가 담긴 채로 시작한다.
  List<StoreCart> get exactStoreCarts =>
      [for (final m in exactMatches) m.toStoreCart()];

  factory AnalysisResult.fromJson(Map<String, dynamic> json) => AnalysisResult(
        exactMatches: [
          for (final e in (json['exactMatches'] ?? const []) as List)
            if (e is Map<String, dynamic>) ComboSuggestion.fromJson(e),
        ],
        combos: [
          for (final e in (json['combos'] ?? const []) as List)
            if (e is Map<String, dynamic>) ComboSuggestion.fromJson(e),
        ],
      );
}

/// 비교 목록 상단 정렬 기준.
enum ComboSort {
  /// 서버가 준 `comboScore` 순. `exactMatches` 는 점수가 없어 항상 맨 앞이다.
  similarity('먹방 유사도순'),
  deliveryTime('빠른 배달순'),
  price('낮은 가격순');

  const ComboSort(this.title);

  final String title;

  /// 정렬을 적용한 새 목록. 원본은 건드리지 않는다.
  List<ComboSuggestion> apply(List<ComboSuggestion> input) {
    final sorted = [...input];
    switch (this) {
      case ComboSort.similarity:
        // 영상에 나온 브랜드가 먼저, 그 다음이 점수 높은 순이다.
        sorted.sort((a, b) {
          if (a.isExactMatch != b.isExactMatch) return a.isExactMatch ? -1 : 1;
          return (b.comboScore ?? 0).compareTo(a.comboScore ?? 0);
        });
      case ComboSort.deliveryTime:
        sorted.sort((a, b) => a.restaurant.etaMin.compareTo(b.restaurant.etaMin));
      case ComboSort.price:
        sorted.sort((a, b) => a.payableTotal.compareTo(b.payableTotal));
    }
    return sorted;
  }
}
