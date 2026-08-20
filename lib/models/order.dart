/// 주문(결제) 도메인 모델. `docs/api-spec.md` 3·4·5번과 1:1이다.
///
/// 이름이 헷갈리기 쉬워 먼저 정리한다.
/// - **결제 하나 = 영상 하나 = 카드 하나** 이고 그 키가 `checkoutId` 다.
/// - 한 결제 안에 가게가 여러 곳일 수 있다 (`stores[]`). 엽떡+명랑핫도그를 한 번에
///   결제하면 DB 행은 2개 생기고 두 행의 `checkout_id` 가 같다.
/// - API 에 나가는 `orderId` 는 `checkout_id` 다. DB 의 `order_id` 는 내부 저장용이라
///   밖으로 노출되지 않는다.
library;

import 'dart:convert';
import 'credit.dart';

import 'cart.dart';
import 'menu.dart';

/// 출처 영상. 주문 요청·응답과 결제 목록이 같은 모양을 쓴다.
class OrderSource {
  const OrderSource({
    required this.platform,
    required this.url,
    this.thumbnailUrl,
    this.title = '',
  });

  /// `INSTAGRAM` | `YOUTUBE`. 명세가 두 값만 허용한다.
  final SourceKind platform;

  final String url;
  final String? thumbnailUrl;
  final String title;

  factory OrderSource.fromJson(Map<String, dynamic> json) => OrderSource(
        platform: SourceKind.fromWire(json['platform'] as String?),
        url: (json['url'] ?? '') as String,
        thumbnailUrl: json['thumbnailUrl'] as String?,
        title: (json['title'] ?? '') as String,
      );

  Map<String, dynamic> toJson() => {
        'platform': platform.wire,
        'url': url,
        'thumbnailUrl': thumbnailUrl,
        'title': clampTitle(title),
      };

  /// 서버가 저장할 수 있는 길이로 자른다.
  ///
  /// **인스타 제목은 캡션 전문이다.** `og:title` 이 본문을 통째로 담고 있어 1000
  /// 바이트를 넘기기 일쑤다. 서버 컬럼이 300바이트뿐이던 때는 이것 때문에
  /// `POST v1/orders` 가 500 으로 떨어져 **결제 자체가 불가능**했다. 유튜브는 제목이
  /// 짧아 멀쩡히 되고 인스타만 안 되니, 원인이 결제가 아니라 영상 쪽에 있다는 게
  /// 드러나지 않았다.
  ///
  /// 2026-08-13 서버가 컬럼을 늘려 실제 캡션(978바이트)이 그대로 통과한다. 4000
  /// 바이트까지 확인했다. 그래도 자르는 것을 남겨 두는 이유는, 상한이 어디인지
  /// 모르는 채로 넘기면 더 긴 캡션이 나타나는 날 똑같이 500 을 맞고 그때도 서버가
  /// 사유를 주지 않기 때문이다. 확인된 범위 안에서 넉넉히 잡는다.
  ///
  /// 명세에 상한이 명시되면 이 값을 거기 맞추고, 제한이 사라지면 함수도 지운다.
  static const titleMaxBytes = 2000;

  static String clampTitle(String raw) {
    if (utf8.encode(raw).length <= titleMaxBytes) return raw;

    // 글자 중간에서 자르면 깨진 바이트가 남는다. 코드포인트 단위로 담다가
    // 넘치는 순간 멈춘다. 말줄임표(3바이트)까지 미리 빼 둔다.
    const ellipsis = '…';
    final budget = titleMaxBytes - utf8.encode(ellipsis).length;

    final kept = <int>[];
    var used = 0;
    for (final rune in raw.runes) {
      final size = utf8.encode(String.fromCharCode(rune)).length;
      if (used + size > budget) break;
      kept.add(rune);
      used += size;
    }
    return '${String.fromCharCodes(kept)}$ellipsis';
  }
}

/// 영상 플랫폼. `POST v1/analyses` 와 `POST v1/orders` 가 공유한다.
///
/// 명세는 두 값만 받는다. 그 밖의 링크는 분석 전에 막아야 하고, 그 판정은
/// `AnalysisSource` 쪽 `SourcePlatform.fromUrl` 이 한다.
enum SourceKind {
  instagram('INSTAGRAM'),
  youtube('YOUTUBE');

  const SourceKind(this.wire);

  final String wire;

  static SourceKind fromWire(String? value) {
    final upper = (value ?? '').trim().toUpperCase();
    for (final k in values) {
      if (k.wire == upper) return k;
    }
    return SourceKind.youtube;
  }
}

/// 주문내역 카드의 `[지점명] 메뉴, 메뉴` 한 줄 (시안 857:4509 Content 주석).
class OrderStoreMenus {
  const OrderStoreMenus({required this.storeName, required this.menuNames});

  final String storeName;
  final List<String> menuNames;

  /// `[두찜 - 잠실새내점] [원조 K로제] 로제 닭발, [사이드] 치즈볼`
  String get line => '[$storeName] ${menuNames.join(', ')}';

