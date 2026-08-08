import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mukbang_ttaradamgi/api/api_client.dart';
import 'package:mukbang_ttaradamgi/api/user_api.dart';
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

/// 서버가 준 실제 응답을 그대로 옮긴 것 (2026-08-08 확인).
///
/// 명세(`docs/api-spec.md` 6번)와 다른 부분이 여기 잠긴다 — 로그인에 `user` 블록이
/// 없고, 회원가입은 본문이 없고, `me` 는 `{id, email, role}` 뿐이다.
const _loginBody = '{"accessToken":"access-1","refreshToken":"refresh-1"}';
const _meBody = '{"id":1020,"email":"qa-check-0808@example.com","role":"USER"}';
const _unauthorizedBody =
    '{"status":401,"code":"AUTHENTICATION_REQUIRED","message":"인증이 필요한 요청입니다. 로그인 해주세요.","path":"GET /v1/users/me"}';
const _invalidCredentialsBody =
    '{"status":401,"code":"INVALID_CREDENTIALS","message":"이메일 또는 비밀번호가 올바르지 않습니다.","path":"POST /v1/users/login"}';

/// 응답 하나. `http.Response(문자열)` 은 본문을 latin1 로 인코딩해서 한글이 든
/// 서버 문구를 그대로 쓸 수 없다. 바이트로 만들어 utf-8 임을 헤더에 적는다.
http.Response _json(String body, int status) => http.Response.bytes(
      utf8.encode(body),
      status,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );

/// 오간 요청을 붙잡아 두는 가짜 서버.
class _FakeServer {
  _FakeServer(this._respond);

  final http.Response Function(http.Request request, int hits) _respond;

  final List<http.Request> requests = [];

  /// 경로별 호출 횟수. 재발급 뒤 같은 요청을 다시 보냈는지 세는 데 쓴다.
  final Map<String, int> hits = {};

  http.Client get client => MockClient((request) async {
        requests.add(request);
        final path = request.url.path;
        hits[path] = (hits[path] ?? 0) + 1;
        return _respond(request, hits[path]!);
      });

  int hitsOf(String path) => hits['/$path'] ?? 0;

  http.Request? requestTo(String path) {
    for (final r in requests) {
      if (r.url.path == '/$path') return r;
    }
    return null;
  }
}

