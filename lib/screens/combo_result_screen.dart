import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../app_flow.dart';
import '../models/combo.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/ds.dart';
import '../widgets/overlays.dart';
import 'menu_option_sheet.dart';

/// Figma "먹방 조합" (node 681:5981).
///
/// 분석 결과를 가로로 넘겨 보는 화면. 카드 하나가 매장 하나다.
/// 매장 영역은 매장 사진을 흐리게 깔고 그 위에 흰 글씨를 얹는다.
///
/// 영상에 가게가 두 곳 나오면 `exactMatches` 가 두 개라 카드도 두 장이다.
/// "이대로 주문하기" 는 그 둘을 **한 장바구니에** 담아 다음 화면으로 보낸다 —
/// 회의(2026-08-04)에서 정한 다중 매장 묶음 결제의 기본 동작이다.
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

  @override
  Widget build(BuildContext context) {
    final flow = context.watch<AppFlow>();
    final combos = flow.suggestions;

    // 영상 속 메뉴를 파는 곳이 반경 안에 없을 때. 비슷한 집을 여기에 대신 세우면
    // 안 된다 — 이 화면은 "먹방 속 조합" 이라고 말하고 있다.
    if (flow.hasOnlySimilar) {
      return _NoExactMatch(
        dishNames: flow.analysis.dishResults.map((d) => d.dishName).toList(),
        onHome: () => context.read<AppFlow>().backToYogiyoHome(),
        onOthers: () => context.read<AppFlow>().showComboList(),
      );
    }

    if (combos.isEmpty) return const SizedBox.shrink();

    return Container(
      // 시안 925:4220 의 배경은 회색(bg)이다. 헤더와 카드만 흰색이라
      // 카드가 배경에서 떠 보인다.
      color: AppColors.bg,
      child: Column(
        children: [
          _TitleArea(
            storeCount: flow.analysis.exactMatches.length,
            onHome: () => context.read<AppFlow>().backToYogiyoHome(),
          ),
          // 시안 925:4305 — 카드 위에 "N개 중 M개 선택". 카드를 넘기며 고르는
          // 화면이라 몇 개를 담았는지가 안 보이면 진행 상황을 알 수 없다.
          _SelectionCount(
            total: combos.length,
            selected: combos.where((c) => flow.isInCart(c.id)).length,
            onReason: () => RecommendationModal.show(
              context,
              title: '영상과 가장 비슷한 결과예요',
              body: flow.analysis.reasonText(
                maxDeliveryMinutes: flow.preference.maxDeliveryMinutes,
              ),
              hint: '다른 추천 결과는 ‘다른 결과 보기’에서 확인해 보세요.',
            ),
          ),
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
                        child: _ComboCard(
                          combo: combos[i],
                          // 체크박스가 곧 "담는다" 다. 지금 보고 있는 카드인지와
                          // 무관하다 — 넘겨 본 카드가 저절로 담기면 안 된다.
                          selected: flow.isInCart(combos[i].id),
                        ),
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
            onOrder: () => context.read<AppFlow>().openCartFromAnalysis(),
            onOthers: () => context.read<AppFlow>().showComboList(),
          ),
        ],
      ),
    );
  }
}

class _TitleArea extends StatelessWidget {
  const _TitleArea({required this.storeCount, required this.onHome});

  /// 영상에 나온 매장 수. 여러 곳이면 안내 문구가 달라진다.
  final int storeCount;

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
                  // 시안은 디자인 시스템의 `icon/home` (line) 이다. Material 의
                  // home_outlined 는 지붕 모양이 달라 원본과 다르게 보인다.
                  child: SvgPicture.asset(DsIcons.home, width: 24, height: 24),
                ),
              ),
              const SizedBox(height: 3),
              Text('먹방 속 조합을 담았어요',
                  style: AppText.h1().copyWith(letterSpacing: -0.7)),
              Text(
                storeCount > 1
                    ? '$storeCount곳에서 시켜야 하는 조합이에요. 한 번에 결제돼요.'
                    : '먹방 속 메뉴와 가장 유사한 조합이에요.',
                style: AppText.body1(color: AppColors.gray700)
                    .copyWith(letterSpacing: -0.4),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      );
}

