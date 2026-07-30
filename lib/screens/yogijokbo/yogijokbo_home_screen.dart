import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_flow.dart';
import '../../models/post.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../address_input_sheet.dart';
import 'jokbo_widgets.dart';

/// 요기족보 홈 (Figma "먹슐랭 홈").
/// 실시간 인기 조합 캐러셀 + 위치 필터 + 조합 목록 + 하단 탭바.
class YogijokboHomeScreen extends StatelessWidget {
  const YogijokboHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final flow = context.watch<AppFlow>();

    return Container(
      color: AppColors.pageBackground,
      child: Column(
        children: [
          const _JokboHeader(),
          Expanded(
            child: flow.postsLoading && flow.posts.isEmpty
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () => context.read<AppFlow>().loadPosts(),
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 24),
                      children: [
                        if (flow.posts.isNotEmpty) _PopularCard(post: flow.posts.first),
                        const _FilterRow(),
                        if (flow.posts.isEmpty)
                          const _EmptyList()
                        else
                          for (final post in flow.posts)
                            _PostRow(
                              post: post,
                              onTap: () => context.read<AppFlow>().openPost(post.id),
                            ),
                      ],
                    ),
                  ),
          ),
          JokboTabBar(onHome: () => context.read<AppFlow>().backToHome()),
        ],
      ),
    );
  }
}

class _JokboHeader extends StatelessWidget {
  const _JokboHeader();

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
                Text('요기족보', style: AppText.semiBold(22, spacing: -0.55)),
                const Spacer(),
                // 검색·프로필은 시안에 자리만 있고 연결될 화면이 아직 없다.
                // 자리를 지키되 눌러도 동작하지 않는다는 것이 보이도록 흐리게 뒀다.
                Icon(Icons.search, size: 22, color: AppColors.gray400),
                const SizedBox(width: 16),
                Icon(Icons.person_outline, size: 22, color: AppColors.gray400),
              ],
            ),
          ),
        ),
      );
}

/// "실시간 인기 먹방 조합" 카드.
/// 시안은 좌우로 넘기는 캐러셀이지만 목록 API 가 인기 조합을 따로 내려주지 않아
/// 지금은 정렬 첫 항목 하나를 보여준다. 인디케이터는 시안 형태를 유지했다.
class _PopularCard extends StatelessWidget {
  const _PopularCard({required this.post});

  final YogijokboPost post;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: GestureDetector(
          onTap: () => context.read<AppFlow>().openPost(post.id),
          child: FigmaCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Text('실시간 인기 ',
                        style: AppText.semiBold(17, spacing: -0.4, color: AppColors.primary)),
                    Text('먹방 조합', style: AppText.semiBold(17, spacing: -0.4)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RemoteOrAssetImage(
                      imageUrl: post.thumbnailUrl,
                      assetPath: post.thumbnailPath,
                      size: 84,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(post.title, style: AppText.semiBold(15, spacing: -0.4)),
                          const SizedBox(height: 4),
                          Text(
                            post.bodyPreview,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.regular(13,
                                spacing: -0.3, color: AppColors.gray700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < 5; i++)
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: i == 0 ? AppColors.primary : AppColors.gray300,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}

class _FilterRow extends StatelessWidget {
  const _FilterRow();

  @override
  Widget build(BuildContext context) {
    final flow = context.watch<AppFlow>();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _onToggle(context, flow),
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                FigmaCheckbox(isOn: flow.orderableOnly),
                const SizedBox(width: 8),
                Text('내 위치에서 가능한 조합만',
                    style: AppText.medium(14, spacing: -0.35, color: AppColors.gray800)),
              ],
            ),
          ),
          const Spacer(),
          _sortDropdown(context, flow),
        ],
      ),
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

  Widget _sortDropdown(BuildContext context, AppFlow flow) => GestureDetector(
        onTap: () async {
          final selected = await showModalBottomSheet<PostSort>(
            context: context,
            backgroundColor: Colors.transparent,
            builder: (_) => _SortSheet(current: flow.postSort),
          );
          if (selected != null) {
            // ignore: use_build_context_synchronously — mounted 확인 후 사용
            if (context.mounted) context.read<AppFlow>().updatePostSort(selected);
          }
        },
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            Text(flow.postSort.title,
                style: AppText.medium(14, spacing: -0.35, color: AppColors.gray800)),
            Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.gray800),
          ],
        ),
      );
}

class _SortSheet extends StatelessWidget {
  const _SortSheet({required this.current});

  final PostSort current;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('정렬', style: AppText.semiBold(18, spacing: -0.45)),
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
                              ? AppText.semiBold(16, spacing: -0.4, color: AppColors.primary)
                              : AppText.regular(16, spacing: -0.4),
                        ),
                        const Spacer(),
                        if (sort == current)
                          const Icon(Icons.check, size: 18, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
}

class _PostRow extends StatelessWidget {
  const _PostRow({required this.post, required this.onTap});

  final YogijokboPost post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          // color 와 decoration 을 함께 주면 런타임 assertion 이 터진다.
          // 배경색은 decoration 안에 둔다.
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.gray200)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RemoteOrAssetImage(
                    imageUrl: post.thumbnailUrl,
                    assetPath: post.thumbnailPath,
                    size: 76,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(post.title, style: AppText.semiBold(15, spacing: -0.4)),
                        const SizedBox(height: 4),
                        Text(
                          post.bodyPreview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.regular(13, spacing: -0.3, color: AppColors.gray700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (post.source != null) ...[
                const SizedBox(height: 10),
                YoutubeSourceBadge(source: post.source!),
              ],
              const SizedBox(height: 10),
              LikeCommentRow(likeCount: post.likeCount, commentCount: post.commentCount),
            ],
          ),
        ),
      );
}

class _EmptyList extends StatelessWidget {
  const _EmptyList();

  @override
  Widget build(BuildContext context) => Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
        alignment: Alignment.center,
        child: Column(
          children: [
            Image.asset('assets/images/platter.png', width: 100, height: 100),
            const SizedBox(height: 16),
            Text(
              '이 위치에서 주문할 수 있는 조합이 없어요',
              textAlign: TextAlign.center,
              style: AppText.regular(15, spacing: -0.35, color: AppColors.gray700),
            ),
          ],
        ),
      );
}
