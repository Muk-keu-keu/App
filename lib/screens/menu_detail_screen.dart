import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../app_flow.dart';
import '../models/combo.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/ds.dart';
import 'menu_option_body.dart';

/// Figma "메뉴 추가하기" (node 925:4037).
///
/// 매장 메뉴에서 메뉴를 누르면 열린다. 옵션을 고르고 "추가하기" 로 장바구니에
/// 담는다 — 목록의 + 는 옵션 없이 바로 담는 빠른 길이고, 이 화면이 제대로 고르는
/// 길이다 (피드백 25번: 눌러도 이 화면이 안 떴다).
///
/// **바텀시트가 아니라 전체 화면이다.** 옵션 변경 시트와 고르는 방식은 같아서
/// 본문은 [MenuOptionList] 를 함께 쓰고 껍데기만 다르다.
class MenuDetailScreen extends StatefulWidget {
  const MenuDetailScreen({super.key});

  @override
  State<MenuDetailScreen> createState() => _MenuDetailScreenState();
}

class _MenuDetailScreenState extends State<MenuDetailScreen> {
  Set<String>? _checked;
  SpiceLevel? _spice;

  /// 담기 전이라 처음 선택은 서버가 `selected` 로 준 것뿐이다. 메뉴 조회 응답에는
  /// 그 값이 없어 실제로는 비어 있고, 맵기는 메뉴의 기본 맵기에서 시작한다.
  void _seed(Menu menu) {
    _checked ??= {
      for (final o in menu.options)
        if (o.selected) menuOptionKey(o),
    };
    _spice ??= menu.spiceAdjustable ? menu.spiceLevel : null;
  }

  List<MenuOption> _selection(Menu menu) => [
        for (final o in menu.options)
          if (_checked!.contains(menuOptionKey(o))) o,
      ];

  @override
  Widget build(BuildContext context) {
    final flow = context.watch<AppFlow>();
    final menu = flow.menuDetail;

    // 닫은 직후 한 프레임 동안 null 이 될 수 있다.
    if (menu == null) return const SizedBox.shrink();
    _seed(menu);

    return Container(
      color: Colors.white,
      child: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    // 메뉴 사진 (925:4090). 좌우를 꽉 채운다.
                    SizedBox(
                      height: 202,
                      width: double.infinity,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          RemoteOrAssetImage(
                            imageUrl: menu.imageUrl,
                            assetPath: menu.imagePath,
                            size: 202,
                            radius: 0,
                          ),
                        ],
                      ),
                    ),
                    // 메뉴명·설명 (925:4202). 사진 아래 13.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 13, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(menu.name, style: AppText.h2()),
                          if (menu.description.isNotEmpty)
                            Text(
                              menu.description,
                              style: AppText.body2(color: AppColors.gray600),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: MenuOptionList(
                        options: menu.options,
                        spiceAdjustable: menu.spiceAdjustable,
                        spice: _spice,
                        onPickSpice: (next) => setState(() => _spice = next),
                        checked: _checked!,
                        onPickOption: (option) => setState(
                          () => _checked = pickInGroup(_checked!, option),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Bottom CTA (925:4203). 시안 문구는 "추가하기" 다.
              Container(
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
                  child: DsButton(
                    label: '추가하기',
                    onPressed: () => context.read<AppFlow>().addMenuToCart(
                          menu,
                          chosen: _selection(menu),
                          spice: menu.spiceAdjustable ? _spice : null,
                          thenOpenCart: true,
                        ),
                  ),
                ),
              ),
            ],
          ),
          // 뒤로가기 (925:4091). 사진 위에 얹은 반투명 흰 원형이다 — 사진이 밝든
          // 어둡든 아이콘이 보인다. 상태바(53) 바로 아래 y 55 에 온다.
          Positioned(
            left: 20,
            top: MediaQuery.paddingOf(context).top + 2,
            child: GestureDetector(
              onTap: () => context.read<AppFlow>().closeMenuDetail(),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const DsChevron.left(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
