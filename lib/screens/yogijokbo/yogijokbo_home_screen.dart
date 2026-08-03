import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_flow.dart';
import '../../models/post.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/ds.dart';
import '../address_input_sheet.dart';

/// Figma "요기족보" (node 681:8066).
///
/// 실시간 인기 조합 캐러셀 + 위치 필터 + 조합 목록 + 떠 있는 4탭 내비.
class YogijokboHomeScreen extends StatelessWidget {
  const YogijokboHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final flow = context.watch<AppFlow>();

    return Container(
      color: AppColors.bg,
      child: Column(
        children: [
          _JokboHeader(),
          Expanded(
            child: Stack(
              children: [
                flow.postsLoading && flow.posts.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.primary500),
                      )
                    : RefreshIndicator(
                        color: AppColors.primary500,
                        onRefresh: () => context.read<AppFlow>().loadPosts(),
                        child: ListView(
                          padding: EdgeInsets.zero,
                          children: [
                            _PopularSection(posts: flow.popularPosts),
                            const SizedBox(height: 16),
                            _PostList(posts: flow.posts),
                          ],
                        ),
                      ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: SafeArea(
                    child: DsBottomNavigation(
                      current: DsTab.jokbo,
                      onChanged: (tab) => _onTab(context, tab),
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

  void _onTab(BuildContext context, DsTab tab) {
    final flow = context.read<AppFlow>();
    switch (tab) {
      case DsTab.home:
        flow.backToYogiyoHome();
      case DsTab.orders:
        flow.openOrders();
      case DsTab.jokbo:
        break; // 이미 이 화면이다
      case DsTab.my:
        break; // 마이요기요는 시안에 화면이 없다
    }
  }
}

class _JokboHeader extends StatelessWidget {
  const _JokboHeader({super.key});

  @override
  Widget build(BuildContext context) => DsHeader.main(
        title: '요기족보',
        // 알림·프로필은 시안에 자리만 있고 연결될 화면이 아직 없다.
        // 자리를 지키되 눌러도 동작하지 않는다는 것이 보이도록 흐리게 뒀다.
        actions: const [
          Icon(Icons.notifications_none, size: 24, color: AppColors.gray400),
          Icon(Icons.person_outline, size: 24, color: AppColors.gray400),
        ],
      );
}

/// "🔥 실시간 인기 먹방 조합" — 좌우로 넘겨 보는 캐러셀.
///
/// 카드 폭은 시안대로 340 이고, 다음 카드가 오른쪽에 살짝 걸쳐 보인다.
/// 지금 보고 있는 카드만 gray100 + primary300 테두리로 강조된다.
class _PopularSection extends StatefulWidget {
  const _PopularSection({required this.posts});

  final List<YogijokboPost> posts;

  @override
  State<_PopularSection> createState() => _PopularSectionState();
}

class _PopularSectionState extends State<_PopularSection> {
  final _pages = PageController(viewportFraction: 340 / 390);
  int _current = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.posts.isEmpty) return const SizedBox.shrink();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(top: 20, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const _FireIcon(),
                const SizedBox(width: 4),
                Expanded(
                  child: RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: AppText.h3(color: AppColors.gray800),
                      children: [
                        TextSpan(
                          text: '실시간 인기',
                          style: AppText.h3(color: AppColors.primary500),
                        ),
                        const TextSpan(text: ' 먹방 조합'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 124,
            child: PageView.builder(
              controller: _pages,
              itemCount: widget.posts.length,
              onPageChanged: (i) => setState(() => _current = i),
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: _PopularCard(
                  post: widget.posts[i],
                  highlighted: i == _current,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.center,
            child: _Dots(count: widget.posts.length, current: _current),
          ),
        ],
      ),
    );
  }
}

/// 불꽃 이모지. 시안은 24 프레임 안에서 181% 로 키워 여백을 잘라낸다.
class _FireIcon extends StatelessWidget {
  const _FireIcon();

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 24,
        height: 24,
        child: ClipRect(
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                left: -0.3816 * 24,
                top: -0.3645 * 24,
                width: 24 * 1.8134,
                height: 24 * 1.8134,
                child: Image.asset('assets/images/fire.png'),
              ),
            ],
          ),
        ),
      );
}

class _PopularCard extends StatelessWidget {
  const _PopularCard({required this.post, required this.highlighted});

  final YogijokboPost post;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => context.read<AppFlow>().openPost(post.id),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          decoration: BoxDecoration(
            color: highlighted ? AppColors.gray100 : Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: highlighted
                ? Border.all(color: AppColors.primary300, width: 2)
                : null,
          ),
          child: Row(
            children: [
              RemoteOrAssetImage(
                imageUrl: post.thumbnailUrl,
                assetPath: post.thumbnailPath,
                size: 80,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      post.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.sub2(color: AppColors.gray800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      post.bodyPreview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption(color: AppColors.gray700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: i == current ? AppColors.primary500 : AppColors.gray300,
                shape: BoxShape.circle,
              ),
            ),
        ],
      );
}

class _PostList extends StatelessWidget {
  const _PostList({required this.posts});

  final List<YogijokboPost> posts;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: Colors.white,
        // 아래 여백 100 은 떠 있는 내비에 마지막 글이 가리지 않게 하는 자리다.
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _FilterRow(),
            const SizedBox(height: 12),
            if (posts.isEmpty)
              const _EmptyList()
            else
              for (var i = 0; i < posts.length; i++) ...[
                if (i > 0) const DsDivider(color: AppColors.gray300),
                DsPostItem(
                  title: posts[i].title,
                  content: posts[i].bodyPreview,
                  likeCount: posts[i].likeCount,
                  commentCount: posts[i].commentCount,
                  dateText: posts[i].relativeDateText,
                  liked: posts[i].likedByMe,
                  thumbnail: RemoteOrAssetImage(
                    imageUrl: posts[i].thumbnailUrl,
                    assetPath: posts[i].thumbnailPath,
                    size: 60,
                  ),
                  onTap: () => context.read<AppFlow>().openPost(posts[i].id),
                  onLike: () => context.read<AppFlow>().toggleLikeOn(posts[i].id),
                ),
              ],
          ],
        ),
      );
}

class _FilterRow extends StatelessWidget {
  const _FilterRow();

