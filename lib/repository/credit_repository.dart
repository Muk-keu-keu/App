import '../api/mukbang_api.dart';
import '../models/credit.dart';

/// 포인트 조회.
///
/// 적립·사용하는 길은 없다. 포인트는 결제의 부산물이라 `POST v1/orders` 에서만
/// 움직인다. 따로 충전하거나 쓰는 경로를 열면 그 순간 선불충전 서비스가 된다.
abstract class CreditRepository {
  /// 잔액이 남은 가게만. 잔액 많은 순이다.
  Future<List<StoreCredit>> credits();
}

class ApiCreditRepository implements CreditRepository {
  const ApiCreditRepository(this._api);

  final MukbangApi _api;

  @override
  Future<List<StoreCredit>> credits() => _api.credits();
}

/// 서버 주소가 없을 때 쓰는 빈 구현.
///
/// 더미 데이터를 만들지 않는다 — 있지도 않은 포인트를 화면에 그리면 결제에서
/// 서버 값과 어긋난다. 포인트가 없는 상태로 도는 편이 정직하다.
class EmptyCreditRepository implements CreditRepository {
  const EmptyCreditRepository();

  @override
  Future<List<StoreCredit>> credits() async => const [];
}
