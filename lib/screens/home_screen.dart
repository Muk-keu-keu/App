import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/common.dart';

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
                const SizedBox(height: 40),
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

  Widget _step(int number, String text) => Row(
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
