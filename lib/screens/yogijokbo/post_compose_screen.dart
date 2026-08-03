import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../app_flow.dart';
import '../../models/combo.dart';
import '../../models/post.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/ds.dart';

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
    await context.read<AppFlow>().submitPost(
          title: _titleController.text,
          body: _bodyController.text,
        );
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final flow = context.watch<AppFlow>();
    final combo = flow.composeCombo;
    if (combo == null) return const SizedBox.shrink();

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
                  _VideoSection(source: flow.composeSource!, combo: combo),
                _MenuToggle(
                  combo: combo,
                  expanded: _menuExpanded,
                  onToggle: () => setState(() => _menuExpanded = !_menuExpanded),
                ),
                _FormSection(
                  titleController: _titleController,
                  bodyController: _bodyController,
                  titleMax: _titleMax,
                  bodyMax: _bodyMax,
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
  const _VideoSection({required this.source, required this.combo});

  final PostSource source;
  final ComboRecommendation combo;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: DsVideoSummary(
          thumbnail: RemoteOrAssetImage(
            imageUrl: combo.items.isEmpty ? null : combo.items.first.imageUrl,
            assetPath: combo.store.imagePath,
            size: 100,
            radius: 0,
          ),
          videoTitle: source.videoTitle,
          creatorName: combo.store.name,
        ),
      );
}

/// "주문한 메뉴" — 눌러서 펼친다. 시안 기본은 접힌 상태다.
class _MenuToggle extends StatelessWidget {
  const _MenuToggle({
    required this.combo,
    required this.expanded,
    required this.onToggle,
  });

  final ComboRecommendation combo;
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
              for (final item in combo.items) ...[
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
                          Text(item.options,
                              style: AppText.caption(color: AppColors.gray600)),
                        ],
                      ),
                    ),
                  ],
                ),
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
  });

  final TextEditingController titleController;
  final TextEditingController bodyController;
  final int titleMax;
  final int bodyMax;

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
            _Field(
              controller: titleController,
              hint: '제목을 입력해주세요',
              maxLength: titleMax,
            ),
            const SizedBox(height: 16),
            _Field(
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
            const _PhotoRow(),
          ],
        ),
      );
}

/// 시안의 입력칸. 회색 판 안에 글자수 카운터가 함께 들어간다.
/// 한 줄짜리는 오른쪽에, 여러 줄짜리는 오른쪽 아래에 붙는다.
class _Field extends StatelessWidget {
  const _Field({
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

/// 사진 첨부. 촬영·선택이 이번 범위가 아니라 추가 버튼 자리만 시안대로 둔다.
class _PhotoRow extends StatelessWidget {
  const _PhotoRow();

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