void main() {
  /// 서버를 쓰는 [AppFlow]. 토큰 저장소는 메모리다 — 단위 테스트에 저장소 플러그인이 없다.
  ({AppFlow flow, ApiClient client, MemoryTokenStore store}) makeFlow(
    _FakeServer server, {
    AuthTokens? saved,
  }) {
    final client = ApiClient(baseUrl: 'http://server.test', httpClient: server.client);
    final store = MemoryTokenStore(saved);
    final flow = AppFlow(
      apiClient: client,
      tokenStore: store,
      locationService: const _NoLocation(),
    );
    return (flow: flow, client: client, store: store);
  }

  /// 로그인 → me 까지 정상으로 답하는 서버.
  _FakeServer happyServer() => _FakeServer((request, _) => switch (request.url.path) {
        '/${UserApi.loginPath}' => _json(_loginBody, 200),
        '/${UserApi.signupPath}' => _json('', 201),
        '/${UserApi.mePath}' => _json(_meBody, 200),
        _ => _json('{}', 200),
      });

  group('로그인 — 실제 서버 계약', () {
    test('응답에 user 블록이 없어도 토큰을 꽂고 홈으로 간다', () async {
      final server = happyServer();
      final (flow: flow, client: client, store: store) = makeFlow(server);

      final result = await flow.login(
        email: 'qa-check-0808@example.com',
        password: 'Test1234!',
      );

      expect(result.isSuccess, isTrue);
      expect(client.accessToken, 'access-1');
      expect(flow.isLoggedIn, isTrue);
      expect(flow.stage, AppStage.yogiyoHome);
      // 토큰은 다음 실행의 자동 로그인을 위해 저장돼야 한다.
      expect((await store.read())?.refreshToken, 'refresh-1');
    });

    test('로그인 응답에 사용자 정보가 없어 me 를 따로 부른다', () async {
      final server = happyServer();
      final (flow: flow, client: _, store: _) = makeFlow(server);

      await flow.login(email: 'a@b.com', password: 'Test1234!');

      expect(server.hitsOf(UserApi.mePath), 1);
      expect(flow.currentUser?.id, 1020);
      expect(flow.currentUser?.email, 'qa-check-0808@example.com');
    });

    test('로그인은 Authorization 헤더를 보내지 않는다', () async {
      final server = happyServer();
      final (flow: flow, client: client, store: _) = makeFlow(server);

      // 만료된 토큰이 남아 있는 상황. 그것을 실어 보내면 로그인 자체가 401 이 된다.
      client.accessToken = 'expired-token';
      await flow.login(email: 'a@b.com', password: 'Test1234!');

      final login = server.requestTo(UserApi.loginPath);
      expect(login?.headers.containsKey('Authorization'), isFalse);
    });

    test('401 INVALID_CREDENTIALS 는 자격 실패로 바꾼다', () async {
      final server = _FakeServer(
        (request, _) => _json(_invalidCredentialsBody, 401),
      );
      final (flow: flow, client: _, store: _) = makeFlow(server);

      final result = await flow.login(email: 'a@b.com', password: 'wrong');

      expect(result.failure, AuthFailure.invalidCredentials);
      expect(flow.isLoggedIn, isFalse);
      expect(flow.stage, AppStage.login);
      // 자격 실패에 재발급을 시도하면 안 된다. 로그인은 토큰 없이 부르는 경로다.
      expect(server.hitsOf(UserApi.reissuePath), 0);
    });

    test('연결이 안 되면 network 로 바꾼다', () async {
      final server = _FakeServer((request, _) => throw http.ClientException('no route'));
      final (flow: flow, client: _, store: _) = makeFlow(server);

      final result = await flow.login(email: 'a@b.com', password: 'Test1234!');

      expect(result.failure, AuthFailure.network);
    });
  });

  group('회원가입 — 실제 서버 계약', () {
    test('닉네임은 nickName (대문자 N) 으로 보낸다', () async {
      final server = happyServer();
      final (flow: flow, client: _, store: _) = makeFlow(server);

      await flow.signUp(email: 'a@b.com', password: 'Test1234!', nickname: '큐에이');

      final body = jsonDecode(server.requestTo(UserApi.signupPath)!.body)
          as Map<String, dynamic>;
      // 소문자 nickname 으로 보내면 서버가 400 INVALID_REQUEST_DATA 를 준다.
      expect(body['nickName'], '큐에이');
      expect(body.containsKey('nickname'), isFalse);
    });

    test('가입 응답에 토큰이 없어 이어서 로그인한다', () async {
      final server = happyServer();
      final (flow: flow, client: client, store: _) = makeFlow(server);

      final result = await flow.signUp(
        email: 'a@b.com',
        password: 'Test1234!',
        nickname: '큐에이',
      );

      expect(result.isSuccess, isTrue);
      expect(server.hitsOf(UserApi.signupPath), 1);
      expect(server.hitsOf(UserApi.loginPath), 1);
      expect(client.accessToken, 'access-1');
      expect(flow.stage, AppStage.yogiyoHome);
    });

    test('409 는 이메일 중복으로 바꾸고 서버 문구를 함께 준다', () async {
      final server = _FakeServer((request, _) => _json(
            '{"status":409,"code":"EMAIL_ALREADY_EXISTS","message":"이미 존재하는 이메일입니다."}',
            409,
          ));
      final (flow: flow, client: _, store: _) = makeFlow(server);

      final result =
          await flow.signUp(email: 'a@b.com', password: 'Test1234!', nickname: '큐에이');

      expect(result.failure, AuthFailure.emailTaken);
      expect(result.message, '이미 존재하는 이메일입니다.');
    });

    test('400 은 서버가 준 규칙 문구를 그대로 넘긴다', () async {
      final server = _FakeServer((request, _) => _json(
            '{"status":400,"code":"INVALID_REQUEST_DATA","message":"비밀번호는 8자 이상 64자 이하여야 합니다."}',
            400,
          ));
      final (flow: flow, client: _, store: _) = makeFlow(server);

      final result = await flow.signUp(email: 'a@b.com', password: '12', nickname: '큐에이');

      expect(result.failure, AuthFailure.invalidInput);
      // 길이 규칙은 서버만 안다. 앱이 문구를 지어내면 규칙이 바뀔 때 어긋난다.
      expect(result.message, contains('8자 이상 64자 이하'));
    });
  });

  group('자동 로그인', () {
    test('저장된 토큰이 살아 있으면 로그인 화면을 건너뛴다', () async {
      final server = happyServer();
      final (flow: flow, client: client, store: _) = makeFlow(
        server,
        saved: const AuthTokens(accessToken: 'saved-a', refreshToken: 'saved-r'),
      );

      await flow.restoreSession();

      expect(client.accessToken, 'saved-a');
      expect(flow.stage, AppStage.yogiyoHome);
      expect(flow.isRestoringSession, isFalse);
      // 로그인을 다시 부르지 않는다. 토큰이 있으면 me 로 확인만 한다.
      expect(server.hitsOf(UserApi.loginPath), 0);
    });

    test('저장된 토큰이 없으면 아무 요청도 하지 않는다', () async {
      final server = happyServer();
      final (flow: flow, client: _, store: _) = makeFlow(server);

      await flow.restoreSession();

      expect(server.requests, isEmpty);
      expect(flow.stage, AppStage.login);
    });

    test('토큰이 죽었으면 지우고 로그인 화면에 남는다', () async {
      // me 도 재발급도 401. 다시 로그인해야 하는 상태다.
      final server = _FakeServer((request, _) => _json(_unauthorizedBody, 401));
      final (flow: flow, client: client, store: store) = makeFlow(
        server,
        saved: const AuthTokens(accessToken: 'dead-a', refreshToken: 'dead-r'),
      );

      await flow.restoreSession();

      expect(flow.stage, AppStage.login);
      expect(flow.isLoggedIn, isFalse);
      expect(client.accessToken, isNull);
      // 죽은 토큰을 남겨 두면 다음 실행에서 같은 실패를 반복한다.
      expect(await store.read(), isNull);
    });
  });

  group('401 → 재발급 → 재시도', () {
    test('만료된 토큰으로 부른 요청을 재발급 뒤 한 번 더 보낸다', () async {
      final server = _FakeServer((request, hits) => switch (request.url.path) {
            // 첫 호출만 만료. 재발급 뒤 두 번째는 통과한다.
            '/v1/orders' => hits == 1
                ? _json(_unauthorizedBody, 401)
                : _json('{"orders":[],"nextCursor":null}', 200),
            '/${UserApi.reissuePath}' => _json(
                '{"accessToken":"access-2","refreshToken":"refresh-2"}',
                200,
              ),
            _ => _json('{}', 200),
          });
      final (flow: flow, client: client, store: store) = makeFlow(
        server,
        saved: const AuthTokens(accessToken: 'old-a', refreshToken: 'old-r'),
      );

      // 저장된 토큰을 이번 실행에 꽂는다 (me 는 통과시켜 두었다).
      await flow.restoreSession();
      await flow.loadOrders();

      expect(server.hitsOf('v1/orders'), 2);
      expect(server.hitsOf(UserApi.reissuePath), 1);
      // 새 토큰으로 갈아탔고 저장된 것도 함께 바뀐다.
      expect(client.accessToken, 'access-2');
      expect((await store.read())?.accessToken, 'access-2');
    });

    test('재발급도 실패하면 로그아웃하고 로그인 화면으로 보낸다', () async {
      final server = _FakeServer((request, _) => switch (request.url.path) {
            '/${UserApi.mePath}' => _json(_meBody, 200),
            _ => _json(_unauthorizedBody, 401),
          });
      final (flow: flow, client: client, store: store) = makeFlow(
        server,
        saved: const AuthTokens(accessToken: 'old-a', refreshToken: 'old-r'),
      );
      await flow.restoreSession();
      expect(flow.stage, AppStage.yogiyoHome);

      // 목록을 부르다 401 → 재발급 실패. 화면을 붙잡고 있으면 조용히 빈 목록이 된다.
      await expectLater(flow.loadOrders(), throwsA(isA<ApiException>()));

      expect(flow.stage, AppStage.login);
      expect(flow.isLoggedIn, isFalse);
      expect(client.accessToken, isNull);
      expect(await store.read(), isNull);
    });

    test('요청 두 개가 동시에 401 을 받아도 재발급은 한 번만 돈다', () async {
      var refreshCalls = 0;
      final server = _FakeServer(
        (request, hits) =>
            hits == 1 ? _json(_unauthorizedBody, 401) : _json('{}', 200),
      );
      final client = ApiClient(baseUrl: 'http://server.test', httpClient: server.client)
        ..accessToken = 'expired'
        ..onUnauthorized = (() async {
          refreshCalls++;
          return true;
        });

      await Future.wait([client.get('v1/a'), client.get('v1/b')]);

      // 나란히 재발급하면 뒤에 온 응답이 앞의 토큰을 덮어써 방금 갱신한 토큰이 죽는다.
      expect(refreshCalls, 1);
      expect(server.hitsOf('v1/a'), 2);
      expect(server.hitsOf('v1/b'), 2);
    });

    test('재발급이 성공했는데도 401 이면 다시 시도하지 않는다', () async {
      // 경로가 틀린 경우다 — 서버는 없는 경로에도 401 을 준다.
      final server = _FakeServer((request, _) => _json(_unauthorizedBody, 401));
      final client = ApiClient(baseUrl: 'http://server.test', httpClient: server.client)
        ..accessToken = 'whatever'
        ..onUnauthorized = (() async => true);

      await expectLater(client.get('v1/nope'), throwsA(isA<ApiException>()));

      expect(server.hitsOf('v1/nope'), 2); // 최초 + 재발급 후 1회. 무한 반복이 아니다.
    });
  });

  group('로그아웃', () {
    test('토큰과 장바구니를 비우고 로그인 화면으로 간다', () async {
      final server = happyServer();
      final (flow: flow, client: client, store: store) = makeFlow(server);
      await flow.login(email: 'a@b.com', password: 'Test1234!');

      await flow.logout();

      expect(flow.stage, AppStage.login);
      expect(flow.isLoggedIn, isFalse);
      expect(flow.currentUser, isNull);
      expect(client.accessToken, isNull);
      expect(await store.read(), isNull);
      // 다음에 로그인한 사람이 남의 장바구니를 보면 안 된다.
      expect(flow.cart.stores, isEmpty);
      expect(flow.orders, isEmpty);
      expect(flow.popularPosts, isEmpty);
    });

    test('서버 로그아웃이 실패해도 앱은 토큰을 지운다', () async {
      // 서버가 토큰을 무효화하지 않으므로 실질적인 로그아웃은 토큰을 지우는 쪽이다.
      final server = _FakeServer((request, _) => switch (request.url.path) {
            '/${UserApi.logoutPath}' => _json('{"status":500}', 500),
            '/${UserApi.loginPath}' => _json(_loginBody, 200),
            '/${UserApi.mePath}' => _json(_meBody, 200),
            _ => _json('{}', 200),
          });
      final (flow: flow, client: client, store: store) = makeFlow(server);
      await flow.login(email: 'a@b.com', password: 'Test1234!');

      await flow.logout();

      expect(client.accessToken, isNull);
      expect(await store.read(), isNull);
      expect(flow.stage, AppStage.login);
    });
  });

  group('더미 — 서버 없이 도는 경로', () {
    test('빈 이메일·비밀번호는 자격 실패로 막는다', () async {
      final repo = MockAuthRepository(delay: Duration.zero);

      await expectLater(
        repo.login(email: '', password: ''),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401)),
      );
    });

    test('같은 이메일로 다시 가입하면 서버처럼 409 를 준다', () async {
      final repo = MockAuthRepository(delay: Duration.zero);
      await repo.signup(email: 'a@b.com', password: 'x', nickName: '나');

      await expectLater(
        repo.signup(email: 'A@B.com', password: 'x', nickName: '나'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 409)),
      );
    });

    test('더미로 돌 때는 토큰을 기기에 남기지 않는다', () async {
      // 더미 토큰으로 자동 로그인이 걸리면 시연에서 로그인 화면을 다시 볼 수 없다.
      final flow = AppFlow(
        locationService: const _NoLocation(),
        authRepository: MockAuthRepository(delay: Duration.zero),
      );

      await flow.login(email: 'a@b.com', password: 'x');
      expect(flow.stage, AppStage.yogiyoHome);

      // 새로 켠 앱과 같은 상태. 저장된 토큰이 없으니 로그인 화면에서 시작한다.
      final restarted = AppFlow(
        locationService: const _NoLocation(),
        authRepository: MockAuthRepository(delay: Duration.zero),
      );
      await restarted.restoreSession();
      expect(restarted.stage, AppStage.login);
    });
  });

  group('화면 이동', () {
    test('회원가입으로 갔다가 돌아온다', () {
      final flow = AppFlow(
        locationService: const _NoLocation(),
        authRepository: MockAuthRepository(delay: Duration.zero),
      );

      expect(flow.stage, AppStage.login);
      flow.openSignup();
      expect(flow.stage, AppStage.signup);
      flow.backToLogin();
      expect(flow.stage, AppStage.login);
    });
  });
}
