import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_flow.dart';
import '../../models/post.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/ds.dart';
import '../address_input_sheet.dart';
import '../my_menu.dart';

/// Figma "홈" (node 681:6419) — 요기요 메인 홈.
///
/// 배너 · 검색 · 퀵메뉴 · 카테고리 · 요기족보 차트로 구성된다.
/// 회의록의 *"기존 요기요 앱 하단 내비 틀 유지 + 메인 홈 하단에 요기족보 차트 링크"*
/// 가 이 화면이다. 퀵메뉴 첫 칸(먹방요기)이 공유 분석 흐름의 진입점이다.
class YogiyoHomeScreen extends StatelessWidget {
  const YogiyoHomeScreen({super.key});

  static const _bannerHeight = 240.0;

  @override
  Widget build(BuildContext context) {
    final flow = context.watch<AppFlow>();

    return Container(
      color: Colors.white,
      child: Stack(
        children: [
          ListView(
            padding: EdgeInsets.zero,
            children: [
              _Banner(location: flow.location?.displayText),
              // 카드 섹션이 배너를 20 만큼 덮어 올라온다 (시안 배너 240 / 섹션 top 204).
              Transform.translate(
                offset: const Offset(0, -36),
                child: const _CardSection(),
              ),
            ],
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: DsBottomNavigation(
                current: DsTab.home,
                onChanged: (tab) => _onTab(context, tab),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onTab(BuildContext context, DsTab tab) {
    final flow = context.read<AppFlow>();
    switch (tab) {
      case DsTab.home:
        break;
      case DsTab.jokbo:
        flow.openJokbo();
      case DsTab.orders:
        flow.openOrders();
      case DsTab.my:
        // 마이요기요 화면은 시안에 없다. 로그아웃만 시트로 낸다.
        showMyMenu(context);
    }
  }
}

// ── 배너 ──────────────────────────────────────────────────────────────────────

/// 배너의 접시 일러스트 + 그림자 (시안 681:6424).
///
/// 시안은 접시 아래에 타원 그림자 벡터 두 개를 따로 깔았다
/// (681:6425 — 그룹 기준 13,68 크기 113x33 / 681:6426 — 89,82 크기 63x29).
/// 그 두 벡터를 받아 오는 대신, **같은 PNG 를 검게 칠해 흐리게 깔아** 모양을 그대로
/// 따르는 그림자를 만든다. 투명 PNG 라 `BoxShadow` 는 사각형 그림자가 되어 못 쓴다.
class _BannerPlatter extends StatelessWidget {
  const _BannerPlatter();

  static const _asset = 'assets/images/home/banner_platter.png';
  static const _size = Size(152, 120);

  @override
  Widget build(BuildContext context) => SizedBox(
        width: _size.width,
        // 그림자가 아래로 빠져나갈 만큼만 키운다.
        height: _size.height + 10,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 10,
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    Colors.black.withValues(alpha: 0.22),
                    BlendMode.srcIn,
                  ),
                  child: Image.asset(
                    _asset,
                    width: _size.width,
                    height: _size.height,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Image.asset(
              _asset,
              width: _size.width,
              height: _size.height,
              fit: BoxFit.contain,
            ),
          ],
        ),
      );
}

class _Banner extends StatelessWidget {
  const _Banner({this.location});

  final String? location;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: YogiyoHomeScreen._bannerHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 시안은 살구색 바탕에 분홍 타원 두 개가 겹친 형태다.
            // 타원을 개별 이미지로 받는 대신 같은 방향의 그라데이션으로 옮겼다.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFCDB9), Color(0xFFFF7BA5), Color(0xFFFA0050)],
                  stops: [0, 0.55, 1],
                ),
              ),
            ),
            // 시안 681:6424 — x 218 / y 77, 152x120. 배너 폭 390 기준 오른쪽 20 이다.
            // 예전에는 top 24 라 상태바(53)만큼 올라가 접시 윗부분이 잘렸다.
            const Positioned(
              right: 20,
              top: 77,
              child: _BannerPlatter(),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(left: 20, top: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _locationChip(context),
                    const SizedBox(height: 15),
                    Text('먹방요기',
                        style: AppText.waguri(26, color: Colors.white)),
                    const SizedBox(height: 5),
                    Text('먹방 속 메뉴를 내 한끼로',
                        style: AppText.waguri(16, color: Colors.white)),
                    const SizedBox(height: 10),
                    // 배너의 "바로가기" 는 퀵메뉴 첫 칸과 같은 곳으로 간다.
                    // 문구만 있고 눌리지 않아 배너가 장식처럼 보였다.
                    GestureDetector(
                      onTap: () => context.read<AppFlow>().openShareGuide(),
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('먹방요기 바로가기',
                              style: AppText.caption(color: Colors.white)),
                          const Icon(Icons.chevron_right, size: 16, color: Colors.white),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  /// 위치 칩. 좌표 대신 동네 이름을 보여주고, 탭하면 주소 시트가 열린다.
  Widget _locationChip(BuildContext context) => GestureDetector(
        onTap: () => AddressInputSheet.show(context),
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                location ?? '위치를 설정해 주세요',
                style: AppText.btn2(color: AppColors.gray700),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.gray700),
            ],
          ),
        ),
      );
}

