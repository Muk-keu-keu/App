import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_flow.dart';
import '../../models/combo.dart';
import '../../models/post.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'jokbo_widgets.dart';

/// 조합 상세 (Figma "조합 상세").
/// 작성자·본문·사진·출처 영상·조합 메뉴·좋아요·댓글 + "나도 주문하기".
class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({super.key});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _commentController = TextEditingController();

  /// 매장 섹션 접기. 시안은 펼쳐진(chevron up) 상태가 기본이다.
  bool _storeExpanded = true;

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
      color: Colors.white,
      child: Column(
        children: [
          _backBar(context),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PostAuthorRow(author: post.author, dateText: post.dateText),
                      const SizedBox(height: 16),
                      Text(post.title, style: AppText.semiBold(17, spacing: -0.4)),
                      const SizedBox(height: 8),
                      Text(
                        post.body,
                        style: AppText.regular(14, spacing: -0.35, color: AppColors.gray800),
                      ),
                      if (post.imagePaths.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _photos(post),
                      ],
                      if (post.source != null) ...[
                        const SizedBox(height: 12),
                        YoutubeSourceBadge(source: post.source!),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _storeSection(context, post),
                Container(height: 8, color: AppColors.pageBackground),
                _commentSection(post, flow.postComments),
              ],
            ),
          ),
          _commentInput(),
        ],
      ),
    );
  }

  Widget _backBar(BuildContext context) => Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 32,
            child: Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: () => context.read<AppFlow>().backToJokboHome(),
                behavior: HitTestBehavior.opaque,
                child: const SizedBox(
                  width: 32,
                  height: 32,
                  child: Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.black),
                ),
              ),
            ),
          ),
        ),
      );

  Widget _photos(YogijokboPost post) => Row(
        children: [
          for (final path in post.imagePaths.take(2))
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: RemoteOrAssetImage(
                imageUrl: post.imageUrls.isEmpty ? null : post.imageUrls.first,
                assetPath: path,
                size: 104,
              ),
            ),
        ],
      );

  /// 매장 + 조합 메뉴. 시안처럼 접을 수 있다.
  Widget _storeSection(BuildContext context, YogijokboPost post) {
    final combo = post.combo;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _storeExpanded = !_storeExpanded),
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Text(combo.store.name, style: AppText.semiBold(16, spacing: -0.4)),
                const Spacer(),
                Icon(
                  _storeExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 22,
                  color: AppColors.gray800,
                ),
              ],
            ),
          ),
          if (_storeExpanded) ...[
            const SizedBox(height: 8),
            Container(height: 1, color: AppColors.gray200),
            for (final item in combo.items) _menuRow(item),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              LikeCommentRow(
                likeCount: post.likeCount,
                commentCount: post.commentCount,
                likedByMe: post.likedByMe,
                onLike: () => context.read<AppFlow>().toggleLike(),
              ),
              const Spacer(),
              _reorderButton(context, post),
            ],
          ),
        ],
      ),
    );
  }

  /// 상세의 메뉴 줄은 수량·가격 없이 이름과 옵션만 보여준다(시안 동일).
  /// 가격은 지금 값과 다를 수 있어 "나도 주문하기"가 재확인한 뒤 주문 화면에서 보여준다.
  Widget _menuRow(ComboItem item) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RemoteOrAssetImage(
              imageUrl: item.imageUrl,
              assetPath: item.imagePath,
              size: 56,
              radius: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: AppText.semiBold(14, spacing: -0.35)),
                  const SizedBox(height: 4),
                  Text(
                    item.options,
                    style: AppText.regular(12, spacing: -0.3, color: AppColors.gray600),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _reorderButton(BuildContext context, YogijokboPost post) => GestureDetector(
        onTap: () => context.read<AppFlow>().startReorder(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('나도 주문하기',
              style: AppText.semiBold(14, spacing: -0.35, color: Colors.white)),
        ),
      );

  Widget _commentSection(YogijokboPost post, List<PostComment> comments) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('댓글 ${post.commentCount}', style: AppText.semiBold(16, spacing: -0.4)),
            const SizedBox(height: 4),
            for (final comment in comments)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PostAuthorRow(author: comment.author, size: 28),
                    const SizedBox(height: 6),
                    Text(
                      comment.body,
                      style: AppText.regular(14, spacing: -0.35, color: AppColors.gray800),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );

  Widget _commentInput() => Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _submitComment(),
                  style: AppText.regular(14, spacing: -0.35),
                  decoration: InputDecoration(
                    hintText: '댓글을 입력해 주세요',
                    hintStyle:
                        AppText.regular(14, spacing: -0.35, color: AppColors.gray500),
                    filled: true,
                    fillColor: AppColors.gray100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _submitComment,
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: Icon(Icons.send, size: 22, color: AppColors.gray500),
                ),
              ),
            ],
          ),
        ),
      );
}
