import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_flow.dart';
import '../models/combo.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/ds.dart';
import 'menu_edit_sheet.dart';

/// Figma "먹방 조합" (node 681:5981).
///
/// 추천 조합을 가로로 넘겨 보는 화면. 카드 하나가 매장 하나다.
/// 매장 영역은 매장 사진을 흐리게 깔고 그 위에 흰 글씨를 얹는다.
class ComboResultScreen extends StatefulWidget {
  const ComboResultScreen({super.key});

  @override
  State<ComboResultScreen> createState() => _ComboResultScreenState();
}

class _ComboResultScreenState extends State<ComboResultScreen> {
  late final PageController _pages = PageController(
    initialPage: context.read<AppFlow>().selectedComboIndex,
    viewportFraction: 0.94,
  );

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _openYogiyo(String storeName) async {
    final uri = Uri.parse('https://www.yogiyo.co.kr/mobile/#/search/?q=$storeName');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final flow = context.watch<AppFlow>();
    final combos = flow.recommendations;
    if (combos.isEmpty) return const SizedBox.shrink();

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          _TitleArea(onHome: () => context.read<AppFlow>().backToYogiyoHome()),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pages,
                    itemCount: combos.length,
                    onPageChanged: (i) =>
                        context.read<AppFlow>().selectCombo(combos[i].id),
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: SingleChildScrollView(
                        child: _ComboCard(combo: combos[i]),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _PageIndicator(
                  count: combos.length,
                  current: flow.selectedComboIndex,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          _BottomCta(
            onOrder: () => _openYogiyo(flow.selectedCombo?.store.name ?? ''),
            onOthers: () => context.read<AppFlow>().showComboList(),
          ),
        ],
      ),
    );
  }
}

class _TitleArea extends StatelessWidget {
  const _TitleArea({required this.onHome});

  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) => SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(21, 3, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: onHome,
                  behavior: HitTestBehavior.opaque,
                  child: const SizedBox(
                    width: 24,
                    height: 24,
                    child: Icon(Icons.home_outlined, size: 24, color: Colors.black),
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text('먹방 속 조합을 담았어요',
                  style: AppText.h1().copyWith(letterSpacing: -0.7)),
              Text('먹방 속 메뉴와 가장 유사한 조합이에요.',
                  style: AppText.body1(color: AppColors.gray700)
                      .copyWith(letterSpacing: -0.4)),
              const SizedBox(height: 20),
            ],
          ),
        ),
      );
}

class _ComboCard extends StatelessWidget {
  const _ComboCard({required this.combo});

  final ComboRecommendation combo;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(16),
          bottom: Radius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StoreArea(store: combo.store),
            _MenuList(combo: combo),
          ],
        ),
      );
}

/// 매장 사진을 흐리게 깔고 그 위에 흰 글씨를 얹는다 (시안 blur 30).
class _StoreArea extends StatelessWidget {
  const _StoreArea({required this.store});

  final StoreSummary store;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 152,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            RemoteOrAssetImage(
              imageUrl: store.imageUrl,
              assetPath: store.imagePath,
              size: 152,
              radius: 0,
            ),
            BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              // 흐리게만 하면 흰 글씨가 밝은 사진 위에서 안 보인다.
              child: Container(color: Colors.black.withValues(alpha: 0.28)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  RemoteOrAssetImage(
                    imageUrl: store.imageUrl,
                    assetPath: store.imagePath,
                    size: 64,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(store.name, style: AppText.h3(color: Colors.white)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.star, size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(store.ratingText,
                                style: AppText.caption(color: Colors.white)),
                          ],
                        ),
                        Row(
                          children: [
                            Text(store.distanceText,
                                style: AppText.caption(color: Colors.white)),
                            const SizedBox(width: 4),
                            Container(
                              width: 2,
                              height: 2,
                              decoration: const BoxDecoration(
                                  color: Colors.white, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 4),
                            Text('배달 완료까지 ${store.deliveryText}',
                                style: AppText.caption(color: Colors.white)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _MenuList extends StatelessWidget {
  const _MenuList({required this.combo});

  final ComboRecommendation combo;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            for (final item in combo.items) ...[
              _MenuItem(combo: combo, item: item),
              const SizedBox(height: 16),
              const DsDivider(),
              const SizedBox(height: 16),
            ],
            GestureDetector(
              onTap: () => MenuEditSheet.show(context, combo),
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add, size: 20, color: AppColors.gray800),
                  const SizedBox(width: 4),
                  Text('메뉴 추가하기', style: AppText.btn1(color: AppColors.gray800)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.combo, required this.item});

  final ComboRecommendation combo;
  final ComboItem item;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RemoteOrAssetImage(
                imageUrl: item.imageUrl,
                assetPath: item.imagePath,
                size: 80,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: AppText.sub2()),
                    const SizedBox(height: 4),
                    Text(item.options,
                        style: AppText.caption(color: AppColors.gray600)),
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
                  QuantityStepper(
                    quantity: item.quantity,
                    onDecrease: () => context.read<AppFlow>().changeQuantity(
                        comboId: combo.id, itemId: item.id, delta: -1),
                    onIncrease: () => context.read<AppFlow>().changeQuantity(
                        comboId: combo.id, itemId: item.id, delta: 1),
                  ),
                  const SizedBox(width: 4),
                  _optionButton(context),
                ],
              ),
              Text('${wonFormat(item.lineTotal)}원',
                  style: AppText.sub2(color: AppColors.gray800)
                      .copyWith(letterSpacing: -0.4)),
            ],
          ),
        ],
      );

  /// 옵션 변경 — 메뉴 수정 시트를 그 항목으로 연다.
  Widget _optionButton(BuildContext context) => GestureDetector(
        onTap: () => MenuEditSheet.show(context, combo),
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

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: i == current ? AppColors.primary500 : AppColors.gray300,
                shape: BoxShape.circle,
              ),
            ),
        ],
      );
}

class _BottomCta extends StatelessWidget {
  const _BottomCta({required this.onOrder, required this.onOthers});

  final VoidCallback onOrder;
  final VoidCallback onOthers;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF5D5D5D).withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              DsButton(label: '이대로 주문하기', onPressed: onOrder),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: onOthers,
                behavior: HitTestBehavior.opaque,
                child: Text(
                  '다른 결과 보기',
                  style: AppText.btn2(color: AppColors.primary500)
                      .copyWith(decoration: TextDecoration.underline),
                ),
              ),
            ],
          ),
        ),
      );
}
