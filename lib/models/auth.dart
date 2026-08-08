/// 로그인·회원가입 응답 모델.
///
/// **명세(`docs/api-spec.md` 6번)와 실제 서버가 다르다.** 실제 응답을 기준으로 짰다
/// (2026-08-08 서버에 직접 요청해 확인):
/// - 로그인 응답에 `user` 블록이 없다. 토큰 두 개뿐이다.
/// - 회원가입은 `201` + 본문 0바이트다. 토큰을 주지 않아 가입 직후 로그인을 따로 부른다.
/// - `GET v1/users/me` 는 `{id, email, role}` 뿐이다. `nickname` 도 `profileImageUrl` 도 없다.
library;

/// 서버가 준 토큰 한 쌍.
class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});

  final String accessToken;

  /// 재발급용. 지금 서버는 accessToken 과 같은 문자열을 준다.
  final String refreshToken;

  bool get isUsable => accessToken.trim().isNotEmpty;

  factory AuthTokens.fromJson(Map<String, dynamic> json) => AuthTokens(
        accessToken: '${json['accessToken'] ?? ''}',
        refreshToken: '${json['refreshToken'] ?? ''}',
      );

  AuthTokens copyWith({String? accessToken, String? refreshToken}) => AuthTokens(
        accessToken: accessToken ?? this.accessToken,
        refreshToken: refreshToken ?? this.refreshToken,
      );
}

/// 로그인한 사람. `GET v1/users/me` 의 응답이다.
///
/// 명세는 `userId`(UUID)·`nickname`·`profileImageUrl`·`createdAt` 을 적어 두었지만
/// 서버는 `id`(정수)·`email`·`role` 만 준다. 없는 값을 지어내지 않고 오는 것만 담는다 —
/// 닉네임이 필요한 화면이 생기면 그때 서버에 요청해야 한다.
class AuthUser {
  const AuthUser({required this.id, required this.email, required this.role});

  /// 정수 id. 명세의 UUID 가 아니다.
  final int id;

  final String email;

  /// `USER` 등. 지금 앱은 쓰지 않지만 응답에 있어 버리지 않는다.
  final String role;

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: switch (json['id']) {
          final int v => v,
          final Object? v => int.tryParse('$v') ?? 0,
        },
        email: '${json['email'] ?? ''}',
        role: '${json['role'] ?? ''}',
      );
}

/// 로그인·회원가입이 실패한 이유. 화면이 문구를 고르는 데 쓴다.
enum AuthFailure {
  /// 이메일이나 비밀번호가 틀렸다 (`401 INVALID_CREDENTIALS`).
  invalidCredentials,

  /// 이미 가입된 이메일 (`409 EMAIL_ALREADY_EXISTS`).
  emailTaken,

  /// 서버가 입력을 거절했다 (`400 INVALID_REQUEST_DATA`). 서버 문구를 그대로 보여준다.
  invalidInput,

  /// 연결이 안 됐다.
  network,

  /// 그 밖의 서버 오류.
  server,
}

/// 로그인·회원가입 결과. 성공이면 [failure] 가 null 이다.
class AuthResult {
  const AuthResult.success() : failure = null, message = null;
  const AuthResult.failed(this.failure, {this.message});

  final AuthFailure? failure;

  /// 서버가 준 설명. 있으면 화면이 이것을 먼저 쓴다 —
  /// 비밀번호 길이 같은 규칙은 서버만 알고 있어 앱이 문구를 지어내면 어긋난다.
  final String? message;

  bool get isSuccess => failure == null;
}
