import 'dart:async';
import 'dart:io' show Platform;

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'app_flow.dart';
import 'env.dart';
import 'screens/analyze_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/combo_list_screen.dart';
import 'screens/combo_result_screen.dart';
import 'screens/home/order_detail_screen.dart';
import 'screens/home/order_history_screen.dart';
import 'screens/home/yogiyo_home_screen.dart';
import 'screens/home_screen.dart';
import 'screens/keyword_select_screen.dart';
import 'screens/login_screen.dart';
import 'screens/order_done_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/store_menu_screen.dart';
import 'screens/yogijokbo/post_compose_screen.dart';
import 'screens/yogijokbo/post_detail_screen.dart';
import 'screens/yogijokbo/post_edit_screen.dart';
import 'screens/yogijokbo/yogijokbo_home_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Env.load();

  runApp(
    ChangeNotifierProvider(
      // 저장된 토큰이 있으면 로그인 화면을 건너뛴다. 앱을 띄우기 전에 기다리지 않는다 —
      // 저장소 읽기와 `me()` 왕복만큼 흰 화면이 길어지고, 그동안 [AppFlow] 가
      // `isRestoringSession` 으로 화면을 잡아 준다.
      create: (_) => AppFlow()..restoreSession(),
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
    final flow = context.watch<AppFlow>();

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      // 자동 로그인을 확인하는 동안은 흰 화면으로 둔다. 로그인 화면을 먼저 그리면
      // 자동 로그인이 될 사람에게 로그인 화면이 한 번 번쩍여, 로그아웃된 것처럼 보인다.
      body: flow.isRestoringSession
          ? const ColoredBox(color: Colors.white)
          : _screenFor(flow.stage),
    );
  }

  Widget _screenFor(AppStage stage) => switch (stage) {
        AppStage.login => const LoginScreen(),
        AppStage.signup => const SignupScreen(),
        AppStage.yogiyoHome => const YogiyoHomeScreen(),
        AppStage.orders => const OrderHistoryScreen(),
        AppStage.orderDetail => const OrderDetailScreen(),
        AppStage.home => const HomeScreen(),
        AppStage.keyword => const KeywordSelectScreen(),
        AppStage.analyzing => const AnalyzeScreen(),
        AppStage.combo => const ComboResultScreen(),
        AppStage.comboList => const ComboListScreen(),
        AppStage.storeMenu => const StoreMenuScreen(),
        AppStage.cart => _CartStage(),
        AppStage.orderDone => const OrderDoneScreen(),
        AppStage.failed => const _FailedScreen(),
        AppStage.jokboHome => const YogijokboHomeScreen(),
        AppStage.jokboDetail => const PostDetailScreen(),
        // "나도 주문하기" 도 같은 장바구니 화면이다. 남의 조합을 복사해 온
        // 장바구니라 구조가 같고, 돌아갈 곳과 주문 불가 안내만 다르다.
        AppStage.jokboOrder => const _JokboOrderStage(),
        AppStage.jokboCompose => const PostComposeScreen(),
        AppStage.jokboEdit => const PostEditScreen(),
      };
}

/// 분석 결과에서 온 장바구니. 뒤로 가면 조합 카드로 돌아간다.
class _CartStage extends StatelessWidget {
  @override
  Widget build(BuildContext context) => CartScreen(
        onBack: () => context.read<AppFlow>().backToCombo(),
      );
}

/// 요기족보 "나도 주문하기" 로 온 장바구니.
class _JokboOrderStage extends StatelessWidget {
  const _JokboOrderStage();

  @override
  Widget build(BuildContext context) => CartScreen(
        title: '주문하기',
        onBack: () => context.read<AppFlow>().backToPostDetail(),
      );
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
