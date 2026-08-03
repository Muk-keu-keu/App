import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme.dart';

/// Figma 03_디자인시스템 / component 를 옮긴 것.
///
/// 기존 `widgets/common.dart` 는 화면들이 아직 참조 중이라 남겨 두고,
/// 새 시안을 적용한 화면부터 이 파일의 컴포넌트를 쓴다.

// ── Button ───────────────────────────────────────────────────────────────────

/// Figma `button` — size L/M/S/XS × state default/pressed/disabled.
///
/// 사이즈마다 라운딩이 다르다(L 16 · M 12 · XS 8 · S 16). 시안 그대로 따른다.
/// S 만 회색 계열이고 나머지는 primary 계열이다.
enum DsButtonSize { l, m, s, xs }

class DsButton extends StatefulWidget {
  const DsButton({
    super.key,
    required this.label,
    this.onPressed,
    this.size = DsButtonSize.l,
    this.expand = true,
  });

  final String label;

  /// null 이면 disabled 상태로 그린다.
  final VoidCallback? onPressed;
  final DsButtonSize size;

  /// 가로를 채울지. false 면 시안의 고정 폭(L 350 · M 250 · S 92)을 쓴다.
  final bool expand;

  @override
  State<DsButton> createState() => _DsButtonState();
}

class _DsButtonState extends State<DsButton> {
  bool _pressed = false;

  bool get _disabled => widget.onPressed == null;

  double get _height => widget.size == DsButtonSize.xs ? 36 : 52;

  double get _radius => switch (widget.size) {
        DsButtonSize.l => 16,
        DsButtonSize.m => 12,
        DsButtonSize.s => 16,
        DsButtonSize.xs => 8,
      };

  double? get _fixedWidth => switch (widget.size) {
        DsButtonSize.l => 350,
        DsButtonSize.m => 250,
        DsButtonSize.s => 92,
        DsButtonSize.xs => null, // 내용에 맞춘다
      };

  Color get _background {
    if (widget.size == DsButtonSize.s) {
      if (_pressed && !_disabled) return AppColors.gray300;
      return AppColors.gray200;
    }
    if (_disabled) return AppColors.primary400;
    return _pressed ? AppColors.primary600 : AppColors.primary500;
  }

  TextStyle get _textStyle {
    if (widget.size == DsButtonSize.s) {
      if (_disabled) return AppText.body1(color: AppColors.gray500);
      return _pressed
          ? AppText.btn1(color: AppColors.gray800)
          : AppText.body1(color: AppColors.gray800);
    }
    return widget.size == DsButtonSize.xs
        ? AppText.btn2(color: Colors.white)
        : AppText.btn1(color: Colors.white);
  }

  @override
  Widget build(BuildContext context) {
    final button = Container(
      width: widget.expand ? double.infinity : _fixedWidth,
      height: _height,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(_radius),
      ),
      child: Text(widget.label, style: _textStyle, maxLines: 1),
    );

    if (_disabled) return button;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onPressed,
      behavior: HitTestBehavior.opaque,
      child: button,
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────────────

/// Figma `header` — type=detail(가운데 정렬 + 뒤로가기) / type=main(좌측 정렬).
///
/// 높이 56, 배경 흰색, 좌우 20 패딩. 좌·우 영역은 각각 64 고정이라
/// 타이틀이 길어져도 가운데가 밀리지 않는다.
class DsHeader extends StatelessWidget {
  const DsHeader.detail({
    super.key,
    required this.title,
    this.onBack,
    this.actions = const [],
  }) : _main = false;

  const DsHeader.main({
    super.key,
    required this.title,
    this.actions = const [],
  })  : _main = true,
        onBack = null;

