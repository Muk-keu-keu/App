import '../api/api_client.dart';
import '../api/user_api.dart';
import '../models/auth.dart';

/// 로그인·회원가입 데이터 소스.
///
/// 구현이 둘이다 — 다른 repository 와 같은 규칙이다.
/// - [ApiAuthRepository] — 실제 서버. `.env` 의 `API_BASE_URL` 이 있을 때.
/// - [MockAuthRepository] — 더미. 서버 없이 시연할 때.
///
/// 실패는 [ApiException] · [NetworkException] 으로 던진다. 어떤 문구를 보여줄지는
/// [AppFlow] 가 정한다 — 주문 실패를 다루는 방식과 같다.
abstract class AuthRepository {
  Future<AuthTokens> login({required String email, required String password});

  /// 가입하고 이어서 로그인한 결과를 준다.
  ///
  /// 서버 회원가입이 토큰을 주지 않아 두 번 부르는 것이지, 화면이 알 필요는 없다.
  Future<AuthTokens> signup({
    required String email,
    required String password,
    required String nickName,
  });

  /// 재발급. 실패하면 null — 다시 로그인해야 하는 상태다.
  Future<AuthTokens?> reissue(String refreshToken);

  /// 서버에 로그아웃을 알린다. 실패해도 앱은 토큰을 지운다.
  Future<void> logout();

  /// 지금 토큰이 살아 있는지 확인하고 그 사람을 준다. 죽었으면 예외를 던진다.
  Future<AuthUser> me();

  /// 닉네임 변경 후 갱신된 사용자 정보.
  Future<AuthUser> updateNickName(String nickName);

  /// 회원 탈퇴. 성공하면 호출한 쪽이 토큰을 지운다.
  Future<void> deleteAccount({required String email, required String password});
}

class ApiAuthRepository implements AuthRepository {
  const ApiAuthRepository(this._api);

  final UserApi _api;

  @override
  Future<AuthTokens> login({required String email, required String password}) =>
      _api.login(email: email, password: password);

  /// 가입 응답이 `201` + 본문 0바이트다. 토큰을 안 주므로 같은 자격으로 로그인해서
  /// 토큰을 받아 온다. 서버가 나중에 토큰을 주기 시작하면 이 두 번째 호출만 빼면 된다.
  @override
  Future<AuthTokens> signup({
    required String email,
    required String password,
    required String nickName,
  }) async {
    await _api.signup(email: email, password: password, nickName: nickName);
    return login(email: email, password: password);
  }

  @override
  Future<AuthTokens?> reissue(String refreshToken) async {
    if (refreshToken.trim().isEmpty) return null;
    try {
      final tokens = await _api.reissue(refreshToken);
      return tokens.isUsable ? tokens : null;
    } on ApiException {
      // 만료·위조된 refreshToken 이다. 재시도가 소용없어 null 로 접는다.
      return null;
    } on NetworkException {
      // 연결이 끊긴 것뿐이라 토큰이 죽었다고 볼 수 없지만, 지금 요청은 살릴 수 없다.
      return null;
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _api.logout();
    } on ApiException {
      // 서버가 거절해도 앱은 토큰을 지운다. 어차피 서버는 토큰을 무효화하지 않는다.
    } on NetworkException {
      // 같은 이유로 삼킨다. 비행기 모드에서도 로그아웃은 돼야 한다.
    }
  }

  @override
  Future<AuthUser> me() => _api.me();

  @override
  Future<AuthUser> updateNickName(String nickName) async {
    await _api.updateNickName(nickName);
    // PATCH 응답에 본문이 없다. 바뀐 값을 화면에 반영하려면 다시 읽어야 한다.
    return _api.me();
  }

  @override
  Future<void> deleteAccount({required String email, required String password}) =>
      _api.deleteUser(email: email, password: password);
}

/// 백엔드 없이 시연할 때 쓰는 더미.
///
/// **서버의 입력 검증을 흉내내지 않는다.** 이메일 형식이나 비밀번호 8자 규칙은
/// 서버만 아는 것이고, 시연에서는 실제 계정이 없어도 화면 흐름을 볼 수 있어야 한다.
/// 비어 있지 않기만 하면 통과시킨다 — 빈 값 검사는 화면이 이미 한다.
class MockAuthRepository implements AuthRepository {
  MockAuthRepository({this.delay = const Duration(milliseconds: 300)});

  final Duration delay;

  /// 가입된 이메일. 같은 이메일로 다시 가입하면 서버처럼 409 를 준다.
  final Set<String> _registered = {};

  Future<void> get _wait =>
      delay == Duration.zero ? Future<void>.value() : Future<void>.delayed(delay);

  @override
  Future<AuthTokens> login({required String email, required String password}) async {
    await _wait;
    if (email.trim().isEmpty || password.isEmpty) {
      throw const ApiException(
        statusCode: 401,
        code: 'INVALID_CREDENTIALS',
        path: UserApi.loginPath,
      );
    }
    return _tokensFor(email);
  }

  @override
  Future<AuthTokens> signup({
    required String email,
    required String password,
    required String nickName,
  }) async {
    await _wait;
    final key = email.trim().toLowerCase();
    if (!_registered.add(key)) {
      throw const ApiException(
        statusCode: 409,
        code: 'EMAIL_ALREADY_EXISTS',
        message: '이미 존재하는 이메일입니다.',
        path: UserApi.signupPath,
      );
    }
    return _tokensFor(email);
  }

  /// 더미 토큰은 만료가 없다. 재발급은 같은 토큰을 그대로 돌려준다.
  @override
  Future<AuthTokens?> reissue(String refreshToken) async =>
      refreshToken.trim().isEmpty
          ? null
          : AuthTokens(accessToken: refreshToken, refreshToken: refreshToken);

  @override
  Future<void> logout() async => _wait;

  @override
  Future<AuthUser> updateNickName(String nickName) async => AuthUser(
        id: 0,
        email: 'demo@mukbang.local',
        role: 'USER',
        nickName: nickName,
      );

  @override
  Future<void> deleteAccount({required String email, required String password}) async {}

  @override
  Future<AuthUser> me() async {
    await _wait;
    return const AuthUser(id: 0, email: 'demo@mukbang.local', role: 'USER');
  }

  static AuthTokens _tokensFor(String email) {
    final token = 'mock-token-${email.trim().toLowerCase()}';
    return AuthTokens(accessToken: token, refreshToken: token);
  }
}
