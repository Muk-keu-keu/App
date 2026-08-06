import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../app_flow.dart';
import '../../models/post.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/ds.dart';
import '../../widgets/overlays.dart';

/// Figma "조합 상세" (node 681:8105).
///
/// 글 본문 · 출처 영상 · 조합에 담긴 메뉴 · 댓글이 세로로 쌓인다.
/// 댓글 입력창은 아래에 고정된다.
class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({super.key});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _submitComment() {
    final body = _commentController.text;
    if (body.trim().isEmpty) return;
    context.read<AppFlow>().submitComment(body);
    _commentController.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final flow = context.watch<AppFlow>();
    final post = flow.selectedPost;

    // 뒤로가기 직후 한 프레임 동안 null 이 될 수 있다.
    if (post == null) return const SizedBox.shrink();

    return Container(
      color: AppColors.bg,
      child: Column(
        children: [
          // 시안의 헤더는 뒤로가기만 있고 제목 자리가 비어 있다.
          DsHeader.detail(
            title: '',
            onBack: () => context.read<AppFlow>().backToJokboHome(),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _PostSection(post: post),
                const SizedBox(height: 16),
                _MenuSection(post: post),
                const SizedBox(height: 16),
                _CommentSection(
                  count: post.commentCount,
                  comments: flow.postComments,
                ),
              ],
            ),
          ),
          _Composer(controller: _commentController, onSend: _submitComment),
        ],
      ),
    );
  }
}

class _PostSection extends StatelessWidget {
  const _PostSection({required this.post});

  final YogijokboPost post;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Profile(author: post.author, dateText: post.dateText),
            const SizedBox(height: 16),
            Text(post.title, style: AppText.sub1().copyWith(letterSpacing: -0.45)),
            const SizedBox(height: 9),
            Text(post.body, style: AppText.body2(color: AppColors.gray800)),
            if (post.imagePaths.isNotEmpty || post.imageUrls.isNotEmpty) ...[
              const SizedBox(height: 16),
              _ImageRow(post: post),
            ],
            const SizedBox(height: 20),
            if (post.source != null) ...[
              _SourceLink(source: post.source!),
              const SizedBox(height: 20),
            ],
            _ActionRow(post: post),
          ],
        ),
      );
}

class _Profile extends StatelessWidget {
  const _Profile({required this.author, required this.dateText});

  final PostAuthor author;
  final String dateText;

  /// 헤더 점 아이콘 → 수정하기 / 삭제하기 (시안 922:2734 —
  /// "게시물 헤더의 우측 점 아이콘 선택시 하단에 나타남").
  Future<void> _openMenu(BuildContext context) async {
    final flow = context.read<AppFlow>();
    final picked = await AppActionSheet.show(
      context,
      items: const [
        AppActionSheetItem(label: '수정하기', value: 'edit'),
        AppActionSheetItem(label: '삭제하기', value: 'delete', destructive: true),
      ],
    );

    if (picked == 'edit') {
      flow.openPostEdit();
      return;
    }
    if (picked != 'delete' || !context.mounted) return;

    final ok = await AppConfirmDialog.show(
      context,
      title: '게시물을 삭제할까요?',
      message: '삭제한 게시물은 복구할 수 없어요.',
    );
    if (ok) await flow.deleteCurrentPost();
  }

  @override
  Widget build(BuildContext context) => Row(
        children: [
          // 시안은 옅은 분홍 원 위에 프로필 사진을 올린다. 사진이 없으면 첫 글자를 쓴다.
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFFFEBF1),
              shape: BoxShape.circle,
            ),
            child: Text(author.initial,
                style: AppText.sub2(color: AppColors.primary500)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(author.nickname, style: AppText.sub2(color: AppColors.gray800)),
                Text(dateText, style: AppText.caption(color: AppColors.gray600)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _openMenu(context),
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.only(left: 12),
              child: Icon(
                Icons.more_vert,
                size: 20,
                color: AppColors.gray600,
              ),
            ),
          ),
        ],
      );
}

class _ImageRow extends StatelessWidget {
  const _ImageRow({required this.post});

  final YogijokboPost post;

  @override
  Widget build(BuildContext context) {
    final count = post.imageUrls.isNotEmpty
        ? post.imageUrls.length
        : post.imagePaths.length;

    return Row(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.gray400),
              borderRadius: BorderRadius.circular(AppRadius.chip),
            ),
            child: RemoteOrAssetImage(
              imageUrl: i < post.imageUrls.length ? post.imageUrls[i] : null,
              assetPath:
                  i < post.imagePaths.length ? post.imagePaths[i] : post.thumbnailPath,
              size: 80,
            ),
          ),
        ],
      ],
    );
  }
}

/// 출처 영상 한 줄. 회색 판 위에 아이콘과 제목을 얹는다.
class _SourceLink extends StatelessWidget {
  const _SourceLink({required this.source});

