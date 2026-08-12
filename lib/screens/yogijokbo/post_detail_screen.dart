import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../app_flow.dart';
import '../../models/combo.dart';
import '../../models/post.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/ds.dart';
import '../../widgets/overlays.dart';
import 'jokbo_widgets.dart';

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
          // 점 3개는 뒤로가기와 같은 줄(헤더 right_area)에 온다 — 시안 909:2583.
          DsHeader.detail(
            title: '',
            onBack: () => context.read<AppFlow>().backToJokboHome(),
            actions: [
              if (post.mine)
                _MoreDots(
                  key: const ValueKey('post-menu'),
                  onTap: () => openPostMenu(context),
                ),
            ],
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _PostSection(post: post),
                const SizedBox(height: 16),
                // 시안 909:2578 은 아코디언이 아니다. 누르면 바텀시트가 뜬다.
                _OrderedMenuRow(
                  onTap: () => _OrderedMenuSheet.show(context, post: post),
                ),
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
              // 목록 카드와 같은 배지를 쓴다. 탭하면 그 영상이 열린다 —
              // 상세에만 따로 만든 줄은 제목만 보여주고 눌러도 아무 일이 없었다.
              YoutubeSourceBadge(source: post.source!),
              const SizedBox(height: 20),
            ],
            _ActionRow(post: post),
          ],
        ),
      );
}

/// 게시물 점 아이콘 → 수정하기 / 삭제하기 (시안 922:2734 —
/// "게시물 헤더의 우측 점 아이콘 선택시 하단에 나타남").
///
/// 헤더에서 부르므로 작성자 줄 위젯 안에 두지 않는다.
Future<void> openPostMenu(BuildContext context) async {
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

/// 점 3개 (시안 909:2583 `right_area` 의 24x24 아이콘).
///
/// Figma 이름은 `icon/bell` 이지만 종 모양이 아니다 — 지름 2 원 세 개를 세로로,
/// 중심에서 -6 / 0 / +6 에 놓는다. `Icons.more_vert` 는 점이 더 크고 간격도 달라
/// 원본과 다르게 보인다.
class _MoreDots extends StatelessWidget {
  const _MoreDots({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 24,
          height: 24,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 3; i++) ...[
                // 중심 간격 6 = 점 2 + 여백 4.
                if (i > 0) const SizedBox(height: 4),
                Container(
                  width: 2,
                  height: 2,
                  decoration: const BoxDecoration(
                    color: AppColors.gray800,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
}

class _Profile extends StatelessWidget {
  const _Profile({required this.author, required this.dateText});

  final PostAuthor author;
  final String dateText;

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

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.post});

  final YogijokboPost post;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          _count(
            // 누르면 채워진다. 색만 바꾸면 외곽선만 분홍이 되어 눌렀는지 알기 어렵다.
            asset: post.likedByMe ? DsIcons.heartFill : DsIcons.heart,
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

/// "주문한 메뉴" 한 줄 (시안 909:2578, h 62).
///
/// 아코디언이 아니다 — 누르면 바텀시트가 뜬다. 텍스트 x 20 / 꺾쇠 x 350.
class _OrderedMenuRow extends StatelessWidget {
  const _OrderedMenuRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: double.infinity,
          height: 62,
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('주문한 메뉴', style: AppText.sub2()),
              const RotatedBox(quarterTurns: 2, child: DsChevron.left()),
            ],
          ),
        ),
      );
}

/// "주문한 메뉴" 바텀시트 (시안 893:1944, 390x780).
///
/// 상세에 조합을 펼쳐 두면 댓글이 한참 아래로 밀린다. 시안이 조합을 시트로 뺀
/// 이유이고, 피드백에도 두 번 적혔다.
class _OrderedMenuSheet extends StatelessWidget {
  const _OrderedMenuSheet({required this.post});

  final YogijokboPost post;

  static void show(BuildContext context, {required YogijokboPost post}) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _OrderedMenuSheet(post: post),
    );
  }

  @override
  Widget build(BuildContext context) => Container(
        // 시안은 937 중 780 이다. 화면 높이에 비례해 잡는다.
        height: MediaQuery.sizeOf(context).height * 0.83,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
        ),
        child: Column(
          children: [
            // Drag Handle 48x5 at y 12 (893:1997).
            const SizedBox(height: 12),
            Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.gray300,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            // header 56 (893:1996). 시트라 뒤로가기가 없고 제목만 있다.
            SizedBox(
              height: 56,
              child: Center(child: Text('주문한 메뉴', style: AppText.h3())),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: _MenuSection(post: post, showPrice: true),
              ),
            ),
            // Bottom CTA 104 — Button 350x52 at (20, 20) (900:1256).
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: SafeArea(
                top: false,
                child: DsButton(
                  label: '나도 주문하기',
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.read<AppFlow>().startReorder();
                  },
                ),
              ),
            ),
          ],
        ),
      );
}

/// 조합에 담긴 메뉴. 매장 이름을 누르면 그 매장 메뉴로 넘어간다.
///
/// 회의(2026-08-04) 이후 글 하나에 매장이 여러 곳일 수 있다. 매장마다 섹션을
/// 나눠 그린다 — 한 목록에 섞어 놓으면 어느 가게에서 시키는 메뉴인지 알 수 없다.
class _MenuSection extends StatelessWidget {
  const _MenuSection({required this.post, this.showPrice = false});

  /// 시트에서는 금액·수량까지 보여준다 (시안 893:1944 의 cart item).
  final bool showPrice;

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
                          if (showPrice) ...[
                            const SizedBox(height: 8),
                            // 시트에서는 금액과 수량을 오른쪽에 붙여 준다.
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                '${wonFormat(item.lineTotal)}원 ${item.quantity}개',
                                style: AppText.sub2(color: AppColors.gray800),
                              ),
                            ),
                          ],
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
              // 내 댓글만 지울 수 있다. 남의 댓글은 서버가 403 을 준다.
              if (comment.mine)
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
                // 입력 전에는 회색, 한 글자라도 넣으면 핑크 (피드백 2026-08-09).
                // controller 가 ValueNotifier 라 입력마다 이 버튼만 다시 그린다.
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) {
                    final ready = value.text.trim().isNotEmpty;
                    return GestureDetector(
                      // 빈 입력으로 눌러도 아무 일이 없어야 한다. 색만 회색이고
                      // 눌리면 "보냈는데 안 올라갔다" 로 읽힌다.
                      onTap: ready ? onSend : null,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: 36,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: ready ? AppColors.primary500 : AppColors.gray500,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.arrow_upward,
                          // 시안보다 작게 그려져 있었다. 버튼 28 높이에 맞춰 키운다.
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
}
