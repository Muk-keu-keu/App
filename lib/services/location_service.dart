import 'package:flutter/widgets.dart' show Locale;
import 'package:geocoding/geocoding.dart';
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
          // 좌표만 보여주면 위치가 잡혔는지 사용자가 알 수 없어 동네 이름을 함께 채운다.
          placeLabel: await describePlace(position.latitude, position.longitude),
        ),
      );
    } catch (_) {
      // 타임아웃·실내 등. 권한은 있으니 다시 시도할 수 있다.
      return const LocationResult.failed(LocationFailure.unavailable);
    }
  }

  /// 좌표를 "구 동" 형태로 바꾼다. 실패하면 빈 문자열.
  ///
  /// **표시 전용이다.** 서버로는 좌표만 보낸다.
  /// OS 지오코더를 쓰므로 API 키가 필요 없고, 대신 네트워크가 없거나 기기가
  /// 지오코딩을 지원하지 않으면 실패한다. 그때는 화면이 좌표를 그대로 보여준다 —
  /// 동네 이름 하나 때문에 위치 수집 전체를 실패로 만들 이유가 없다.
  static Future<String> describePlace(double lat, double lng) async {
    try {
      // geocoding 5.x 는 최상위 함수가 아니라 Geocoding 인스턴스를 쓴다.
      // 로케일을 한국어로 고정해 기기 언어와 무관하게 "연수구 송도동"으로 받는다.
      final marks = await Geocoding(locale: const Locale('ko', 'KR'))
          .placemarkFromCoordinates(lat, lng);
      if (marks.isEmpty) return '';
      return formatPlacemark(marks.first);
    } catch (_) {
      return '';
    }
  }

  /// 한국 주소에서 사용자가 알아보는 단위만 골라낸다.
  ///
  /// 한국은 보통 `locality` 가 시·구, `subLocality` 가 동으로 온다.
  /// "인천광역시 연수구 송도동 123-4" 전체를 상단 바에 넣으면 잘리므로
  /// **구·동 두 조각만** 쓴다. 둘 다 없으면 광역시/도라도 보여준다.
  static String formatPlacemark(Placemark mark) {
    final parts = [
      mark.locality, // 연수구
      mark.subLocality, // 송도동
    ].whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    if (parts.isEmpty) {
      // 구·동을 못 얻은 경우. 시·도라도 있으면 그걸 쓴다.
      final fallback = (mark.administrativeArea ?? '').trim();
      return fallback;
    }

    // locality 와 subLocality 가 같은 값으로 올 수 있어 "연수구 연수구"가 되는 것을 막는다.
    final unique = <String>[];
    for (final part in parts) {
      if (!unique.contains(part)) unique.add(part);
    }
    return unique.join(' ');
  }
}
