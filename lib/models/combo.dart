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

import 'package:flutter/foundation.dart';

import 'cart.dart';
import 'enums.dart';
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
    this.tags = const [],
    this.reasonLines = const [],
  });

  /// 서버가 붙인 추천 근거 태그. 우선순위 순으로 최대 2개다
  /// (`MatchReasonTag`: EXACT_MATCH · OPTION_MATCH · TASTE_SIMILAR · DISTANCE).
  ///
  /// 내세울 것이 없는 카드에는 아무것도 안 붙는다. 서버가 의도한 것이다 —
  /// 모든 카드에 배지를 달면 배지가 정보가 아니라 장식이 된다.
  final List<String> tags;

  /// 서버 `reason` 문구. "영상에 나온 그 지점이고 분모자까지 담았어요" 처럼
  /// 옵션명·거리 같은 구체적인 값이 들어 있다.
  ///
  /// 서버는 카드당 한 줄을 주지만 여기서는 목록이다. [AnalysisResult.combos] 가
  /// 여러 요리의 후보를 한 가게로 묶으면 근거도 그 수만큼 생기기 때문이다.
  final List<String> reasonLines;

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

  /// 서버가 계산한 `lineTotal` 합. **배달비는 들어있지 않다.**
  /// 배달비는 `restaurant.deliveryFee` 에 따로 있고 결제 화면에서 프론트가 더한다.
  /// 화면은 수량이 바뀌는 즉시 [payableTotal] 로 다시 계산해 쓴다.
  final int? totalPrice;

  /// 영상에 나온 그 브랜드인지.
  bool get isExactMatch => brandName != null;

  /// 팝오버에 실제로 그릴 불릿 (시안 1052:8091).
  ///
  /// 서버 문구가 오면 그걸 쓰고, 태그만 오면 태그별 문구로 옮긴다. 둘 다 없을
  /// 때만 카드가 들고 있는 사실로 만든다.
  ///
  /// **평점은 근거로 쓰지 않는다.** 시안에는 "주변 후보 중 평점이 높아요" 가
  /// 있지만 서버 랭킹에 평점이 들어가지 않는다 — 평점 때문에 고른 것이 아닌데
  /// 그렇게 적으면 거짓말이 된다 (서버 `MatchReasonTag` 주석과 같은 판단이다).
  List<String> get reasonBullets {
    final given = [
      for (final line in reasonLines)
        if (line.trim().isNotEmpty) line.trim(),
    ];
    if (given.isNotEmpty) return given;

    final fromTags = [
      for (final tag in tags)
        if (_tagText[tag] != null) _tagText[tag]!,
    ];
    if (fromTags.isNotEmpty) return fromTags;

    return [
      if (isExactMatch) '영상에 나온 그 지점이에요',
      if (items.length > 1) '한 곳에서 ${items.length}개 메뉴를 시킬 수 있어요',
    ];
  }

  /// 서버가 태그만 주고 문구를 못 만든 경우의 대체 문구.
  /// 서버 `MatchReasonTagger` 와 같은 뜻이되, 옵션명·거리 같은 값이 없어 더 짧다.
  static const _tagText = {
    'EXACT_MATCH': '영상에 나온 그 지점이에요',
    'OPTION_MATCH': '영상에서 말한 옵션까지 맞출 수 있어요',
    'TASTE_SIMILAR': '같은 요리 후보 중 가장 비슷해요',
    'DISTANCE': '가까운 편이에요',
  };

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
        tags: tags,
        reasonLines: reasonLines,
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
        tags: [
          for (final e in (json['tags'] ?? const []) as List)
            if (e is String) e,
        ],
        reasonLines: [
          if (json['reason'] is String && (json['reason'] as String).isNotEmpty)
            json['reason'] as String,
        ],
      );
}

