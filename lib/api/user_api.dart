/// Users 엔드포인트를 그대로 옮긴 얇은 층. `mukbang_api.dart` 와 같은 규칙이다 —
/// 경로·본문 모양만 담고 판단은 repository 가 한다.
///
/// 명세는 `docs/api-spec.md` 6번이지만 **실제 응답이 명세와 다르다.** 각 메서드에
/// 확인한 내용을 적어 뒀다 (2026-08-08 서버 직접 확인).
library;

import '../models/auth.dart';
import 'api_client.dart';

class UserApi {
  const UserApi(this.client);

  final ApiClient client;

  /// `POST v1/users/login` — 인증 없이 부른다.
  ///
  /// 실패는 `401 INVALID_CREDENTIALS`. 명세의 `U001` 이 아니다.
  /// 응답은 토큰 두 개뿐이고 `user` 블록이 없다.
  Future<AuthTokens> login({required String email, required String password}) async {
    final json = await client.post(
      loginPath,
      body: {'email': email, 'password': password},
      authenticated: false,
    );
    return AuthTokens.fromJson(json);
  }

  /// `POST v1/users/signup` — 인증 없이 부른다.
  ///
  /// **본문 없는 `201` 을 준다.** 토큰을 주지 않으므로 부른 쪽이 이어서 로그인해야 한다.
  /// 필드 이름은 `nickName` — 대문자 N 이다. 소문자로 보내면
  /// `400 INVALID_REQUEST_DATA "닉네임은 필수 입력값입니다"` 가 온다.
  Future<void> signup({
    required String email,
    required String password,
    required String nickName,
  }) =>
      client.post(
        signupPath,
        body: {'email': email, 'password': password, 'nickName': nickName},
        authenticated: false,
      );

  /// `POST v1/users/reissue-token` — 인증 없이 부른다. 만료된 accessToken 을
  /// 헤더에 실어 보내면 그 자체가 401 이 되므로 토큰을 뺀다.
  ///
  /// 응답은 `accessToken` 과 `refreshToken` 둘 다 온다 (명세에는 앞의 것만 적혀 있다).
  Future<AuthTokens> reissue(String refreshToken) async {
    final json = await client.post(
      reissuePath,
      body: {'refreshToken': refreshToken},
      authenticated: false,
    );
    return AuthTokens.fromJson(json);
  }

  /// `POST v1/users/logout` — `204 No Content`.
  ///
  /// 서버가 토큰을 무효화하지 않는다. 로그아웃 뒤에도 같은 토큰으로 `me` 가 200 이다.
  /// 실질적인 로그아웃은 앱이 토큰을 지우는 것이고, 이 호출은 서버에 알리는 것뿐이다.
  Future<void> logout() => client.post(logoutPath);

  /// `GET v1/users/me` — `{id, email, role}`.
  Future<AuthUser> me() async => AuthUser.fromJson(await client.get(mePath));

  /// 인증 없이 부르는 경로들. [ApiClient] 가 401 재발급 대상에서 빼는 데 쓴다.
  static const loginPath = 'v1/users/login';
  static const signupPath = 'v1/users/signup';
  static const reissuePath = 'v1/users/reissue-token';
  static const logoutPath = 'v1/users/logout';
  static const mePath = 'v1/users/me';
}