  final String title;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final bool _main;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 32,
            child: Row(
              children: [
                if (!_main)
                  SizedBox(
                    width: 64,
                    child: onBack == null
                        ? null
                        : Align(
                            alignment: Alignment.centerLeft,
                            child: GestureDetector(
                              onTap: onBack,
                              behavior: HitTestBehavior.opaque,
                              child: const SizedBox(
                                width: 24,
                                height: 24,
                                child: Icon(Icons.arrow_back_ios_new,
                                    size: 18, color: Colors.black),
                              ),
                            ),
                          ),
                  ),
                Expanded(
                  child: _main
                      ? Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(title, style: AppText.h3()),
                          ),
                        )
                      : Center(child: Text(title, style: AppText.h3())),
                ),
                SizedBox(
                  width: 64,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      for (final a in actions) ...[a, const SizedBox(width: 12)],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

// ── Bottom navigation ────────────────────────────────────────────────────────

/// Figma `bottom navigation` — 탭 4개. 요기요 앱의 하단 바 틀을 따른다.
///
/// 떠 있는 알약 형태다. 폭 350, 라운딩 100, 반투명 흰 배경에 그림자.
/// 선택된 탭 뒤에 회색 알약이 깔린다.
enum DsTab {
  home('홈', 'assets/icons/nav_home.svg'),
  orders('주문내역', 'assets/icons/nav_order.svg'),
  jokbo('요기족보', 'assets/icons/nav_jokbo.svg'),
  my('마이요기요', 'assets/icons/nav_my.svg');

  const DsTab(this.label, this.icon);

  final String label;
  final String icon;
}

class DsBottomNavigation extends StatelessWidget {
  const DsBottomNavigation({
    super.key,
    required this.current,
    required this.onChanged,
  });

  final DsTab current;
  final ValueChanged<DsTab> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Container(
          height: 67.5,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(100),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8D8D8D).withValues(alpha: 0.25),
                blurRadius: 12,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [for (final tab in DsTab.values) _item(tab)],
          ),
        ),
      );

  Widget _item(DsTab tab) {
    final selected = tab == current;
    return GestureDetector(
      onTap: () => onChanged(tab),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 80,
        height: 51.5,
        alignment: Alignment.center,
        decoration: selected
            ? BoxDecoration(
                color: const Color(0xFFECECEC).withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(100),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(tab.icon, width: 24, height: 24),
            const SizedBox(height: 0.5),
            Text(
              tab.label,
              textAlign: TextAlign.center,
              style: AppText.caption2().copyWith(letterSpacing: -0.25),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Post item ────────────────────────────────────────────────────────────────

/// Figma `post item` — 요기족보 목록의 한 줄.
///
/// 썸네일 60 정사각(라운딩 8) + 제목·본문 2줄, 그 아래 좋아요·댓글·날짜.
class DsPostItem extends StatelessWidget {
  const DsPostItem({
    super.key,
    required this.title,
    required this.content,
    required this.likeCount,
    required this.commentCount,
    required this.dateText,
    required this.thumbnail,
    this.liked = false,
    this.onTap,
    this.onLike,
  });

  final String title;
  final String content;
  final int likeCount;
  final int commentCount;
  final String dateText;

  /// 썸네일 위젯. 원격/에셋 구분은 호출하는 쪽이 정한다.
  final Widget thumbnail;

  final bool liked;
  final VoidCallback? onTap;
  final VoidCallback? onLike;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(width: 60, height: 60, child: thumbnail),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppText.sub2().copyWith(letterSpacing: -0.4),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 40,
                          child: Text(
                            content,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.body2(color: AppColors.gray700)
                                .copyWith(height: 1.3, letterSpacing: -0.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _count(
                    icon: liked ? Icons.favorite : Icons.favorite_border,
                    color: liked ? AppColors.primary500 : AppColors.gray600,
                    value: likeCount,
                    onTap: onLike,
                  ),
                  const SizedBox(width: 8),
                  _count(
                    icon: Icons.chat_bubble_outline,
                    color: AppColors.gray600,
                    value: commentCount,
                  ),
                  const Spacer(),
                  Text(
                    dateText,
                    style: AppText.caption(color: AppColors.gray500),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _count({
    required IconData icon,
    required Color color,
    required int value,
    VoidCallback? onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 20, height: 20, child: Icon(icon, size: 17, color: color)),
            const SizedBox(width: 2),
            Text('$value', style: AppText.caption(color: AppColors.gray600)),
          ],
        ),
      );
}

// ── Divider ──────────────────────────────────────────────────────────────────

/// 시안 전반에서 반복되는 1px 구분선.
class DsDivider extends StatelessWidget {
  const DsDivider({super.key, this.indent = 0});

  final double indent;

  @override
  Widget build(BuildContext context) => Container(
        height: 1,
        margin: EdgeInsets.symmetric(horizontal: indent),
        color: AppColors.gray200,
      );
}
