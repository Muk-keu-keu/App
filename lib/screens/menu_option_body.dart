/// 메뉴 옵션 고르기 본문.
///
/// 두 화면이 같은 내용을 쓴다 — 장바구니의 "옵션 변경" 바텀시트와, 매장 메뉴에서
/// 메뉴를 눌러 들어가는 "메뉴 추가하기" 전체 화면(시안 925:4037)이다. 껍데기만
/// 다르고 고르는 방식과 줄 모양은 같아서 여기 한 벌만 둔다.
library;

import 'package:flutter/material.dart';

import '../models/combo.dart';
import '../theme.dart';
import '../widgets/ds.dart';

/// 고른 옵션을 담는 키. 서버가 옵션 id 를 주지 않아 `group + name` 이 사실상의 키다.
String menuOptionKey(MenuOption o) => '${o.group ?? ''}|${o.name}';

/// 그룹 안에서 하나만 남기고 고른다 (개정 시안 925:4128 — 체크박스가 라디오다).
///
/// 같은 그룹의 다른 선택을 먼저 지운다. 이미 고른 것을 다시 눌러도 해제하지
/// 않는다 — 라디오는 "고르지 않음" 상태가 없다.
Set<String> pickInGroup(Set<String> checked, MenuOption option) {
  final group = option.group ?? '';
  return {
    for (final key in checked)
      if (!key.startsWith('$group|')) key,
    menuOptionKey(option),
  };
}

/// 맵기 + 옵션 그룹 목록. 스크롤은 부르는 쪽이 맡는다.
class MenuOptionList extends StatelessWidget {
  const MenuOptionList({
    super.key,
    required this.options,
    required this.spiceAdjustable,
    required this.spice,
    required this.onPickSpice,
    required this.checked,
    required this.onPickOption,
  });

  final List<MenuOption> options;

  /// 맵기를 고를 수 있는 메뉴인지. 맵기는 옵션 밖이라 값이 따로 나간다.
  final bool spiceAdjustable;
  final SpiceLevel? spice;
  final ValueChanged<SpiceLevel> onPickSpice;

  final Set<String> checked;
  final ValueChanged<MenuOption> onPickOption;

  @override
  Widget build(BuildContext context) {
    final groups = MenuOptionGroup.groupBy(options);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (spiceAdjustable)
          _SpiceSection(selected: spice, onPick: onPickSpice),
        for (var i = 0; i < groups.length; i++) ...[
          if (i > 0 || spiceAdjustable) const DsDivider(color: AppColors.gray300),
          _Group(
            group: groups[i],
            isSelected: (o) => checked.contains(menuOptionKey(o)),
            onPick: onPickOption,
          ),
        ],
        if (groups.isEmpty && !spiceAdjustable)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                '이 메뉴는 고를 수 있는 옵션이 없어요',
                style: AppText.body2(color: AppColors.gray600),
              ),
            ),
          ),
      ],
    );
  }
}

/// 맵기 3버튼. `spiceAdjustable` 이 true 인 메뉴에만 나온다.
///
/// 라디오처럼 하나만 고른다 — 옵션과 달리 값이 하나(`selectedSpice`)라서다.
class _SpiceSection extends StatelessWidget {
  const _SpiceSection({required this.selected, required this.onPick});

  final SpiceLevel? selected;
  final ValueChanged<SpiceLevel> onPick;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('맵기 선택', style: AppText.sub2(color: AppColors.gray800)),
                const SizedBox(width: 4),
                const DsRequirementBadge(isRequired: true),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                for (final level in SpiceLevel.values) ...[
                  if (level != SpiceLevel.values.first) const SizedBox(width: 8),
                  Expanded(
                    child: DsChipChoice(
                      label: level.title,
                      selected: selected == level,
                      onTap: () => onPick(level),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      );
}

/// 옵션 그룹 하나. 제목(sub2) + 옵션 줄들 (시안 925:4128 — py 20, 줄 간격 12).
class _Group extends StatelessWidget {
  const _Group({
    required this.group,
    required this.isSelected,
    required this.onPick,
  });

  final MenuOptionGroup group;
  final bool Function(MenuOption) isSelected;
  final ValueChanged<MenuOption> onPick;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 라벨이 없는 옵션(`group == null`)은 제목 줄 없이 바로 나열한다.
            if (group.label != null) ...[
              // 개정 시안의 그룹 제목은 글자 하나뿐이다. 라디오라 하나는 반드시
              // 골라진 상태이므로 "선택" 뱃지가 알려 줄 것이 없어졌다.
              Text(group.label!, style: AppText.sub2(color: AppColors.gray800)),
              const SizedBox(height: 16),
            ],
            for (var i = 0; i < group.options.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _Row(
                option: group.options[i],
                isOn: isSelected(group.options[i]),
                onTap: () => onPick(group.options[i]),
              ),
            ],
          ],
        ),
      );
}

class _Row extends StatelessWidget {
  const _Row({required this.option, required this.isOn, required this.onTap});

  final MenuOption option;
  final bool isOn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  DsRadio(isOn: isOn),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      option.name,
                      style: AppText.body2(color: AppColors.gray800),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '+${wonFormat(option.price)}원',
              style: AppText.body2(color: AppColors.gray600),
            ),
          ],
        ),
      );
}
