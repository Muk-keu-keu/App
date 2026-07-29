import 'package:flutter/material.dart';

/// Figma "요기요 해커톤" 파일의 디자인 토큰.
/// iOS 앱의 Theme.swift 와 같은 값을 쓴다. 색 이름은 Figma 변수명을 따른다.
class AppColors {
  const AppColors._();

  static const primary = Color(0xFFFA0050); // 요기요 핑크
  static final primarySoft = const Color(0xFFFA0050).withValues(alpha: 0.08);

  static const selectedFill = Color(0xFFFFF4F7); // 선택된 카드 배경
  static const selectedBorder = Color(0xFFFF9FBE); // 선택된 카드 테두리
  static const softPinkFill = Color(0xFFFFDCE7); // 보조 버튼 배경
  static const checkedBorder = Color(0xFFFFA2C0); // 선택된 조합 카드 테두리

  static const gray100 = Color(0xFFF8F8F8); // 체크박스 비선택 배경
  static const gray200 = Color(0xFFF5F5F5); // 보조 버튼 배경
  static const gray300 = Color(0xFFE1E1E1); // 카드 테두리, 슬라이더 트랙
  static const gray400 = Color(0xFFD9D9D9); // 체크박스 비선택 테두리
  static const gray500 = Color(0xFFAEAEAE); // 비활성 아이콘
  static const gray600 = Color(0xFF828282); // 보조 라벨
  static const gray700 = Color(0xFF575757); // 설명 문구
  static const gray800 = Color(0xFF2B2B2B); // 강조 문구

  static const pageBackground = Color(0xFFF6F6F6);
  static const dragHandle = Color(0xFFDCDCDC);

  /// Figma: DROP_SHADOW #8D8D8D26, offset (0,4), radius 12
  static final cardShadow = const Color(0xFF8D8D8D).withValues(alpha: 0.15);
}

/// Pretendard 타이포. size 와 letterSpacing 은 Figma 값을 그대로 쓴다.
class AppText {
  const AppText._();

  static const _family = 'Pretendard';

  static TextStyle _base(double size, FontWeight weight, double spacing, Color color) => TextStyle(
        fontFamily: _family,
        fontSize: size,
        fontWeight: weight,
        letterSpacing: spacing,
        color: color,
        height: 1.4, // Figma line-height
      );

  static TextStyle regular(double size, {double spacing = 0, Color color = Colors.black}) =>
      _base(size, FontWeight.w400, spacing, color);

  static TextStyle medium(double size, {double spacing = 0, Color color = Colors.black}) =>
      _base(size, FontWeight.w500, spacing, color);

  static TextStyle semiBold(double size, {double spacing = 0, Color color = Colors.black}) =>
      _base(size, FontWeight.w600, spacing, color);

  // 자주 쓰는 조합
  static TextStyle get screenTitle => semiBold(28, spacing: -0.7);
  static TextStyle get sectionTitle => semiBold(16, spacing: -0.4);
  static TextStyle get sectionBody => regular(16, spacing: -0.4, color: AppColors.gray700);
  static TextStyle get button => semiBold(16, spacing: -0.4, color: Colors.white);
}

/// Figma 카드 드롭섀도우
List<BoxShadow> get figmaCardShadow => [
      BoxShadow(color: AppColors.cardShadow, blurRadius: 6, offset: const Offset(0, 4)),
    ];

ThemeData buildAppTheme() => ThemeData(
      fontFamily: 'Pretendard',
      scaffoldBackgroundColor: AppColors.pageBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
      ),
      useMaterial3: true,
    );
