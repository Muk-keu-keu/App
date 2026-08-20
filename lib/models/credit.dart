/// 포인트. 최소 주문 미달분을 음식 대신 받아 두었다가 다음 주문에 쓰는 금액이다.
///
/// **가게 전용이다.** 홍콩반점에서 받은 포인트는 홍콩반점에서만 쓸 수 있다.
/// 그래서 "총 잔액" 이라는 값을 서버가 내려주지 않는다 — 여러 가게 잔액을 더한
/// 숫자로는 아무것도 할 수 없기 때문이다. 화면이 합계를 쓰고 싶으면 [totalOf] 로
/// 직접 더한다.
library;

/// `GET v1/credits` 의 원소. 잔액이 0 인 가게는 목록에 오지 않는다.
class StoreCredit {
  const StoreCredit({
    required this.restaurantId,
    required this.restaurantName,
    required this.balance,
    this.imageUrl = '',
  });

  final int restaurantId;

  /// 가게 이름. 서버가 가게를 못 찾으면 null 이 올 수 있어 빈 문자열로 받는다.
  final String restaurantName;

  final int balance;
  final String imageUrl;

  factory StoreCredit.fromJson(Map<String, dynamic> json) => StoreCredit(
        restaurantId: ((json['restaurantId'] ?? 0) as num).toInt(),
        restaurantName: (json['restaurantName'] ?? '') as String,
        balance: ((json['balance'] ?? 0) as num).toInt(),
        imageUrl: (json['imageUrl'] ?? '') as String,
      );

  static int totalOf(List<StoreCredit> credits) =>
      credits.fold(0, (sum, c) => sum + c.balance);

  /// `restaurantId → balance`. 장바구니가 가게마다 잔액을 꽂을 때 쓴다.
  static Map<int, int> indexOf(List<StoreCredit> credits) =>
      {for (final c in credits) c.restaurantId: c.balance};
}

/// 결제 응답의 가게별 포인트 결과. 잔액을 화면에 바로 반영하는 데 쓴다.
class StorePointResult {
  const StorePointResult({
    required this.restaurantId,
    required this.balance,
    this.restaurantName = '',
    this.usedPoint = 0,
    this.earnedPoint = 0,
  });

  final int restaurantId;
  final String restaurantName;

  /// 정산·디버깅용 상세. 화면은 순액([balance] 변화)만 쓴다.
  final int usedPoint;
  final int earnedPoint;

  /// 이 결제 뒤 남은 잔액.
  final int balance;

  factory StorePointResult.fromJson(Map<String, dynamic> json) => StorePointResult(
        restaurantId: ((json['restaurantId'] ?? 0) as num).toInt(),
        restaurantName: (json['restaurantName'] ?? '') as String,
        usedPoint: ((json['usedPoint'] ?? 0) as num).toInt(),
        earnedPoint: ((json['earnedPoint'] ?? 0) as num).toInt(),
        balance: ((json['balance'] ?? 0) as num).toInt(),
      );
}
