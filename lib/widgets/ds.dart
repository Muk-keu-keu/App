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
                              child: const DsChevron.left(),
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
                      // 마지막 뒤에도 여백을 넣으면 아이콘 2개에서 64를 넘겨 터진다.
                      for (var i = 0; i < actions.length; i++) ...[
                        if (i > 0) const SizedBox(width: 12),
                        actions[i],
                      ],
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
                    asset: DsIcons.heart,
                    width: 15.5,
                    height: 14.5,
                    color: liked ? AppColors.primary500 : null,
                    value: likeCount,
                    onTap: onLike,
                  ),
                  const SizedBox(width: 8),
                  _count(
                    asset: DsIcons.bubble,
                    width: 15.78,
                    height: 15.83,
                    value: commentCount,
                  ),
                  const Spacer(),
                  // 시안은 날짜 칸을 58 로 고정하고 오른쪽 정렬한다.
                  // "2분 전"과 "2026.07.22"가 섞여도 오른쪽 끝이 흔들리지 않는다.
                  SizedBox(
                    width: 58,
                    child: Text(
                      dateText,
                      textAlign: TextAlign.right,
                      style: AppText.caption(color: AppColors.gray500),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _count({
    required String asset,
    required double width,
    required double height,
    required int value,
    Color? color,
    VoidCallback? onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Center(
                child: SvgPicture.asset(
                  asset,
                  width: width,
                  height: height,
                  colorFilter: color == null ? null : _tint(color),
                ),
              ),
            ),
            const SizedBox(width: 2),
            Text('$value', style: AppText.caption(color: AppColors.gray600)),
          ],
        ),
      );
}

// ── Divider ──────────────────────────────────────────────────────────────────

/// 시안 전반에서 반복되는 1px 구분선.
class DsDivider extends StatelessWidget {
  const DsDivider({super.key, this.indent = 0, this.color = AppColors.gray200});

  final double indent;

  /// 화면마다 gray200 / gray300 을 섞어 쓴다. 시안에 적힌 쪽을 그대로 넘긴다.
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        height: 1,
        margin: EdgeInsets.symmetric(horizontal: indent),
        color: color,
      );
}

// ── Icons ────────────────────────────────────────────────────────────────────

/// 시안에서 내려받은 아이콘. Material 아이콘으로 흉내 내지 않고 그대로 쓴다.
class DsIcons {
  const DsIcons._();

  static const chevron = 'assets/icons/chevron_left.svg';
  static const filter = 'assets/icons/filter.svg';
  static const check = 'assets/icons/check.svg';
  static const plus = 'assets/icons/plus.svg';
  static const minus = 'assets/icons/minus.svg';
  static const delete = 'assets/icons/delete.svg';
  static const star = 'assets/icons/star.svg';
  static const close = 'assets/icons/close.svg';
  static const radioRing = 'assets/icons/radio_ring.svg';
  static const radioDot = 'assets/icons/radio_dot.svg';
  static const heart = 'assets/icons/heart.svg';
  static const bubble = 'assets/icons/bubble.svg';
  static const camera = 'assets/icons/camera.svg';
}

/// SVG 안에 색이 박혀 있어 다른 색으로 쓰려면 덧씌워야 한다.
ColorFilter _tint(Color color) => ColorFilter.mode(color, BlendMode.srcIn);

/// Figma `icon/chevron` — 아래 방향은 왼쪽 화살표를 반시계로 90° 돌린 것이다
/// (시안 컴포넌트도 같은 벡터를 회전해 쓴다).
class DsChevron extends StatelessWidget {
  const DsChevron.left({super.key, this.color = Colors.black}) : _down = false;
  const DsChevron.down({super.key, this.color = AppColors.gray800}) : _down = true;

  final Color color;
  final bool _down;

  @override
  Widget build(BuildContext context) {
    // 시안 치수: left 는 20 프레임 안에 8×14, down 은 16 프레임 안에 10×6(회전 전 6×10).
    final leaf = SvgPicture.asset(
      DsIcons.chevron,
      width: _down ? 6 : 8,
      height: _down ? 10 : 14,
      fit: BoxFit.fill,
      colorFilter: _tint(color),
    );
    return SizedBox(
      width: _down ? 16 : 20,
      height: _down ? 16 : 20,
      child: Center(
        child: _down ? RotatedBox(quarterTurns: 3, child: leaf) : leaf,
      ),
    );
  }
}

// ── Checkbox ─────────────────────────────────────────────────────────────────

