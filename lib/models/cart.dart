/// 장바구니. **여러 매장을 한 번에 결제하는 묶음**이다.
///
/// 회의(2026-08-04) 결정 두 가지가 이 파일에 들어 있다.
///
/// 1. 한 영상에 가게가 여러 곳(떡볶이+핫도그+공차) 나오면 프론트가 여러 매장의
///    메뉴를 골라 **한 번에 결제**한다. 그래서 [Cart] 가 [StoreCart] 목록을 갖는다.
/// 2. 백엔드는 장바구니를 저장하지 않는다. 프론트가 상태를 들고 있다가 주문 시점에
///    통째로 `POST v1/orders` 한다. 그래서 이 객체가 곧 요청 본문이다.
///
/// 금액은 가게 단위로 끊긴다 — 배달비도 최소 주문 금액도 가게마다 따로다.
/// 전체 합계는 서버로 보내지 않는다. 주문이 가게 단위로 쪼개져 저장되기 때문이다.
library;

import 'menu.dart';
import 'order.dart';
import 'restaurant.dart';

/// 한 가게에 담은 것. 명세 `stores[]` 의 원소다.
class StoreCart {
  StoreCart({required this.restaurant, required this.lines});

  /// 결제 상세로 되돌린 장바구니는 매장 정보가 세 개뿐이다. GET menus 로 온전한
  /// 값을 받아 갈아끼울 수 있어야 해서 final 이 아니다.
  Restaurant restaurant;

  List<CartLine> lines;

  int get restaurantId => restaurant.restaurantId;
  int get deliveryFee => restaurant.deliveryFee;

  /// 그 가게 메뉴 + 옵션 합.
  int get itemsTotal => lines.fold(0, (sum, line) => sum + line.lineTotal);

  /// 그 가게의 결제액. 배달비는 가게마다 한 번 부과된다.
  int get subtotal => itemsTotal + deliveryFee;

  bool get isEmpty => lines.isEmpty;

  /// 최소 주문 금액을 넘겼는지. 배달비는 빼고 음식값으로만 판정한다.
  bool get meetsMinimum => itemsTotal >= restaurant.minOrderPrice;

  /// 최소 주문까지 남은 금액. 넘겼으면 0.
  int get shortfall => restaurant.shortfallFrom(itemsTotal);

  /// "3,000원 더 담아주세요" 안내. 넘겼으면 null.
  String? get shortfallText =>
      meetsMinimum ? null : '${wonFormat(shortfall)}원 더 담아주세요';

  CartLine? lineOf(int menuId) {
    for (final line in lines) {
      if (line.menuId == menuId) return line;
    }
    return null;
  }

  /// 같은 메뉴를 다시 담으면 수량만 올린다. 요기요와 같은 동작이다.
  void add(Menu menu) {
    final existing = lineOf(menu.menuId);
    if (existing != null) {
      existing.quantity += 1;
      return;
    }
    lines = [...lines, menu.toCartLine()];
  }

  /// 수량 변경. 0 이하가 되면 그 줄을 뺀다.
  void changeQuantity({required int menuId, required int delta}) {
    final i = lines.indexWhere((l) => l.menuId == menuId);
    if (i < 0) return;
    final next = lines[i].quantity + delta;
    if (next <= 0) {
      lines = [...lines]..removeAt(i);
    } else {
      lines[i].quantity = next;
    }
  }

  StoreCart copy() =>
      StoreCart(restaurant: restaurant, lines: [for (final l in lines) l.copy()]);

  /// `POST v1/orders` 의 `stores[]` 원소.
  Map<String, dynamic> toOrderJson() => {
        'restaurantId': restaurantId,
        'restaurantName': restaurant.name,
        'deliveryFee': deliveryFee,
        'items': [for (final line in lines) line.toOrderJson()],
        'itemsTotal': itemsTotal,
        'subtotal': subtotal,
      };
}

/// 결제 한 건. 영상 하나에서 고른 가게 전부를 담는다.
class Cart {
  Cart({this.source, List<StoreCart>? stores}) : stores = stores ?? [];

