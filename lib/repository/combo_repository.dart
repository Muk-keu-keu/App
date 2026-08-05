import '../api/api_client.dart';
import '../api/mukbang_api.dart';
import '../models/analysis_source.dart';
import '../models/combo.dart';
import '../models/preference.dart';
import '../services/gemini_extractor.dart';
import 'combo_builder.dart';

/// 분석·메뉴 데이터 소스.
///
/// 구현이 둘이다.
/// - [ApiComboRepository] — 실제 서버. `.env` 의 `API_BASE_URL` 이 있을 때 쓴다.
/// - [MockComboRepository] — 더미. 백엔드가 없어도 시연이 돌아가게 한다.
///
/// 화면과 [AppFlow] 는 이 계약만 본다. 서버가 올라오면 갈아끼우는 것 말고 할 일이 없다.
abstract class ComboRepository {
  /// `POST v1/analyses`.
  ///
  /// 결과가 0개여도 예외가 아니다 — 명세가 200 + 빈 배열을 주고, 빈 화면은 호출한
  /// 쪽이 다룬다.
  Future<AnalysisResult> analyze({
    required AnalysisSource source,
    required ExtractionResult extraction,
    required String? thumbnailUrl,
    required TastePreference preference,
  });

  /// `GET v1/restaurants/{restaurantId}/menus` — "메뉴 수정하기" 가 쓴다.
  Future<RestaurantMenus?> menus(int restaurantId);
}

class ApiComboRepository implements ComboRepository {
  const ApiComboRepository(this._api);

  final MukbangApi _api;

  @override
  Future<AnalysisResult> analyze({
    required AnalysisSource source,
    required ExtractionResult extraction,
    required String? thumbnailUrl,
    required TastePreference preference,
  }) =>
      // thumbnailUrl 은 서버로 보내지 않는다. 명세의 `source` 는 platform·url·rawText
      // 셋뿐이고, 썸네일은 주문할 때(`POST v1/orders`) 실어 보낸다.
      _api.analyze(source: source, extraction: extraction, preference: preference);

  @override
  Future<RestaurantMenus?> menus(int restaurantId) async {
    try {
      return await _api.restaurantMenus(restaurantId);
    } on ApiException catch (e) {
      // 404 는 그 restaurantId 가 없을 때만 온다. 화면은 "메뉴를 불러올 수 없어요"
      // 대신 빈 목록으로 두는 게 낫다 — 조합 카드 자체는 이미 보이고 있다.
      if (e.isNotFound) return null;
      rethrow;
    }
  }
}

/// 백엔드가 없는 동안 쓰는 더미. [ComboBuilder] 가 만든 값을 돌려준다.
class MockComboRepository implements ComboRepository {
  const MockComboRepository({this.delay = const Duration(milliseconds: 900)});

  /// 로딩 화면이 보이도록 흉내내는 지연. 테스트는 0으로 준다.
  final Duration delay;

  @override
  Future<AnalysisResult> analyze({
    required AnalysisSource source,
    required ExtractionResult extraction,
    required String? thumbnailUrl,
    required TastePreference preference,
  }) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);

    final built = ComboBuilder.build(
      extraction: extraction,
      thumbnailUrl: thumbnailUrl,
      preference: preference,
    );

    // 서버는 배달시간 필터를 검색 단계에서 건다. 더미는 만든 뒤에 걸러야 해서,
    // 조건에 맞는 게 하나도 없으면 필터를 포기하고 전체를 준다 —
    // 시연 중에 "조건에 맞는 조합이 없어요" 만 보이는 편이 더 나쁘다.
    final within = [
      for (final c in built.combos)
        if (c.restaurant.etaMin <= preference.maxDeliveryMinutes) c,
    ];

    return AnalysisResult(
      exactMatches: built.exactMatches,
      combos: within.isEmpty ? built.combos : within,
    );
  }

  @override
  Future<RestaurantMenus?> menus(int restaurantId) async {
    final restaurant = ComboBuilder.restaurantFor(restaurantId);
    if (restaurant == null) return null;
    return RestaurantMenus(
      restaurant: restaurant,
      menus: ComboBuilder.menuFor(restaurantId),
    );
  }
}
