import '../api/mukbang_api.dart';
import '../models/combo.dart';
import '../models/order.dart';

/// 결제(주문) 데이터 소스. `docs/api-spec.md` 3·4·5번이다.
///
/// 명세에 주문 목록이 두 벌 있다 — `GET v1/orders` (checkoutId · restaurantNames)
/// 와 `GET v1/users/me/orders` (orderId · storeName 단일). **다중 매장을 담는 건
/// 앞쪽뿐**이라 앱은 `GET v1/orders` 를 쓴다 (확인 필요 항목에 남겨 뒀다).
abstract class OrderRepository {
  /// 최신 결제가 먼저 온다.
  Future<OrderPage> list({String? cursor, int size = 20});

  /// 결제 내역 상세. 없으면 null.
  Future<OrderDetail?> detail(int checkoutId);

  /// 장바구니를 통째로 보낸다. 가게가 여러 곳이어도 요청은 한 번이다.
  Future<OrderReceipt> create(Cart cart);

  /// 족보 작성을 마친 결제를 표시한다.
  ///
  /// `GET v1/orders` 응답에 `isPostedToJokbo` 가 없다 (`v1/users/me/orders` 에만
  /// 있다). 그래서 서버에 물어볼 수 없고, 이번 세션 동안만 앱이 기억한다.
  Future<void> markPosted(int checkoutId);

  /// 이 결제로 이미 족보를 썼는지. 서버가 알려주지 않아 앱이 기억한 값이다.
  bool isPostedToJokbo(int checkoutId);
}

class ApiOrderRepository implements OrderRepository {
  ApiOrderRepository(this._api);

  final MukbangApi _api;

  /// 서버가 안 주는 값을 앱이 세션 동안만 들고 있는다.
  final Set<int> _posted = {};

  @override
  Future<OrderPage> list({String? cursor, int size = 20}) =>
      _api.orders(cursor: cursor, size: size);

  @override
  Future<OrderDetail?> detail(int checkoutId) => _api.orderDetail(checkoutId);

  @override
  Future<OrderReceipt> create(Cart cart) => _api.createOrder(cart);

  @override
  Future<void> markPosted(int checkoutId) async => _posted.add(checkoutId);

  @override
  bool isPostedToJokbo(int checkoutId) => _posted.contains(checkoutId);
}

/// 백엔드가 없는 동안 쓰는 더미.
///
/// 첫 카드는 **가게 두 곳(엽떡 + 교촌)** 이다. 명세 예시와 같은 모양이고,
/// 다중 매장 묶음 결제가 화면에서 어떻게 보이는지 서버 없이 확인할 수 있다.
class MockOrderRepository implements OrderRepository {
  MockOrderRepository({this.delay = const Duration(milliseconds: 300)});

  final Duration delay;

  final Set<int> _posted = {};

  /// 결제한 것을 목록 맨 앞에 얹는다. 결제 → 내역 확인 흐름을 시연할 수 있다.
  final List<OrderDetail> _created = [];

  Future<void> get _wait =>
      delay == Duration.zero ? Future<void>.value() : Future<void>.delayed(delay);

  List<OrderDetail> get _all => [..._created, ..._samples];

  @override
  Future<OrderPage> list({String? cursor, int size = 20}) async {
    await _wait;
    final all = _all;

    // cursor 는 "여기까지 봤다" 는 checkoutId 다. 서버 구현과 무관한 더미 규칙이다.
    final start = cursor == null
        ? 0
        : all.indexWhere((o) => '${o.checkoutId}' == cursor) + 1;
    final page = all.skip(start < 0 ? 0 : start).take(size).toList();
    final consumed = (start < 0 ? 0 : start) + page.length;

    return OrderPage(
      orders: [
        for (final detail in page)
          OrderSummary(
            checkoutId: detail.checkoutId,
            orderedAt: detail.orderedAt,
            source: detail.source,
            restaurantNames: detail.restaurantNames,
            totalPrice: detail.totalPrice,
          ),
      ],
      nextCursor:
          consumed >= all.length || page.isEmpty ? null : '${page.last.checkoutId}',
    );
  }

  @override
  Future<OrderDetail?> detail(int checkoutId) async {
    await _wait;
    for (final o in _all) {
      if (o.checkoutId == checkoutId) return o;
    }
    return null;
  }