/// Figma `checkbox` — size L(24)/S(20) × state default/selected.
///
/// 선택되면 primary500 로 채우고 흰 체크를 올린다. 비선택은 gray100 + gray400 테두리.
class DsCheckbox extends StatelessWidget {
  const DsCheckbox({super.key, required this.isOn, this.size = 20, this.onTap});

  final bool isOn;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isOn ? AppColors.primary500 : AppColors.gray100,
        borderRadius: BorderRadius.circular(4.8),
        border: isOn ? null : Border.all(color: AppColors.gray400, width: 1.5),
      ),
      // 체크 표시는 20 기준 14×10 이고, 상자가 커지면 같은 비율로 커진다.
      child: isOn
          ? SvgPicture.asset(
              DsIcons.check,
              width: size / 20 * 14,
              height: size / 20 * 10,
              fit: BoxFit.fill,
            )
          : null,
    );
    if (onTap == null) return box;
    return GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: box);
  }
}

// ── Chip ─────────────────────────────────────────────────────────────────────

/// Figma `chip/filter` — 높이 36, 라운딩 20. 글자 뒤에 chevron 이 붙는다.
/// [label] 을 비우면 시안의 아이콘 전용 칩(폭 48, 테두리 gray800)이 된다.
class DsChipFilter extends StatelessWidget {
  const DsChipFilter({super.key, required this.label, this.onTap});

  const DsChipFilter.icon({super.key, this.onTap}) : label = null;

  final String? label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final iconOnly = label == null;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 36,
        width: iconOnly ? 48 : null,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: iconOnly ? AppColors.gray800 : AppColors.gray600,
          ),
        ),
        child: iconOnly
            ? SizedBox(
                width: 16,
                height: 16,
                child: Center(
                  child: SvgPicture.asset(DsIcons.filter, width: 15.5, height: 13),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label!, style: AppText.body2(color: AppColors.gray700)),
                  const DsChevron.down(color: AppColors.gray600),
                ],
              ),
      ),
    );
  }
}

/// Figma `chip/choice` — 카테고리 고르기. 고르면 primary300 채움 + primary400 테두리.
class DsChipChoice extends StatelessWidget {
  const DsChipChoice({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 36,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary300 : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.primary400 : AppColors.gray400,
            ),
          ),
          child: Text(
            label,
            style: AppText.body2(
              color: selected ? AppColors.primary500 : AppColors.gray800,
            ),
          ),
        ),
      );
}

/// "필수" / "선택" 배지. 필수는 분홍, 선택은 회색.
class DsRequirementBadge extends StatelessWidget {
  const DsRequirementBadge({super.key, required this.isRequired});

  final bool isRequired;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: isRequired ? AppColors.primary300 : AppColors.gray300,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          isRequired ? '필수' : '선택',
          style: AppText.btn3(
            color: isRequired ? AppColors.primary500 : AppColors.gray700,
          ),
        ),
      );
}

// ── Radio ────────────────────────────────────────────────────────────────────

/// Figma `radio button` — 20 프레임 안에 16 테두리 원, 고르면 가운데 8 점이 찍힌다.
class DsRadio extends StatelessWidget {
  const DsRadio({super.key, required this.isOn});

  final bool isOn;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 20,
        height: 20,
        child: Stack(
          children: [
            Positioned(
              left: 2,
              top: 2,
              child: SvgPicture.asset(DsIcons.radioRing, width: 16, height: 16),
            ),
            if (isOn)
              Positioned(
                left: 6,
                top: 6,
                child: SvgPicture.asset(DsIcons.radioDot, width: 8, height: 8),
              ),
          ],
        ),
      );
}

// ── Stepper ──────────────────────────────────────────────────────────────────

/// Figma `stepper` — 높이 28, 라운딩 20, gray300 테두리.
/// 수량이 1이면 빼기 자리에 휴지통이 뜬다(시안의 state=minimum).
class DsStepper extends StatelessWidget {
  const DsStepper({
    super.key,
    required this.quantity,
    required this.onDecrease,
    required this.onIncrease,
  });

  final int quantity;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) => Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.gray300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _icon(quantity <= 1 ? DsIcons.delete : DsIcons.minus, onDecrease),
            SizedBox(
              width: 24,
              child: Text(
                '$quantity',
                textAlign: TextAlign.center,
                style: AppText.body2(),
              ),
            ),
            _icon(DsIcons.plus, onIncrease),
          ],
        ),
      );

  Widget _icon(String asset, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SvgPicture.asset(asset, width: 20, height: 20),
      );
}

