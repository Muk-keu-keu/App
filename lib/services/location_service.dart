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

  /// 한국 주소에서 사용자가 알아보는 단위(구·동)만 골라낸다.
  ///
  /// **필드 배치가 플랫폼마다 다르다.** iOS 는 `locality` 에 시(서울특별시)를 넣고
  /// 구는 `subAdministrativeArea` 로 보낸다. Android 는 `locality` 에 구가 오기도 한다.
  /// 그래서 필드 이름이 아니라 **접미사(구·군)로 판별**한다.
  ///
  /// "서울특별시 삼성동" 보다 "강남구 삼성동" 이 배달 맥락에서 훨씬 유용하다.
  /// 시·도는 구를 못 찾았을 때의 마지막 수단이다.
  static String formatPlacemark(Placemark mark) {
    String clean(String? v) => (v ?? '').trim();

    bool isDistrict(String v) => v.endsWith('구') || v.endsWith('군');

    // 구 후보 — 플랫폼에 따라 들어오는 자리가 달라 둘 다 본다.
    final district = [
      clean(mark.subAdministrativeArea),
      clean(mark.locality),
    ].firstWhere((v) => v.isNotEmpty && isDistrict(v), orElse: () => '');

    final neighborhood = clean(mark.subLocality);

    final parts = <String>[];
    if (district.isNotEmpty) parts.add(district);
    // 같은 값이 두 자리에 들어와 "강남구 강남구" 가 되는 것을 막는다.
    if (neighborhood.isNotEmpty && neighborhood != district) parts.add(neighborhood);

    if (parts.isNotEmpty) return parts.join(' ');

    // 구·동을 못 얻었다. 시·도라도 보여준다.
    final city = clean(mark.locality);
    if (city.isNotEmpty) return city;
    return clean(mark.administrativeArea);
  }
}
