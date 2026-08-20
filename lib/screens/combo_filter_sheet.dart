import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_flow.dart';
import '../models/preference.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/ds.dart';

/// 비교 목록의 필터 칩이 여는 시트. Figma 「필터」 섹션 (1114:5603).
///
/// **칩을 눌러도 화면을 옮기지 않는다.** 예전에는 분석 전 취향 설정 화면
/// (`AppStage.keyword`)을 다시 열었다 — 목록을 보다가 화면이 통째로 바뀌어
/// 어디로 왔는지 알 수 없었다 (피드백 2026-08-13). 이제 목록 위에 시트만 올라오고,
/// "적용하기" 를 눌렀을 때만 분석을 다시 받는다.
///
/// 시트는 셋이고 칩 하나가 시트 하나를 연다.
/// - [FilterSheetMode.all] — 필터 아이콘 칩. 맵기 + 예상 도착 시간 (1114:4765)
/// - [FilterSheetMode.spice] — 맛 칩. 맵기만 (1114:4602)
/// - [FilterSheetMode.delivery] — 예상 시간 칩. 도착 시간만 (1114:4687)
enum FilterSheetMode { all, spice, delivery }

class ComboFilterSheet extends StatefulWidget {
  const ComboFilterSheet({super.key, required this.mode, required this.draft});

  final FilterSheetMode mode;

  /// 시트 안에서 고칠 사본. 슬라이더를 만지는 동안 뒤 목록이 다시 분석되면
  /// 안 되므로 원본은 건드리지 않고 "적용하기" 에서 한 번에 넘긴다.
  final TastePreference draft;

  static Future<void> show(BuildContext context, {required FilterSheetMode mode}) {
    final flow = context.read<AppFlow>();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider<AppFlow>.value(
        value: flow,
        child: ComboFilterSheet(mode: mode, draft: flow.preference.copy()),
      ),
    );
  }

  @override
  State<ComboFilterSheet> createState() => _ComboFilterSheetState();
}

class _ComboFilterSheetState extends State<ComboFilterSheet> {
  TastePreference get _draft => widget.draft;

  bool get _hasSpice => widget.mode != FilterSheetMode.delivery;
  bool get _hasDelivery => widget.mode != FilterSheetMode.spice;

  /// 통합 시트만 섹션 제목(H3)을 달고 섹션 사이에 구분선을 둔다. 단일 시트는
  /// 헤더가 이미 그 섹션 이름이라 제목을 두 번 쓰지 않는다.
  bool get _isCombined => widget.mode == FilterSheetMode.all;

  String get _title => switch (widget.mode) {
        FilterSheetMode.all => '필터',
        FilterSheetMode.spice => '맵기',
        FilterSheetMode.delivery => '예상 도착 시간',
      };

  /// 헤더가 시작하는 y. 시안이 시트마다 조금 다르다 (맵기 30 · 나머지 40).
  double get _headerTop => widget.mode == FilterSheetMode.spice ? 30 : 40;

  /// 헤더와 본문 사이. 시안: 필터 24 · 맵기 0 · 예상 도착 시간 16.
  double get _bodyGap => switch (widget.mode) {
        FilterSheetMode.all => 24,
        FilterSheetMode.spice => 0,
        FilterSheetMode.delivery => 16,
      };

  void _reset() => setState(() {
        if (_hasSpice) _draft.spice = TastePreference.resetSpice;
        if (_hasDelivery) _draft.maxDeliveryMinutes = TastePreference.resetMinutes;
      });

  void _apply() {
    // 시트를 먼저 닫는다. 열어 둔 채로 분석을 시작하면 분석 중 화면이 시트에
    // 가려 무엇이 진행되는지 안 보인다.
    final flow = context.read<AppFlow>();
    Navigator.of(context).pop();
    flow.applyFilter(_draft);
  }

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF444444).withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.dragHandle,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            // 손잡이가 17 에서 끝난다. 헤더 시작 y 에서 그만큼 뺀 값이 간격이다.
            SizedBox(height: _headerTop - 17),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(_title, style: AppText.h2()),
            ),
            SizedBox(height: _bodyGap),
            // 작은 화면에서 통합 시트(650)가 안 들어가면 본문만 줄어들게 한다.
            // 손잡이·헤더·버튼은 항상 보여야 한다.
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _body(),
              ),
            ),
            const SizedBox(height: 42),
            _bottomCta(),
          ],
        ),
      );

  Widget _body() {
    if (!_isCombined) {
      return _hasSpice ? _spiceOptions(divided: true) : _deliverySlider();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section(title: '맵기', gap: 8, child: _spiceOptions(divided: false)),
        const SizedBox(height: 32),
        const DsDivider(color: AppColors.gray400),
        const SizedBox(height: 32),
        _section(title: '예상 도착 시간', gap: 19, child: _deliverySlider()),
      ],
    );
  }

  Widget _section({required String title, required double gap, required Widget child}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppText.h3()),
          SizedBox(height: gap),
          child,
        ],
      );

  /// 맵기 3단계. [divided] 는 단일 시트에서만 켠다 — 통합 시트에는 항목 사이
  /// 구분선이 없다(시안 1114:4848 vs 1114:4836).
  Widget _spiceOptions({required bool divided}) {
    final rows = <Widget>[];
    for (final level in SpiceLevel.values) {
      if (divided && rows.isNotEmpty) {
        rows.add(const DsDivider(color: AppColors.gray300));
      }
      rows.add(
        DsOptionItem(
          label: level.title,
          isSelected: _draft.spice == level,
          onTap: () => setState(() => _draft.spice = level),
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }

  Widget _deliverySlider() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _draft.deliveryLabel,
            style: AppText.medium(16, spacing: -0.4, color: AppColors.gray600),
          ),
          const SizedBox(height: 9),
          DeliveryTimeSlider(
            minutes: _draft.maxDeliveryMinutes,
            onChanged: (v) => setState(() => _draft.maxDeliveryMinutes = v),
          ),
        ],
      );

  /// 시안 `Bottom CTA` — 초기화는 남는 폭을 먹고 적용하기가 240 이다.
  /// 390 폭에서 102:240 이 되도록 비율로 나눠, 좁은 화면에서도 초기화가 찌그러지지 않는다.
  Widget _bottomCta() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: 32),
          child: Row(
            children: [
              Expanded(
                flex: 102,
                child: DsButton(label: '초기화', size: DsButtonSize.s, onPressed: _reset),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 240,
                child: DsButton(label: '적용하기', onPressed: _apply),
              ),
            ],
          ),
        ),
      );
}