// ── Store row ────────────────────────────────────────────────────────────────

/// 카드 머리의 매장 한 줄 — 로고 44 + 상호 + 별점·거리·배달시간.
class DsStoreRow extends StatelessWidget {
  const DsStoreRow({
    super.key,
    required this.logo,
    required this.name,
    required this.ratingText,
    required this.distanceText,
    required this.deliveryText,
    this.trailing,
  });

  final Widget logo;
  final String name;
  final String ratingText;
  final String distanceText;
  final String deliveryText;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 44, height: 44, child: logo),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppText.sub2().copyWith(letterSpacing: -0.4)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    // 시안은 12 프레임 안에 10.5×10 별이다. 프레임까지 맞춰야 간격이 맞는다.
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: Center(
                        child: SvgPicture.asset(DsIcons.star, width: 10.5, height: 10),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text(
                        ratingText,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption(color: AppColors.gray600),
                      ),
                    ),
                    _dot(),
                    Text(distanceText, style: AppText.caption(color: AppColors.gray600)),
                    _dot(),
                    Text(deliveryText, style: AppText.caption(color: AppColors.gray600)),
                  ],
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 16), trailing!],
        ],
      );

  Widget _dot() => Container(
        width: 2,
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: const BoxDecoration(
          color: AppColors.gray600,
          shape: BoxShape.circle,
        ),
      );
}

// ── Menu item ────────────────────────────────────────────────────────────────

/// Figma `menu item` — 먹방 조합·다른 결과보기 카드가 같은 모양을 쓴다.
///
/// 썸네일 80 + 메뉴명·옵션, 그 아래 수량 스테퍼 · "옵션 변경" · 금액.
class DsMenuItem extends StatelessWidget {
  const DsMenuItem({
    super.key,
    required this.thumbnail,
    required this.name,
    required this.options,
    required this.quantity,
    required this.priceText,
    required this.onDecrease,
    required this.onIncrease,
    this.onEditOption,
  });

  final Widget thumbnail;
  final String name;
  final String options;
  final int quantity;
  final String priceText;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback? onEditOption;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 80, height: 80, child: thumbnail),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: AppText.sub2()),
                    const SizedBox(height: 4),
                    Text(options, style: AppText.caption(color: AppColors.gray600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  DsStepper(
                    quantity: quantity,
                    onDecrease: onDecrease,
                    onIncrease: onIncrease,
                  ),
                  const SizedBox(width: 4),
                  _optionButton(),
                ],
              ),
              Text(
                priceText,
                style: AppText.sub2(color: AppColors.gray800)
                    .copyWith(letterSpacing: -0.4),
              ),
            ],
          ),
        ],
      );

  Widget _optionButton() => GestureDetector(
        onTap: onEditOption,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.gray500),
            borderRadius: BorderRadius.circular(200),
          ),
          child: Text('옵션 변경', style: AppText.btn3(color: AppColors.gray800)),
        ),
      );
}

// ── Video summary ────────────────────────────────────────────────────────────

/// Figma `video summary` — 출처 영상 한 덩어리.
///
/// 족보 작성과 주문하기 화면이 같은 컴포넌트를 쓴다. 썸네일과 글이 화면을
/// 반씩 나눠 갖고, 제목은 세 줄까지 보인다.
class DsVideoSummary extends StatelessWidget {
  const DsVideoSummary({
    super.key,
    required this.thumbnail,
    required this.videoTitle,
    required this.creatorName,
    this.creatorAvatar,
  });

  final Widget thumbnail;
  final String videoTitle;
  final String creatorName;
  final Widget? creatorAvatar;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.chip),
                child: SizedBox(height: 100, child: thumbnail),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 66,
                    child: Text(
                      videoTitle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.sub2(color: AppColors.gray800)
                          .copyWith(letterSpacing: 0),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: creatorAvatar ??
                            Container(
                              decoration: const BoxDecoration(
                                color: AppColors.gray300,
                                shape: BoxShape.circle,
                              ),
                            ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          creatorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body2(color: AppColors.gray700)
                              .copyWith(letterSpacing: 0),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

/// 카드 아래쪽의 "+ 메뉴 추가하기" 줄.
class DsAddMenuButton extends StatelessWidget {
  const DsAddMenuButton({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              DsIcons.plus,
              width: 20,
              height: 20,
              colorFilter: _tint(AppColors.gray800),
            ),
            const SizedBox(width: 4),
            Text('메뉴 추가하기', style: AppText.btn1(color: AppColors.gray800)),
          ],
        ),
      );
}