/// 조합 카드 하나 (시안 925:4225 선택 / 925:4251 미선택).
///
/// 체크박스가 "이 조합을 담는다" 다. 카드를 넘겨 보는 것과 담는 것은 별개이므로
/// 여러 장을 담을 수 있다 — 회의(2026-08-04)의 다중 매장 묶음 결제와 같은 규칙이다.
class _ComboCard extends StatelessWidget {
  const _ComboCard({required this.combo, required this.selected});

  final ComboSuggestion combo;

  /// 장바구니에 담겼는지. 테두리와 체크가 함께 켜진다.
  final bool selected;

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              // 미선택도 2px 테두리가 있다 (시안 925:4251 은 gray300).
              // 투명으로 두면 카드가 배경에 붙어 경계가 사라진다.
              border: Border.all(
                color: selected ? AppColors.primary400 : AppColors.gray300,
                width: 2,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StoreArea(store: combo.restaurant),
                _MenuList(combo: combo),
              ],
            ),
          ),
          // 담기지 않은 카드에도 빈 체크박스를 그린다. 켜졌을 때만 그리면
          // 무엇을 눌러야 담기는지 알 수 없고, 해제할 자리도 없어진다.
          Positioned(
            top: 14,
            right: 18,
            child: DsCheckbox(
              isOn: selected,
              size: 32,
              onTap: () => context.read<AppFlow>().toggleSuggestionInCart(combo),
            ),
          ),
        ],
      );
}

/// "N개 중 M개 선택" 과 "AI 추천 이유" (시안 1059:5972).
///
/// 고른 개수만 14 SemiBold primary500 이고 나머지는 12 Regular 다.
///
/// 오른쪽 "AI 추천 이유" 는 개정 시안에서 붙었다. 결과가 왜 이 순서인지 묻는
/// 자리를 화면에 두지 않으면, 카드가 임의로 배열된 것처럼 보인다.
class _SelectionCount extends StatelessWidget {
  const _SelectionCount({
    required this.total,
    required this.selected,
    required this.onReason,
  });

  final int total;
  final int selected;
  final VoidCallback onReason;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.only(left: 21, right: 20, bottom: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '$total개 중 ', style: AppText.caption()),
                  TextSpan(
                    text: '$selected개',
                    style: AppText.btn2(color: AppColors.primary500),
                  ),
                  TextSpan(text: ' 선택', style: AppText.caption()),
                ],
              ),
            ),
            // 글씨 12에 아이콘 20 짜리라 스크린 리더에는 이름이 안 잡힌다.
            // 여는 창이 무엇인지 라벨로 말해 준다.
            Semantics(
              button: true,
              label: 'AI 추천 이유',
              child: GestureDetector(
                onTap: onReason,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'AI 추천 이유',
                      style: AppText.caption(color: AppColors.gray700),
                    ),
                    const SizedBox(width: 3),
                    SvgPicture.asset(DsIcons.help, width: 20, height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

/// 매장 사진을 흐리게 깔고 그 위에 흰 글씨를 얹는다 (시안 925:4226).
///
/// 상호 · 별점 · 거리/배달시간 세 줄만 얹는다. "영상 속 {브랜드}" 라벨은 개정
/// 시안에서 빠졌다 — 영상에 나온 조합이 앞에 오고 헤더가 "먹방 속 조합을
/// 담았어요" 라고 말하므로 카드마다 다시 적지 않는다.
///
/// **블러는 위로 갈수록 사라진다.** 시안의 레이어 블러가 프로그레시브라 위쪽은
/// 사진이 선명하고 글씨가 얹히는 아래쪽만 흐려진다. Flutter 에는 그런 필터가 없어
/// 흐린 사본을 위→아래 그라디언트로 마스킹해 겹친다. 어둡게 덮는 층도 같은
/// 그라디언트를 쓴다 — 위쪽까지 덮으면 선명한 사진이 탁해진다.
class _StoreArea extends StatelessWidget {
  const _StoreArea({required this.store});

  final Restaurant store;

  /// 위는 투명, 아래로 갈수록 불투명. 블러와 어둡게 덮는 층이 같이 쓴다.
  static const _fade = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Colors.transparent, Colors.white],
    stops: [0.12, 0.62],
  );

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
            ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: _fade.createShader,
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: RemoteOrAssetImage(
                  imageUrl: store.imageUrl,
                  assetPath: store.imagePath,
                  size: 152,
                  radius: 0,
                ),
              ),
            ),
            // 흐리게만 하면 흰 글씨가 밝은 사진 위에서 안 보인다.
            ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: _fade.createShader,
              child: Container(color: Colors.black.withValues(alpha: 0.32)),
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
                            Text('배달 완료까지 ${store.etaText}',
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

  final ComboSuggestion combo;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            for (final item in combo.items) ...[
              DsMenuItem(
                thumbnail: RemoteOrAssetImage(
                  imageUrl: item.imageUrl,
                  assetPath: item.imagePath,
                  size: 80,
                ),
                name: item.name,
                options: item.optionsText,
                quantity: item.quantity,
                priceText: '${wonFormat(item.lineTotal)}원',
                onDecrease: () => context.read<AppFlow>().changeSuggestionQuantity(
                    combo: combo, menuId: item.menuId, delta: -1),
                onIncrease: () => context.read<AppFlow>().changeSuggestionQuantity(
                    combo: combo, menuId: item.menuId, delta: 1),
                // 개정 시안(925:4243)에 카드 안에도 "옵션 변경" 이 생겼다.
                // 아직 담기 전이라 고친 값은 장바구니가 아니라 이 조합에 들어간다.
                onEditOption: () => MenuOptionSheet.show(
                  context,
                  restaurantId: combo.restaurant.restaurantId,
                  line: item,
                  suggestion: combo,
                ),
              ),
              const SizedBox(height: 16),
              const DsDivider(color: AppColors.gray300),
              const SizedBox(height: 16),
            ],
            DsAddMenuButton(
              onTap: () =>
                  context.read<AppFlow>().openStoreMenu(combo.restaurant.restaurantId),
            ),
          ],
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

