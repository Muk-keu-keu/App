import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:mukbang_ttaradamgi/app_flow.dart';
import 'package:mukbang_ttaradamgi/models/user_location.dart';
import 'package:mukbang_ttaradamgi/services/location_service.dart';

/// 실제 GPS 없이 결과만 정해 주는 대역.
class _FakeLocationService implements LocationService {
  _FakeLocationService(this.result);

  final LocationResult result;
  int calls = 0;

  @override
  Future<LocationResult> current() async {
    calls++;
    return result;
  }
}

const _seoul = UserLocation(lat: 37.5114, lng: 127.0863, origin: LocationOrigin.gps);

void main() {
  AppFlow flowWith(LocationResult result) =>
      AppFlow(locationService: _FakeLocationService(result));

  group('UserLocation', () {
    test('GPS 로 얻은 위치는 주소가 비어 있다 — 변환은 서버가 한다', () {
      expect(_seoul.hasAddress, isFalse);
      expect(_seoul.toJson().containsKey('address'), isFalse);
    });

    test('주소가 있으면 toJson 에 함께 실린다', () {
      const manual = UserLocation(
        lat: 0,
        lng: 0,
        origin: LocationOrigin.manual,
        address: '서울 송파구 잠실동 40-1',
      );
      expect(manual.toJson(), {'lat': 0.0, 'lng': 0.0, 'address': '서울 송파구 잠실동 40-1'});
    });

    test('동네 이름이 있으면 좌표 대신 그걸 보여준다', () {
      // 숫자 좌표만 보이면 위치가 잡혔는지 사용자가 알 수 없다.
      expect(_seoul.copyWith(placeLabel: '송파구 잠실동').displayText, '송파구 잠실동');
    });

    test('직접 입력한 주소가 동네 이름보다 우선한다', () {
      final both = _seoul.copyWith(
        address: '서울 송파구 잠실동 40-1',
        placeLabel: '송파구 잠실동',
      );
      expect(both.displayText, '서울 송파구 잠실동 40-1');
    });

    test('둘 다 없으면 마지막 수단으로 좌표를 보여준다', () {
      expect(_seoul.displayText, '37.5114, 127.0863');
    });

    test('표시용 동네 이름은 서버로 보내지 않는다', () {
      // 좌표만 보내는 계약을 지킨다. placeLabel 은 화면 전용이다.
      final json = _seoul.copyWith(placeLabel: '송파구 잠실동').toJson();
      expect(json.containsKey('placeLabel'), isFalse);
      expect(json.containsKey('address'), isFalse);
      expect(json.keys, containsAll(['lat', 'lng']));
    });

    test('디버그 프리셋은 시연 기준 동네를 담고 있다', () {
      expect(UserLocation.debugPresets.keys, containsAll(['강남역', '용산역']));
      for (final preset in UserLocation.debugPresets.values) {
        expect(preset.origin, LocationOrigin.debugOverride);
        expect(preset.lat, greaterThan(37));
        expect(preset.lng, greaterThan(126));
        // 이름은 표시용이라 서버 요청에 실리지 않아야 한다
        expect(preset.hasPlaceLabel, isTrue);
        expect(preset.hasAddress, isFalse);
      }
    });
  });

  group('좌표 → 구·동 변환', () {
    Placemark mark({
      String? locality,
      String? subLocality,
      String? subAdministrativeArea,
      String? administrativeArea,
    }) =>
        Placemark(
          locality: locality,
          subLocality: subLocality,
          subAdministrativeArea: subAdministrativeArea,
          administrativeArea: administrativeArea,
        );

    test('iOS 배치 — 구가 subAdministrativeArea 로 온다', () {
      // 실제 iOS 시뮬레이터 관측값. locality 에 시가 들어와 그대로 쓰면
      // "서울특별시 삼성동" 이 된다. 배달 맥락에서는 구가 필요하다.
      expect(
        GeolocatorLocationService.formatPlacemark(
          mark(
            administrativeArea: '서울특별시',
            locality: '서울특별시',
            subAdministrativeArea: '강남구',
            subLocality: '삼성동',
          ),
        ),
        '강남구 삼성동',
      );
    });

    test('Android 배치 — 구가 locality 로 온다', () {
      expect(
        GeolocatorLocationService.formatPlacemark(
          mark(locality: '연수구', subLocality: '송도동'),
        ),
        '연수구 송도동',
      );
    });

    test('동만 있으면 동만 보여준다', () {
      expect(
        GeolocatorLocationService.formatPlacemark(mark(subLocality: '잠실동')),
        '잠실동',
      );
    });

    test('구와 동이 같은 값으로 오면 한 번만 쓴다', () {
      expect(
        GeolocatorLocationService.formatPlacemark(
          mark(locality: '연수구', subLocality: '연수구'),
        ),
        '연수구',
      );
    });

    test('구를 못 얻으면 동만 보여준다 — 시는 앞에 붙이지 않는다', () {
      expect(
        GeolocatorLocationService.formatPlacemark(
          mark(locality: '서울특별시', subLocality: '삼성동'),
        ),
        '삼성동',
      );
    });

    test('구·동을 못 얻으면 시·도라도 보여준다', () {
      expect(
        GeolocatorLocationService.formatPlacemark(mark(administrativeArea: '인천광역시')),
        '인천광역시',
      );
      expect(
        GeolocatorLocationService.formatPlacemark(mark(locality: '세종특별자치시')),
        '세종특별자치시',
      );
    });

    test('아무것도 없으면 빈 문자열 — 화면이 좌표로 되돌아간다', () {
      expect(GeolocatorLocationService.formatPlacemark(mark()), '');
      expect(
        GeolocatorLocationService.formatPlacemark(
          mark(locality: '  ', subLocality: ''),
        ),
        '',
      );
    });
  });

  group('AppFlow — 위치 수집', () {
    test('로그인하면 위치를 1회 수집한다', () async {
      final service = _FakeLocationService(const LocationResult.success(_seoul));
      final flow = AppFlow(locationService: service);

      flow.completeLogin();
      await pumpEventQueue();

      expect(service.calls, 1);
      expect(flow.location?.lat, 37.5114);
      expect(flow.locationFailure, isNull);
      expect(flow.isLocating, isFalse);
    });

    test('수집에 실패해도 화면 흐름은 홈으로 넘어간다', () async {
      final flow = flowWith(const LocationResult.failed(LocationFailure.unavailable));

      flow.completeLogin();
      await pumpEventQueue();

      // 로그인 후 도착지는 요기요 메인 홈이다. 공유 안내 화면은 퀵메뉴로 들어간다.
      expect(flow.stage, AppStage.yogiyoHome);
      expect(flow.location, isNull);
      expect(flow.locationFailure, LocationFailure.unavailable);
    });

    test('영구 거부·서비스 꺼짐이면 주소 직접 입력이 필요하다', () async {
      for (final failure in [
        LocationFailure.deniedForever,
        LocationFailure.serviceDisabled,
      ]) {
        final flow = flowWith(LocationResult.failed(failure));
        await flow.refreshLocation();
        expect(flow.needsAddressInput, isTrue, reason: '$failure');
      }
    });

    test('일시 거부는 다시 물어볼 수 있어 주소 입력을 강요하지 않는다', () async {
      final flow = flowWith(const LocationResult.failed(LocationFailure.denied));
      await flow.refreshLocation();
      expect(flow.needsAddressInput, isFalse);
    });

    test('수집 중에는 중복 요청하지 않는다', () async {
      final service = _FakeLocationService(const LocationResult.success(_seoul));
      final flow = AppFlow(locationService: service);

      // await 하지 않고 연달아 호출
      final first = flow.refreshLocation();
      final second = flow.refreshLocation();
      await Future.wait([first, second]);

      expect(service.calls, 1);
    });

    test('주소를 직접 입력하면 좌표를 지어내지 않는다', () async {
      final flow = flowWith(const LocationResult.failed(LocationFailure.deniedForever));
      await flow.refreshLocation();

      flow.setManualAddress('  서울 송파구 잠실동 40-1  ');

      expect(flow.location?.origin, LocationOrigin.manual);
      expect(flow.location?.address, '서울 송파구 잠실동 40-1'); // 앞뒤 공백 제거
      expect(flow.location?.lat, 0); // 서버가 주소로 좌표를 찾는다
      expect(flow.needsAddressInput, isFalse);
    });

    test('빈 주소는 무시한다', () async {
      final flow = flowWith(const LocationResult.failed(LocationFailure.deniedForever));
      await flow.refreshLocation();

      flow.setManualAddress('   ');

      expect(flow.location, isNull);
    });

    test('디버그 override 가 수집된 위치를 덮어쓴다', () async {
      final flow = flowWith(const LocationResult.success(_seoul));
      await flow.refreshLocation();

      flow.applyDebugLocation(UserLocation.debugPresets['강남역']!);

      expect(flow.location?.origin, LocationOrigin.debugOverride);
      expect(flow.location?.lat, 37.4979);
    });

    test('위치 변경은 리스너에게 알린다', () async {
      final flow = flowWith(const LocationResult.success(_seoul));
      var notified = 0;
      flow.addListener(() => notified++);

      await flow.refreshLocation();

      expect(notified, greaterThan(0));
    });
  });
}
