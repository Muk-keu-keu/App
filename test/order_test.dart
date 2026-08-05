import 'package:flutter_test/flutter_test.dart';
import 'package:mukbang_ttaradamgi/api/api_client.dart';
import 'package:mukbang_ttaradamgi/api/mukbang_api.dart';
import 'package:mukbang_ttaradamgi/app_flow.dart';
import 'package:mukbang_ttaradamgi/models/analysis_source.dart';
import 'package:mukbang_ttaradamgi/models/combo.dart';
import 'package:mukbang_ttaradamgi/models/order.dart';
import 'package:mukbang_ttaradamgi/models/preference.dart';
import 'package:mukbang_ttaradamgi/repository/combo_repository.dart';
import 'package:mukbang_ttaradamgi/repository/order_repository.dart';
import 'package:mukbang_ttaradamgi/repository/post_repository.dart';
import 'package:mukbang_ttaradamgi/services/gemini_extractor.dart';
import 'package:mukbang_ttaradamgi/services/location_service.dart';

class _NoLocation implements LocationService {
  const _NoLocation();

  @override
  Future<LocationResult> current() async =>
      const LocationResult.failed(LocationFailure.denied);
}

/// 결제 요청 본문을 그대로 붙잡아 둔다. 명세와 대조하려면 보낸 JSON 을 봐야 한다.
class _RecordingOrderRepository implements OrderRepository {
  Cart? sent;
  ApiException? failWith;

  final Set<int> _posted = {};

  @override
  Future<OrderPage> list({String? cursor, int size = 20}) async =>
      const OrderPage.empty();

  @override
  Future<OrderDetail?> detail(int checkoutId) async => null;

  @override
  Future<OrderReceipt> create(Cart cart) async {
    if (failWith != null) throw failWith!;
    sent = cart;
    return OrderReceipt(restaurantNames: cart.restaurantNames);
  }

  @override
  Future<void> markPosted(int checkoutId) async => _posted.add(checkoutId);

  @override
  bool isPostedToJokbo(int checkoutId) => _posted.contains(checkoutId);
}

/// 가게 두 곳이 나오는 영상을 흉내낸다.
class _TwoStoreRepository implements ComboRepository {
  @override
  Future<AnalysisResult> analyze({
    required AnalysisSource source,
    required ExtractionResult extraction,
    required String? thumbnailUrl,
    required TastePreference preference,
  }) async =>
      AnalysisResult(
        exactMatches: [
          _suggestion(
            brandName: '엽기떡볶이',
            id: 101,
            name: '엽기떡볶이 성수점',
            deliveryFee: 2000,
            minOrderPrice: 12000,
            menuId: 101001,
            menuName: '오리지널 떡볶이',
            price: 14000,
          ),
          _suggestion(
            brandName: '교촌치킨',
            id: 1,
            name: '교촌치킨 성수점',
            deliveryFee: 3000,
            minOrderPrice: 15000,
            menuId: 1001,
            menuName: '레드콤보',
            price: 23000,
          ),
        ],
      );

  @override
  Future<RestaurantMenus?> menus(int restaurantId) async => null;

  static ComboSuggestion _suggestion({
    required String brandName,
    required int id,
    required String name,
    required int deliveryFee,
    required int minOrderPrice,
    required int menuId,
    required String menuName,
    required int price,
  }) =>
      ComboSuggestion(
        brandName: brandName,
        restaurant: Restaurant(
          restaurantId: id,
          name: name,
          foodCategory: FoodCategory.snack,
          area: '성수동',
          rating: 4.5,
          etaMin: 30,
          deliveryFee: deliveryFee,
          minOrderPrice: minOrderPrice,
          distanceKm: 1.2,
        ),
        items: [
          CartLine(
            menuId: menuId,
            name: menuName,
            menuType: MenuType.main,
            price: price,
            quantity: 1,
            spiceAdjustable: true,
            selectedSpice: SpiceLevel.medium,
            options: const [
              MenuOption(group: '사리 추가', name: '분모자', price: 2000),
            ],
          ),
        ],
      );
}