  factory OrderStoreMenus.fromJson(Map<String, dynamic> json) => OrderStoreMenus(
        storeName: '${json['storeName'] ?? json['restaurantName'] ?? ''}',
        menuNames: [
          for (final e in (json['menuNames'] ?? const []) as List) '$e',
        ],
      );
}

/// 결제 목록의 카드 하나. `GET v1/orders` 의 `orders[]`.
///
/// 목록은 조합 전체를 내리지 않는다. 메뉴·옵션·금액은 상세에서 받는다.
class OrderSummary {
  const OrderSummary({
    required this.checkoutId,
    required this.orderedAt,
    required this.restaurantNames,
    required this.totalPrice,
    this.source,
    this.menuSummary = const [],
  });

  final int checkoutId;
  final DateTime orderedAt;
  final OrderSource? source;

  /// 그 결제에 들어간 가게 이름 전부. 카드에 두 줄로 보여준다.
  final List<String> restaurantNames;

  final int totalPrice;

  /// 가게별 메뉴 이름. 시안이 카드에 요구하는 값이다.
  ///
  /// **현재 `GET v1/orders` 응답에는 없다** (`docs/api-spec.md` 확인 필요 항목).
  /// 목록에서 카드마다 상세를 한 번씩 더 부르는 건 "목록에는 조합 전체를 내리지
  /// 않는다" 는 명세와 충돌하므로, 서버가 이 필드를 목록에 실어 주는 쪽으로 정해야 한다.
  /// 비어 있으면 카드는 이 줄을 그리지 않는다 — 값이 올 때까지 화면이 깨지지 않는다.
  final List<OrderStoreMenus> menuSummary;

  /// 가게 수. 메뉴 요약이 오면 그쪽을 믿는다.
  int get storeCount =>
      menuSummary.isNotEmpty ? menuSummary.length : restaurantNames.length;

  /// 총 메뉴 수. 요약이 없으면 셀 수 없어 0이다.
  int get menuCount => menuSummary.fold(0, (sum, s) => sum + s.menuNames.length);

  /// `2개 매장 · 총 3개 메뉴`. 메뉴 수를 모르면 매장 수만 쓴다.
  String get countText => menuCount > 0
      ? '$storeCount개 매장 · 총 $menuCount개 메뉴'
      : '$storeCount개 매장';

  /// 카드 제목 자리. 가게가 여러 곳이면 "외 N곳" 으로 줄인다.
  String get storeSummary => switch (restaurantNames.length) {
        0 => '',
        1 => restaurantNames.first,
        final n => '${restaurantNames.first} 외 ${n - 1}곳',
      };

  String get sourceVideoTitle => source?.title ?? '';

  String? get thumbnailUrl => source?.thumbnailUrl;

  /// 2026.08.04
  String get dateText =>
      '${orderedAt.year}.${_two(orderedAt.month)}.${_two(orderedAt.day)}';

  static String _two(int v) => v.toString().padLeft(2, '0');

  factory OrderSummary.fromJson(Map<String, dynamic> json) => OrderSummary(
        checkoutId: ((json['checkoutId'] ?? 0) as num).toInt(),
        orderedAt:
            DateTime.tryParse((json['orderedAt'] ?? '') as String) ?? DateTime(2026),
        source: json['source'] is Map<String, dynamic>
            ? OrderSource.fromJson(json['source'] as Map<String, dynamic>)
            : null,
        restaurantNames: [
          for (final e in (json['restaurantNames'] ?? const []) as List) '$e',
        ],
        totalPrice: ((json['totalPrice'] ?? 0) as num).toInt(),
        menuSummary: [
          for (final e in (json['menuSummary'] ?? const []) as List)
            if (e is Map<String, dynamic>) OrderStoreMenus.fromJson(e),
        ],
      );
}

/// 결제 내역 상세. `GET v1/orders/{checkoutId}`.
class OrderDetail {
  const OrderDetail({
    required this.checkoutId,
    required this.orderedAt,
    required this.stores,
    required this.totalPrice,
    this.source,
  });

  final int checkoutId;
  final DateTime orderedAt;
  final OrderSource? source;
  final List<OrderStore> stores;
  final int totalPrice;

  List<String> get restaurantNames => [for (final s in stores) s.restaurantName];

  /// 카드에 두 줄로 보여줄 메뉴 이름들.
  List<String> get menuNames =>
      [for (final s in stores) for (final i in s.items) i.name];

  factory OrderDetail.fromJson(Map<String, dynamic> json) => OrderDetail(
        checkoutId: ((json['checkoutId'] ?? 0) as num).toInt(),
        orderedAt:
            DateTime.tryParse((json['orderedAt'] ?? '') as String) ?? DateTime(2026),
        source: json['source'] is Map<String, dynamic>
            ? OrderSource.fromJson(json['source'] as Map<String, dynamic>)
            : null,
        stores: [
          for (final e in (json['stores'] ?? const []) as List)
            if (e is Map<String, dynamic>) OrderStore.fromJson(e),
        ],
        totalPrice: ((json['totalPrice'] ?? 0) as num).toInt(),
      );
}

