import '../models/combo.dart';
import '../models/order.dart';

/// 주문 이력 데이터 소스.
///
/// 서버 `GET v1/users/me/orders` 자리다. 백엔드 연동 전까지
/// [MockOrderRepository] 가 시안의 데이터를 돌려준다.
abstract class OrderRepository {
  /// 최신 주문이 먼저 온다.
  Future<List<OrderHistoryItem>> list();

  /// 족보 작성을 마친 주문을 표시한다. 목록에서 버튼 상태가 바뀐다.
  Future<void> markPosted(String orderId);
}

class MockOrderRepository implements OrderRepository {
  MockOrderRepository({this.delay = const Duration(milliseconds: 300)});

  final Duration delay;

  List<OrderHistoryItem>? _cache;

  Future<void> get _wait =>
      delay == Duration.zero ? Future<void>.value() : Future<void>.delayed(delay);

  @override
  Future<List<OrderHistoryItem>> list() async {
    await _wait;
    return _cache ??= _samples();
  }

  @override
  Future<void> markPosted(String orderId) async {
    for (final o in _cache ?? const <OrderHistoryItem>[]) {
      if (o.orderId == orderId) o.isPostedToJokbo = true;
    }
  }

  /// 시안 "주문내역" 의 카드 두 장. 두찜 로제 닭발 조합으로 통일돼 있다.
  static List<OrderHistoryItem> _samples() => [
        _order('order_01', DateTime(2026, 7, 22)),
        _order('order_02', DateTime(2026, 7, 22)),
      ];

  static OrderHistoryItem _order(String id, DateTime at) => OrderHistoryItem(
        orderId: id,
        storeName: '두찜 - 잠실새내점',
        orderedAt: at,
        sourceVideoTitle: 'Sub) 로제닭발 먹방! 두찜에서 로제닭발과 중국당면, 치즈 추가',
        thumbnailPath: 'assets/images/store_dujjim.png',
        combo: ComboRecommendation(
          store: const StoreSummary(
            id: 'dujjim-jamsil',
            name: '두찜 - 잠실새내점',
            rating: 4.2,
            reviewCount: 312,
            distanceKm: 3.2,
            deliveryMinutes: 40,
            imagePath: 'assets/images/store_dujjim.png',
            minimumOrderAmount: 14000,
            deliveryFee: 3000,
            similarity: 1,
          ),
          items: [
            ComboItem(
              id: 'rose-dakbal',
              name: '[원조 K로제] 로제 닭발',
              options: '순살, 보통맛, 분모자로 변경, 치즈몽땅 추가',
              unitPrice: 16000,
              quantity: 1,
              imagePath: 'assets/images/menu_rose_dakbal.png',
            ),
            ComboItem(
              id: 'cheese-ball',
              name: '[사이드] 치즈볼',
              options: '모짜렐라 치즈 가득한 쫀득 치즈볼',
              unitPrice: 2000,
              quantity: 2,
              imagePath: 'assets/images/menu_cheese_ball.png',
            ),
          ],
        ),
      );
}
