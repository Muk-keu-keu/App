/// 주문 가능 여부를 판단할 사용자 위치.
///
/// 승중님 API 두 곳이 좌표를 요구한다 (`docs/api-yogijokbo.md` 미해결 5번).
/// - `GET /api/v1/posts` 의 `orderableOnly=true` → `lat` `lng` 필수
/// - `POST /api/v1/posts/{postId}/reorder` → body `lat` `lng`
library;

/// 좌표를 어떻게 얻었는지. 화면 표기와 디버깅에 쓴다.
enum LocationOrigin {
  /// 기기 GPS
  gps('현재 위치'),

  /// 권한 거부 등으로 사용자가 주소를 직접 입력
  manual('직접 입력'),

  /// 디버그 빌드의 좌표 override (시연 리허설용)
  debugOverride('디버그 지정');

  const LocationOrigin(this.label);

  final String label;
}

class UserLocation {
  const UserLocation({
    required this.lat,
    required this.lng,
    required this.origin,
    this.address = '',
    this.placeLabel = '',
  });

  final double lat;
  final double lng;
  final LocationOrigin origin;

  /// 화면에 보여줄 동네 이름. "연수구 송도동" 같은 형태.
  ///
  /// **표시 전용이다. 서버로 보내지 않는다.** 좌표만 보내는 계약은 그대로 두고,
  /// 사용자가 "내 위치가 제대로 잡혔구나"를 알 수 있게 하려고 둔 값이다.
  /// 숫자 좌표만 보여주면 위치가 인식됐는지 판단할 수 없다.
  ///
  /// OS 지오코더로 채운다. 실패하면 빈 문자열이고 좌표를 대신 보여준다.
  final String placeLabel;

  bool get hasPlaceLabel => placeLabel.trim().isNotEmpty;

  /// 사용자가 직접 입력한 주소 문자열.
  ///
  /// **좌표 → 주소 변환(reverse geocoding)은 서버가 하는 것으로 가정한다.**
  /// 승중님 확인 전이라 앱은 좌표만 수집하고, 이 필드는 사용자가 직접 입력한
  /// 경우에만 채운다. GPS 로 얻은 위치는 빈 문자열이다.
  final String address;

  bool get hasAddress => address.trim().isNotEmpty;

  /// 화면에 보여줄 한 줄.
  ///
  /// 순서 — 직접 입력한 주소 → 지오코딩으로 얻은 동네 이름 → 좌표.
  /// 좌표는 마지막 수단이다. 숫자만 보이면 사용자가 위치를 인식했는지 알 수 없다.
  String get displayText {
    if (hasAddress) return address;
    if (hasPlaceLabel) return placeLabel;
    return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
  }

  /// API 쿼리·바디에 실을 형태. `address` 는 비어 있으면 키를 보내지 않는다.
  /// 서버가 좌표로 주소를 만드는 쪽이라 빈 문자열을 덮어쓰게 두면 안 된다.
  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
        if (hasAddress) 'address': address,
      };

  UserLocation copyWith({
    double? lat,
    double? lng,
    LocationOrigin? origin,
    String? address,
    String? placeLabel,
  }) =>
      UserLocation(
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        origin: origin ?? this.origin,
        address: address ?? this.address,
        placeLabel: placeLabel ?? this.placeLabel,
      );

  /// 시연 더미 데이터가 강남·용산 기준이라, 리허설 장소가 달라도 맞출 수 있게
  /// 프리셋을 둔다. 디버그 빌드에서만 노출한다.
  ///
  /// 이름은 `placeLabel`(표시용)에 넣는다. `address` 에 넣으면 사용자가 직접 입력한
  /// 주소로 취급돼 서버 요청에 실린다. 프리셋은 GPS 를 흉내내는 것이므로
  /// 좌표만 보내는 쪽이 맞다.
  static const debugPresets = <String, UserLocation>{
    '강남역': UserLocation(
      lat: 37.4979,
      lng: 127.0276,
      origin: LocationOrigin.debugOverride,
      placeLabel: '강남구 역삼동',
    ),
    '용산역': UserLocation(
      lat: 37.5299,
      lng: 126.9648,
      origin: LocationOrigin.debugOverride,
      placeLabel: '용산구 한강로3가',
    ),
    '잠실새내역': UserLocation(
      lat: 37.5114,
      lng: 127.0863,
      origin: LocationOrigin.debugOverride,
      placeLabel: '송파구 잠실동',
    ),
  };
}
