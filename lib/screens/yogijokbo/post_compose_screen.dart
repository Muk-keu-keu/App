import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_flow.dart';
import '../../models/combo.dart';
import '../../models/post.dart';
import '../../services/photo_picker.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/ds.dart';
import '../../widgets/overlays.dart';
import 'jokbo_widgets.dart';

/// Figma "조합 공유" (node 681:7992).
///
/// 주문한 조합을 요기족보에 공유한다. 상단에 출처 영상, 그 아래 "주문한 메뉴"(접힘),
/// 제목·본문 입력과 사진 첨부가 온다.
class PostComposeScreen extends StatefulWidget {
  const PostComposeScreen({super.key});

  @override
  State<PostComposeScreen> createState() => _PostComposeScreenState();
}

class _PostComposeScreenState extends State<PostComposeScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  static const _titleMax = 20;
  static const _bodyMax = 400;

  /// "주문한 메뉴" 접기. 시안은 접힌(chevron down) 상태가 기본이다.
  bool _menuExpanded = false;

  bool _submitting = false;

  /// 첨부한 사진의 기기 안 경로. 공유할 때 그대로 멀티파트로 올라간다.
  final List<String> _photoPaths = [];

  static const _photoMax = 5;

  Future<void> _addPhotos() async {
    final picked = await const PhotoPicker()
        .pick(remaining: _photoMax - _photoPaths.length);
    if (picked.isEmpty || !mounted) return;
    setState(() => _photoPaths.addAll(picked));
  }

  @override
  void initState() {
    super.initState();
    // 글자수 카운터를 갱신하려면 입력마다 다시 그려야 한다.
    _titleController.addListener(_onChanged);
    _bodyController.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      !_submitting && _titleController.text.trim().isNotEmpty;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _submitting = true);

    final flow = context.read<AppFlow>();

    // 공유가 끝나면 [AppFlow.submitPost] 가 주문내역으로 옮겨 놓으므로, await 가
    // 끝난 시점에 이 화면은 이미 사라져 있다. 그때 context 로 messenger 를 찾으면
    // 못 찾아서 토스트가 조용히 안 떴다 — 미리 붙잡아 둔다.
    final messenger = ScaffoldMessenger.of(context);

    final postId = await flow.submitPost(
      title: _titleController.text,
      body: _bodyController.text,
      imagePaths: _photoPaths,
    );

    // 화면이 남아 있을 때만 버튼 상태를 되돌린다. 사라졌으면 되돌릴 대상이 없다.
    if (mounted) setState(() => _submitting = false);

    // 방금 쓴 글로 가는 길은 이 토스트에만 있다 (시안 952:5089).
    if (postId == null) return;
    AppToast.showOn(
      messenger,
      message: '요기족보를 공유했습니다.',
      actionLabel: '보러가기',
      onAction: () => flow.openPost(postId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final flow = context.watch<AppFlow>();
    final cart = flow.composeCart;
    if (cart == null) return const SizedBox.shrink();

    return Container(
      color: AppColors.bg,
      child: Column(
        children: [
          DsHeader.detail(
            title: '족보 작성',
            onBack: () => context.read<AppFlow>().cancelCompose(),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                if (flow.composeSource != null)
                  _VideoSection(source: flow.composeSource!, cart: cart),
                _MenuToggle(
                  cart: cart,
                  expanded: _menuExpanded,
                  onToggle: () => setState(() => _menuExpanded = !_menuExpanded),
                ),
                _FormSection(
                  titleController: _titleController,
                  bodyController: _bodyController,
                  titleMax: _titleMax,
                  bodyMax: _bodyMax,
                  photoPaths: _photoPaths,
                  photoMax: _photoMax,
                  onAddPhoto: _addPhotos,
                  onRemovePhoto: (i) => setState(() => _photoPaths.removeAt(i)),
                ),
              ],
            ),
          ),
          _BottomCta(onSubmit: _canSubmit ? _submit : null),
        ],
      ),
    );
  }
}

class _VideoSection extends StatelessWidget {
  const _VideoSection({required this.source, required this.cart});

  final PostSource source;
  final Cart cart;

  @override
  Widget build(BuildContext context) {
    final firstLine = cart.allLines.isEmpty ? null : cart.allLines.first;
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: DsVideoSummary(
        thumbnail: RemoteOrAssetImage(
          imageUrl: source.thumbnailUrl ?? firstLine?.imageUrl,
          assetPath: firstLine?.imagePath ?? 'assets/images/store_dujjim.png',
          size: 100,
          radius: 0,
        ),
        videoTitle: source.title,
      ),
    );
  }
}

/// "주문한 메뉴" — 눌러서 펼친다. 시안 기본은 접힌 상태다.
///
/// 가게가 여러 곳인 결제였으면 가게 이름을 소제목으로 끼워 넣는다. 회의에서 족보를
/// 묶음 조합 단위로 바꿨으니, 어느 가게 메뉴인지 글에도 남아야 한다.
class _MenuToggle extends StatelessWidget {
  const _MenuToggle({
    required this.cart,
    required this.expanded,
    required this.onToggle,
  });

  final Cart cart;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: onToggle,
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('주문한 메뉴', style: AppText.sub2()),
                  RotatedBox(
                    quarterTurns: expanded ? 2 : 0,
                    child: const DsChevron.down(),
                  ),
                ],
              ),
            ),
            if (expanded)
              for (final store in cart.stores) ...[
                // 가게가 한 곳이면 소제목이 군더더기다.
                if (cart.storeCount > 1) ...[
                  const SizedBox(height: 12),
                  Text(
                    store.restaurant.name,
                    style: AppText.caption(color: AppColors.gray600),
                  ),
                ],
                for (final item in store.lines) ...[
                  const SizedBox(height: 12),
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

class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.titleController,
    required this.bodyController,
    required this.titleMax,
    required this.bodyMax,
    required this.photoPaths,
    required this.photoMax,
    required this.onAddPhoto,
    required this.onRemovePhoto,
  });

  final TextEditingController titleController;
  final TextEditingController bodyController;
  final int titleMax;
  final int bodyMax;
  final List<String> photoPaths;
  final int photoMax;
  final VoidCallback onAddPhoto;
  final ValueChanged<int> onRemovePhoto;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('먹방 속 조합, 어땠나요?', style: AppText.sub2()),
            const SizedBox(height: 16),
            JokboTextField(
              controller: titleController,
              hint: '제목을 입력해주세요',
              maxLength: titleMax,
            ),
            const SizedBox(height: 16),
            JokboTextField(
              controller: bodyController,
              hint: '본문을 입력해주세요',
              maxLength: bodyMax,
              height: 189,
              multiline: true,
            ),
            const SizedBox(height: 12),
            Text('사진 첨부',
                style: AppText.sub2().copyWith(letterSpacing: 0)),
            const SizedBox(height: 12),
            JokboPhotoRow(
              photos: photoPaths,
              maxCount: photoMax,
              onAdd: onAddPhoto,
              onRemove: onRemovePhoto,
            ),
          ],
        ),
      );
}

class _BottomCta extends StatelessWidget {
  const _BottomCta({required this.onSubmit});

  final VoidCallback? onSubmit;

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
          child: DsButton(label: '조합 공유하기', onPressed: onSubmit),
        ),
      );
}
