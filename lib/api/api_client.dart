/// HTTP 계층. 모든 서버 호출이 이 파일을 지난다.
///
/// 인증 헤더가 한 곳에만 있는 게 중요하다. 명세 표는 `User-Id`, Request example 은
/// `X-User-Id` 로 섞여 있어 example 쪽으로 통일했다 (`docs/api-spec.md` 확인 필요 항목).
/// 나중에 로그인이 붙어 `Authorization: Bearer` 로 바뀌어도 고칠 자리는 [_headers] 하나다.
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
    this.userId = 1,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 15),
  }) : _http = httpClient ?? http.Client();

  /// `https://host/` 까지. 끝의 `/` 는 있어도 없어도 된다.
  final String baseUrl;

  /// `X-User-Id` 로 나갈 값. 로그인이 붙으면 토큰으로 바뀐다.
  int userId;

  final Duration timeout;
  final http.Client _http;

  bool get isConfigured => baseUrl.trim().isNotEmpty;

  Map<String, String> get _headers => {
        'content-type': 'application/json',
        'accept': 'application/json',
        'X-User-Id': '$userId',
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
