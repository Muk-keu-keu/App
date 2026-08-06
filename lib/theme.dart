import 'package:flutter/material.dart';

/// Figma 「요기요 x 오라클 해커톤」 03_디자인시스템 / foundation 의 토큰.
/// 이름은 Figma 변수명을 그대로 따른다.
class AppColors {
  const AppColors._();

  // ── Primary ────────────────────────────────────────────────────────────────
  static const primary600 = Color(0xFFDD0047); // pressed
  static const primary500 = Color(0xFFFA0050); // 기본 요기요 핑크
  static const primary400 = Color(0xFFFFA2C0); // 선택 테두리
  static const primary300 = Color(0xFFFFDCE7); // 보조 버튼 배경
  static const primary100 = Color(0xFFFFF4F7); // 선택 카드 배경

  // ── Grayscale ──────────────────────────────────────────────────────────────
  static const gray100 = Color(0xFFF8F8F8);
  static const gray200 = Color(0xFFF3F3F3);
  static const gray300 = Color(0xFFE1E1E1);
  static const gray400 = Color(0xFFD9D9D9);
  static const gray500 = Color(0xFFAEAEAE);
  static const gray600 = Color(0xFF828282);
  static const gray700 = Color(0xFF575757);
  static const gray800 = Color(0xFF2B2B2B);

  /// 되돌릴 수 없는 동작(삭제)의 버튼 색.
  ///
  /// 시안의 삭제 alert 는 요기요 핑크가 아니라 별도의 빨강을 쓴다. 결제·주문 같은
  /// 정상 동작과 같은 색이면 실수로 누르기 쉬워서 구분한 것으로 보인다.
  /// Figma 변수로 승격되지 않은 값이라 시안에서 눈으로 딴 근사치다.
  static const danger = Color(0xFFE93B32);

  /// 페이지 배경
  static const bg = Color(0xFFF2F2F2);

  /// 섹션 구분용 옅은 회색
  static const gray = Color(0xFFF9F9F9);

  // ── 기존 이름 (화면 코드가 참조 중) ─────────────────────────────────────────
  // 디자인 시스템 토큰으로 매핑해 둔다. 화면을 하나씩 새 이름으로 옮기는 동안
  // 양쪽이 같은 값을 가리키므로 중간 상태에서도 색이 어긋나지 않는다.
  static const primary = primary500;
  static const selectedFill = primary100;
  static const selectedBorder = primary400;
  static const softPinkFill = primary300;
  static const checkedBorder = primary400;
  static const pageBackground = bg;

  static final primarySoft = primary500.withValues(alpha: 0.08);
  static const dragHandle = Color(0xFFDCDCDC);

  /// Figma: DROP_SHADOW #8D8D8D26, offset (0,4), radius 12
  static final cardShadow = const Color(0xFF8D8D8D).withValues(alpha: 0.15);
}

/// Figma 03_디자인시스템 / Typhography.
///
/// 12개 토큰 모두 Pretendard 이고 line-height 는 caption 만 1.3, 나머지는 1.4다.
/// letterSpacing 은 Figma 가 % 로 잡아 두었으므로 px 로 환산해 넣는다
/// (본문 계열 -2%, 버튼·캡션 계열 -2.5%, caption2 만 0).
class AppText {
  const AppText._();

  static const _family = 'Pretendard';

  /// 워드마크용 디스플레이 폰트. 시안에서 `먹방요기` · `요기족보` 같은
  /// 브랜드 문구에만 쓴다. 본문에는 쓰지 않는다.
  static const _display = 'WAGURI';

  /// Figma 배너·섹션 타이틀. line-height 가 none 이라 1.0 으로 둔다.
  static TextStyle waguri(
    double size, {
    double spacing = 0,
    Color color = Colors.black,
  }) =>
      TextStyle(
        fontFamily: _display,
        fontSize: size,
        letterSpacing: spacing,
        height: 1.0,
        color: color,
      );

  static TextStyle _t(
    double size,
    FontWeight weight,
    double spacing, {
    double height = 1.4,
    Color color = Colors.black,
  }) =>
      TextStyle(
        fontFamily: _family,
        fontSize: size,
        fontWeight: weight,
        letterSpacing: spacing,
        height: height,
        color: color,
      );

  // ── Heading ────────────────────────────────────────────────────────────────
  static TextStyle h1({Color color = Colors.black}) =>
      _t(28, FontWeight.w600, -0.56, color: color);
  static TextStyle h2({Color color = Colors.black}) =>
      _t(24, FontWeight.w600, -0.48, color: color);
  static TextStyle h3({Color color = Colors.black}) =>
      _t(20, FontWeight.w600, -0.40, color: color);

  // ── Subtitle ───────────────────────────────────────────────────────────────
  static TextStyle sub1({Color color = Colors.black}) =>
      _t(18, FontWeight.w600, -0.36, color: color);
  static TextStyle sub2({Color color = Colors.black}) =>
      _t(16, FontWeight.w600, -0.32, color: color);

  // ── Body ───────────────────────────────────────────────────────────────────
  static TextStyle body1({Color color = Colors.black}) =>
      _t(16, FontWeight.w400, -0.32, color: color);
  static TextStyle body2({Color color = Colors.black}) =>
      _t(14, FontWeight.w400, -0.28, color: color);

  // ── Button ─────────────────────────────────────────────────────────────────
  static TextStyle btn1({Color color = Colors.black}) =>
      _t(16, FontWeight.w600, -0.40, color: color);
  static TextStyle btn2({Color color = Colors.black}) =>
      _t(14, FontWeight.w600, -0.35, color: color);
  static TextStyle btn3({Color color = Colors.black}) =>
      _t(12, FontWeight.w400, -0.30, color: color);

  // ── Caption ────────────────────────────────────────────────────────────────
  static TextStyle caption({Color color = Colors.black}) =>
      _t(12, FontWeight.w400, -0.30, height: 1.3, color: color);
  static TextStyle caption2({Color color = Colors.black}) =>
      _t(10, FontWeight.w400, 0, color: color);

  // ── 기존 API (화면 코드가 참조 중) ──────────────────────────────────────────
  // 임의 크기를 받는 형태라 디자인 시스템에 없는 값도 만들 수 있다.
  // 화면을 옮기면서 위 토큰으로 대체한다.
  static TextStyle regular(double size, {double spacing = 0, Color color = Colors.black}) =>
      _t(size, FontWeight.w400, spacing, color: color);

  static TextStyle medium(double size, {double spacing = 0, Color color = Colors.black}) =>
      _t(size, FontWeight.w500, spacing, color: color);

  static TextStyle semiBold(double size, {double spacing = 0, Color color = Colors.black}) =>
      _t(size, FontWeight.w600, spacing, color: color);

  static TextStyle get screenTitle => h1();
  static TextStyle get sectionTitle => sub2();
  static TextStyle get sectionBody => body1(color: AppColors.gray700);
  static TextStyle get button => btn1(color: Colors.white);
}

/// Figma 카드 드롭섀도우
List<BoxShadow> get figmaCardShadow => [
      BoxShadow(color: AppColors.cardShadow, blurRadius: 6, offset: const Offset(0, 4)),
    ];

/// 라운딩. Figma 컴포넌트에서 반복되는 값.
class AppRadius {
  const AppRadius._();

  static const chip = 8.0;
  static const card = 12.0;
  static const button = 12.0;
  static const sheet = 20.0;
  static const pill = 999.0;
}

ThemeData buildAppTheme() => ThemeData(
      fontFamily: AppText._family,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary500,
        primary: AppColors.primary500,
      ),
      useMaterial3: true,
    );