  /// 출처 영상. 주문 요청에 그대로 실린다. 다시 주문처럼 영상을 모르는 경우 null.
  OrderSource? source;

  List<StoreCart> stores;

  bool get isEmpty => stores.every((s) => s.isEmpty);
  bool get isNotEmpty => !isEmpty;

  /// 가게 수. 완료 화면의 "2건" 이 이 값이다.
  int get storeCount => stores.length;

  List<String> get restaurantNames => [for (final s in stores) s.restaurant.name];

  /// 음식값 합. 배달비는 빠져 있다.
  int get itemsTotal => stores.fold(0, (sum, s) => sum + s.itemsTotal);

  /// 배달비 합. 가게마다 한 번씩이라 가게 수만큼 붙는다.
  int get deliveryFeeTotal => stores.fold(0, (sum, s) => sum + s.deliveryFee);

  /// 결제 예상액. 서버로 보내지 않고 화면에만 쓴다 — 명세가 전체 합계를 받지 않는다.
  int get totalPrice => stores.fold(0, (sum, s) => sum + s.subtotal);

  List<CartLine> get allLines => [for (final s in stores) ...s.lines];

  /// 최소 주문 금액을 못 넘긴 가게들. 하나라도 있으면 결제 버튼을 막는다.
  List<StoreCart> get storesBelowMinimum =>
      [for (final s in stores) if (!s.meetsMinimum) s];

  /// 결제 가능한지. 빈 장바구니와 최소 주문 미달을 함께 본다.
  bool get canCheckout => isNotEmpty && storesBelowMinimum.isEmpty;

  StoreCart? storeOf(int restaurantId) {
    for (final s in stores) {
      if (s.restaurantId == restaurantId) return s;
    }
    return null;
  }

  /// 그 가게 칸을 만들어서라도 돌려준다. 메뉴를 담을 때 쓴다.
  StoreCart ensureStore(Restaurant restaurant) {
    final existing = storeOf(restaurant.restaurantId);
    if (existing != null) return existing;
    final created = StoreCart(restaurant: restaurant, lines: []);
    stores = [...stores, created];
    return created;
  }

  /// 빈 가게 칸을 정리한다. 마지막 메뉴를 뺀 가게가 이름만 남아 있으면
  /// 배달비가 총액에 계속 붙어 금액이 틀린다.
  void pruneEmptyStores() {
    stores = [for (final s in stores) if (s.isNotEmptyStore) s];
  }

  Cart copy() => Cart(source: source, stores: [for (final s in stores) s.copy()]);

  /// `POST v1/orders` 의 본문 전체.
  ///
  /// 가게가 여러 곳이어도 요청은 한 번이다. 전체 합계(`totalPrice`)는 담지 않는다.
  Map<String, dynamic> toOrderJson() => {
        if (source != null) 'source': source!.toJson(),
        'stores': [for (final s in stores) s.toOrderJson()],
      };

  /// 주문 상세를 그대로 장바구니로 되돌린다 ("다시 주문").
  ///
  /// 주문 상세의 매장 정보는 세 개뿐이라 [Restaurant.partial] 이 된다.
  /// 평점·최소주문 같은 값이 0이므로, 정확한 화면이 필요하면 호출한 쪽이
  /// GET menus 로 매장을 다시 받아 [StoreCart.restaurant] 를 갈아끼운다.
  factory Cart.fromOrderDetail(OrderDetail detail) => Cart(
        source: detail.source,
        stores: [
          for (final store in detail.stores)
            StoreCart(
              restaurant: Restaurant.partial(
                restaurantId: store.restaurantId,
                name: store.restaurantName,
                deliveryFee: store.deliveryFee,
              ),
              lines: [for (final line in store.items) line.copy()],
            ),
        ],
      );
}

extension on StoreCart {
  bool get isNotEmptyStore => lines.isNotEmpty;
}

/// 1,234 형태로 끊어 표시.
String wonFormat(int value) {
  final negative = value < 0;
  final s = value.abs().toString();
  final buffer = StringBuffer(negative ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buffer.write(',');
    buffer.write(s[i]);
  }
  return buffer.toString();
}
