import 'package:image_picker/image_picker.dart';

/// 족보 작성·수정의 사진 첨부.
///
/// 두 화면이 같은 규칙(장수 제한·크기 축소·실패 처리)을 쓰도록 한 곳에 둔다.
/// 화면마다 `ImagePicker` 를 직접 부르면 한쪽만 리사이즈를 빠뜨리는 식으로 갈린다.
class PhotoPicker {
  const PhotoPicker();

  /// 서버가 받는 형식. `UploadImage.contentType` 이 확장자로 판단하므로
  /// 여기서 거른 것만 올라간다.
  static const _allowed = {'jpg', 'jpeg', 'png', 'webp'};

  /// 원본 그대로 올리면 요즘 폰 사진 한 장이 5MB 를 넘는다. 멀티파트로 여러 장을
  /// 한 요청에 실으므로 그대로 두면 업로드가 느려지고 타임아웃이 난다.
  /// 글에 붙는 사진은 화면 폭이면 충분하다.
  static const _maxEdge = 1600.0;
  static const _quality = 85;

  /// [remaining] 장까지 고른다. 사용자가 더 고르면 앞에서부터 자른다 —
  /// 골랐는데 조용히 사라지는 것보다 개수 제한이 있다는 걸 화면이 보여주는 쪽이 낫다.
  ///
  /// 취소하면 빈 목록이다. 예외는 던지지 않는다 — 사진 첨부가 실패해도 글쓰기
  /// 자체는 계속돼야 한다.
  Future<List<String>> pick({required int remaining}) async {
    if (remaining <= 0) return const [];

    try {
      final picked = await ImagePicker().pickMultiImage(
        maxWidth: _maxEdge,
        maxHeight: _maxEdge,
        imageQuality: _quality,
        limit: remaining,
      );

      return [
        for (final file in picked.take(remaining))
          if (_allowed.contains(file.path.toLowerCase().split('.').last)) file.path,
      ];
    } on Object {
      // 권한 거부·플랫폼 오류. 화면은 아무 일도 없던 것처럼 두고,
      // 사용자는 다시 누르거나 사진 없이 올릴 수 있다.
      return const [];
    }
  }
}