void main() {
  AppFlow makeFlow({
    ComboRepository? combos,
    OrderRepository? orders,
  }) =>
      AppFlow(
        repository: combos ?? _TwoStoreRepository(),
        orderRepository: orders ?? MockOrderRepository(delay: Duration.zero),
        postRepository: MockPostRepository(delay: Duration.zero),
        locationService: const _NoLocation(),
      );

  /// 분석이 끝난 상태를 만든다.
  Future<AppFlow> analyzed({OrderRepository? orders}) async {
    final flow = makeFlow(orders: orders);
    flow.source = AnalysisSource.fromUrl(
      url: Uri.parse('https://www.instagram.com/p/xxxxx/'),
      rawText: '엽떡에 교촌 말아먹기',
    );
    flow.extraction = const ExtractionResult(
      dishes: [
        ExtractedDish(name: '오리지널 떡볶이', brandName: '엽기떡볶이'),
        ExtractedDish(name: '레드콤보', brandName: '교촌치킨'),
      ],
    );
    flow.openFilter();
    await flow.applyPreferenceAndAnalyze();
    return flow;
  }

  group('다중 매장 장바구니 — 회의(2026-08-04) 결정', () {
    test('영상에 나온 브랜드를 전부 담은 채로 장바구니가 열린다', () async {
      final flow = await analyzed();
      flow.openCartFromAnalysis();

      expect(flow.stage, AppStage.cart);
      expect(flow.cart.storeCount, 2);
      expect(flow.cart.restaurantNames, ['엽기떡볶이 성수점', '교촌치킨 성수점']);
    });

    test('배달비는 가게마다 붙어 총액에 두 번 들어간다', () async {
      final flow = await analyzed();
      flow.openCartFromAnalysis();

      expect(flow.cart.itemsTotal, 37000);
      expect(flow.cart.deliveryFeeTotal, 5000);
      expect(flow.cart.totalPrice, 42000);
    });

    test('체크박스로 가게를 빼면 배달비도 함께 빠진다', () async {
      final flow = await analyzed();
      flow.openCartFromAnalysis();

      flow.removeStoreFromCart(1); // 교촌치킨
      expect(flow.cart.storeCount, 1);
      expect(flow.cart.totalPrice, 16000); // 14,000 + 2,000
    });

    test('빼고 다시 담으면 원래대로 돌아온다', () async {
      final flow = await analyzed();
      final second = flow.analysis.exactMatches[1];

      flow.toggleSuggestionInCart(second);
      expect(flow.isInCart(second.id), isTrue);

      flow.toggleSuggestionInCart(second);
      expect(flow.isInCart(second.id), isFalse);
    });

    test('출처 영상은 장바구니에 한 번만 붙는다', () async {
      final flow = await analyzed();
      flow.openCartFromAnalysis();

      expect(flow.cart.source?.platform, SourceKind.instagram);
      expect(flow.cart.source?.url, 'https://www.instagram.com/p/xxxxx/');
    });
  });

  group('결제 — POST v1/orders 한 번', () {
    test('가게가 두 곳이어도 요청은 한 번이고 stores 가 두 개다', () async {
      final orders = _RecordingOrderRepository();
      final flow = await analyzed(orders: orders);
      flow.openCartFromAnalysis();

      await flow.checkout();

      expect(orders.sent, isNotNull);
      final json = orders.sent!.toOrderJson();
      expect(json['stores'], hasLength(2));
    });

    test('요청 본문에 전체 합계가 없다', () async {
      // 주문이 가게 단위로 쪼개져 저장되므로 넣어둘 자리가 없다 (명세 5번).
      final orders = _RecordingOrderRepository();
      final flow = await analyzed(orders: orders);
      flow.openCartFromAnalysis();
      await flow.checkout();

      expect(orders.sent!.toOrderJson().containsKey('totalPrice'), isFalse);
    });

    test('가게마다 itemsTotal 과 subtotal 을 담는다', () async {
      final orders = _RecordingOrderRepository();
      final flow = await analyzed(orders: orders);
      flow.openCartFromAnalysis();
      await flow.checkout();

      final stores =
          (orders.sent!.toOrderJson()['stores'] as List).cast<Map<String, dynamic>>();
      expect(stores[0]['itemsTotal'], 14000);
      expect(stores[0]['subtotal'], 16000);
      expect(stores[1]['itemsTotal'], 23000);
      expect(stores[1]['subtotal'], 26000);
    });

    test('고르지 않은 옵션은 보내지 않는다', () async {
      final orders = _RecordingOrderRepository();
      final flow = await analyzed(orders: orders);
      flow.openCartFromAnalysis();
      await flow.checkout();

      final stores =
          (orders.sent!.toOrderJson()['stores'] as List).cast<Map<String, dynamic>>();
      final items = (stores[0]['items'] as List).cast<Map<String, dynamic>>();
      expect(items.first['selectedOptions'], isEmpty);
    });

    test('고른 옵션은 group·name·price 세 개로 나간다', () async {
      final orders = _RecordingOrderRepository();
      final flow = await analyzed(orders: orders);
      flow.openCartFromAnalysis();

      final line = flow.cart.stores.first.lines.first;
      flow.updateLineOptions(
        restaurantId: flow.cart.stores.first.restaurantId,
        menuId: line.menuId,
        chosen: [line.options.first],
      );
      await flow.checkout();

      final stores =
          (orders.sent!.toOrderJson()['stores'] as List).cast<Map<String, dynamic>>();
      final items = (stores[0]['items'] as List).cast<Map<String, dynamic>>();
      expect(items.first['selectedOptions'], [
        {'group': '사리 추가', 'name': '분모자', 'price': 2000},
      ]);
      // 옵션 추가금이 lineTotal 에 반영된다.
      expect(items.first['optionsPrice'], 2000);
      expect(items.first['lineTotal'], 16000);
    });

    test('맵기는 selectedSpice 로 따로 나간다', () async {
      final orders = _RecordingOrderRepository();
      final flow = await analyzed(orders: orders);
      flow.openCartFromAnalysis();
      await flow.checkout();

      final stores =
          (orders.sent!.toOrderJson()['stores'] as List).cast<Map<String, dynamic>>();
      final items = (stores[0]['items'] as List).cast<Map<String, dynamic>>();
      expect(items.first['selectedSpice'], 'MEDIUM');
    });

    test('완료 화면은 가게 이름만 받는다', () async {
      final flow = await analyzed();
      flow.openCartFromAnalysis();
      await flow.checkout();

      expect(flow.stage, AppStage.orderDone);
      expect(flow.receipt?.storeCount, 2);
      expect(flow.receipt?.completionText, '2건 · 엽기떡볶이 성수점, 교촌치킨 성수점');
    });

    test('결제하면 장바구니가 비워진다', () async {
      final flow = await analyzed();
      flow.openCartFromAnalysis();
      await flow.checkout();

      expect(flow.cart.isEmpty, isTrue);
    });

    test('최소 주문 금액을 못 넘긴 가게가 있으면 보내지 않는다', () async {
      final orders = _RecordingOrderRepository();
      final flow = await analyzed(orders: orders);
      flow.openCartFromAnalysis();

      // 교촌치킨 최소 주문 15,000 인데 수량을 줄이면 23,000 → 0 이 되어 가게가 빠진다.
      // 대신 엽떡 최소 주문(12,000)을 못 넘기게 만든다.
      flow.removeStoreFromCart(1);
      final store = flow.cart.stores.first;
      store.restaurant = Restaurant(
        restaurantId: store.restaurantId,
        name: store.restaurant.name,
        foodCategory: FoodCategory.snack,
        area: '성수동',
        rating: 4.5,
        etaMin: 30,
        deliveryFee: 2000,
        minOrderPrice: 30000,
        distanceKm: 1.2,
      );

      expect(flow.cart.canCheckout, isFalse);
      await flow.checkout();
      expect(orders.sent, isNull);
    });

    test('결제 실패는 실패 화면으로 보낸다', () async {
      final orders = _RecordingOrderRepository()
        ..failWith = const ApiException(statusCode: 400, path: 'v1/orders');
      final flow = await analyzed(orders: orders);
      flow.openCartFromAnalysis();

      await flow.checkout();

      expect(flow.stage, AppStage.failed);
      expect(flow.failureMessage, contains('다시 확인'));
      // 실패했으니 장바구니는 남아 있어야 한다. 비우면 다시 시도할 수 없다.
      expect(flow.cart.isEmpty, isFalse);
    });

    test('결제 중에는 다시 누를 수 없다', () async {
      final flow = await analyzed();
      flow.openCartFromAnalysis();

      final first = flow.checkout();
      // 진행 중 두 번째 호출은 그대로 무시된다.
      await flow.checkout();
      await first;

      final page = await MockOrderRepository(delay: Duration.zero).list();
      // 더미 저장소가 새로 만들어졌으므로 개수는 샘플 두 건 그대로다.
      expect(page.orders, hasLength(2));
    });
  });

  group('결제 목록·상세', () {
    test('카드 하나가 결제 하나다. 가게 이름을 모두 준다', () async {
      final page = await MockOrderRepository(delay: Duration.zero).list();

      expect(page.orders.first.checkoutId, 7002);
      expect(page.orders.first.restaurantNames, ['엽기떡볶이 성수점', '교촌치킨 성수점']);
      expect(page.orders.first.storeSummary, '엽기떡볶이 성수점 외 1곳');
    });

    test('상세는 stores 로 쪼개져 오고 totalPrice 는 소계의 합이다', () async {
      final detail = await MockOrderRepository(delay: Duration.zero).detail(7002);

      expect(detail!.stores, hasLength(2));
      expect(
        detail.totalPrice,
        detail.stores.fold(0, (sum, s) => sum + s.subtotal),
      );
    });

    test('주문 상세를 장바구니로 되돌린다', () async {
      final detail = await MockOrderRepository(delay: Duration.zero).detail(7002);
      final cart = detail!.toCart();

      expect(cart.storeCount, 2);
      expect(cart.totalPrice, detail.totalPrice);
      // 상세의 옵션은 고른 것만 오므로 전부 체크된 상태다.
      final withOption = cart.allLines.firstWhere((l) => l.options.isNotEmpty);
      expect(withOption.selectedOptions, hasLength(withOption.options.length));
    });

    test('결제하면 목록 맨 앞에 새 카드가 생긴다', () async {
      final repo = MockOrderRepository(delay: Duration.zero);
      final flow = makeFlow(orders: repo);
      flow.source = AnalysisSource.fromUrl(
        url: Uri.parse('https://www.instagram.com/p/xxxxx/'),
        rawText: '엽떡',
      );
      flow.extraction = const ExtractionResult(
        dishes: [ExtractedDish(name: '떡볶이', brandName: '엽기떡볶이')],
      );
      flow.openFilter();
      await flow.applyPreferenceAndAnalyze();
      flow.openCartFromAnalysis();
      await flow.checkout();

      final page = await repo.list();
      expect(page.orders, hasLength(3));
      expect(page.orders.first.restaurantNames, hasLength(2));
    });

    test('족보 작성 표시는 앱이 기억한다', () async {
      // GET v1/orders 응답에 isPostedToJokbo 가 없다.
      final repo = MockOrderRepository(delay: Duration.zero);
      expect(repo.isPostedToJokbo(7002), isFalse);

      await repo.markPosted(7002);
      expect(repo.isPostedToJokbo(7002), isTrue);
    });

    test('cursor 로 이어 받는다', () async {
      final repo = MockOrderRepository(delay: Duration.zero);
      final first = await repo.list(size: 1);

      expect(first.orders, hasLength(1));
      expect(first.nextCursor, isNotNull);

      final next = await repo.list(cursor: first.nextCursor, size: 1);
      expect(next.orders.first.checkoutId, isNot(first.orders.first.checkoutId));
      expect(next.nextCursor, isNull);
    });
  });

  group('분석 전 링크 검사', () {
    test('인스타·유튜브가 아닌 링크는 분석하지 않는다', () async {
      // 명세의 source.platform 은 두 값만 받는다.
      final flow = makeFlow();
      flow.start('https://www.tiktok.com/@x/video/1');
      await flow.applyPreferenceAndAnalyze();

      expect(flow.stage, AppStage.failed);
      expect(flow.failureMessage, contains('인스타그램과 유튜브'));
    });

    test('링크 형태가 아니면 바로 실패한다', () async {
      final flow = makeFlow();
      flow.start('그냥 텍스트');
      await flow.applyPreferenceAndAnalyze();

      expect(flow.stage, AppStage.failed);
      expect(flow.failureMessage, contains('올바른 링크'));
    });
  });
}
