import 'package:flutter_test/flutter_test.dart';
import 'package:mukbang_ttaradamgi/api/mukbang_api.dart';
import 'package:mukbang_ttaradamgi/app_flow.dart';
import 'package:mukbang_ttaradamgi/models/analysis_source.dart';
import 'package:mukbang_ttaradamgi/models/combo.dart';
import 'package:mukbang_ttaradamgi/models/preference.dart';
import 'package:mukbang_ttaradamgi/repository/combo_repository.dart';
import 'package:mukbang_ttaradamgi/services/gemini_extractor.dart';
import 'package:mukbang_ttaradamgi/services/location_service.dart';

class _NoLocation implements LocationService {
  const _NoLocation();

  @override
  Future<LocationResult> current() async =>
      const LocationResult.failed(LocationFailure.denied);
}

Restaurant _store(int id, String name) => Restaurant(
      restaurantId: id,
      name: name,
      foodCategory: FoodCategory.chinese,
      area: '신사동',
      rating: 4.7,
      etaMin: 25,
      deliveryFee: 2000,
      minOrderPrice: 12000,
      distanceKm: 1.2,
    );

DishCandidate _candidate(int storeId, String storeName, int menuId, double score) =>
    DishCandidate(
      restaurant: _store(storeId, storeName),
      item: CartLine(
        menuId: menuId,
        name: '마라샹궈',
        menuType: MenuType.main,
        price: 26000,
        quantity: 1,
        spiceLevel: SpiceLevel.medium,
        spiceAdjustable: true,
        options: const [MenuOption(group: '토핑', name: '분모자', price: 2000)],
      ),
      score: score,
    );

/// 브랜드를 못 찾은 응답. `exactMatches` 가 비고 한 요리에 후보가 여러 곳이다 —
/// 사용자가 겪은 상황(탕화쿵푸 마라샹궈 · 소림마라 마라샹궈…) 그대로다.
class _DishOnlyRepository implements ComboRepository {
  @override
  Future<AnalysisResult> analyze({
    required AnalysisSource source,
    required ExtractionResult extraction,
    required String? thumbnailUrl,
    required TastePreference preference,
  }) async =>
      AnalysisResult(
        dishResults: [
          DishResult(
            dishName: '마라샹궈',
            candidates: [
              _candidate(101, '탕화쿵푸 신사점', 101001, 0.82),
              _candidate(102, '소림마라 신사점', 102001, 0.79),
              _candidate(103, '라공방 신사점', 103001, 0.77),
            ],
          ),
        ],
      );

  @override
  Future<RestaurantMenus?> menus(int restaurantId) async => null;
}

const _extraction = ExtractionResult(
  dishes: [ExtractedDish(name: '마라샹궈', foodCategory: FoodCategory.chinese)],
);

final _source = AnalysisSource.fromUrl(
  url: Uri.parse('https://www.instagram.com/p/xxxxx/'),
  rawText: '마라샹궈 먹방',
);

Future<AppFlow> analyzedFlow() async {
  final flow = AppFlow(
    repository: _DishOnlyRepository(),
    locationService: const _NoLocation(),
  );
  flow.source = _source;
  flow.extraction = _extraction;
  await flow.applyFilter(flow.preference);
  return flow;
}

