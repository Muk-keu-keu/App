import 'package:flutter/material.dart';

import '../models/preference.dart';
import '../theme.dart';

/// Figma 헤더 (node 480:1896). 좌측 뒤로가기, 중앙 타이틀, 우측 여백.
/// onBack 이 null 이면 뒤로가기를 그리지 않는다.
class AppHeader extends StatelessWidget {
  const AppHeader({super.key, required this.title, this.onBack});

  final String title;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 32,
            child: Row(
              children: [
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
                  child: Center(
                    child: Text(title, style: AppText.semiBold(20, spacing: -0.5)),
                  ),
                ),
                // 우측은 Figma 에서 아이콘이 hidden 이라 자리만 비워 균형을 맞춘다.
                const SizedBox(width: 64),
              ],
            ),
          ),
        ),
      );
}

/// 매장·메뉴 썸네일. 원격 URL 이 있으면 그걸 쓰고, 없거나 실패하면 번들 이미지로 돌아간다.
/// 지금 원격 URL 은 공유된 릴스의 og:image 라서 "영상에서 본 그 음식"이 그대로 보인다.
class RemoteOrAssetImage extends StatelessWidget {
  const RemoteOrAssetImage({
    super.key,
    required this.imageUrl,
    required this.assetPath,
    required this.size,
    this.radius = 8,
  });

  final String? imageUrl;
  final String assetPath;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: url == null || url.isEmpty
            ? Image.asset(assetPath, fit: BoxFit.cover)
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Image.asset(assetPath, fit: BoxFit.cover),
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : Container(color: AppColors.gray100),
              ),
      ),
    );
  }
}

/// 흰 카드. Figma 의 radius 12 + 드롭섀도우.
class FigmaCard extends StatelessWidget {
  const FigmaCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderColor,
    this.borderWidth = 1,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? borderColor;
  final double borderWidth;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: figmaCardShadow,
          border: borderColor == null ? null : Border.all(color: borderColor!, width: borderWidth),
        ),
        child: child,
      );
}

/// 하단 고정 CTA 버튼
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onPressed,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(label, style: AppText.button),
        ),
      );
}

/// 수량 스테퍼. 수량이 1이면 마이너스 자리에 휴지통이 뜬다(Figma 시안 동일).
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13.5),
          border: Border.all(color: AppColors.gray300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _iconButton(quantity <= 1 ? Icons.delete_outline : Icons.remove, onDecrease),
            SizedBox(
              width: 24,
              child: Text(
                '$quantity',
                textAlign: TextAlign.center,
                style: AppText.regular(13.5),
              ),
            ),
            _iconButton(Icons.add, onIncrease),
          ],
        ),
      );

  Widget _iconButton(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 20,
          height: 20,
          child: Icon(icon, size: 16, color: AppColors.gray800),
        ),
      );
}

/// Figma 체크박스. 선택 시 요기요 핑크 채움, 비선택 시 gray100 배경 + gray400 테두리.
class FigmaCheckbox extends StatelessWidget {
  const FigmaCheckbox({super.key, required this.isOn, this.size = 20});

  final bool isOn;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isOn ? AppColors.primary : AppColors.gray100,
          borderRadius: BorderRadius.circular(size * 0.2),
          border: isOn ? null : Border.all(color: AppColors.gray400, width: 1.5),
        ),
        child: isOn ? Icon(Icons.check, size: size * 0.62, color: Colors.white) : null,
      );
}

/// Figma 슬라이더: 트랙 8pt, 노브 28pt. 기본 Slider 로는 이 치수가 안 나와 직접 그린다.
class DeliveryTimeSlider extends StatelessWidget {
  const DeliveryTimeSlider({super.key, required this.minutes, required this.onChanged});

  final int minutes;
  final ValueChanged<int> onChanged;

  static const _knob = 28.0;
  static const _track = 8.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          const span = TastePreference.maxMinutes - TastePreference.minMinutes;
          final usable = (constraints.maxWidth - _knob).clamp(1.0, double.infinity);
          final ratio = (minutes - TastePreference.minMinutes) / span;
          final x = usable * ratio;

          void update(double dx) {
            final clamped = (dx - _knob / 2).clamp(0.0, usable);
            final value = TastePreference.minMinutes + (clamped / usable) * span;
            onChanged((value / 5).round() * 5);
          }

          return GestureDetector(
            onTapDown: (d) => update(d.localPosition.dx),
            onHorizontalDragUpdate: (d) => update(d.localPosition.dx),
            child: SizedBox(
              height: _knob,
              width: double.infinity,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: _track,
                    decoration: BoxDecoration(
                      color: AppColors.gray300,
                      borderRadius: BorderRadius.circular(_track / 2),
                    ),
                  ),
                  Container(
                    width: x + _knob / 2,
                    height: _track,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(_track / 2),
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(x, 0),
                    child: Container(
                      width: _knob,
                      height: _knob,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
}