/// `POST v1/analyses` 응답 전체.
/// 한 요리에 대한 가게 후보 하나. `dishResults[].candidates[]`.
class DishCandidate {
  const DishCandidate({
    required this.restaurant,
    required this.item,
    required this.score,
    this.tags = const [],
    this.reason,
  });

  /// 서버가 붙인 근거 태그·문구. 가게 단위로 묶은 [AnalysisResult.combos] 카드가
  /// 이 값을 물려받는다.
  final List<String> tags;
  final String? reason;

  final Restaurant restaurant;

  /// 그 가게에서 이 요리에 가장 가까운 메뉴 **하나**.
  final CartLine item;

  /// 0~1. `유사도 × 0.9 + 옵션 일치 비율 × 0.1`. 이 순서로 정렬되어 온다.
  final double score;

  factory DishCandidate.fromJson(Map<String, dynamic> json) => DishCandidate(
        restaurant: Restaurant.fromJson(
          (json['restaurant'] ?? const <String, dynamic>{}) as Map<String, dynamic>,
        ),
        item: CartLine.fromJson(
          (json['item'] ?? const <String, dynamic>{}) as Map<String, dynamic>,
        ),
        score: ((json['score'] ?? 0) as num).toDouble(),
        tags: [
          for (final e in (json['tags'] ?? const []) as List)
            if (e is String) e,
        ],
        reason: json['reason'] as String?,
      );
}

/// 요리 하나와 그 후보 가게들. `dishResults[]`.
class DishResult {
  const DishResult({required this.dishName, this.candidates = const []});

  /// 요청의 `dishes[].name` 그대로.
  final String dishName;

  /// score 내림차순, 최대 5곳. 없으면 빈 배열.
  final List<DishCandidate> candidates;

  factory DishResult.fromJson(Map<String, dynamic> json) => DishResult(
        dishName: (json['dishName'] ?? '') as String,
        candidates: [
          for (final e in (json['candidates'] ?? const []) as List)
            if (e is Map<String, dynamic>) DishCandidate.fromJson(e),
        ],
      );
}

class AnalysisResult {
  const AnalysisResult({
    this.exactMatches = const [],
    this.dishResults = const [],
    this.summary,
    this.emptyReason,
    List<ComboSuggestion>? combos,
    // 이름이 다른 이유가 있다. 밖에서는 `combos` 로 받고 안에서는 `_combos` 에
    // 둔다 — 같은 이름의 게터가 있어야 하고, named 파라미터는 private 일 수 없다.
    // ignore: prefer_initializing_formals
  }) : _combos = combos;

  const AnalysisResult.empty()
      : exactMatches = const [],
        dishResults = const [],
        summary = null,
        emptyReason = null,
        _combos = null;

  /// "AI 추천 이유" 모달 본문 (시안 1059:5981). 서버 `summary` 다.
  ///
  /// LLM 이 쓰고, 호출이 실패하거나 결과가 비면 null 이 온다. 그때는
  /// [reasonText] 가 분석 결과로 대신 만든다.
  final String? summary;

  /// 결과가 완전히 비었을 때만 온다. 평소에는 null.
  /// 서버 `EmptyReason` 값 그대로다.
  final String? emptyReason;

  /// 왜 0개인지 사용자에게 할 말.
  ///
  /// 서버는 조건을 임의로 완화하지 않는다 — 0개면 0개로 준다. 이유를 말해 주지
  /// 않으면 사용자는 빈 화면만 보고 앱이 고장 났다고 읽는다. 그 자리를 메우려고
  /// 서버가 일부러 넣은 필드다.
  ///
  /// 배달시간 때문인 경우만 사용자가 직접 풀 수 있어 그 방법을 알려 준다. 맵기·고기
  /// 조건 때문에 0개인 경우는 서버가 NO_SIMILAR_MENU 로 합쳐서 내려주므로
  /// (판별하려면 벡터 검색을 한 번 더 돌려야 한다) 그 안내는 하지 않는다.
  String get emptyMessage => switch (emptyReason) {
        'NO_NEARBY' => '근처에 배달 가능한 가게가 없어요.\n주소를 다시 확인해 주세요.',
        'DELIVERY_TIME_FILTERED' =>
          '배달시간 조건에 맞는 가게가 없어요.\n시간을 늘리면 후보가 나올 수 있어요.',
        'NO_SIMILAR_MENU' => '조건에 맞는 비슷한 메뉴를 찾지 못했어요.\n조건을 바꿔서 다시 시도해 보세요.',
        _ => '조건에 맞는 조합을 찾지 못했어요.',
      };