  @override
  Widget build(BuildContext context) {
    final flow = context.watch<AppFlow>();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () => _onToggle(context, flow),
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              DsCheckbox(isOn: flow.orderableOnly),
              const SizedBox(width: 8),
              Text('내 위치에서 가능한 조합만',
                  style: AppText.body2(color: AppColors.gray800)),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => _pickSort(context, flow),
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              Text(flow.postSort.title,
                  style: AppText.btn2(color: AppColors.gray800)),
              const SizedBox(width: 4),
              const DsChevron.down(),
            ],
          ),
        ),
      ],
    );
  }

  /// 위치가 없으면 걸러낼 근거가 없다. 체크만 켜고 아무 일도 안 일어나면
  /// 고장으로 보이므로, 켜는 순간 주소 입력 시트를 띄워 위치를 받는다.
  void _onToggle(BuildContext context, AppFlow flow) {
    final willTurnOn = !flow.orderableOnly;
    context.read<AppFlow>().toggleOrderableOnly();
    if (willTurnOn && flow.location == null) {
      AddressInputSheet.show(context);
    }
  }

  Future<void> _pickSort(BuildContext context, AppFlow flow) async {
    final selected = await showModalBottomSheet<PostSort>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SortSheet(current: flow.postSort),
    );
    if (selected != null && context.mounted) {
      context.read<AppFlow>().updatePostSort(selected);
    }
  }
}

class _SortSheet extends StatelessWidget {
  const _SortSheet({required this.current});

  final PostSort current;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('정렬', style: AppText.sub1()),
              const SizedBox(height: 8),
              for (final sort in PostSort.values)
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(sort),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      children: [
                        Text(
                          sort.title,
                          style: sort == current
                              ? AppText.btn1(color: AppColors.primary500)
                              : AppText.body1(),
                        ),
                        const Spacer(),
                        if (sort == current)
                          const Icon(Icons.check, size: 18, color: AppColors.primary500),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
}

class _EmptyList extends StatelessWidget {
  const _EmptyList();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 48),
        alignment: Alignment.center,
        child: Column(
          children: [
            Image.asset('assets/images/platter.png', width: 100, height: 100),
            const SizedBox(height: 16),
            Text(
              '이 위치에서 주문할 수 있는 조합이 없어요',
              textAlign: TextAlign.center,
              style: AppText.body2(color: AppColors.gray700),
            ),
          ],
        ),
      );
}
