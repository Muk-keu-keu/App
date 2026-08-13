import 'package:flutter_test/flutter_test.dart';
import 'package:mukbang_ttaradamgi/app_flow.dart';
import 'package:mukbang_ttaradamgi/models/auth.dart';
import 'package:mukbang_ttaradamgi/repository/auth_repository.dart';
import 'package:mukbang_ttaradamgi/services/location_service.dart';
import 'package:mukbang_ttaradamgi/services/token_store.dart';

class _NoLocation implements LocationService {
  const _NoLocation();

  @override
  Future<LocationResult> current() async =>
      const LocationResult.failed(LocationFailure.denied);
}

/// 메모리에만 두는 저장소. 디스크를 건드리지 않는다.
class _MemoryTokenStore implements TokenStore {
  AuthTokens? _saved;

  @override
  Future<AuthTokens?> read() async => _saved;

  @override
  Future<void> write(AuthTokens tokens) async => _saved = tokens;

  @override
  Future<void> clear() async => _saved = null;
}

/// 항상 성공하는 로그인. 이 테스트는 인증이 아니라 진입 순서를 본다.
class _OkAuth implements AuthRepository {
  const _OkAuth();

  static const _tokens = AuthTokens(accessToken: 'a', refreshToken: 'r');

  @override
  Future<AuthTokens> login({required String email, required String password}) async =>
      _tokens;

  @override
  Future<AuthTokens> signup({
    required String email,
    required String password,
    required String nickName,
  }) async =>
      _tokens;

  @override
  Future<AuthTokens?> reissue(String refreshToken) async => _tokens;

  @override
  Future<void> logout() async {}

  @override
  Future<AuthUser> me() async =>
      const AuthUser(id: 1, email: 'a@b.c', role: 'USER');
}

/// 공유로 들어오면 **어느 화면에 있든, 앱이 꺼져 있었든** 조건 선택 화면으로 간다.
///
/// 앱이 꺼진 상태에서 공유로 열면 세션 복원과 링크 처리가 같이 달린다. 링크가
/// 먼저 도착해 조건 화면을 세워 놔도, 복원이 끝나면서 completeLogin() 이 홈으로
/// 덮어써 앱만 열리고 분석으로 넘어가지 않았다.
void main() {
  AppFlow makeFlow() => AppFlow(
        locationService: const _NoLocation(),
        authRepository: const _OkAuth(),
        tokenStore: _MemoryTokenStore(),
      );

  Future<AppFlow> loggedIn() async {
    final flow = makeFlow();
    await flow.login(email: 'a@b.c', password: 'pw12345678');
    return flow;
  }

  const link = 'https://www.instagram.com/reel/DXZQeEnCXqC/';

  test('로그인 상태에서 공유하면 바로 조건 화면이다', () async {
    final flow = await loggedIn();
    expect(flow.stage, AppStage.yogiyoHome);

    flow.start(link);

    expect(flow.stage, AppStage.keyword);
  });

  test('세션 복원이 늦게 끝나도 조건 화면을 덮지 않는다', () async {
    // 실제 순서를 그대로 흉내 낸다 — 링크가 먼저, 복원 완료가 나중.
    final flow = await loggedIn();
    flow.start(link);
    expect(flow.stage, AppStage.keyword);

    flow.completeLogin(); // restoreSession 이 뒤늦게 끝난 지점

    expect(flow.stage, AppStage.keyword, reason: '홈으로 덮이면 공유가 사라진다');
  });

  test('다른 화면(주문내역)에 있어도 조건 화면으로 간다', () async {
    final flow = await loggedIn();
    flow.openOrders();

    flow.start(link);

    expect(flow.stage, AppStage.keyword);
  });

  test('로그인 전에 공유하면 로그인 먼저, 끝나면 조건 화면이다', () async {
    final flow = makeFlow();
    expect(flow.isLoggedIn, isFalse);

    flow.start(link);
    // 여기서 조건 화면을 열면 분석이 401 을 맞는다.
    expect(flow.stage, AppStage.login);

    await flow.login(email: 'a@b.c', password: 'pw12345678');

    expect(flow.stage, AppStage.keyword);
  });

  test('공유 없이 로그인하면 홈으로 간다', () async {
    final flow = await loggedIn();

    expect(flow.stage, AppStage.yogiyoHome);
  });

  test('조건 화면에서 나오면 다음 로그인은 홈으로 간다', () async {
    final flow = await loggedIn();
    flow.start(link);
    expect(flow.stage, AppStage.keyword);

    flow.backToYogiyoHome();
    flow.completeLogin();

    expect(flow.stage, AppStage.yogiyoHome);
  });

  test('로그아웃하면 기다리던 공유도 함께 버린다', () async {
    // 다음에 로그인한 사람을 남의 링크 분석 화면으로 떨어뜨리면 안 된다.
    final flow = await loggedIn();
    flow.start(link);

    await flow.logout();
    await flow.login(email: 'other@b.c', password: 'pw12345678');

    expect(flow.stage, AppStage.yogiyoHome);
  });

  test('공유 원문은 링크와 함께 살아 있다', () async {
    final flow = await loggedIn();

    flow.start(link, sharedText: '토핑 잔뜩 때려넣은 꿈의 마라로제 $link');

    expect(flow.sharedCaption, '토핑 잔뜩 때려넣은 꿈의 마라로제');
    expect(flow.stage, AppStage.keyword);
  });
}
