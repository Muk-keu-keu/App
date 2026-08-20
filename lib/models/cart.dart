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
  StoreCart({required this.restaurant, required this.lines, this.creditBalance = 0});

  /// 이 가게의 미달분을 포인트로 채우기로 했는가.
  ///
  /// **미달을 자동으로 메우지 않는다.** 사용자가 가게 카드에서 직접 고른다.
  /// 돈을 더 내는 선택이라 물어보지 않고 대신 정하면 결제 금액이 왜 늘었는지
  /// 알 수 없다. 고르지 않은 미달 가게가 하나라도 있으면 결제 버튼이 잠긴다.
  bool prepaidOptIn = false;

  /// 이 가게에 남은 포인트. 서버가 알려주기 전에는 0이다.
  ///
  /// 두 경로로 채워진다 — 장바구니에 들어갈 때 `GET v1/credits` 한 번,
  /// 족보·다시주문은 `AppFlow._hydrateStores` 가 GET menus 응답에서 흡수한다.
  int creditBalance;

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

  /// **실질 최소 주문 금액** = 가게가 정한 값 − 이 가게에 남은 포인트.
  ///
  /// 포인트는 최소주문을 '채우는' 것이 아니라 '낮춘다'. 잔액 9,000 인 사람에게
  /// 최소주문 14,000 은 사실상 5,000 이다 — 이미 그 가게에 9,000 을 냈기 때문이다.
  ///
  /// 채우는 방식으로 하면 같은 상황에서 포인트 9,000 을 쓰고 9,000 을 도로 적립받아
  /// 잔액이 그대로이고 현금만 5,000 이 나간다. 회계는 맞지만 "포인트가 있는데 왜
  /// 현금을 내지" 가 된다. 가게가 인식하는 매출은 양쪽 다 5,000 으로 같다.
  int get effectiveMinOrder {
    final min = restaurant.minOrderPrice - creditBalance;
    return min < 0 ? 0 : min;
  }

  /// 최소 주문 금액을 넘겼는지. 배달비는 빼고 음식값으로만 판정한다.
  bool get meetsMinimum => itemsTotal >= effectiveMinOrder;

  /// 최소 주문까지 남은 금액. 넘겼으면 0.
  int get shortfall =>
      itemsTotal >= effectiveMinOrder ? 0 : effectiveMinOrder - itemsTotal;

  /// "3,000원 더 담아주세요" 안내. 넘겼으면 null.
  String? get shortfallText =>
      meetsMinimum ? null : '${wonFormat(shortfall)}원 더 담아주세요';

  // ── 포인트 계산 ──────────────────────────────────────────────────────────
  //
  // **서버 `CreditPlan.of()` 와 글자 그대로 같은 식이다.** 한쪽만 고치면 화면 금액과
  // 실제 결제액이 달라진다. 고칠 일이 생기면 양쪽을 같은 커밋에서 고친다.
  //
  //   base   = max(음식값, 최소주문)      가게가 받을 음식값
  //   payable = base + 배달비             이번에 낼 총액
  //   used   = min(잔액, payable)         포인트 우선, 배달비까지
  //   earned = base - 음식값              음식으로 안 받은 만큼 되돌아온다

  /// 가게가 받을 음식값.
  ///
  /// **채우기를 고른 가게만** 실질 최소주문까지 올린다. 고르지 않았으면 담은 값
  /// 그대로이고, 그 상태로는 결제가 잠긴다([isBlocked]).
  int get base => prepaidOptIn && itemsTotal < effectiveMinOrder
      ? effectiveMinOrder
      : itemsTotal;

  /// 이 가게 때문에 결제를 못 하는 상태인가.
  /// 실질 최소주문에도 미달인데 채우기를 안 골랐을 때다.
  bool get isBlocked => !meetsMinimum && !prepaidOptIn;

  /// 포인트를 쓰기 전, 이번에 내야 할 총액.
  int get payable => base + deliveryFee;

  /// 쓰는 포인트. 배달비까지 포함해 낼 수 있는 만큼 전부 쓴다.
  int get usedPoint => creditBalance < payable ? creditBalance : payable;

  /// 되돌려받는 포인트 = 최소 주문 미달분. [shortfall] 과 같은 값이다.
  int get earnedPoint => base - itemsTotal;

  /// 이 가게에 실제로 결제되는 현금.
  int get payAmount => payable - usedPoint;

  /// 잔액 순변화. 음수면 포인트가 줄어든다.
  int get pointDelta => earnedPoint - usedPoint;

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

  StoreCart copy() => StoreCart(
        restaurant: restaurant,
        lines: [for (final l in lines) l.copy()],
        creditBalance: creditBalance,
      )..prepaidOptIn = prepaidOptIn;

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

  // ── 포인트 합계 ──────────────────────────────────────────────────────────

  int get usedPointTotal => stores.fold(0, (sum, s) => sum + s.usedPoint);
  int get earnedPointTotal => stores.fold(0, (sum, s) => sum + s.earnedPoint);

  /// 잔액 순변화 합. 화면 요약이 쓰는 값이다.
  int get pointDeltaTotal => earnedPointTotal - usedPointTotal;

  /// 실제로 결제되는 현금 합. 잔액이 넉넉하면 0 이 될 수 있다.
  int get payAmountTotal => stores.fold(0, (sum, s) => sum + s.payAmount);

  /// 새로 선불해야 하는가. **결제 바가 두 버튼이 되는 기준이다.**
  bool get needsPrepaid => earnedPointTotal > 0;

  /// 쓸 수 있는 잔액이 있는가.
  bool get hasCredit => stores.any((s) => s.creditBalance > 0);

  /// 서버에 보낼 플래그. 포인트가 개입할 일이 있을 때만 켠다.
  ///
  /// 끄고 보내면 서버는 지금까지와 똑같이 동작한다 — 미달이면 400 이고 잔액도
  /// 건드리지 않는다. 켜면 서버가 가게별로 금액을 다시 계산한다.
  ///
  /// 채우기를 고르지 않은 가게가 섞여 있어도 상관없다. 그런 가게는 미달이 아니라서
  /// (미달이면 결제 자체가 잠긴다) 켜 두어도 적립이 0 이고, 잔액이 있으면 쓰일 뿐이다.
  bool get usePrepaid => stores.any((s) => s.prepaidOptIn) || hasCredit;

  /// 채우기를 아직 안 고른 미달 가게들. 결제 버튼이 잠기는 이유다.
  List<StoreCart> get blockedStores => [
        for (final s in stores)
          if (s.isBlocked) s,
      ];

  /// 결제 가능한지.
  ///
  /// 미달 가게는 **메뉴를 더 담거나 채우기를 고르면** 풀린다. 둘 중 하나도 안 한
  /// 가게가 남아 있으면 잠긴 채로 둔다 — 어느 가게가 걸렸는지는 그 가게 카드가
  /// 자기 자리에서 말한다.
  bool get canCheckout => isNotEmpty && blockedStores.isEmpty;

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
        // 가게별 포인트 값은 보내지 않는다. 돈이라 **서버가 다시 계산**한다.
        'usePrepaid': usePrepaid,
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