  /// 1등과 이만큼 벌어지면 "비슷한 수준" 이 아니다. 그 아래는 커버리지가 많아도
  /// 앞으로 나오지 못한다. 점수는 0~1 이라 0.15 는 한 단계 차이쯤 된다.
  static const _scoreGap = 0.15;

  /// 이미 가게 단위로 묶인 조합을 그대로 쓸 때만 채운다.
  ///
  /// 서버 응답에는 없다 — 더미 저장소와 테스트가 [dishResults] 를 거치지 않고
  /// 곧바로 카드를 만들 때 쓴다. 값이 있으면 [combos] 가 묶는 대신 이것을 준다.
  final List<ComboSuggestion>? _combos;

  /// 영상에 나온 브랜드들. 여러 가게가 나오는 영상이면 여러 개다 —
  /// 다중 매장 묶음 주문의 출발점이 이 목록이다.
  final List<ComboSuggestion> exactMatches;

  /// 요리별 후보 가게 목록.
  ///
  /// **서버는 가게 단위로 묶어 주지 않는다.** 떡볶이와 치킨을 한 집에서 파는 가게가
  /// 거의 없어서, 서버가 "한 집에서 조합 전체" 로 묶으면 대부분 빈 결과가 되기
  /// 때문이다. 결제도 어차피 가게별로 쪼개져 `checkoutId` 로 묶인다.
  final List<DishResult> dishResults;

  /// 후보들을 가게 단위로 묶은 조합. **명세가 프론트에 맡긴 판단이다.**
  ///
  /// 같은 `restaurantId` 가 여러 요리의 후보에 나오면 그 집에서 다 시킬 수 있다는
  /// 뜻이고, 그러면 배달비가 한 번만 든다. 그래서 많이 커버하는 집을 앞에 놓고,
  /// 같은 개수면 점수 평균이 높은 집을 앞에 놓는다.
  ///
  /// `exactMatches` 에 실린 지점은 서버가 후보에서 빼고 주므로 여기서 겹치지 않는다.
  List<ComboSuggestion> get combos {
    final given = _combos;
    if (given != null) return given;

    final byStore = <int, List<DishCandidate>>{};
    for (final dish in dishResults) {
      for (final c in dish.candidates) {
        // 한 요리에서 같은 가게가 두 번 나올 일은 없지만, 나오더라도 첫 번째(점수가
        // 더 높은 쪽)만 쓴다. 같은 메뉴가 장바구니에 두 줄로 들어가면 안 된다.
        final lines = byStore.putIfAbsent(c.restaurant.restaurantId, () => []);
        if (lines.any((x) => x.item.menuId == c.item.menuId)) continue;
        lines.add(c);
      }
    }

    final result = [
      for (final entry in byStore.entries)
        ComboSuggestion(
          restaurant: entry.value.first.restaurant,
          items: [for (final c in entry.value) c.item],
          comboScore: entry.value.map((c) => c.score).reduce((a, b) => a + b) /
              entry.value.length,
          // 근거는 후보마다 따로 붙어 온다. 한 가게로 묶었으니 근거도 모은다.
          // 같은 문구가 두 요리에서 겹칠 수 있어 중복은 뺀다.
          tags: {for (final c in entry.value) ...c.tags}.toList(),
          reasonLines: {
            for (final c in entry.value)
              if ((c.reason ?? '').trim().isNotEmpty) c.reason!.trim(),
          }.toList(),
        ),
    ];

    // 커버리지는 **비슷한 수준의 후보끼리만** 따진다.
    //
    // 커버리지를 먼저 보면 관련 없는 집이 앞으로 나온다. 치킨 영상(치킨 + 치즈볼)에서
    // 두 요리에 어중간하게 걸린 한식집이 커버리지 2로, 치킨 하나만 정확히 맞춘
    // 치킨집(커버리지 1)을 제친다. 실제로 "치킨 영상인데 한식집이 뜬다" 는 것이
    // 이 정렬이었다. 배달비 한 번은 이득이지만 안 시킬 집이면 이득이 아니다.
    final best = result.fold<double>(
      0,
      (m, c) => (c.comboScore ?? 0) > m ? (c.comboScore ?? 0) : m,
    );
    bool strong(ComboSuggestion c) => (c.comboScore ?? 0) >= best - _scoreGap;

    result.sort((a, b) {
      if (strong(a) != strong(b)) return strong(a) ? -1 : 1;
      final byCoverage = b.items.length.compareTo(a.items.length);
      if (byCoverage != 0) return byCoverage;
      return (b.comboScore ?? 0).compareTo(a.comboScore ?? 0);
    });
    return result;
  }

