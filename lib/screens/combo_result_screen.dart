import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_flow.dart';
import '../models/combo.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'menu_edit_sheet.dart';

/// Figma "먹방 속 조합을 담았어요" (node 111:1390).
class ComboResultScreen extends StatefulWidget {
  const ComboResultScreen({super.key});

  @override
  State<ComboResultScreen> createState() => _ComboResultScreenState();
}

class _ComboResultScreenState extends State<ComboResultScreen> {
  bool _showTooltip = true;

  @override
  Widget build(BuildContext context) {
    final flow = context.watch<AppFlow>();
    final combo = flow.selectedCombo;
    if (combo == null) return const SizedBox.shrink();

    return Column(
      children: [
        Expanded(
          child: Container(
            color: AppColors.pageBackground,
            child: SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('먹방 속 조합을 담았어요', style: AppText.screenTitle),
                          const SizedBox(height: 2),
                          Text('먹방 속 메뉴와 가장 유사한 조합이에요.', style: AppText.sectionBody),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _storeCard(context, combo),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      child: _comboCard(context, combo, flow),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: SafeArea(
            top: false,
            child: PrimaryButton(
              label: '이대로 주문하기',
              onPressed: () => _openYogiyo(combo.store.name),
            ),
          ),
        ),
      ],
    );
  }

  Widget _storeCard(BuildContext context, ComboRecommendation combo) => FigmaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(combo.store.imagePath,
                          width: 80, height: 80, fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(combo.store.name, style: AppText.semiBold(20, spacing: -0.5)),
                          const SizedBox(height: 4),
                          Row(children: [
                            const Icon(Icons.star, size: 12, color: Colors.black),
                            const SizedBox(width: 2),
                            Text(combo.store.ratingText,
                                style: AppText.regular(12,
                                    spacing: -0.3, color: AppColors.gray600)),
                          ]),
                          Text(
                            '${combo.store.distanceText} · 배달 완료까지 ${combo.store.deliveryText}',
                            style:
                                AppText.regular(12, spacing: -0.3, color: AppColors.gray600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => context.read<AppFlow>().showComboList(),
                  child: Container(
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.softPinkFill,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('다른 결과 확인하기',
                        style: AppText.semiBold(14,
                            spacing: -0.35, color: AppColors.primary)),
                  ),
                ),
        ],
      ),
    );

  /// 매장 카드와 조합 카드 경계에 걸치는 말풍선.
  /// 조합 카드 쪽 Stack 에 넣어 위로 밀어낸다. 매장 카드에 붙이면 나중에 그려지는
  /// 조합 카드가 덮어버려 글자가 가려진다.
  Widget _tooltip() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: CustomPaint(size: const Size(14, 8), painter: _TrianglePainter()),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('다른 매장의 조합도 보고 싶다면?',
                  style: AppText.regular(12, spacing: -0.3, color: Colors.white)),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => setState(() => _showTooltip = false),
                child: const SizedBox(
                  width: 16,
                  height: 16,
                  child: Icon(Icons.close, size: 12, color: Colors.white),
                ),
              ),
            ]),
          ),
        ],
      );

  Widget _comboCard(BuildContext context, ComboRecommendation combo, AppFlow flow) => Stack(
        clipBehavior: Clip.none,
        children: [
          _comboCardBody(context, combo, flow),
          if (_showTooltip) Positioned(left: 20, top: -32, child: _tooltip()),
        ],
      );

  Widget _comboCardBody(BuildContext context, ComboRecommendation combo, AppFlow flow) =>
      FigmaCard(
        child: Column(
          children: [
            for (final item in combo.items) ...[
              ComboMenuRow(
                item: item,
                onDecrease: () => flow.changeQuantity(
                    comboId: combo.id, itemId: item.id, delta: -1),
                onIncrease: () => flow.changeQuantity(
                    comboId: combo.id, itemId: item.id, delta: 1),
              ),
              const SizedBox(height: 16),
            ],
            Container(height: 1, color: AppColors.gray300),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => showMenuEditSheet(context, combo),
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.edit_outlined, size: 18, color: AppColors.gray800),
                  const SizedBox(width: 4),
                  Text('메뉴 수정하기',
                      style: AppText.semiBold(16, spacing: -0.4, color: AppColors.gray800)),
                ],
              ),
            ),
          ],
        ),
      );

  Future<void> _openYogiyo(String query) async {
    final scheme = Uri.parse('yogiyo://search?query=${Uri.encodeComponent(query)}');
    if (await canLaunchUrl(scheme)) {
      await launchUrl(scheme);
      return;
    }
    await launchUrl(
      Uri.parse('https://www.yogiyo.co.kr/mobile/#/search/?keyword=${Uri.encodeComponent(query)}'),
      mode: LaunchMode.externalApplication,
    );
  }
}

class _TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.5);
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
