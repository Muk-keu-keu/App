/// 취향 설정 (Figma "필터" 681:6194).
///
/// `POST v1/analyses` 의 `preferences` 로 그대로 나간다. 명세가 받는 값은 셋이다.
/// - `maxSpiceLevel` — 맵기 상한 (nullable)
/// - `maxDeliveryMin` — 배달 시간 상한 (nullable)
/// - `excludeMeat` — 고기 제외 (기본 false)
///
/// **개정 시안에서 "모드"(1인 모드 / 비건모드) 섹션이 빠졌다.** 고를 자리가 없어진
/// 값이 결과를 조용히 바꾸면 안 되므로 `ServingMode` 자체를 걷어냈다. `excludeMeat`
/// 는 명세에 남아 있는 필드라 계속 보내되 항상 false 다 — 아무도 고기 제외를
/// 요청하지 않았는데 서버가 메뉴를 걸러내면 결과가 이유 없이 비어 보인다.
library;

import 'enums.dart';

export 'enums.dart' show SpiceLevel;

class TastePreference {
  TastePreference({
    this.spice = SpiceLevel.none,
    this.maxDeliveryMinutes = 40,
  });

  /// 맵기 상한. 명세 `maxSpiceLevel` 로 나간다.
  SpiceLevel spice;

  /// 예상 도착 시간 상한(분). 5분 단위. 명세 `maxDeliveryMin` 으로 나간다.
  int maxDeliveryMinutes;

  static const minMinutes = 20.0;
  static const maxMinutes = 60.0;

  /// 필터 시트 "초기화" 의 기준 (시안 1114:5604 — 맵기: 보통 / 예상 도착 시간: 최대값).
  ///
  /// 분석 전 취향 설정의 기본값(생성자 기본 인자)과 다르다. 필터의 초기화는
  /// "조건을 안 건 상태" 로 되돌리는 것이라, 시간 상한을 슬라이더 끝까지 열어
  /// 시간 때문에 걸러지는 매장이 없게 한다.
  static const resetSpice = SpiceLevel.medium;
  static const resetMinutes = 60;

  String get deliveryLabel => '$maxDeliveryMinutes분 이하';

  TastePreference copy() => TastePreference(
        spice: spice,
        maxDeliveryMinutes: maxDeliveryMinutes,
      );

  /// `POST v1/analyses` 의 `preferences`.
  Map<String, dynamic> toJson() => {
        'maxSpiceLevel': spice.wire,
        'maxDeliveryMin': maxDeliveryMinutes,
        'excludeMeat': false,
      };
}
