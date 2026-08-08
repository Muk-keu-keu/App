import 'dart:convert';

import 'package:http/http.dart' as http;

class PageMetadata {
  const PageMetadata({this.title, this.description, this.siteName, this.imageUrl});

  final String? title;
  final String? description;
  final String? siteName;

  /// og:image. 릴스 썸네일이 곧 그 음식 사진이라 결과 카드에 그대로 쓴다.
  final String? imageUrl;

  String get combinedText =>
      [siteName, title, description].where((e) => e != null && e.isNotEmpty).join('\n');

  bool get isEmpty => (title == null || title!.isEmpty) && (description == null || description!.isEmpty);
}

/// 공유된 링크의 og 태그(유튜브는 oEmbed)에서 제목·설명·계정명을 긁어온다.
/// iOS 앱 MetadataFetcher.swift 와 같은 규칙이다.
class MetadataFetcher {
  const MetadataFetcher();

  static const _userAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 '
      '(KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1';

  Future<PageMetadata> fetch(Uri url) async {
    final oembed = _youtubeOEmbedUrl(url);
    if (oembed != null) {
      final meta = await _fetchYouTube(oembed);
      if (meta != null) return meta;
    }

    final response = await http
        .get(url, headers: {'User-Agent': _userAgent})
        .timeout(const Duration(seconds: 10));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('메타데이터 HTTP ${response.statusCode}');
    }

    final html = utf8.decode(response.bodyBytes, allowMalformed: true);
    var meta = parseOgTags(html);

    // 인스타그램은 로그아웃 요청에 캡션/제목을 주지 않는다.
    // og:url 의 계정명이라도 살려 신호로 쓴다.
    if (meta.isEmpty) {
      final handle = instagramHandle(html);
      if (handle != null) {
        meta = PageMetadata(
          title: '인스타그램 @$handle 맛집 게시물',
          siteName: meta.siteName,
          imageUrl: meta.imageUrl,
        );
      }
    }

    if (meta.isEmpty) throw Exception('본문이 비어 있습니다');
    return meta;
  }

  static PageMetadata parseOgTags(String html) => PageMetadata(
        title: ogContent(html, 'og:title') ?? htmlTitle(html),
        description: ogContent(html, 'og:description'),
        siteName: ogContent(html, 'og:site_name'),
        imageUrl: ogContent(html, 'og:image'),
      );

  static String? ogContent(String html, String property) {
    final patterns = [
      RegExp('<meta[^>]*property=["\']$property["\'][^>]*content=["\']([^"\']*)["\']',
          caseSensitive: false, dotAll: true),
      RegExp('<meta[^>]*content=["\']([^"\']*)["\'][^>]*property=["\']$property["\']',
          caseSensitive: false, dotAll: true),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(html);
      final v = m?.group(1);
      if (v != null && v.isNotEmpty) return decodeEntities(v);
    }
    return null;
  }

  static String? htmlTitle(String html) {
    final m = RegExp(r'<title[^>]*>([^<]*)</title>', caseSensitive: false, dotAll: true)
        .firstMatch(html);
    final v = m?.group(1);
    return v == null ? null : decodeEntities(v);
  }

  /// og:url = https://www.instagram.com/<handle>/p/... 에서 계정명 추출
  static String? instagramHandle(String html) {
    final ogUrl = ogContent(html, 'og:url');
    if (ogUrl == null) return null;
    final uri = Uri.tryParse(ogUrl);
    if (uri == null || !uri.host.contains('instagram.com')) return null;
    final parts = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return null;
    const reserved = {'p', 'reel', 'tv', 'explore'};
    return reserved.contains(parts.first) ? null : parts.first;
  }

  /// HTML 엔티티를 되돌린다. 이름 있는 것과 숫자 참조(`&#12345;` · `&#xc384;`)를 모두 본다.
  ///
  /// **숫자 참조가 중요하다.** 인스타그램은 og 태그의 한글을 전부 `&#xc384;` 같은
  /// 16진수 참조로 내려준다. 이름 목록만 보고 있으면 캡션이 인코딩된 채로 Gemini 에
  /// 들어간다. 그래도 추출은 되지만 같은 문장이 열 배 넘는 토큰을 먹고, 무엇보다
  /// 화면에 그 문자열을 그대로 그리면 사람이 읽을 수 없다.
  static String decodeEntities(String s) {
    const named = {
      '&amp;': '&',
      '&quot;': '"',
      '&apos;': "'",
      '&lt;': '<',
      '&gt;': '>',
      '&nbsp;': ' ',
    };

    // 숫자 참조를 먼저 푼다. `&amp;#39;` 처럼 이중 인코딩된 경우 이름 치환이
    // 앞서면 `&#39;` 가 되어 한 번 더 풀려야 하는데, 순서를 이렇게 두면 그 경우도
    // 다음 줄에서 정리된다.
    var out = s.replaceAllMapped(
      // 16진수 접두사는 대소문자 둘 다 유효하다 (`&#x41;` · `&#X41;`).
      RegExp(r'&#([xX][0-9a-fA-F]+|[0-9]+);'),
      (m) {
        final raw = m.group(1)!;
        final isHex = raw.startsWith('x') || raw.startsWith('X');
        final code = isHex
            ? int.tryParse(raw.substring(1), radix: 16)
            : int.tryParse(raw);
        // 유효한 유니코드 스칼라만 되돌린다. 서로게이트 영역은 문자로 만들 수 없다.
        if (code == null || code < 0 || code > 0x10FFFF) return m.group(0)!;
        if (code >= 0xD800 && code <= 0xDFFF) return m.group(0)!;
        return String.fromCharCode(code);
      },
    );

    named.forEach((k, v) => out = out.replaceAll(k, v));
    return out;
  }

  Uri? _youtubeOEmbedUrl(Uri url) {
    if (!url.host.contains('youtube.com') && !url.host.contains('youtu.be')) return null;
    return Uri.https('www.youtube.com', '/oembed', {
      'url': url.toString(),
      'format': 'json',
    });
  }

  Future<PageMetadata?> _fetchYouTube(Uri oembed) async {
    try {
      final response = await http.get(oembed).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final title = json['title'] as String?;
      if (title == null || title.isEmpty) return null;
      return PageMetadata(
        title: title,
        description: json['author_name'] as String?,
        siteName: 'YouTube',
        imageUrl: json['thumbnail_url'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}