// ── 카드 섹션 ─────────────────────────────────────────────────────────────────

class _CardSection extends StatelessWidget {
  const _CardSection();

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const _SearchField(),
            const SizedBox(height: 24),
            const _QuickMenuRow(),
            const SizedBox(height: 20),
            const _CategoryGrid(),
            const _JokboChart(),
          ],
        ),
      );
}

class _SearchField extends StatelessWidget {
  const _SearchField();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.chip),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8D8D8D).withValues(alpha: 0.2),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '검색어를 입력해주세요',
                  style: AppText.body2(color: AppColors.gray500)
                      .copyWith(letterSpacing: -0.35),
                ),
              ),
              const Icon(Icons.search, size: 24, color: AppColors.gray700),
            ],
          ),
        ),
      );
}

class _QuickMenuRow extends StatelessWidget {
  const _QuickMenuRow();

  static const _items = [
    ('먹방요기', 'assets/images/home/quick_mukbang.png'),
    ('포장', 'assets/images/home/quick_takeout.png'),
    ('할인랭킹', 'assets/images/home/quick_ranking.png'),
    ('선물하기', 'assets/images/home/quick_gift.png'),
  ];

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: _items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final (label, icon) = _items[i];
            // 첫 칸이 먹방요기 진입점이다. 나머지는 시안의 자리만 지킨다.
            final isMukbang = i == 0;
            return GestureDetector(
              onTap: isMukbang ? () => context.read<AppFlow>().openShareGuide() : null,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8D8D8D).withValues(alpha: 0.2),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(icon, width: 24, height: 24, fit: BoxFit.contain),
                    const SizedBox(width: 4),
                    Text(label, style: AppText.btn2(color: AppColors.gray800)),
                  ],
                ),
              ),
            );
          },
        ),
      );
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid();

  static const _items = [
    ('전체', 'cat_all'),
    ('중국집', 'cat_chinese'),
    ('한식', 'cat_korean'),
    ('카페/디저트', 'cat_cafe'),
    ('버거', 'cat_burger'),
    ('치킨', 'cat_chicken'),
    ('고기/구이', 'cat_meat'),
    ('족발/보쌈', 'cat_jokbal'),
    ('피자/양식', 'cat_pizza'),
    ('마라탕', 'cat_malatang'),
  ];

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.all(20),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            mainAxisSpacing: 16,
            crossAxisSpacing: 12,
            mainAxisExtent: 60,
          ),
          itemCount: _items.length,
          itemBuilder: (context, i) {
            final (label, asset) = _items[i];
            return Column(
              children: [
                SizedBox(
                  height: 40,
                  child: Image.asset(
                    'assets/images/home/$asset.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  style: AppText.caption(color: AppColors.gray700),
                ),
              ],
            );
          },
        ),
      );
}

/// 요기족보 실시간 인기조합. 회의록의 "메인 홈 하단 차트 링크"에 해당한다.
class _JokboChart extends StatelessWidget {
  const _JokboChart();

  @override
  Widget build(BuildContext context) {
    final posts = context.watch<AppFlow>().popularPosts;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 120),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFD2E0), Color(0xFFFDEBF0), Colors.white],
          stops: [0, 0.09, 0.25],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('요기족보',
                          style: AppText.waguri(26,
                              spacing: -0.52, color: AppColors.primary500)),
                      const SizedBox(height: 4),
                      Text('실시간 인기조합 Best 5',
                          style: AppText.body2(color: AppColors.gray700)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => context.read<AppFlow>().openJokbo(),
                  behavior: HitTestBehavior.opaque,
                  // 섹션 하나를 여는 자리라 목록 줄의 꺾쇠보다 크다.
                  child: const DsChevron.right(
                    large: true,
                    color: AppColors.gray700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 210,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: posts.length > 5 ? 5 : posts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) => _card(context, posts[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, YogijokboPost post) => GestureDetector(
        onTap: () => context.read<AppFlow>().openPost(post.id),
        child: Container(
          width: 180,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.chip),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8D8D8D).withValues(alpha: 0.15),
                blurRadius: 6,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                    child: SizedBox(
                      width: 180,
                      height: 109,
                      // 목록 API가 고른 게시글 대표 이미지를 그대로 쓴다. 에셋만
                      // 그리면 실제 글은 imagePaths가 비어 있어 두찜 대체 이미지로
                      // 전부 같아진다. 바깥 ClipRRect가 카드 윗모서리를 담당한다.
                      child: RemoteOrAssetImage(
                        imageUrl: post.thumbnailUrl,
                        assetPath: post.thumbnailPath,
                        size: 180,
                        radius: 0,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🔥', style: TextStyle(fontSize: 10)),
                          const SizedBox(width: 2),
                          Text('인기',
                              style: AppText.caption2(color: AppColors.primary500)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.btn2(color: AppColors.gray800)
                          .copyWith(letterSpacing: -0.28),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      post.bodyPreview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption2(color: AppColors.gray600)
                          .copyWith(height: 1.3, letterSpacing: -0.25),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
