import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/post.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/ds.dart';

/// 조합의 출처 영상 배지.
///
/// 탭하면 유튜브를 외부 브라우저·앱으로 연다. Figma 의 "영상 연결" 화면이 앱 안의
/// 웹뷰가 아니라 youtube.com 그대로였으므로 별도 화면을 만들지 않고 외부로 넘긴다.
/// 영상 재생을 앱 안에 품으면 저작권·성능 문제가 생기고 시안과도 어긋난다.
class YoutubeSourceBadge extends StatelessWidget {
  const YoutubeSourceBadge({super.key, required this.source});

  final PostSource source;

  Future<void> _open() async {
    final uri = Uri.tryParse(source.url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: _open,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.gray100,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              // 유튜브 로고 자리. 실제 로고 에셋이 없어 브랜드 색 사각형으로 대체했다.
              Container(
                width: 20,
                height: 14,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF0000),
                  borderRadius: BorderRadius.circular(3),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.play_arrow, size: 10, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  source.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.regular(12, spacing: -0.3, color: AppColors.gray700),
                ),
              ),
            ],
          ),
        ),
      );
}

/// 좋아요·댓글 수 표시. 목록과 상세가 같은 모양을 쓴다.
class LikeCommentRow extends StatelessWidget {
  const LikeCommentRow({
    super.key,
    required this.likeCount,
    required this.commentCount,
    this.likedByMe = false,
    this.onLike,
  });

  final int likeCount;
  final int commentCount;
  final bool likedByMe;
  final VoidCallback? onLike;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          GestureDetector(
            onTap: onLike,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Icon(
                  likedByMe ? Icons.favorite : Icons.favorite_border,
                  size: 18,
                  color: likedByMe ? AppColors.primary : AppColors.gray600,
                ),
                const SizedBox(width: 4),
                Text('$likeCount',
                    style: AppText.regular(13, spacing: -0.3, color: AppColors.gray600)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Icon(Icons.chat_bubble_outline, size: 17, color: AppColors.gray600),
          const SizedBox(width: 4),
          Text('$commentCount',
              style: AppText.regular(13, spacing: -0.3, color: AppColors.gray600)),
        ],
      );
}

/// 작성자 한 줄 (프로필 + 닉네임 + 날짜).
class PostAuthorRow extends StatelessWidget {
  const PostAuthorRow({super.key, required this.author, this.dateText, this.size = 36});

  final PostAuthor author;
  final String? dateText;
  final double size;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          _avatar(),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(author.nickname, style: AppText.semiBold(14, spacing: -0.35)),
              if (dateText != null) ...[
                const SizedBox(height: 2),
                Text(dateText!,
                    style: AppText.regular(11, spacing: -0.3, color: AppColors.gray500)),
              ],
            ],
          ),
        ],
      );

  /// 프로필 사진이 없으면 닉네임 첫 글자를 원에 넣는다.
  /// 디자인에서 받은 프로필 에셋이 없어 실제 이미지가 붙을 때까지 쓰는 대체 표현이다.
  Widget _avatar() {
    final url = author.profileImageUrl;
    if (url != null && url.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initialCircle(),
        ),
      );
    }
    return _initialCircle();
  }

  Widget _initialCircle() => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.softPinkFill,
          shape: BoxShape.circle,
        ),
        child: Text(
          author.initial,
          style: AppText.semiBold(size * 0.44, color: AppColors.primary),
        ),
      );
}

