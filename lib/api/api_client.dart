/// HTTP 계층. 모든 서버 호출이 이 파일을 지난다.
///
/// 인증은 `Authorization: Bearer <accessToken>` 이다. 초기 명세에 `X-User-Id` 로
/// 적혀 있었으나 서버가 토큰 인증으로 구현되어 그쪽에 맞췄다.
/// 헤더를 만드는 자리는 [_headers] 하나뿐이다.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

/// multipart 로 올릴 사진 한 장.
///
/// 기기에서 고른 파일이거나, **이미 서버에 있던 사진을 다시 받아 온 바이트**다.
/// 게시물 수정(`PATCH v1/posts/{id}`)이 남길 사진을 전부 파일로 다시 보내야 해서
/// 두 가지가 다 필요하다.
class UploadImage {
  const UploadImage.file(String path)
      : _path = path,
        _bytes = null,
        givenFilename = null;

  const UploadImage.bytes(List<int> bytes, {required String filename})
      : _bytes = bytes,
        givenFilename = filename,
        _path = null;

  final String? _path;
  final List<int>? _bytes;

  /// 바이트로 올릴 때 부르는 쪽이 정한 이름. 파일 경로로 올릴 때는 null 이고
  /// 경로의 마지막 조각을 쓴다.
  final String? givenFilename;

  String get filename => givenFilename ?? _path!.split('/').last;

  /// 파트의 `Content-Type`. 확장자로 정한다.
  ///
  /// http 패키지는 이 값을 추측하지 않고 `application/octet-stream` 을 넣는다.
  /// 서버는 jpg/jpeg/png/webp 만 받으므로 그대로 보내면 형식 검증에 걸린다.
  MediaType get contentType => switch (filename.toLowerCase().split('.').last) {
        'png' => MediaType('image', 'png'),
        'webp' => MediaType('image', 'webp'),
        'jpg' || 'jpeg' => MediaType('image', 'jpeg'),
        // 확장자를 모르면 서버가 판단하도록 일반 형식으로 둔다.
        _ => MediaType('application', 'octet-stream'),
      };

