import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../app_flow.dart';
import '../theme.dart';
import '../widgets/ds.dart';

/// Figma "먹방요기" (node 681:7115) — 공유 안내 화면.
///
/// 요기요 메인 홈의 퀵메뉴 "먹방요기" 로 들어온다. 인스타·유튜브에서 공유했을 때
/// 무슨 일이 일어나는지 설명하는 서비스 소개 화면이다.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Container(
        color: Colors.white,
        child: Column(
          children: [
            DsHeader.detail(
              title: '먹방요기',
              onBack: () => context.read<AppFlow>().backToYogiyoHome(),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: const [
                  _Hero(),
                  SizedBox(height: 20),
                  _StepSection(),
                  SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      );
}

/// 일러스트 + 헤드라인 + 설명.
///
/// 일러스트는 Figma export 에 배경(#FFEBF1)이 구워져 나온다. 조각별로 받아도
/// 마찬가지라, 섹션 배경을 같은 색으로 끝맺어 이음새가 보이지 않게 했다.
class _Hero extends StatelessWidget {
  const _Hero();

  static const _bottom = Color(0xFFFFEBF1);

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFB6CE), _bottom, Colors.white],
            stops: [0, 0.55, 1],
          ),
        ),
        child: Column(
          children: [
            Image.asset(
              'assets/images/guide/hero.png',
              width: double.infinity,
              fit: BoxFit.fitWidth,
            ),
            const SizedBox(height: 20),
            const _Headline(),
            const SizedBox(height: 27),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 26),
              child: Text(
                '먹방을 보다 배가 고파지는 순간 공유버튼을 누르면\n'
                '먹방 속 음식을 찾아 주문 가능한 조합으로 바꿔드릴게요',
                textAlign: TextAlign.center,
                style: AppText.body2(color: AppColors.gray700),
              ),
            ),
            const SizedBox(height: 56),
          ],
        ),
      );
}

/// "**먹방** 속 그 메뉴, / 지금 바로 먹어볼까요?"
///
/// 시안에서는 글자가 아웃라인 벡터로 분해돼 있어 폰트를 알 수 없다. 디자인시스템의
/// 디스플레이 폰트(WAGURI)로 옮겼다 — 배너 워드마크와 같은 계열이라 톤이 맞는다.
class _Headline extends StatelessWidget {
  const _Headline();

  @override
  Widget build(BuildContext context) => Column(
        children: [
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: AppText.waguri(24, color: AppColors.gray800),
              children: [
                TextSpan(
                  text: '먹방',
                  style: AppText.waguri(24, color: AppColors.primary500),
                ),
                const TextSpan(text: ' 속 그 메뉴,'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '지금 바로 먹어볼까요?',
            style: AppText.waguri(24, color: AppColors.gray800),
          ),
        ],
      );
}

class _StepSection extends StatelessWidget {
  const _StepSection();

  static const _steps = [
    ('Step 1', 'assets/icons/step_share.svg', '영상 시청 중\n공유 버튼을 눌러요'),
    ('Step 2', 'assets/icons/step_upload.svg', '하단에 있는\n공유대상을 눌러요'),
    ('Step 3', 'assets/icons/step_app.svg', '먹방요기를\n선택해요'),
  ];

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('먹방요기, 이렇게 사용해요', style: AppText.h3()),
            const SizedBox(height: 20),
            Row(
              children: [
                for (var i = 0; i < _steps.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: _card(_steps[i])),
                ],
              ],
            ),
          ],
        ),
      );

  Widget _card((String, String, String) step) {
    final (badge, icon, label) = step;
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.gray300),
        borderRadius: BorderRadius.circular(AppRadius.chip),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8D8D8D).withValues(alpha: 0.15),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 50,
            height: 21,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary500,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(badge, style: AppText.btn3(color: Colors.white)),
          ),
          const SizedBox(height: 20),
          // 아이콘은 옅은 분홍 원 위에 올린다.
          Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.primary100,
              shape: BoxShape.circle,
            ),
            child: SvgPicture.asset(icon, width: 24, height: 24),
          ),
          const SizedBox(height: 20),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppText.caption2(color: AppColors.gray700),
          ),
        ],
      ),
    );
  }
}
