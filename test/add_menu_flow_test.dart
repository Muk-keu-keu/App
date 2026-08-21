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

const _store = Restaurant(
  restaurantId: 101,
  name: '동대문엽기떡볶이 삼성점',
  foodCategory: FoodCategory.snack,
  area: '삼성동',
  rating: 4.8,
  etaMin: 25,
  deliveryFee: 0,
  minOrderPrice: 14000,
  distanceKm: 1.1,
);

const _menu = Menu(
  menuId: 101002,
  name: '마라떡볶이',
  menuType: MenuType.main,
  price: 16000,
);

class _StoreRepository implements ComboRepository {
  @override
  Future<AnalysisResult> analyze({
    required AnalysisSource source,
    required ExtractionResult extraction,
    required String? thumbnailUrl,
    required TastePreference preference,
  }) async =>
      AnalysisResult(
        exactMatches: [
          ComboSuggestion(
            brandName: '엽기떡볶이',
            restaurant: _store,
            items: [
              CartLine(
                menuId: 101001,
                name: '로제떡볶이',
                menuType: MenuType.main,
                price: 13000,
                quantity: 1,
              ),
            ],
          ),
        ],
      );

  @override
  Future<RestaurantMenus?> menus(int restaurantId) async =>
      const RestaurantMenus(restaurant: _store, menus: [_menu]);
}

/// 피드백 2026-08-21 — 메뉴를 담으면 가게 메뉴판으로 되돌아왔다. 담은 것이 어디로
/// 갔는지 보이지 않고, 결제까지 가려면 뒤로 두 번 나가야 했다.
void main() {
  Future<AppFlow> flowOnStoreMenu() async {
    final flow = AppFlow(
      repository: _StoreRepository(),
      locationService: const _NoLocation(),
    );
    flow.source = AnalysisSource.fromUrl(
      url: Uri.parse('https://www.instagram.com/p/xxxxx/'),
      rawText: '엽떡 먹방',
    );
    flow.extraction = const ExtractionResult(
      dishes: [ExtractedDish(name: '로제떡볶이', brandName: '엽기떡볶이')],
    );
    await flow.applyFilter(flow.preference);

    // 조합 카드의 "메뉴 추가하기" → 가게 메뉴판 → 메뉴 상세.
    await flow.openStoreMenu(_store.restaurantId);
    expect(flow.stage, AppStage.storeMenu);
    flow.openMenuDetail(_menu);
    expect(flow.stage, AppStage.menuDetail);
    return flow;
  }

  test('상세에서 추가하면 메뉴판이 아니라 장바구니로 간다', () async {
    final flow = await flowOnStoreMenu();

    flow.addMenuToCart(_menu, thenOpenCart: true);

    expect(flow.stage, AppStage.cart);
    expect(flow.stage, isNot(AppStage.storeMenu));
    // 상세 화면은 닫혔다 — 장바구니 위에 남아 있으면 안 된다.
    expect(flow.menuDetail, isNull);
  });

  test('담은 메뉴가 장바구니에 들어있다', () async {
    final flow = await flowOnStoreMenu();

    flow.addMenuToCart(_menu, thenOpenCart: true);

    final store = flow.cart.storeOf(_store.restaurantId)!;
    expect(store.lineOf(_menu.menuId)?.name, '마라떡볶이');
  });

  test('상세의 뒤로가기는 메뉴판으로 돌아간다', () async {
    final flow = await flowOnStoreMenu();

    // 담지 않고 나가는 길은 그대로다.
    flow.closeMenuDetail();

    expect(flow.stage, AppStage.storeMenu);
    expect(flow.cart.isEmpty, isTrue);
  });
}