  /// 결과가 하나도 없는지. 명세는 이때도 에러가 아니라 200 + 빈 배열을 준다.
  bool get isEmpty => exactMatches.isEmpty && combos.isEmpty;
  bool get isNotEmpty => !isEmpty;

  /// 요리와 카테고리가 다른 후보를 걷어낸 결과.
  ///
  /// 서버 벡터 검색은 "가장 가까운 N개" 를 주므로 그 카테고리 가게가 반경 안에
  /// 하나도 없으면 전혀 다른 음식이 그대로 1등으로 올라온다. 실제로 포테이토피자
  /// 릴스에서 한솥도시락의 돈치마요가 추천됐다 (2026-08-13).
  ///
  /// **같은 카테고리가 하나도 없으면 그 요리는 빈 결과로 둔다.** 엉뚱한 집을
  /// 다섯 개 보여주는 것보다 "찾지 못했어요" 가 맞다.
  ///
  /// [categoryByDish] 에 없는 요리(추출이 카테고리를 못 정한 경우)는 손대지 않는다.
  /// `exactMatches` 도 손대지 않는다 — 브랜드로 직접 찾은 것이라 카테고리와
  /// 무관하게 정확하다.
  AnalysisResult withCategoryFilter(Map<String, FoodCategory> categoryByDish) {
    if (categoryByDish.isEmpty) return this;

    return AnalysisResult(
      summary: summary,
      emptyReason: emptyReason,
      exactMatches: exactMatches,
      dishResults: [
        for (final dish in dishResults)
          _filterDish(dish, categoryByDish[dish.dishName]),
      ],
    );
  }