  Future<http.MultipartFile> toPart(String field) async => _path != null
      ? http.MultipartFile.fromPath(field, _path, contentType: contentType)
      : http.MultipartFile.fromBytes(
          field,
          _bytes!,
          filename: filename,
          contentType: contentType,
        );
}

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

  /// 토큰이 없거나 못 쓰는 상태. 서버가 `AUTHENTICATION_REQUIRED` 로 준다.
  ///
  /// **경로가 틀렸을 때도 401 이 온다.** 보안 필터가 라우팅보다 먼저 돌아서
  /// 오타 난 경로와 권한 없는 경로가 구분되지 않는다. 이 값만 보고 "로그인이
  /// 풀렸다" 로 단정하면 안 되고, 재발급이 실패하는 것으로 걸러진다.
  bool get isUnauthorized => statusCode == 401;

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

  /// 401 을 받았을 때 토큰을 되살릴 기회를 주는 자리.
  ///
  /// `true` 를 돌려주면 같은 요청을 **한 번만** 다시 보낸다. 재발급 자체를 여기
  /// 넣지 않은 이유는 HTTP 계층이 로그인 도메인을 몰라야 하기 때문이다 —
  /// 실제 재발급은 [AppFlow] 가 꽂아 준다.
  Future<bool> Function()? onUnauthorized;

  /// 진행 중인 재발급. 여러 요청이 동시에 401 을 받아도 재발급은 한 번만 돈다.
  ///
  /// 이게 없으면 화면 진입 때 나란히 나가는 호출(주문 목록 + 인기 조합)이 각각
  /// 재발급을 불러, 뒤에 온 응답이 앞의 토큰을 덮어쓰면서 방금 갱신한 토큰이 죽는다.
  Future<bool>? _refreshing;

  bool get isConfigured => baseUrl.trim().isNotEmpty;

  /// 토큰을 들고 있는지. 로그인 여부와 같은 뜻이다.
  bool get isAuthenticated => (accessToken ?? '').trim().isNotEmpty;

  Map<String, String> _headers({bool authenticated = true}) => {
        'content-type': 'application/json',
        'accept': 'application/json',
        if (authenticated && isAuthenticated)
          'Authorization': 'Bearer ${accessToken!.trim()}',
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

  /// [authenticated] 가 false 면 `Authorization` 헤더를 아예 빼고, 401 재발급도 하지
  /// 않는다. 로그인·회원가입·재발급이 그렇다 — 만료된 토큰을 실어 보내면 그 토큰
  /// 때문에 로그인 자체가 401 이 된다.
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
    bool authenticated = true,
  }) async =>
      _send(
        () => _http.get(_uri(path, query), headers: _headers(authenticated: authenticated)),
        path,
        authenticated: authenticated,
      );

  Future<Map<String, dynamic>> post(
    String path, {
    Object? body,
    bool authenticated = true,
  }) async =>
      _send(
        () => _http.post(
          _uri(path),
          headers: _headers(authenticated: authenticated),
          body: body == null ? null : jsonEncode(body),
        ),
        path,
        authenticated: authenticated,
      );

  /// `multipart/form-data` 로 보낸다. 파일이 없어도 multipart 다.
  ///
  /// **`Content-Type` 을 직접 넣지 않는다.** 손으로 지정하면 `boundary` 가 빠져
  /// 400 이 난다 — 구분선은 http 패키지가 만들어 붙인다. 그래서 [_headers] 를 쓰지
  /// 않고 인증 헤더만 얹는다 ([_headers] 는 `application/json` 을 넣는다).
  ///
  /// 요청 객체는 한 번만 보낼 수 있고 파일 스트림도 한 번만 읽힌다. 401 재발급 뒤
  /// 재시도가 같은 요청을 다시 보내야 하므로 클로저 안에서 매번 새로 조립한다.
  Future<Map<String, dynamic>> multipart(
    String path, {
    String method = 'POST',
    Map<String, String> fields = const {},
    List<UploadImage> images = const [],
    String fileField = 'images',
  }) async =>
      _send(() async {
        final request = http.MultipartRequest(method, _uri(path))
          ..fields.addAll(fields)
          ..headers['accept'] = 'application/json';
        if (isAuthenticated) {
          request.headers['Authorization'] = 'Bearer ${accessToken!.trim()}';
        }
        for (final image in images) {
          request.files.add(await image.toPart(fileField));
        }
        return http.Response.fromStream(await _http.send(request));
      }, path);

  /// 이미 올라가 있는 사진을 바이트로 다시 받아 온다.
  ///
  /// 게시물 수정은 남길 사진을 파일로 다시 보내야 하는데, 앱은 그 사진을 URL 로만
  /// 안다. CDN 주소라 **인증 헤더를 붙이지 않는다.** 실패하면 null 이다 —
  /// 부르는 쪽이 "사진을 지키지 못한다" 를 판단해야 한다.
  Future<List<int>?> fetchBytes(String url) async {
    try {
      final response = await _http.get(Uri.parse(url)).timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      return response.bodyBytes;
    } on Object {
      return null;
    }
  }

  Future<Map<String, dynamic>> patch(String path, {Object? body}) async => _send(
        () => _http.patch(
          _uri(path),
          headers: _headers(),
          body: body == null ? null : jsonEncode(body),
        ),
        path,
      );

  Future<Map<String, dynamic>> delete(String path) async =>
      _send(() => _http.delete(_uri(path), headers: _headers()), path);

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() call,
    String path, {
    bool authenticated = true,
    bool retrying = false,
  }) async {
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

    // 401 이면 토큰을 되살려 한 번만 다시 보낸다. `retrying` 이 재시도의 재시도를 막는다 —
    // 재발급이 성공했는데도 401 이 계속 오면 경로가 틀린 것이므로 그대로 던진다.
    if (response.statusCode == 401 && authenticated && !retrying) {
      if (await _refresh()) {
        return _send(call, path, authenticated: authenticated, retrying: true);
      }
    }

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

  /// 토큰 재발급을 한 번만 돌린다. 이미 돌고 있으면 그 결과를 함께 기다린다.
  Future<bool> _refresh() {
    final handler = onUnauthorized;
    if (handler == null) return Future.value(false);

    // 재발급 중에 들어온 요청은 새 호출을 만들지 않고 같은 Future 를 본다.
    return _refreshing ??= handler().catchError((Object _) => false).whenComplete(() {
      _refreshing = null;
    });
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
