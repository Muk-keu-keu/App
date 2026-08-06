/// HTTP 계층. 모든 서버 호출이 이 파일을 지난다.
///
/// 인증은 `Authorization: Bearer <accessToken>` 이다. 초기 명세에 `X-User-Id` 로
/// 적혀 있었으나 서버가 토큰 인증으로 구현되어 그쪽에 맞췄다.
/// 헤더를 만드는 자리는 [_headers] 하나뿐이다.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// 서버가 2xx 가 아닌 응답을 줬을 때.
class ApiException implements Exception {
  const ApiException({required this.statusCode, this.code, this.message, this.path});

  final int statusCode;

  /// 서버가 준 에러 코드. `U001` 처럼.
  final String? code;

  final String? message;
  final String? path;

  /// 그 리소스가 없는 경우. 메뉴 조회의 404 는 `restaurantId` 가 없을 때만 온다.
  bool get isNotFound => statusCode == 404;

  /// 다시 시도해 볼 만한지. 5xx 와 타임아웃만 재시도 대상이다.
  bool get isRetryable => statusCode >= 500;

  @override
  String toString() =>
      'ApiException($statusCode${code == null ? '' : ' $code'}) $path — ${message ?? ''}';
}

/// 네트워크가 아예 안 됐을 때. 서버 응답을 받지 못한 경우다.
class NetworkException implements Exception {
  const NetworkException(this.cause);

  final Object cause;

  @override
  String toString() => 'NetworkException — $cause';
}

/// `.env` 에 서버 주소가 없어 호출할 수 없는 상태.
///
/// 백엔드가 아직 없는 동안에는 이게 정상이다. 앱은 이 예외를 보고 더미 데이터로
/// 넘어간다 — 시연이 멈추지 않게 하려는 것이다.
class ApiNotConfiguredException implements Exception {
  const ApiNotConfiguredException();

  @override
  String toString() =>
      'ApiNotConfiguredException — .env 의 API_BASE_URL 이 비어 있습니다';
}

class ApiClient {
  ApiClient({
    required this.baseUrl,
    this.accessToken,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 15),
  }) : _http = httpClient ?? http.Client();

  /// `https://host/` 까지. 끝의 `/` 는 있어도 없어도 된다.
  final String baseUrl;

  /// 로그인으로 받은 액세스 토큰. 로그인 전에는 null 이다.
  ///
  /// 회원가입·로그인·토큰 재발급은 인증 없이 부르는 자리라 토큰이 없어야 정상이다.
  /// 그래서 없을 때 헤더를 아예 빼고, `Bearer null` 같은 값을 보내지 않는다.
  String? accessToken;

  final Duration timeout;
  final http.Client _http;

  bool get isConfigured => baseUrl.trim().isNotEmpty;

  /// 토큰을 들고 있는지. 로그인 여부와 같은 뜻이다.
  bool get isAuthenticated => (accessToken ?? '').trim().isNotEmpty;

  Map<String, String> get _headers => {
        'content-type': 'application/json',
        'accept': 'application/json',
        if (isAuthenticated) 'Authorization': 'Bearer ${accessToken!.trim()}',
      };

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final base = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    final clean = path.startsWith('/') ? path.substring(1) : path;
    final uri = Uri.parse('$base$clean');
    if (query == null || query.isEmpty) return uri;
    return uri.replace(
      queryParameters: {
        // null 인 쿼리는 아예 빼야 한다. `cursor=null` 을 보내면 서버가 문자열
        // "null" 을 커서로 받아 첫 페이지를 못 준다.
        for (final e in query.entries)
          if (e.value != null) e.key: '${e.value}',
      },
    );
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) async =>
      _send(() => _http.get(_uri(path, query), headers: _headers), path);

  Future<Map<String, dynamic>> post(String path, {Object? body}) async => _send(
        () => _http.post(
          _uri(path),
          headers: _headers,
          body: body == null ? null : jsonEncode(body),
        ),
        path,
      );

  Future<Map<String, dynamic>> patch(String path, {Object? body}) async => _send(
        () => _http.patch(
          _uri(path),
          headers: _headers,
          body: body == null ? null : jsonEncode(body),
        ),
        path,
      );

  Future<Map<String, dynamic>> delete(String path) async =>
      _send(() => _http.delete(_uri(path), headers: _headers), path);

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() call,
    String path,
  ) async {
    if (!isConfigured) throw const ApiNotConfiguredException();

    late final http.Response response;
    try {
      response = await call().timeout(timeout);
    } on Object catch (e) {
      // 타임아웃·DNS·연결 거부를 한 종류로 묶는다. 화면이 구분해 쓸 일이 없고,
      // 어느 쪽이든 "잠시 후 다시" 가 맞는 안내다.
      throw NetworkException(e);
    }

    final text = response.bodyBytes.isEmpty ? '' : utf8.decode(response.bodyBytes);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        statusCode: response.statusCode,
        code: _field(text, 'code'),
        message: _field(text, 'message'),
        path: path,
      );
    }

    // 204 No Content 와 빈 201 이 있다. 본문이 없으면 빈 맵으로 돌려준다.
    if (text.trim().isEmpty) return const {};

    final decoded = jsonDecode(text);
    // 목록 응답이 배열로 올 수도 있다. 호출한 쪽이 항상 맵을 기대하도록 감싼다.
    return decoded is Map<String, dynamic> ? decoded : {'items': decoded};
  }

  /// 에러 본문에서 필드 하나를 꺼낸다. 본문이 JSON 이 아니어도 터지지 않는다 —
  /// 게이트웨이가 HTML 오류 페이지를 주는 경우가 있다.
  static String? _field(String body, String key) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded[key] != null) return '${decoded[key]}';
    } catch (_) {
      // 무시하고 null 을 준다.
    }
    return null;
  }

  void close() => _http.close();
}