  /// 영상에 나온 것과 **같은 메뉴를 파는 후보만** 남긴다.
  ///
  /// 첫 화면은 "먹방 속 조합" 이다. 마라로제 떡볶이 영상에 마라로제찜닭이 뜨면
  /// 안 된다 — 비슷한 집은 "다른 결과 보기" 의 몫이다.
  ///
  /// 서버는 반경 안에서 "가장 가까운 5개" 를 채워 주기만 한다. 떡볶이집이 없으면
  /// 점수가 평평한 채로 아무거나 올라온다. 실제로 마라로제 떡볶이 요청에
  /// 이렇게 왔다.
  ///
  ///     0.54 두찜 / 마라로제찜닭      0.46 홍수계찜닭 / 로제찜닭
  ///     0.46 직구삼 / 비빔쫄면        0.46 본도시락 / 제육볶음 도시락
  ///     0.44 가장맛있는족발 / 쟁반국수
  ///
  /// 전부 KOREAN 이라 [withCategoryFilter] 로는 하나도 걸러지지 않는다.
  ///
  /// **서버는 최소 유사도 컷을 두지 않는다** — 반경·맵기·고기·배달시간 필터만
  /// 적용한다고 명세에 못박혀 있고, "떡볶이 검색에 마라탕집이 낮은 score 로
  /// 올라오는 일이 있다" 고 스스로 적어 두었다. 즉 이 자리는 앱이 맡는다.
  AnalysisResult withMenuFilter() {
    // 대조할 요리 이름이 없으면 거를 근거도 없다. 카드를 이미 묶어서 받은 경우
    // ([_combos]) 도 여기에 해당한다 — 더미 저장소와 테스트가 그렇게 준다.
    if (dishResults.isEmpty) return this;

    return AnalysisResult(
      summary: summary,
      emptyReason: emptyReason,
      exactMatches: exactMatches,
      dishResults: [
        for (final dish in dishResults)
          DishResult(
            dishName: dish.dishName,
            candidates: [
              for (final c in dish.candidates)
                if (isSameDish(dish.dishName, c.item.name)) c,
            ],
          ),
      ],
    );
  }

  /// 메뉴가 그 요리와 같은 음식인지.
  ///
  ///     마라로제 떡볶이  → "떡볶이" ∈ 마라로제찜닭 ?  아니오 → 거른다
  ///     럭키치즈떡볶이   → "떡볶이" ∈ 치즈떡볶이 ?    예   → 남긴다
  ///     인기폭탄세트     → 무슨 음식인지 모른다        → 거르지 않는다
  ///
  /// **모르면 거르지 않는다.** 판단 근거가 없는데도 걸러 버리면 화면이 통째로
  /// 비는데, 그건 "영상에 없는 음식을 보여주지 않겠다" 보다 훨씬 나쁘다.
  /// 실제로 그랬다 — 인기폭탄세트·오징어 먹물 슬러쉬 같은 이름이 전부
  /// "근처에 없어요" 로 떨어졌다.
  @visibleForTesting
  static bool isSameDish(String dishName, String menuName) {
    final head = dishHeadNoun(dishName);
    if (head.isEmpty) return true;
    return _squash(menuName).contains(head);
  }

  /// 요리 이름에서 핵심 음식명을 뽑는다. 알아보지 못하면 빈 문자열.
  ///
  /// 한국어 음식 이름은 **정체가 뒤에 온다** — "마라로제 떡볶이" 도 "럭키치즈떡볶이"
  /// 도 떡볶이다. 그런데 띄어쓰기가 있을 때만 낱말로 자를 수 있어서, 붙여 쓴
  /// 이름은 표에 있는 말로 찾아내야 한다.
  ///
  /// 처음에는 표 없이 "마지막 낱말" 만 썼다. 그러면 붙여 쓴 이름이 통째로 핵심어가
  /// 되어(럭키치즈떡볶이 ∈ 치즈떡볶이? 아니오) 멀쩡한 후보까지 전부 떨어졌다.
  @visibleForTesting
  static String dishHeadNoun(String dishName) {
    final name = _squash(dishName);
    if (name.isEmpty) return '';

    // 끝에 오는 것이 그 음식의 정체다.
    for (final noun in _foodNouns) {
      if (name.endsWith(noun)) return noun;
    }
    // "떡볶이 2인분" 처럼 뒤에 수량이 붙은 경우. 끝이 아니어도 찾는다.
    for (final noun in _foodNouns) {
      if (name.contains(noun)) return noun;
    }
    return '';
  }