void main() {
  // 피드백 2026-08-14 — 메뉴를 추가해도 조합 카드가 그대로였다.
  //
  // `AnalysisResult.combos` 는 게터라 부를 때마다 카드를 새로 만든다. 화면이 그린
  // 객체와 고치는 객체가 달라 고친 값이 다음 rebuild 에서 사라졌다.
  group('조합 카드 객체가 유지된다', () {
    test('suggestions 를 두 번 읽으면 같은 객체다', () async {
      final flow = await analyzedFlow();

      expect(flow.suggestions, isNotEmpty);
      expect(
        identical(flow.suggestions.first, flow.suggestions.first),
        isTrue,
        reason: '게터가 매번 새로 만들면 화면이 고친 값이 사라진다',
      );
    });

    test('카드 수량을 바꾸면 다시 읽어도 남아 있다', () async {
      final flow = await analyzedFlow();
      final combo = flow.suggestions.first;
      final menuId = combo.items.first.menuId;
      final before = combo.lineOf(menuId)!.quantity;

      flow.changeSuggestionQuantity(combo: combo, menuId: menuId, delta: 1);

      expect(flow.suggestions.first.lineOf(menuId)?.quantity, before + 1);
    });

    test('매장 메뉴에서 담으면 첫 화면 카드에 그 메뉴가 붙는다', () async {
      final flow = await analyzedFlow();
      final combo = flow.suggestions.first;
      final before = combo.items.length;

      // 매장 메뉴 화면을 그 가게로 열어 둔 상태를 만든다.
      await flow.openStoreMenu(combo.restaurant.restaurantId);
      flow.storeMenuRestaurant = combo.restaurant;

      flow.addMenuToCart(
        const Menu(
          menuId: 999001,
          name: '꿔바로우',
          menuType: MenuType.side,
          price: 18000,
        ),
      );

      final card = flow.suggestions.firstWhere(
        (c) => c.id == combo.restaurant.restaurantId,
      );
      expect(card.items, hasLength(before + 1));
      expect(card.items.map((i) => i.name), contains('꿔바로우'));
    });

    test('이미 있는 메뉴를 한 번 담으면 두 카드 모두 수량이 하나만 오른다', () async {
      final flow = await analyzedFlow();
      final combo = flow.suggestions.first;
      final line = combo.items.first;

      await flow.openStoreMenu(combo.restaurant.restaurantId);
      flow.storeMenuRestaurant = combo.restaurant;
      flow.addMenuToCart(
        Menu(
          menuId: line.menuId,
          name: line.name,
          menuType: line.menuType,
          price: line.price,
        ),
      );

      expect(flow.suggestions.first.lineOf(line.menuId)?.quantity, 2);
      expect(
        flow.allSuggestions.firstWhere((card) => card.id == combo.id).lineOf(line.menuId)?.quantity,
        2,
      );
    });

    test('첫 화면에서 메뉴를 지우면 다른 결과 카드에서도 빠진다', () async {
      final flow = await analyzedFlow();
      final combo = flow.suggestions.first;
      final menuId = combo.items.first.menuId;

      flow.changeSuggestionQuantity(combo: combo, menuId: menuId, delta: -1);

      expect(flow.suggestions.first.lineOf(menuId), isNull);
      expect(
        flow.allSuggestions.firstWhere((card) => card.id == combo.id).lineOf(menuId),
        isNull,
      );
    });

    test('첫 화면에서 바꾼 옵션이 다른 결과 카드에도 유지된다', () async {
      final flow = await analyzedFlow();
      final combo = flow.suggestions.first;
      final menuId = combo.items.first.menuId;
      const chosen = MenuOption(group: '토핑', name: '분모자', price: 2000);

      flow.updateSuggestionLineOptions(
        suggestion: combo,
        menuId: menuId,
        chosen: const [chosen],
        spice: SpiceLevel.hot,
      );

      for (final card in [
        flow.suggestions.first,
        flow.allSuggestions.firstWhere((item) => item.id == combo.id),
      ]) {
        final line = card.lineOf(menuId)!;
        expect(line.selectedOptions.map((option) => option.name), ['분모자']);
        expect(line.selectedSpice, SpiceLevel.hot);
      }
    });
  });

  // 피드백 2026-08-14 — 브랜드가 안 잡힌 영상은 한 요리에 카드가 여러 장 떴다.
  group('첫 화면은 요리마다 카드 한 장', () {
    test('같은 요리 후보가 셋이어도 첫 화면은 한 장이다', () async {
      final flow = await analyzedFlow();

      expect(flow.suggestions, hasLength(1));
      // 점수가 가장 높은 곳이 남는다.
      expect(flow.suggestions.first.restaurant.name, '탕화쿵푸 신사점');
    });

    test('밀려난 후보는 "다른 결과 보기" 에 그대로 있다', () async {
      final flow = await analyzedFlow();

      expect(flow.allSuggestions, hasLength(3));
      expect(
        flow.allSuggestions.map((c) => c.restaurant.name),
        containsAll(['탕화쿵푸 신사점', '소림마라 신사점', '라공방 신사점']),
      );
    });

    test('요리가 둘이면 요리마다 한 장씩 나온다', () async {
      final flow = AppFlow(
        repository: _TwoDishRepository(),
        locationService: const _NoLocation(),
      );
      flow.source = _source;
      flow.extraction = const ExtractionResult(
        dishes: [
          ExtractedDish(name: '마라샹궈', foodCategory: FoodCategory.chinese),
          ExtractedDish(name: '꿔바로우', foodCategory: FoodCategory.chinese),
        ],
      );
      await flow.applyFilter(flow.preference);

      // 요리 둘을 서로 다른 집이 덮으므로 카드는 두 장이다.
      expect(flow.suggestions, hasLength(2));
    });
  });
}

/// 요리 둘, 각 요리에 후보 둘. 한 집이 두 요리를 겹쳐 덮지는 않는다.
class _TwoDishRepository implements ComboRepository {
  @override
  Future<AnalysisResult> analyze({
    required AnalysisSource source,
    required ExtractionResult extraction,
    required String? thumbnailUrl,
    required TastePreference preference,
  }) async =>
      AnalysisResult(
        dishResults: [
          DishResult(
            dishName: '마라샹궈',
            candidates: [
              _candidate(101, '탕화쿵푸 신사점', 101001, 0.82),
              _candidate(102, '소림마라 신사점', 102001, 0.79),
            ],
          ),
          DishResult(
            dishName: '꿔바로우',
            candidates: [
              DishCandidate(
                restaurant: _store(201, '연길양꼬치 신사점'),
                item: CartLine(
                  menuId: 201001,
                  name: '꿔바로우',
                  menuType: MenuType.main,
                  price: 18000,
                  quantity: 1,
                ),
                score: 0.80,
              ),
            ],
          ),
        ],
      );

  @override
  Future<RestaurantMenus?> menus(int restaurantId) async => null;
}
