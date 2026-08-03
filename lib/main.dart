import 'dart:async';
import 'dart:io' show Platform;

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'app_flow.dart';
import 'env.dart';
import 'screens/analyze_screen.dart';
import 'screens/combo_list_screen.dart';
import 'screens/combo_result_screen.dart';
import 'screens/home/yogiyo_home_screen.dart';
import 'screens/home_screen.dart';
import 'screens/keyword_select_screen.dart';
import 'screens/login_screen.dart';
import 'screens/yogijokbo/post_compose_screen.dart';
import 'screens/yogijokbo/post_detail_screen.dart';
import 'screens/yogijokbo/post_order_screen.dart';
import 'screens/yogijokbo/yogijokbo_home_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Env.load();

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
        title: '먹방요기',
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
  StreamSubscription<List<SharedMediaFile>>? _shareSub;
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      _listenForAndroidShare();
    } else {
      _listenForIosShareExtension();
    }
  }

  /// 안드로이드: ACTION_SEND intent-filter 로 들어온 공유를 그대로 받는다.
  void _listenForAndroidShare() {
    _shareSub = ReceiveSharingIntent.instance.getMediaStream().listen(
          _handleSharedMedia,
          onError: (Object _) {},
        );

    // 공유로 앱이 처음 켜진 경우
    ReceiveSharingIntent.instance.getInitialMedia().then((value) {
      _handleSharedMedia(value);
      ReceiveSharingIntent.instance.reset();
    });
  }

  /// iOS: Swift Share Extension 이 mukbang://analyze?u=<링크> 로 앱을 연다.
  /// App Group 없이 URL 스킴만 쓰는 구조라 익스텐션 코드를 그대로 재사용한다.
  void _listenForIosShareExtension() {
    final links = AppLinks();
    _linkSub = links.uriLinkStream.listen(_handleIncomingUri, onError: (Object _) {});
    links.getInitialLink().then((uri) {
      if (uri != null) _handleIncomingUri(uri);
    });
  }

  void _handleIncomingUri(Uri uri) {
    if (!mounted) return;
    if (uri.scheme != 'mukbang' || uri.host != 'analyze') return;
    final link = uri.queryParameters['u'];
    if (link == null || link.isEmpty) return;
    context.read<AppFlow>().start(link);
  }

  void _handleSharedMedia(List<SharedMediaFile> files) {
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
    _shareSub?.cancel();
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stage = context.watch<AppFlow>().stage;

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: switch (stage) {
        AppStage.login => const LoginScreen(),
        AppStage.yogiyoHome => const YogiyoHomeScreen(),
        AppStage.home => const HomeScreen(),
        AppStage.keyword => const KeywordSelectScreen(),
        AppStage.analyzing => const AnalyzeScreen(),
        AppStage.combo => const ComboResultScreen(),
        AppStage.comboList => const ComboListScreen(),
        AppStage.failed => const _FailedScreen(),
        AppStage.jokboHome => const YogijokboHomeScreen(),
        AppStage.jokboDetail => const PostDetailScreen(),
        AppStage.jokboOrder => const PostOrderScreen(),
        AppStage.jokboCompose => const PostComposeScreen(),
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
            // 좌우 여백이 없으면 긴 문구가 화면 끝에 붙어 잘려 보인다.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                flow.failureMessage,
                textAlign: TextAlign.center,
                style: AppText.regular(16, color: AppColors.gray700),
              ),
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
