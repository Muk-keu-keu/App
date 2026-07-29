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
  });

  final double lat;
  final double lng;
  final LocationOrigin origin;

  /// 사용자가 직접 입력한 주소 문자열.
  ///
  /// **좌표 → 주소 변환(reverse geocoding)은 서버가 하는 것으로 가정한다.**
  /// 승중님 확인 전이라 앱은 좌표만 수집하고, 이 필드는 사용자가 직접 입력한
  /// 경우에만 채운다. GPS 로 얻은 위치는 빈 문자열이다.
  final String address;

  bool get hasAddress => address.trim().isNotEmpty;

  /// 화면에 보여줄 한 줄. 주소가 있으면 주소, 없으면 좌표.
  String get displayText =>
      hasAddress ? address : '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';

  /// API 쿼리·바디에 실을 형태. `address` 는 비어 있으면 키를 보내지 않는다.
  /// 서버가 좌표로 주소를 만드는 쪽이라 빈 문자열을 덮어쓰게 두면 안 된다.
  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
        if (hasAddress) 'address': address,
      };

  UserLocation copyWith({double? lat, double? lng, LocationOrigin? origin, String? address}) =>
      UserLocation(
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        origin: origin ?? this.origin,
        address: address ?? this.address,
      );

  /// 시연 더미 데이터가 강남·용산 기준이라, 리허설 장소가 달라도 맞출 수 있게
  /// 프리셋을 둔다. 디버그 빌드에서만 노출한다.
  static const debugPresets = <String, UserLocation>{
    '강남역': UserLocation(
      lat: 37.4979,
      lng: 127.0276,
      origin: LocationOrigin.debugOverride,
      address: '서울 강남구 강남대로 396',
    ),
    '용산역': UserLocation(
      lat: 37.5299,
      lng: 126.9648,
      origin: LocationOrigin.debugOverride,
      address: '서울 용산구 한강대로23길 55',
    ),
    '잠실새내역': UserLocation(
      lat: 37.5114,
      lng: 127.0863,
      origin: LocationOrigin.debugOverride,
      address: '서울 송파구 잠실동',
    ),
  };
}