  /// 음식의 정체를 가리키는 말. **임시 표다** — 서버가 "이 메뉴가 그 요리인가" 를
  /// 판단해 주면 통째로 사라진다.
  ///
  /// 긴 것부터 본다. "떡볶이" 를 "볶이" 보다, "치즈돈까스" 를 "돈까스" 보다 먼저
  /// 잡아야 한다. 여기 없는 음식은 못 알아보는 것으로 두고 거르지 않는다 —
  /// 표에 없다고 후보를 버리면 새 메뉴가 나올 때마다 화면이 빈다.
  static final List<String> _foodNouns = [
    ...['떡볶이', '라볶이', '쫄면', '순대', '튀김', '핫도그', '김밥', '만두', '어묵'],
    ...['치킨', '후라이드', '양념치킨', '닭강정', '닭발', '찜닭', '불닭', '닭갈비'],
    ...['피자', '파스타', '스파게티', '리조또', '스테이크', '햄버거', '샌드위치'],
    ...['짜장면', '짬뽕', '탕수육', '깐풍기', '유린기', '동파육', '마라탕', '마라샹궈'],
    ...['초밥', '회', '돈까스', '우동', '라멘', '규동', '덮밥', '카레'],
    ...['쌀국수', '팟타이', '분짜', '똠얌꿍'],
    ...['국밥', '해장국', '설렁탕', '갈비탕', '삼계탕', '부대찌개', '김치찌개'],
    ...['된장찌개', '순두부', '제육볶음', '불고기', '비빔밥', '냉면', '국수', '칼국수'],
    ...['족발', '보쌈', '곱창', '막창', '삼겹살', '갈비', '스테이크'],
    ...['샐러드', '포케', '케이크', '와플', '크로플', '빙수', '아이스크림'],
    ...['커피', '라떼', '스무디', '에이드', '주스', '버블티'],
  ]..sort((a, b) => b.length.compareTo(a.length));

  /// 띄어쓰기·가운뎃점을 지운다. "마라 로제 떡볶이" 와 "마라로제떡볶이" 를 같게 본다.
  static String _squash(String s) => s.replaceAll(RegExp(r'[\s·・,]'), '');

  /// **임시 표다.** 서버가 유사도로 걸러 주면 이 표와 [withCategoryFilter] 는
  /// 통째로 사라진다.
  ///
  /// 값은 "같은 카테고리가 없을 때 대신 보여줘도 되는 곳" 이다. 피자를 찾는데
  /// 피자집이 없으면 파스타집까지는 납득이 되지만 한식집은 아니다.
  /// 여기 없는 카테고리는 아예 다른 음식으로 본다.
  ///
  /// 카페·디저트는 대체할 곳을 두지 않는다 — 디저트 대신 밥집을 주면 안 된다.
  static const _nearby = {
    FoodCategory.pizza: {FoodCategory.western},
    FoodCategory.western: {FoodCategory.pizza},
    FoodCategory.chicken: {FoodCategory.snack},
    FoodCategory.snack: {FoodCategory.korean, FoodCategory.chicken},
    FoodCategory.korean: {FoodCategory.snack},
    FoodCategory.chinese: {FoodCategory.asian},
    FoodCategory.asian: {FoodCategory.chinese, FoodCategory.japanese},
    FoodCategory.japanese: {FoodCategory.asian},
    FoodCategory.cafeDessert: <FoodCategory>{},
  };

  static DishResult _filterDish(DishResult dish, FoodCategory? wanted) {
    if (wanted == null || dish.candidates.isEmpty) return dish;

    final allowed = {wanted, ...?_nearby[wanted]};
    final matched = [
      for (final c in dish.candidates)
        if (allowed.contains(c.restaurant.foodCategory)) c,
    ];
    return DishResult(dishName: dish.dishName, candidates: matched);
  }

  /// 영상에 나온 것을 앞에, 비슷한 곳을 뒤에. 카드를 한 줄로 넘겨 볼 때 쓴다.
  List<ComboSuggestion> get all => [...exactMatches, ...combos];

