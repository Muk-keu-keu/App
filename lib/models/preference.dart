/// 취향 설정 (Figma "키워드 선택" 화면).
///
/// `POST v1/analyses` 의 `preferences` 로 그대로 나간다. 명세가 받는 값은 셋이다.
/// - `maxSpiceLevel` — 맵기 상한 (nullable)
/// - `maxDeliveryMin` — 배달 시간 상한 (nullable)
/// - `excludeMeat` — 고기 제외 (기본 false)
///
/// 화면의 "1인 모드 / 비건모드" 는 명세에 대응 필드가 하나뿐이다. 비건모드가
/// `excludeMeat: true` 로 나가고, 1인 모드는 서버로 나가지 않는다 — DB `menu` 에
/// 인분 정보가 없어 서버가 쓸 값이 없다. 화면 문구로만 남는다.
library;

import 'enums.dart';

export 'enums.dart' show SpiceLevel;

enum ServingMode {
  solo(
    title: '1인 모드',
    subtitle: '혼자 먹기 좋은 양으로\n먹방의 핵심 조합만 담아요',
    imagePath: 'assets/images/mode_solo.png',
  ),
  healthy(
    title: '비건모드',
    subtitle: '칼로리를 낮춘 대체 옵션을 추천받고 싶어요',
    imagePath: 'assets/images/mode_healthy.png',
  );

  const ServingMode({required this.title, required this.subtitle, required this.imagePath});

  final String title;
  final String subtitle;
  final String imagePath;

  /// 비건모드만 서버로 전달된다.
  bool get excludeMeat => this == ServingMode.healthy;
}

class TastePreference {
  TastePreference({
    this.mode = ServingMode.healthy,
    this.spice = SpiceLevel.none,
    this.maxDeliveryMinutes = 40,
  });

  ServingMode mode;

  /// 맵기 상한. 명세 `maxSpiceLevel` 로 나간다.
  SpiceLevel spice;

  /// 예상 도착 시간 상한(분). 5분 단위. 명세 `maxDeliveryMin` 으로 나간다.
  int maxDeliveryMinutes;

  static const minMinutes = 20.0;
  static const maxMinutes = 60.0;

  String get deliveryLabel => '$maxDeliveryMinutes분 이하';

  bool get excludeMeat => mode.excludeMeat;

  TastePreference copy() => TastePreference(
        mode: mode,
        spice: spice,
        maxDeliveryMinutes: maxDeliveryMinutes,
      );

  /// `POST v1/analyses` 의 `preferences`.
  Map<String, dynamic> toJson() => {
        'maxSpiceLevel': spice.wire,
        'maxDeliveryMin': maxDeliveryMinutes,
        'excludeMeat': excludeMeat,
      };
}