/// 영상 속 메뉴를 파는 곳이 없을 때의 첫 화면.
///
/// 비슷한 집으로 자리를 채우지 않는다. 무엇을 찾았고 왜 못 담았는지 말한 다음
/// "다른 결과 보기" 로 넘긴다 — 대체품은 그 화면의 몫이다.
class _NoExactMatch extends StatelessWidget {
  const _NoExactMatch({
    required this.dishNames,
    required this.onHome,
    required this.onOthers,
  });

  /// 영상에서 뽑은 요리들. 무엇을 찾았는지 그대로 보여준다.
  final List<String> dishNames;

  final VoidCallback onHome;
  final VoidCallback onOthers;

  @override
  Widget build(BuildContext context) {
    final dishes = dishNames.where((d) => d.trim().isNotEmpty).toList();

    return Container(
      color: AppColors.bg,
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(21, 3, 20, 0),
              child: Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: onHome,
                  behavior: HitTestBehavior.opaque,
                  child: SvgPicture.asset(DsIcons.home, width: 24, height: 24),
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 21),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dishes.isEmpty
                        ? '영상 속 메뉴를 파는 곳을\n찾지 못했어요'
                        : '${dishes.join(', ')}${objectParticle(dishes.last)}\n'
                            '파는 곳이 근처에 없어요',
                    style: AppText.h2(),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '배달 가능한 거리 안에 같은 메뉴가 없었어요.\n'
                    '비슷한 메뉴는 아래에서 골라 보세요.',
                    style: AppText.body2(color: AppColors.gray600),
                  ),
                ],
              ),
            ),
          ),
          Container(
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
              child: DsButton(label: '비슷한 메뉴 보기', onPressed: onOthers),
            ),
          ),
        ],
      ),
    );
  }
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
              // 시안(681:5981) 문구 그대로. 몇 곳인지는 상단 부제가 알려 준다.
              DsButton(label: '이대로 주문하기', onPressed: onOrder),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: onOthers,
                behavior: HitTestBehavior.opaque,
                child: Text(
                  '다른 결과 보기',
                  // 밑줄 색을 따로 주지 않으면 글자색을 따라가지 않고 검게 그려진다.
                  style: AppText.btn2(color: AppColors.primary500).copyWith(
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.primary500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}
