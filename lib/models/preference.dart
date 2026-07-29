/// 취향 설정 (Figma "키워드 선택" 화면).
/// iOS 앱 Models.swift 의 TastePreference 와 같은 구조다.

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
}

enum SpiceLevel {
  mild(title: '순한맛', imagePath: 'assets/images/spice_mild.png'),
  medium(title: '보통맛', imagePath: 'assets/images/spice_medium.png'),
  hot(title: '매운맛', imagePath: 'assets/images/spice_hot.png');

  const SpiceLevel({required this.title, required this.imagePath});

  final String title;
  final String imagePath;
}

class TastePreference {
  TastePreference({
    this.mode = ServingMode.healthy,
    this.spice = SpiceLevel.mild,
    this.maxDeliveryMinutes = 40,
  });

  ServingMode mode;
  SpiceLevel spice;

  /// 예상 도착 시간 상한(분). 5분 단위.
  int maxDeliveryMinutes;

  static const minMinutes = 20.0;
  static const maxMinutes = 60.0;

  String get deliveryLabel => '$maxDeliveryMinutes분 이하';

  TastePreference copy() => TastePreference(
        mode: mode,
        spice: spice,
        maxDeliveryMinutes: maxDeliveryMinutes,
      );
}
