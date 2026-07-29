import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'app_flow.dart';
import 'screens/analyze_screen.dart';
import 'screens/combo_list_screen.dart';
import 'screens/combo_result_screen.dart';
import 'screens/home_screen.dart';
import 'screens/keyword_select_screen.dart';
import 'theme.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppFlow(),
      child: const MukbangApp(),
    ),
  );
}

class MukbangApp extends StatelessWidget {
  const MukbangApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: '먹방 따라담기',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const RootScreen(),
      );
}

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  StreamSubscription<List<SharedMediaFile>>? _sub;

  @override
  void initState() {
    super.initState();
    _listenForSharedLinks();
  }

  /// 공유 시트로 들어온 링크를 받는다.
  /// iOS 는 Swift Share Extension 이, 안드로이드는 ACTION_SEND intent-filter 가
  /// 각각 처리하고 이 패키지가 양쪽을 하나의 스트림으로 넘겨준다.
  void _listenForSharedLinks() {
    // 앱이 떠 있는 동안 들어오는 공유
    _sub = ReceiveSharingIntent.instance.getMediaStream().listen(
          _handleShared,
          onError: (Object _) {},
        );

    // 공유로 앱이 처음 켜진 경우
    ReceiveSharingIntent.instance.getInitialMedia().then((value) {
      _handleShared(value);
      ReceiveSharingIntent.instance.reset();
    });
  }

  void _handleShared(List<SharedMediaFile> files) {
    if (files.isEmpty || !mounted) return;

    // 텍스트/URL 공유는 path 에 원문이 담겨 온다. 그 안에서 첫 http 링크를 찾는다.
    for (final file in files) {
      final match = RegExp(r'https?://\S+').firstMatch(file.path);
      if (match != null) {
        context.read<AppFlow>().start(match.group(0)!);
        return;
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stage = context.watch<AppFlow>().stage;

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: switch (stage) {
        AppStage.home => const HomeScreen(),
        AppStage.keyword => const KeywordSelectScreen(),
        AppStage.analyzing => const AnalyzeScreen(),
        AppStage.combo => const ComboResultScreen(),
        AppStage.comboList => const ComboListScreen(),
        AppStage.failed => const _FailedScreen(),
      },
    );
  }
}

class _FailedScreen extends StatelessWidget {
  const _FailedScreen();

  @override
  Widget build(BuildContext context) {
    final flow = context.watch<AppFlow>();
    return Container(
      color: AppColors.pageBackground,
      width: double.infinity,
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/platter.png', width: 160, height: 160),
            const SizedBox(height: 24),
            Text(
              flow.failureMessage,
              textAlign: TextAlign.center,
              style: AppText.regular(16, color: AppColors.gray700),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => context.read<AppFlow>().backToHome(),
              child: Text('처음으로', style: AppText.semiBold(16, color: AppColors.primary)),
            ),
          ],
        ),
      ),
    );
  }
}