/// 요기족보 홈 하단 탭바.
///
/// **찜 탭은 없다.** 회의(2026-08-04)에서 찜하기 기능을 제거했다 — 복잡도만
/// 올리고 쓰이지 않는 기능이었다. 자리도 남기지 않는다. 비활성 탭으로 두면
/// "곧 생긴다"는 뜻이 되는데 그럴 계획이 없다.
///
/// 홈은 앱의 공유 안내 화면으로 돌아가고, My 는 아직 화면이 없어 비활성이다.
/// 흐릿하게 그려 "아직 없음"이 보이게 한다.
class JokboTabBar extends StatelessWidget {
  const JokboTabBar({super.key, required this.onHome});

  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.gray300)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                _tab(Icons.home_outlined, '홈', onTap: onHome),
                _tab(Icons.receipt_long_outlined, '주문내역'),
                _tab(Icons.menu_book_outlined, '요기족보', isActive: true),
                _tab(Icons.person_outline, 'My'),
              ],
            ),
          ),
        ),
      );

  Widget _tab(IconData icon, String label, {bool isActive = false, VoidCallback? onTap}) {
    final enabled = isActive || onTap != null;
    final color = isActive
        ? AppColors.primary
        : enabled
            ? AppColors.gray600
            : AppColors.gray400;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: isActive
                  ? AppText.semiBold(11, spacing: -0.3, color: color)
                  : AppText.regular(11, spacing: -0.3, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// 조합 공유·주문하기 화면 상단의 영상 카드.
/// 썸네일 + 영상 제목 + 작성자를 한 덩어리로 보여준다.
class SourceVideoCard extends StatelessWidget {
  const SourceVideoCard({
    super.key,
    required this.title,
    required this.author,
    this.imageUrl,
    this.imagePath = 'assets/images/store_dujjim.png',
  });

  final String title;
  final PostAuthor author;
  final String? imageUrl;
  final String imagePath;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RemoteOrAssetImage(imageUrl: imageUrl, assetPath: imagePath, size: 88),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.semiBold(15, spacing: -0.4),
                  ),
                  const SizedBox(height: 8),
                  PostAuthorRow(author: author, size: 22),
                ],
              ),
            ),
          ],
        ),
      );
}

/// 사진 첨부 줄. 촬영·선택이 이번 범위가 아니라 추가 버튼 자리만 시안대로 둔다.
///
/// 작성(681:7992)과 수정(925:3676) 두 화면에 같은 모양으로 들어간다.
class JokboPhotoRow extends StatelessWidget {
  const JokboPhotoRow({super.key});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Container(
              width: 80,
              height: 80,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.gray200,
                border: Border.all(color: AppColors.gray400),
                borderRadius: BorderRadius.circular(AppRadius.chip),
              ),
              child: SvgPicture.asset(DsIcons.camera, width: 24, height: 24),
            ),
          ],
        ),
      );
}

/// 족보 작성·수정이 함께 쓰는 입력칸.
///
/// 회색 판 안에 글자수 카운터가 함께 들어간다. 한 줄짜리는 오른쪽에, 여러 줄짜리는
/// 오른쪽 아래에 붙는다. 두 화면이 같은 칸을 그리므로 한 곳에 둔다 — 나눠 두면
/// 글자수 제한이 화면마다 어긋난다.
class JokboTextField extends StatelessWidget {
  const JokboTextField({
    super.key,
    required this.controller,
    required this.hint,
    required this.maxLength,
    this.height = 44,
    this.multiline = false,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLength;
  final double height;
  final bool multiline;

  @override
  Widget build(BuildContext context) {
    final counter = Text(
      '${controller.text.characters.length}/$maxLength',
      style: AppText.btn3(color: AppColors.gray500),
    );

    final field = TextField(
      controller: controller,
      maxLength: maxLength,
      maxLines: multiline ? null : 1,
      expands: multiline,
      textAlignVertical: TextAlignVertical.top,
      style: AppText.body2().copyWith(letterSpacing: -0.35),
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        counterText: '',
        hintText: hint,
        hintStyle: AppText.body2(color: AppColors.gray600)
            .copyWith(letterSpacing: -0.35),
      ),
    );

    return Container(
      height: height,
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.gray200,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: multiline
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: field),
                const SizedBox(height: 8),
                counter,
              ],
            )
          : Row(
              children: [
                Expanded(child: field),
                const SizedBox(width: 8),
                counter,
              ],
            ),
    );
  }
}