  @override
  Future<OrderReceipt> create(Cart cart) async {
    await _wait;
    // 서버는 checkout_id 를 매긴다. 더미는 목록 맨 앞에 올 큰 수를 쓴다.
    final checkoutId = 9000 + _created.length + 1;
    _created.insert(
      0,
      OrderDetail(
        checkoutId: checkoutId,
        orderedAt: DateTime(2026, 8, 5),
        source: cart.source,
        stores: [
          for (final store in cart.stores)
            OrderStore(
              restaurantId: store.restaurantId,
              restaurantName: store.restaurant.name,
              deliveryFee: store.deliveryFee,
              items: [for (final l in store.lines) l.copy()],
              itemsTotal: store.itemsTotal,
              subtotal: store.subtotal,
            ),
        ],
        totalPrice: cart.totalPrice,
      ),
    );
    return OrderReceipt(restaurantNames: cart.restaurantNames);
  }

  @override
  Future<void> markPosted(int checkoutId) async => _posted.add(checkoutId);

  @override
  bool isPostedToJokbo(int checkoutId) => _posted.contains(checkoutId);

  /// 명세 예시와 같은 두 건. 첫 건이 가게 두 곳이다.
  static final List<OrderDetail> _samples = [
    _detail(
      checkoutId: 7002,
      orderedAt: DateTime(2026, 8, 4, 19, 22, 10),
      source: const OrderSource(
        platform: SourceKind.instagram,
        url: 'https://www.instagram.com/p/xxxxx/',
        thumbnailUrl: null,
        title: '엽떡에 교촌 말아먹기',
      ),
      stores: [
        _store(
          restaurantId: 101,
          name: '엽기떡볶이 성수점',
          deliveryFee: 2000,
          lines: [
            _line(
              menuId: 101001,
              name: '오리지널 떡볶이',
              price: 14000,
              quantity: 1,
              spice: SpiceLevel.medium,
              options: const [MenuOption(name: '분모자', price: 2000, selected: true)],
            ),
            _line(menuId: 101004, name: '주먹밥', price: 2500, quantity: 2),
          ],
        ),
        _store(
          restaurantId: 1,
          name: '교촌치킨 성수점',
          deliveryFee: 3000,
          lines: [
            _line(
              menuId: 1001,
              name: '레드콤보',
              price: 23000,
              quantity: 1,
              options: const [
                MenuOption(group: '소스 선택', name: '치즈소스', price: 1000, selected: true),
              ],
            ),
          ],
        ),
      ],
    ),
    _detail(
      checkoutId: 7001,
      orderedAt: DateTime(2026, 8, 2, 12, 10, 3),
      source: const OrderSource(
        platform: SourceKind.youtube,
        url: 'https://www.youtube.com/watch?v=yyyyy',
        thumbnailUrl: null,
        title: '신전떡볶이 순한맛 먹방',
      ),
      stores: [
        _store(
          restaurantId: 102,
          name: '신전떡볶이 성수점',
          deliveryFee: 2500,
          lines: [
            _line(
              menuId: 102001,
              name: '신전떡볶이',
              price: 10000,
              quantity: 1,
              spice: SpiceLevel.none,
            ),
          ],
        ),
      ],
    ),
  ];

  /// `totalPrice` 는 가게 소계의 합이다. 서버가 계산해 내려주는 값이라
  /// 샘플에서도 직접 적지 않고 같은 규칙으로 더한다 — 손으로 적으면 어긋난다.
  static OrderDetail _detail({
    required int checkoutId,
    required DateTime orderedAt,
    required OrderSource source,
    required List<OrderStore> stores,
  }) =>
      OrderDetail(
        checkoutId: checkoutId,
        orderedAt: orderedAt,
        source: source,
        stores: stores,
        totalPrice: stores.fold(0, (sum, s) => sum + s.subtotal),
      );

  static OrderStore _store({
    required int restaurantId,
    required String name,
    required int deliveryFee,
    required List<CartLine> lines,
  }) {
    final itemsTotal = lines.fold(0, (sum, l) => sum + l.lineTotal);
    return OrderStore(
      restaurantId: restaurantId,
      restaurantName: name,
      deliveryFee: deliveryFee,
      items: lines,
      itemsTotal: itemsTotal,
      subtotal: itemsTotal + deliveryFee,
    );
  }

  static CartLine _line({
    required int menuId,
    required String name,
    required int price,
    required int quantity,
    SpiceLevel? spice,
    List<MenuOption> options = const [],
  }) =>
      CartLine(
        menuId: menuId,
        name: name,
        menuType: MenuType.main,
        price: price,
        quantity: quantity,
        imagePath: 'assets/images/menu_rose_dakbal.png',
        spiceLevel: spice ?? SpiceLevel.none,
        spiceAdjustable: spice != null,
        selectedSpice: spice,
        options: options,
      );
}