/// 한 결제 안의 가게 하나. 배달은 가게마다 따로 간다.
class OrderStore {
  const OrderStore({
    required this.restaurantId,
    required this.restaurantName,
    required this.deliveryFee,
    required this.items,
    required this.itemsTotal,
    required this.subtotal,
  });

  final int restaurantId;
  final String restaurantName;
  final int deliveryFee;

  /// 주문 상세의 `items[]`. 옵션은 **고른 것만** 온다.
  final List<CartLine> items;

  final int itemsTotal;

  /// `itemsTotal + deliveryFee`. 그 가게의 결제액이다.
  final int subtotal;

  factory OrderStore.fromJson(Map<String, dynamic> json) => OrderStore(
        restaurantId: ((json['restaurantId'] ?? 0) as num).toInt(),
        restaurantName: (json['restaurantName'] ?? '') as String,
        deliveryFee: ((json['deliveryFee'] ?? 0) as num).toInt(),
        items: [
          for (final e in (json['items'] ?? const []) as List)
            if (e is Map<String, dynamic>) CartLine.fromOrderJson(e),
        ],
        itemsTotal: ((json['itemsTotal'] ?? 0) as num).toInt(),
        subtotal: ((json['subtotal'] ?? 0) as num).toInt(),
      );
}

/// `POST v1/orders` 의 `201` 응답. 가게 이름만 돌려준다.
///
/// `orderId` 를 주지 않는다 — 주문이 2건이면 특정 상세로 바로 갈 수도 없어서다.
/// 그래서 완료 화면은 목록으로만 갈 수 있다 (`docs/api-spec.md` 확인 필요 항목).
class OrderReceipt {
  /// 포인트 필드는 **전부 기본값이 있다.** 이 생성자를 쓰는 더미 저장소를 고치지
  /// 않고도 필드를 늘리기 위해서다.
  const OrderReceipt({
    required this.restaurantNames,
    this.pointDelta = 0,
    this.paidCash,
    this.points = const [],
  });

  final List<String> restaurantNames;

  /// 이 결제로 포인트 잔액이 변한 양. 음수면 포인트를 쓴 것이다.
  /// **완료 화면은 이 값 하나만 쓴다** — "포인트 5,000원 사용" / "7,000P 남았어요".
  final int pointDelta;

  /// 실제로 결제된 현금. 잔액이 넉넉했으면 0 일 수 있다.
  ///
  /// **서버가 이 값을 안 주면 null 이다.** 0 과 구분해야 한다 — 포인트가 다 덮어
  /// 0원인 결제와, 포인트를 모르는 서버의 응답은 화면에 쓸 값이 정반대다. null 이면
  /// 앱이 결제 직전에 그린 금액을 그대로 쓴다.
  final int? paidCash;

  /// 가게별 결과. 잔액을 화면에 바로 반영하는 데 쓴다.
  final List<StorePointResult> points;

  /// 포인트가 움직였는지. 안 움직였으면 완료 화면에 포인트 줄을 그리지 않는다.
  bool get touchedPoint => pointDelta != 0;

  /// 건수를 따로 주지 않는다. 이름 개수가 곳 건수다.
  int get storeCount => restaurantNames.length;

  /// "2건 · 엽기떡볶이 성수점, 교촌치킨 성수점"
  String get completionText => '$storeCount건 · ${restaurantNames.join(', ')}';

  factory OrderReceipt.fromJson(Map<String, dynamic> json) => OrderReceipt(
        restaurantNames: [
          for (final e in (json['restaurantNames'] ?? const []) as List) '$e',
        ],
        pointDelta: ((json['pointDelta'] ?? 0) as num).toInt(),
        paidCash: (json['paidCash'] as num?)?.toInt(),
        points: [
          for (final e in (json['points'] ?? const []) as List)
            if (e is Map<String, dynamic>) StorePointResult.fromJson(e),
        ],
      );
}

/// 결제 목록 한 페이지. `{ orders, nextCursor }`.
class OrderPage {
  const OrderPage({required this.orders, this.nextCursor});

  const OrderPage.empty() : orders = const [], nextCursor = null;

  final List<OrderSummary> orders;

  /// 다음 페이지가 없으면 null.
  final String? nextCursor;

  bool get hasMore => nextCursor != null;

  factory OrderPage.fromJson(Map<String, dynamic> json) => OrderPage(
        orders: [
          for (final e in (json['orders'] ?? const []) as List)
            if (e is Map<String, dynamic>) OrderSummary.fromJson(e),
        ],
        nextCursor: json['nextCursor'] as String?,
      );
}

/// 주문 상세를 장바구니로 되돌린 결과. 다시 주문·족보 작성이 쓴다.
extension OrderDetailToCart on OrderDetail {
  Cart toCart() => Cart.fromOrderDetail(this);
}
