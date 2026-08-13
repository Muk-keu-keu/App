import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../app_flow.dart';
import '../models/combo.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/ds.dart';

/// Figma "메뉴 수정하기" (node 681:6132).
///
/// `GET v1/restaurants/{id}/menus` 로 매장 메뉴 전체를 받아 보여준다. 시트가 아니라
/// 전체 화면이고, 요기요 매장 상세와 같은 구조다 — 큰 사진 위에 로고가 걸치고,
/// 칩으로 목록을 걸러 본다. 메뉴 오른쪽 + 를 누르면 장바구니의 그 매장 칸에 담긴다.
///
/// 칩은 `menuType` 이다. 명세가 `MAIN → SIDE → DRINK` 순으로 정렬해 내려주므로
/// 앱이 다시 정렬하지 않고 받은 순서대로 섹션을 나눈다. 사이드를 옵션으로 넣지 않은
/// 이유가 이 화면이다 — 여기서 따로 골라 담으면 된다.
class StoreMenuScreen extends StatefulWidget {
  const StoreMenuScreen({super.key});

  @override
  State<StoreMenuScreen> createState() => _StoreMenuScreenState();
}

class _StoreMenuScreenState extends State<StoreMenuScreen> {
  MenuType? _type;

  @override
  Widget build(BuildContext context) {
    final flow = context.watch<AppFlow>();
    final restaurant = flow.storeMenuRestaurant;
    final menu = flow.storeMenuItems;

    // 매장을 못 받았으면 아직 로딩 중이거나 404 다. 화면 뼈대 대신 비워 둔다.
    if (restaurant == null) {
      return const ColoredBox(
        color: Colors.white,
        child: Center(child: CircularProgressIndicator(color: AppColors.primary500)),
      );
    }

    // 응답 순서를 그대로 쓴다. 서버가 보낸 순서가 곧 노출 순서다.
    final types = <MenuType>[];
    for (final m in menu) {
      if (!types.contains(m.menuType)) types.add(m.menuType);
    }
    final selected = _type != null && types.contains(_type)
        ? _type!
        : (types.isEmpty ? MenuType.main : types.first);
    final visible = [
      for (final m in menu)
        if (m.menuType == selected) m,
    ];

    return Container(
      color: Colors.white,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _Hero(
              store: restaurant,
              onBack: () => context.read<AppFlow>().closeStoreMenu(),
            ),
          ),
          SliverToBoxAdapter(child: _StoreInfo(store: restaurant)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 20, 0, 20),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    for (var i = 0; i < types.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      DsChipChoice(
                        label: types[i].label,
                        selected: types[i] == selected,
                        onTap: () => setState(() => _type = types[i]),
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
              child: Text(selected.label, style: AppText.h3()),
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
              // 담긴 수량을 보여준다. 같은 메뉴를 다시 누르면 수량만 올라가는데,
              // 표시가 없으면 눌린 건지 알 수 없다.
              inCart: flow.cartQuantityOf(visible[i].menuId),
              onAdd: () => context.read<AppFlow>().addMenuToCart(visible[i]),
              onOpen: () => context.read<AppFlow>().openMenuDetail(visible[i]),
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

  final Restaurant store;
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
            // 상태바 바로 아래에 붙인다. `top: 55` 는 SafeArea 가 더하는 상태바
            // 높이만큼 한 번 더 밀려 사진 한가운데까지 내려와 있었다
            // (디자이너 피드백 2026-08-13).
            Positioned(
              left: 20,
              top: 8,
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

  final Restaurant store;

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
                      // 메뉴 조회는 리뷰 수를 준다. 분석 응답에서 온 매장은 아직
                      // 없어서, (0) 으로 "리뷰 0개" 처럼 보이지 않게 있을 때만 붙인다.
                      if (store.reviewCount != null) ...[
                        const SizedBox(width: 4),
                        Text('(${store.reviewCount})',
                            style: AppText.btn3(color: AppColors.gray600)),
                      ],
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
  const _ProductCard({
    required this.menu,
    required this.inCart,
    required this.onAdd,
    required this.onOpen,
  });

  final Menu menu;

  /// 장바구니에 담긴 수량. 0이면 표시하지 않는다.
  final int inCart;

  /// 사진의 + — 옵션 없이 바로 담는다.
  final VoidCallback onAdd;

  /// 카드를 누르면 옵션을 고르는 상세로 간다 (시안 925:4037, 피드백 25번).
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onOpen,
        behavior: HitTestBehavior.opaque,
        child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(menu.name, style: AppText.sub2())),
                      // MEDIUM/HOT 이면 고추 뱃지 (명세 items[] 비고).
                      if (menu.isSpicy) ...[
                        const SizedBox(width: 4),
                        _SpiceBadge(level: menu.spiceLevel),
                      ],
                    ],
                  ),
                  Text('${wonFormat(menu.price)}원', style: AppText.sub2()),
                  const SizedBox(height: 8),
                  // 분석 응답과 달리 여기엔 description 이 있다 — 처음 보는 메뉴를
                  // 고르는 화면이라 "이게 뭐지" 를 알려줘야 한다 (명세 2번 비고).
                  Text(menu.description,
                      style: AppText.body2(color: AppColors.gray600)),
                  if (inCart > 0) ...[
                    const SizedBox(height: 8),
                    Text('담은 수량 $inCart개',
                        style: AppText.caption(color: AppColors.primary500)),
                  ],
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
        ),
      );
}

/// 매운 메뉴 표시. `spiceLevel` 이 MEDIUM/HOT 일 때만 붙는다.
class _SpiceBadge extends StatelessWidget {
  const _SpiceBadge({required this.level});

  final SpiceLevel level;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.primary500.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          '🌶 ${level.title}',
          style: AppText.caption(color: AppColors.primary500),
        ),
      );
}