  final PostSource source;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.gray100,
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
        child: Row(
          children: [
            // 시안은 유튜브 로고 이미지다. 아직 받지 않아 같은 치수의 아이콘으로 둔다.
            const SizedBox(
              width: 20,
              height: 14,
              child: Icon(Icons.play_arrow, size: 14, color: AppColors.primary500),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                source.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption(color: AppColors.gray700),
              ),
            ),
          ],
        ),
      );
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.post});

  final YogijokboPost post;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          _count(
            asset: DsIcons.heart,
            width: 15.5,
            height: 14.5,
            color: post.likedByMe ? AppColors.primary500 : null,
            value: post.likeCount,
            onTap: () => context.read<AppFlow>().toggleLike(),
          ),
          const SizedBox(width: 8),
          _count(
            asset: DsIcons.bubble,
            width: 15.78,
            height: 15.83,
            value: post.commentCount,
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => context.read<AppFlow>().startReorder(),
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: 36,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.primary500,
                borderRadius: BorderRadius.circular(AppRadius.chip),
              ),
              child: Text('나도 주문하기', style: AppText.btn2(color: Colors.white)),
            ),
          ),
        ],
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
                  colorFilter:
                      color == null ? null : ColorFilter.mode(color, BlendMode.srcIn),
                ),
              ),
            ),
            const SizedBox(width: 2),
            Text('$value', style: AppText.caption(color: AppColors.gray600)),
          ],
        ),
      );
}

/// 조합에 담긴 메뉴. 매장 이름을 누르면 그 매장 메뉴로 넘어간다.
///
/// 회의(2026-08-04) 이후 글 하나에 매장이 여러 곳일 수 있다. 매장마다 섹션을
/// 나눠 그린다 — 한 목록에 섞어 놓으면 어느 가게에서 시키는 메뉴인지 알 수 없다.
class _MenuSection extends StatelessWidget {
  const _MenuSection({required this.post});

  final YogijokboPost post;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var s = 0; s < post.stores.length; s++) ...[
              if (s > 0) const SizedBox(height: 24),
              GestureDetector(
                onTap: () => context
                    .read<AppFlow>()
                    .openStoreMenu(post.stores[s].restaurantId),
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(post.stores[s].restaurant.name,
                          style: AppText.sub2()),
                    ),
                    const RotatedBox(quarterTurns: 2, child: DsChevron.left()),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const DsDivider(color: AppColors.gray300),
              for (final item in post.stores[s].lines) ...[
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RemoteOrAssetImage(
                      imageUrl: item.imageUrl,
                      assetPath: item.imagePath,
                      size: 48,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.name,
                              style: AppText.sub2().copyWith(letterSpacing: -0.4)),
                          const SizedBox(height: 4),
                          Text(item.optionsText,
                              style: AppText.caption(color: AppColors.gray600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      );
}

class _CommentSection extends StatelessWidget {
  const _CommentSection({required this.count, required this.comments});

  final int count;
  final List<PostComment> comments;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('댓글 $count', style: AppText.btn2(color: AppColors.gray800)),
            for (var i = 0; i < comments.length; i++) ...[
              const SizedBox(height: 12),
              if (i > 0) ...[
                const DsDivider(),
                const SizedBox(height: 12),
              ],
              _CommentItem(comment: comments[i]),
            ],
          ],
        ),
      );
}

class _CommentItem extends StatefulWidget {
  const _CommentItem({required this.comment});

  final PostComment comment;

  @override
  State<_CommentItem> createState() => _CommentItemState();
}

class _CommentItemState extends State<_CommentItem> {
  /// 메뉴를 점 아이콘 바로 아래에 띄우기 위한 기준점.
  final _anchorKey = GlobalKey();

  PostComment get comment => widget.comment;

  /// 댓글 점 아이콘 → 삭제하기 (시안 922:2734 — "댓글의 점 아이콘 선택 시").
  Future<void> _openMenu() async {
    final flow = context.read<AppFlow>();
    final picked = await AppOverflowMenu.show(
      context,
      anchorKey: _anchorKey,
      items: const [
        AppActionSheetItem(label: '삭제하기', value: 'delete', destructive: true),
      ],
    );
    if (picked != 'delete' || !mounted) return;

    final ok = await AppConfirmDialog.show(
      context,
      title: '댓글을 삭제할까요?',
      message: '삭제한 댓글은 복구할 수 없어요.',
    );
    if (ok) await flow.deleteComment(comment.id);
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFEBF1),
                  shape: BoxShape.circle,
                ),
                child: Text(comment.author.initial,
                    style: AppText.caption(color: AppColors.primary500)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(comment.author.nickname,
                        style: AppText.caption()
                            .copyWith(fontWeight: FontWeight.w600)),
                    Text(_dateOf(comment.createdAt),
                        style: AppText.caption2(color: AppColors.gray600)),
                  ],
                ),
              ),
              GestureDetector(
                key: _anchorKey,
                onTap: _openMenu,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.more_horiz,
                    size: 20,
                    color: AppColors.gray500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(comment.body, style: AppText.body2(color: AppColors.gray700)),
        ],
      );

  static String _dateOf(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFFEFEFE),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8D8D8D).withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: SafeArea(
          top: false,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.gray200,
              borderRadius: BorderRadius.circular(AppRadius.chip),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    onSubmitted: (_) => onSend(),
                    style: AppText.body2(),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: '댓글을 입력해 주세요',
                      hintStyle: AppText.body2(color: AppColors.gray500),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onSend,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 36,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primary500,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.arrow_upward, size: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
