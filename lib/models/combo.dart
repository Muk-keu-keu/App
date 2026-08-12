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
String _topicParticle(String word) {
  if (word.isEmpty) return '는';
  final code = word.codeUnitAt(word.length - 1);
  // 한글 음절이 아니면(영문·숫자) 받침을 알 수 없다. 흔한 쪽으로 둔다.
  if (code < 0xAC00 || code > 0xD7A3) return '는';
  return (code - 0xAC00) % 28 == 0 ? '는' : '은';
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
