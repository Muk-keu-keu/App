import 'combo.dart';

/// 주문 이력 한 건.
///
/// 서버 `GET v1/users/me/orders` 의 `orders[]` 원소에 대응한다.
/// 요기족보 글 작성은 이 목록에서 시작한다 — `isPostedToJokbo` 로 이미 공유한
/// 주문을 구분한다.
class OrderHistoryItem {
  OrderHistoryItem({
    required this.orderId,
    required this.storeName,
    required this.combo,
    required this.orderedAt,
    this.thumbnailPath = 'assets/images/store_dujjim.png',
    this.thumbnailUrl,
    this.sourceVideoTitle = '',
    this.isPostedToJokbo = false,
  });

  final String orderId;
  final String storeName;

  /// 주문한 조합. 족보 작성 시 그대로 게시글에 실린다.
  final ComboRecommendation combo;

  final DateTime orderedAt;
  final String thumbnailPath;
  final String? thumbnailUrl;

  /// 이 주문이 어떤 영상에서 왔는지. 먹방요기로 주문한 건에만 있다.
  final String sourceVideoTitle;

  /// 이미 요기족보에 공유했는지. true 면 "족보 작성" 대신 작성한 글로 보낸다.
  bool isPostedToJokbo;

  /// 카드에 두 줄로 보여줄 메뉴 이름들.
  List<String> get menuNames => combo.items.map((e) => e.name).toList();

  /// 2026.07.22
  String get dateText =>
      '${orderedAt.year}.${_two(orderedAt.month)}.${_two(orderedAt.day)}';

  static String _two(int v) => v.toString().padLeft(2, '0');
}
