import 'package:flutter_test/flutter_test.dart';
import 'package:mukbang_ttaradamgi/api/mukbang_api.dart';
import 'package:mukbang_ttaradamgi/app_flow.dart';
import 'package:mukbang_ttaradamgi/models/analysis_source.dart';
import 'package:mukbang_ttaradamgi/models/combo.dart';
import 'package:mukbang_ttaradamgi/models/post.dart';
import 'package:mukbang_ttaradamgi/models/preference.dart';
import 'package:mukbang_ttaradamgi/repository/combo_repository.dart';
import 'package:mukbang_ttaradamgi/repository/post_repository.dart';
import 'package:mukbang_ttaradamgi/services/gemini_extractor.dart';
import 'package:mukbang_ttaradamgi/services/location_service.dart';

class _NoLocation implements LocationService {
  const _NoLocation();

  @override
  Future<LocationResult> current() async =>
      const LocationResult.failed(LocationFailure.denied);
}

/// 어떤 매장 id 를 물어도 **엉뚱한 가게**를 돌려준다.
///
/// 실서버가 그랬다. 번들 시드 글의 매장 id(201)가 실서버에서는 투썸플레이스
/// 역삼점이라, 두찜 로제닭발 글이 "나도 주문하기" 에서 투썸으로 바뀌었다.
class _StrangerMenus implements ComboRepository {
  int menusCalls = 0;

  @override
  Future<AnalysisResult> analyze({
    required AnalysisSource source,
    required ExtractionResult extraction,
    required String? thumbnailUrl,
    required TastePreference preference,
  }) async =>
      const AnalysisResult.empty();

  @override
  Future<RestaurantMenus?> menus(int restaurantId) async {
    menusCalls++;
    return RestaurantMenus(
      restaurant: Restaurant(
        restaurantId: restaurantId,
        name: '투썸플레이스 역삼점',
        foodCategory: FoodCategory.cafeDessert,
        area: '역삼동',
        rating: 4.7,
        etaMin: 25,
        deliveryFee: 1000,
        minOrderPrice: 10000,
        distanceKm: 0.4,
      ),
      menus: const [],
    );
  }
}

void main() {
  // 피드백 2026-08-21 — 두찜 로제닭발 글에서 "나도 주문하기" 를 누르면 가게가
  // 투썸플레이스 역삼점으로 나왔다. 영상·메뉴는 두찜인데 가게만 남의 것이었다.
  test('온전한 매장 정보를 가진 글은 매장을 다시 받아오지 않는다', () async {
    final posts = MockPostRepository();
    final combos = _StrangerMenus();
    final flow = AppFlow(
      repository: combos,
      postRepository: posts,
      locationService: const _NoLocation(),
    );

    final listed = await posts.list(sort: PostSort.latest, size: 50);
    final dujjim = listed.items.firstWhere((p) => p.title.contains('두찜'));
    await flow.openPost(dujjim.id);
    expect(flow.selectedPost, isNotNull);

    await flow.startReorder();

    final store = flow.cart.stores.single;
    expect(store.restaurant.name, contains('두찜'));
    expect(store.restaurant.name, isNot('투썸플레이스 역삼점'));
    // 금액도 시드 값 그대로다.
    expect(store.restaurant.minOrderPrice, 14000);
    expect(store.restaurant.deliveryFee, 3000);
    expect(combos.menusCalls, 0, reason: '채울 것이 없으면 부르지 않는다');
  });

  test('id·이름·배달비만 아는 매장은 채워야 하는 것으로 본다', () {
    // 실제 게시글·주문 상세가 주는 모양.
    final partial = Restaurant.partial(
      restaurantId: 201,
      name: '이름만 아는 가게',
      deliveryFee: 3000,
    );
    expect(partial.isPartial, isTrue);

    const full = Restaurant(
      restaurantId: 201,
      name: '두찜-잠실새내점',
      foodCategory: FoodCategory.korean,
      area: '잠실동',
      rating: 4.2,
      etaMin: 40,
      deliveryFee: 3000,
      minOrderPrice: 14000,
      distanceKm: 3.2,
    );
    expect(full.isPartial, isFalse);
  });
}
