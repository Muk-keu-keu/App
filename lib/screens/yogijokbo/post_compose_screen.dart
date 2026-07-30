import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_flow.dart';
import '../../models/combo.dart';
import '../../models/post.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'jokbo_widgets.dart';

/// 족보 작성 (Figma "조합 공유").
/// 분석해서 만든 내 조합을 요기족보에 공유한다.
///
/// 진입은 조합 결과 화면이다. 그래야 시안 상단의 영상 카드(출처)와 "주문한 메뉴"를
/// 채울 수 있다. 빈 화면에서 시작하면 어떤 조합을 공유하는지 알 수 없다.
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

  bool get _canSubmit => _titleController.text.trim().isNotEmpty && !_submitting;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _submitting = true);
    await context.read<AppFlow>().submitPost(
          title: _titleController.text,
          body: _bodyController.text,
        );
    // 성공하면 상세 화면으로 넘어가 이 위젯이 사라진다. 실패 시에만 되돌린다.
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final flow = context.watch<AppFlow>();
    final combo = flow.composeCombo;

    if (combo == null) return const SizedBox.shrink();

    return Container(
      color: AppColors.pageBackground,
      child: Column(
        children: [
          AppHeader(title: '족보 작성', onBack: () => context.read<AppFlow>().cancelCompose()),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                if (flow.composeSource != null)
                  SourceVideoCard(
                    title: flow.composeSource!.videoTitle,
                    author: const PostAuthor(id: 'me', nickname: '나'),
                    imagePath: combo.items.first.imagePath,
                    imageUrl: combo.items.first.imageUrl,
                  ),
                _orderedMenuSection(combo),
                const SizedBox(height: 8),
                _writeSection(),
                const SizedBox(height: 8),
                _photoSection(combo),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: SafeArea(
              top: false,
              child: _canSubmit
                  ? PrimaryButton(label: '조합 공유하기', onPressed: _submit)
                  : _disabledButton(),
            ),
          ),
        ],
      ),
    );
  }

  /// 제목이 없으면 공유할 수 없다. 눌리는 버튼이 아무 일도 안 하는 것보다
  /// 왜 못 누르는지 보이는 편이 낫다.
  Widget _disabledButton() => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.gray300,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          _submitting ? '공유 중…' : '제목을 입력해 주세요',
          style: AppText.semiBold(16, spacing: -0.4, color: AppColors.gray600),
        ),
      );

  Widget _orderedMenuSection(ComboRecommendation combo) => Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => setState(() => _menuExpanded = !_menuExpanded),
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Text('주문한 메뉴', style: AppText.semiBold(16, spacing: -0.4)),
                  const Spacer(),
                  Icon(
                    _menuExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 22,
                    color: AppColors.gray800,
                  ),
                ],
              ),
            ),
            if (_menuExpanded) ...[
              const SizedBox(height: 12),
              Text(combo.store.name,
                  style: AppText.medium(14, spacing: -0.35, color: AppColors.gray700)),
              for (final item in combo.items)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RemoteOrAssetImage(
                        imageUrl: item.imageUrl,
                        assetPath: item.imagePath,
                        size: 48,
                        radius: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${item.name} × ${item.quantity}',
                                style: AppText.semiBold(14, spacing: -0.35)),
                            const SizedBox(height: 2),
                            Text(
                              item.options,
                              style: AppText.regular(12,
                                  spacing: -0.3, color: AppColors.gray600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      );

  Widget _writeSection() => Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('먹방 속 조합, 어땠나요?', style: AppText.semiBold(16, spacing: -0.4)),
            const SizedBox(height: 12),
            _field(
              controller: _titleController,
              hint: '제목을 입력해주세요.',
              maxLength: _titleMax,
              maxLines: 1,
            ),
            const SizedBox(height: 12),
            _field(
              controller: _bodyController,
              hint: '본문을 입력해주세요.',
              maxLength: _bodyMax,
              maxLines: 7,
            ),
          ],
        ),
      );

  /// 글자수 카운터를 입력창 안 우측에 두는 시안 형태.
  /// `maxLength` 를 TextField 에 직접 주면 기본 카운터가 밖에 붙어 시안과 달라지므로
  /// `counterText: ''` 로 숨기고 직접 그린다.
  Widget _field({
    required TextEditingController controller,
    required String hint,
    required int maxLength,
    required int maxLines,
  }) =>
      Stack(
        children: [
          TextField(
            controller: controller,
            maxLength: maxLength,
            maxLines: maxLines,
            minLines: maxLines,
            style: AppText.regular(15, spacing: -0.35),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AppText.regular(15, spacing: -0.35, color: AppColors.gray500),
              filled: true,
              fillColor: AppColors.gray200,
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.fromLTRB(16, 14, 60, 14),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 10,
            child: Text(
              '${controller.text.characters.length}/$maxLength',
              style: AppText.regular(12, spacing: -0.3, color: AppColors.gray500),
            ),
          ),
        ],
      );

  /// 사진 첨부.
  ///
  /// 갤러리·카메라 연동(image_picker)은 이번 범위가 아니라 넣지 않았다.
  /// 대신 조합 이미지가 기본 첨부로 들어가 있는 것을 보여준다 — 공유된 글에
  /// 사진이 하나도 없으면 목록 썸네일이 비기 때문이다.
  Widget _photoSection(ComboRecommendation combo) => Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('사진 첨부', style: AppText.semiBold(16, spacing: -0.4)),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: AppColors.gray200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.photo_camera_outlined,
                      size: 26, color: AppColors.gray500),
                ),
                const SizedBox(width: 12),
                for (final item in combo.items.take(2))
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: RemoteOrAssetImage(
                      imageUrl: item.imageUrl,
                      assetPath: item.imagePath,
                      size: 84,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '조합 사진이 기본으로 첨부돼요. 갤러리에서 고르는 기능은 준비 중이에요.',
              style: AppText.regular(12, spacing: -0.3, color: AppColors.gray500),
            ),
          ],
        ),
      );
}
