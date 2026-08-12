import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../app_flow.dart';
import '../../repository/post_repository.dart';
import '../../services/photo_picker.dart';
import '../../theme.dart';
import '../../widgets/ds.dart';
import '../../widgets/overlays.dart';
import 'jokbo_widgets.dart';

/// Figma "족보 수정" (node 922:2734).
///
/// 게시물 헤더의 점 아이콘 → "수정하기" 로 들어온다. 작성 화면과 달리 조합은
/// 손댈 수 없다 — 조합은 결제 스냅샷이라 글쓴이가 바꿀 수 있는 값이 아니다.
/// 그래서 제목과 본문만 있고, 하단 CTA 대신 헤더 오른쪽의 "저장" 을 쓴다.
class PostEditScreen extends StatefulWidget {
  const PostEditScreen({super.key});

  static const titleMax = 20;
  static const bodyMax = 400;

  @override
  State<PostEditScreen> createState() => _PostEditScreenState();
}

class _PostEditScreenState extends State<PostEditScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  bool _saving = false;

  /// 저장하면 남을 사진들. `http` 로 시작하면 이미 서버에 있는 사진이고,
  /// 아니면 방금 고른 기기 안의 파일이다. **서버는 남길 사진 전부를 파일로 다시
  /// 받으므로** 이 목록이 곧 저장 후의 사진 전체다 (빼면 지워진다).
  late final List<String> _photos;

  static const _photoMax = 5;

  @override
  void initState() {
    super.initState();
    // 지금 값을 채워 둔다. 빈 칸으로 열면 수정이 아니라 새로 쓰는 것처럼 보인다.
    final post = context.read<AppFlow>().selectedPost;
    _titleController = TextEditingController(text: post?.title ?? '')
      ..addListener(_onChanged);
    _bodyController = TextEditingController(text: post?.body ?? '')
      ..addListener(_onChanged);
    _photos = [...?post?.imageUrls];
  }

  Future<void> _addPhotos() async {
    final picked =
        await const PhotoPicker().pick(remaining: _photoMax - _photos.length);
    if (picked.isEmpty || !mounted) return;
    setState(() => _photos.addAll(picked));
  }

  /// 글자수 카운터와 저장 버튼 활성 상태가 입력에 따라 다시 그려져야 한다.
  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  bool get _canSave => !_saving && _titleController.text.trim().isNotEmpty;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    final saved = await context.read<AppFlow>().savePostEdit(
          title: _titleController.text,
          body: _bodyController.text,
          images: [
            for (final p in _photos)
              p.startsWith('http') ? PostImage.kept(p) : PostImage.picked(p),
          ],
        );
    if (!mounted) return;
    setState(() => _saving = false);

    // 서버는 남길 사진을 파일로 다시 받는다. 그 사진을 받아 오지 못하면 저장을
    // 멈춘다 — 보내면 사진이 지워지기 때문이다. 이유를 알려주지 않으면 "저장" 이
    // 그냥 안 눌리는 것처럼 보인다.
    if (!saved) {
      AppToast.show(
        context,
        message: '사진을 다시 올릴 수 없어 저장하지 못했어요.\n잠시 후 다시 시도해 주세요.',
      );
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        color: Colors.white,
        child: Column(
          children: [
            _EditHeader(
              onClose: () => context.read<AppFlow>().cancelPostEdit(),
              onSave: _canSave ? _save : null,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                children: [
                  JokboTextField(
                    controller: _titleController,
                    hint: '제목을 입력해주세요',
                    maxLength: PostEditScreen.titleMax,
                  ),
                  const SizedBox(height: 16),
                  JokboTextField(
                    controller: _bodyController,
                    hint: '본문을 입력해주세요',
                    maxLength: PostEditScreen.bodyMax,
                    height: 148,
                    multiline: true,
                  ),
                  const SizedBox(height: 12),
                  Text('사진 첨부',
                      style: AppText.sub2().copyWith(letterSpacing: 0)),
                  const SizedBox(height: 12),
                  JokboPhotoRow(
                    photos: _photos,
                    maxCount: _photoMax,
                    onAdd: _addPhotos,
                    onRemove: (i) => setState(() => _photos.removeAt(i)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

/// ✕ 족보 수정 저장. 시안의 헤더는 뒤로가기가 아니라 닫기다 —
/// 수정은 상세 위에 얹힌 화면이라 되돌아갈 단계가 하나뿐이다.
class _EditHeader extends StatelessWidget {
  const _EditHeader({required this.onClose, required this.onSave});

  final VoidCallback onClose;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 32,
            child: Row(
              children: [
                GestureDetector(
                  onTap: onClose,
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: 64,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SvgPicture.asset(
                        DsIcons.close,
                        width: 20,
                        height: 20,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    '족보 수정',
                    textAlign: TextAlign.center,
                    style: AppText.sub1(),
                  ),
                ),
                GestureDetector(
                  onTap: onSave,
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: 64,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '저장',
                        style: AppText.btn2(
                          color: onSave == null
                              ? AppColors.gray500
                              : AppColors.primary500,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