  /// 영상에 나온 브랜드 전부를 장바구니에 담은 초기 상태.
  /// 떡볶이+핫도그 영상이면 가게 2개가 담긴 채로 시작한다.
  List<StoreCart> get exactStoreCarts =>
      [for (final m in exactMatches) m.toStoreCart()];

  /// 모달에 실제로 그릴 본문.
  ///
  /// 서버 문장이 있으면 그대로 쓴다. 없으면 분석 결과로 조립한다 — 빈 모달을
  /// 띄우느니 실제로 무엇을 찾고 무엇을 못 찾았는지 말해 주는 편이 낫다.
  /// 서버가 `reason` 을 내려주기 시작하면 이 조립은 저절로 안 쓰인다.
  ///
  /// [maxDeliveryMinutes] 는 못 찾은 이유를 설명할 때 쓴다. 조건을 빼고 "못
  /// 찾았어요" 라고만 하면 그 가게가 아예 없는 것처럼 읽힌다.
  String reasonText({required int maxDeliveryMinutes}) {
    final given = (summary ?? '').trim();
    if (given.isNotEmpty) return given;

    final sentences = <String>[];

    final brands = [
      for (final m in exactMatches)
        if (m.brandName != null) m.brandName!,
    ];
    if (brands.isNotEmpty) {
      final names = brands.join(', ');
      sentences.add('영상 속 $names${_topicParticle(brands.last)} 근처 지점에서 '
          '그대로 주문할 수 있어요.');
    }

    for (final dish in dishResults) {
      if (dish.candidates.isEmpty) continue;
      sentences.add('${dish.dishName}${_topicParticle(dish.dishName)} '
          '비슷한 집 ${dish.candidates.length}곳을 찾았어요.');
    }

    final missing = [
      for (final dish in dishResults)
        if (dish.candidates.isEmpty) dish.dishName,
    ];
    if (missing.isNotEmpty) {
      final names = missing.join(', ');
      sentences.add('$names${_topicParticle(missing.last)} '
          '배달 $maxDeliveryMinutes분 조건 안에서는 찾지 못했어요.');
    }

    if (sentences.isEmpty) {
      // 더미 저장소처럼 `dishResults` 를 거치지 않고 카드만 오는 경로다.
      final count = combos.length;
      return count == 0
          ? '영상 속 메뉴와 비슷한 조합을 찾지 못했어요.'
          : '영상 속 메뉴와 가장 비슷한 조합 $count개를 찾았어요.';
    }

    return sentences.join(' ');
  }

  factory AnalysisResult.fromJson(Map<String, dynamic> json) => AnalysisResult(
        summary: json['summary'] as String?,
        emptyReason: json['emptyReason'] as String?,
        exactMatches: [
          for (final e in (json['exactMatches'] ?? const []) as List)
            if (e is Map<String, dynamic>) ComboSuggestion.fromJson(e),
        ],
        dishResults: [
          for (final e in (json['dishResults'] ?? const []) as List)
            if (e is Map<String, dynamic>) DishResult.fromJson(e),
        ],
      );
}

/// 은/는. 마지막 글자에 받침이 있으면 '은' 이다.
///
/// 요리 이름이 데이터에서 오므로 조사를 고정하면 "마라탕는" 같은 문장이 나온다.
String _topicParticle(String word) => _particle(word, '는', '은');

/// 목적격 조사. "떡볶이를", "동파육을".
String objectParticle(String word) => _particle(word, '를', '을');

/// 받침이 없으면 [open], 있으면 [closed].
String _particle(String word, String open, String closed) {
  if (word.isEmpty) return open;
  final code = word.codeUnitAt(word.length - 1);
  // 한글 음절이 아니면(영문·숫자) 받침을 알 수 없다. 흔한 쪽으로 둔다.
  if (code < 0xAC00 || code > 0xD7A3) return open;
  return (code - 0xAC00) % 28 == 0 ? open : closed;
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
