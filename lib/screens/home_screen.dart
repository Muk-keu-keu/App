import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_flow.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'address_input_sheet.dart';

/// 공유로 들어오지 않고 앱을 직접 열었을 때 보여주는 안내 화면.
/// Figma 와이어프레임에는 없어서 로딩화면의 디자인 언어를 따라 만들었다.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.pageBackground,
        width: double.infinity,
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const _LocationBar(),
                const SizedBox(height: 24),
                Image.asset('assets/images/platter.png', width: 200, height: 200),
                const SizedBox(height: 24),
                Text('인스타그램에서 공유해 주세요',
                    textAlign: TextAlign.center, style: AppText.semiBold(26)),
                const SizedBox(height: 12),
                Text(
                  '릴스를 보다가 공유 버튼을 누르면\n먹방 속 조합을 요기요 메뉴로 바꿔드릴게요',
                  textAlign: TextAlign.center,
                  style: AppText.regular(16, color: AppColors.gray700),
                ),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: FigmaCard(
                    child: Column(
                      children: [
                        _step(1, '인스타그램 릴스에서 공유 버튼을 누르세요'),
                        const SizedBox(height: 16),
                        _step(2, '‘공유 대상…’을 선택하세요'),
                        const SizedBox(height: 16),
                        _step(3, '‘먹방요기’를 누르면 분석이 시작돼요'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      );

  static Widget _step(int number, String text) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            child: Text('$number', style: AppText.semiBold(13, color: Colors.white)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: AppText.regular(15, spacing: -0.35, color: AppColors.gray800)),
          ),
        ],
      );
}

/// 상단 위치 표시줄. 탭하면 주소 입력 시트가 열린다.
///
/// 위치는 로그인 직후 자동으로 한 번 수집되지만, 실패했거나 다른 동네로 바꾸고 싶을 때
/// 들어갈 문이 필요하다. 디버그 빌드에서는 이 시트가 좌표 override 진입점도 겸한다.
class _LocationBar extends StatelessWidget {
  const _LocationBar();

  @override
  Widget build(BuildContext context) {
    final flow = context.watch<AppFlow>();
    final location = flow.location;

    final (icon, text, color) = switch (location) {
      null when flow.isLocating => (
          Icons.location_searching,
          '위치 확인 중…',
          AppColors.gray600,
        ),
      null => (
          Icons.location_off_outlined,
          '위치를 설정해 주세요',
          AppColors.primary,
        ),
      _ => (
          Icons.location_on_outlined,
          '${location.displayText} · ${location.origin.label}',
          AppColors.gray800,
        ),
    };

    return GestureDetector(
      onTap: () => AddressInputSheet.show(context),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.medium(14, spacing: -0.35, color: color),
              ),
            ),
            Icon(Icons.keyboard_arrow_right, size: 18, color: AppColors.gray500),
          ],
        ),
      ),
    );
  }
}
