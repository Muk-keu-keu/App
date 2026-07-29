import 'package:geolocator/geolocator.dart';

import '../models/user_location.dart';

/// 권한 요청 결과. 화면이 다음 행동을 고르는 데 쓴다.
enum LocationFailure {
  /// 사용자가 이번에 거부. 다시 물어볼 수 있다.
  denied,

  /// 영구 거부. 앱 설정에서만 바꿀 수 있으니 다시 묻지 말고 주소 입력으로 보낸다.
  deniedForever,

  /// 기기 위치 서비스 자체가 꺼져 있음.
  serviceDisabled,

  /// 권한은 있으나 좌표를 얻지 못함 (실내·타임아웃 등).
  unavailable,
}

/// 좌표 획득 결과. 성공이면 [location], 실패면 [failure] 중 하나가 채워진다.
class LocationResult {
  const LocationResult.success(this.location) : failure = null;
  const LocationResult.failed(this.failure) : location = null;

  final UserLocation? location;
  final LocationFailure? failure;

  bool get isSuccess => location != null;

  /// 다시 물어봐야 소용없는 실패인지. true 면 주소 직접 입력으로 유도한다.
  bool get needsManualInput =>
      failure == LocationFailure.deniedForever || failure == LocationFailure.serviceDisabled;
}

/// 기기 좌표를 가져온다.
///
/// 주소 변환(reverse geocoding)은 하지 않는다. **서버가 좌표로 주소를 만드는 것으로
/// 가정**하고 앱은 좌표만 수집한다 (승중님 확인 전). 그래서 geocoding 패키지도 넣지 않았다.
///
/// 테스트에서 갈아끼울 수 있도록 [LocationService] 를 인터페이스로 두고
/// 실제 구현을 [GeolocatorLocationService] 로 분리했다.
abstract class LocationService {
  Future<LocationResult> current();
}

class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  @override
  Future<LocationResult> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const LocationResult.failed(LocationFailure.serviceDisabled);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      return const LocationResult.failed(LocationFailure.deniedForever);
    }
    if (permission == LocationPermission.denied) {
      return const LocationResult.failed(LocationFailure.denied);
    }

    try {
      // 배달 가능 여부 판단에는 동네 수준이면 충분하다. 정확도를 최고로 올리면
      // 실내에서 오래 붙잡혀 로그인 직후 흐름이 눈에 띄게 느려진다.
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return LocationResult.success(
        UserLocation(
          lat: position.latitude,
          lng: position.longitude,
          origin: LocationOrigin.gps,
        ),
      );
    } catch (_) {
      // 타임아웃·실내 등. 권한은 있으니 다시 시도할 수 있다.
      return const LocationResult.failed(LocationFailure.unavailable);
    }
  }
}
