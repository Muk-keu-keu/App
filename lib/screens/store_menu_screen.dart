import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../app_flow.dart';
import '../models/combo.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/ds.dart';

/// Figma "메뉴 추가하기" (node 681:6132).
///
/// 조합 카드의 "메뉴 추가하기"로 들어오는 매장 메뉴 화면. 시트가 아니라 전체 화면이고,
/// 요기요 매장 상세와 같은 구조다 — 큰 사진 위에 로고가 걸치고, 카테고리 칩으로 목록을
/// 걸러 본다. 메뉴 오른쪽 + 를 누르면 지금 보고 있던 조합에 담긴다.
class StoreMenuScreen extends StatefulWidget {
  const StoreMenuScreen({super.key});

  @override
  State<StoreMenuScreen> createState() => _StoreMenuScreenState();
}

class _StoreMenuScreenState extends State<StoreMenuScreen> {
  String? _category;

  @override
  Widget build(BuildContext context) {
    final flow = context.watch<AppFlow>();
    final combo = flow.storeMenuCombo;
    if (combo == null) return const SizedBox.shrink();

    final menu = flow.storeMenuItems;
    final categories = <String>[];
    for (final m in menu) {
      if (!categories.contains(m.category)) categories.add(m.category);
    }
    final selected = _category != null && categories.contains(_category)
        ? _category!
        : (categories.isEmpty ? '' : categories.first);
    final visible = menu.where((m) => m.category == selected).toList();

    return Container(
      color: Colors.white,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _Hero(
              store: combo.store,
              onBack: () => context.read<AppFlow>().closeStoreMenu(),
            ),
          ),
          SliverToBoxAdapter(child: _StoreInfo(store: combo.store)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 20, 0, 20),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    for (var i = 0; i < categories.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      DsChipChoice(
                        label: categories[i],
                        selected: categories[i] == selected,
                        onTap: () => setState(() => _category = categories[i]),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(selected, style: AppText.h3()),
            ),
          ),
          SliverList.separated(
            itemCount: visible.length,
            separatorBuilder: (_, _) => const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: DsDivider(color: AppColors.gray300),
            ),
            itemBuilder: (_, i) => _ProductCard(
              menu: visible[i],
              onAdd: () => context.read<AppFlow>().addMenuToCombo(visible[i]),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

/// 매장 사진 202 + 반투명 뒤로가기 알약. 로고 80 은 사진 아래쪽에 걸친다.
class _Hero extends StatelessWidget {
  const _Hero({required this.store, required this.onBack});

  final StoreSummary store;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 242, // 사진 202 + 로고가 내려온 40
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              height: 202,
              width: double.infinity,
              child: RemoteOrAssetImage(
                imageUrl: store.imageUrl,
                assetPath: store.heroPath,
                size: 202,
                radius: 0,
              ),
            ),
            Positioned(
              left: 20,
              top: 55,
              child: SafeArea(
                bottom: false,
                child: GestureDetector(
                  onTap: onBack,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const DsChevron.left(),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 20,
              top: 162,
              child: ClipOval(
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: Image.asset(store.imagePath, fit: BoxFit.cover),
                ),
              ),
            ),
          ],
        ),
      );
}

class _StoreInfo extends StatelessWidget {
  const _StoreInfo({required this.store});

  final StoreSummary store;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.gray300)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(store.name, style: AppText.h2()),
            const SizedBox(height: 8),
            Row(
              children: [
                _pill(
                  Row(
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: Center(
                          child: SvgPicture.asset(DsIcons.star,
                              width: 15, height: 14.5),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text('리뷰 ${store.rating.toStringAsFixed(1)}',
                          style: AppText.btn2(color: AppColors.gray800)),
                      const SizedBox(width: 4),
                      Text('(${store.reviewCount})',
                          style: AppText.btn3(color: AppColors.gray600)),
                    ],
                  ),
                ),
                const SizedBox(width: 7),
                _pill(Text('가게·영양성분·원산지',
                    style: AppText.btn2(color: AppColors.gray800))),
              ],
            ),
            const SizedBox(height: 20),
            // 배달/포장 탭. 지금은 배달만 쓰므로 포장은 눌리지 않는 상태로 둔다.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _tab(store.deliveryTabText, active: true),
                const SizedBox(width: 64),
                _tab(store.pickupTabText, active: false),
              ],
            ),
          ],
        ),
      );

  Widget _pill(Widget child) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: AppColors.gray300),
        ),
        child: child,
      );

  Widget _tab(String label, {required bool active}) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? AppColors.gray800 : AppColors.gray300,
              width: active ? 2 : 1,
            ),
          ),
        ),
        child: Text(
          label,
          style: active
              ? AppText.btn2(color: AppColors.gray800)
              : AppText.body2(color: AppColors.gray500),
        ),
      );
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.menu, required this.onAdd});

  final MenuItem menu;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(menu.name, style: AppText.sub2()),
                  Text('${wonFormat(menu.price)}원', style: AppText.sub2()),
                  const SizedBox(height: 8),
                  Text(menu.options,
                      style: AppText.body2(color: AppColors.gray600)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // + 는 사진 오른쪽 아래에 걸친다.
            SizedBox(
              width: 88,
              height: 88,
              child: Stack(
                children: [
                  RemoteOrAssetImage(
                    imageUrl: menu.imageUrl,
                    assetPath: menu.imagePath,
                    size: 88,
                  ),
                  Positioned(
                    right: 8,
                    bottom: 6,
                    child: GestureDetector(
                      onTap: onAdd,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: SvgPicture.asset(
                          DsIcons.plus,
                          width: 20,
                          height: 20,
                          colorFilter: const ColorFilter.mode(
                              AppColors.gray800, BlendMode.srcIn),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
