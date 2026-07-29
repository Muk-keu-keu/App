/// 분석의 **입력**. AI 추출 결과(`ExtractionResult`)와 짝을 이루는 값이다.
///
/// 승중님 요청(2026-07-30): 서버에 분석을 넘길 때 추출 결과만이 아니라
/// **원문 텍스트도 함께** 보내야 한다. 인스타가 로그아웃 요청에 캡션을 주지 않아
/// 앱이 모은 텍스트가 빈약할 때, 서버가 자체 세션으로 다시 긁어 보완할 수 있어야
/// 하기 때문이다. (`docs/extraction.md` 의 "알려진 한계" 참고)
///
/// 그래서 `AppFlow` 는 Gemini 에 넣은 텍스트를 버리지 않고 이 객체로 들고 있는다.
library;

/// 링크 출처. 서버가 재수집 전략을 고르는 데 쓴다.
///
/// 문자열 값은 대문자 스네이크다. `docs/api-yogijokbo.md` 의 공통 규칙
/// "enum 은 대문자 스네이크" 를 따른다.
enum SourcePlatform {
  instagram('INSTAGRAM'),
  youtube('YOUTUBE'),
  other('OTHER');

  const SourcePlatform(this.wire);

  /// 서버로 보내는 값.
  final String wire;

  /// 호스트로 판별한다. 단축 도메인(youtu.be)도 함께 본다.
  static SourcePlatform fromUrl(Uri url) {
    final host = url.host.toLowerCase();
    if (host.contains('instagram.com')) return SourcePlatform.instagram;
    if (host.contains('youtube.com') || host.contains('youtu.be')) {
      return SourcePlatform.youtube;
    }
    return SourcePlatform.other;
  }
}

class AnalysisSource {
  const AnalysisSource({
    required this.url,
    required this.platform,
    required this.rawText,
  });

  /// 공유받은 원본 링크.
  final String url;

  final SourcePlatform platform;

  /// **Gemini 에 실제로 넣은 텍스트 그대로.**
  /// `PageMetadata.combinedText` (siteName + title + description) 다.
  /// 서버가 추출을 다시 돌리거나 품질을 검증할 때 이 값이 있어야 재현이 된다.
  final String rawText;

  /// 앱이 텍스트를 거의 못 건진 경우. 서버 쪽 재수집이 필요하다는 신호다.
  /// 인스타 캡션이 막혔을 때 계정명 한 줄만 남는 상황을 잡아낸다.
  bool get isThin => rawText.trim().length < 20;

  AnalysisSource copyWith({String? url, SourcePlatform? platform, String? rawText}) =>
      AnalysisSource(
        url: url ?? this.url,
        platform: platform ?? this.platform,
        rawText: rawText ?? this.rawText,
      );

  factory AnalysisSource.fromUrl({required Uri url, required String rawText}) =>
      AnalysisSource(
        url: url.toString(),
        platform: SourcePlatform.fromUrl(url),
        rawText: rawText,
      );

  /// 서버 `POST /api/v1/analyses` 의 `source` 에 그대로 들어갈 형태.
  Map<String, dynamic> toJson() => {
        'url': url,
        'platform': platform.wire,
        'rawText': rawText,
      };
}
