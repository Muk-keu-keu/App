import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mukbang_ttaradamgi/app_flow.dart';
import 'package:mukbang_ttaradamgi/models/post.dart';
import 'package:mukbang_ttaradamgi/repository/post_repository.dart';
import 'package:mukbang_ttaradamgi/screens/home/yogiyo_home_screen.dart';
import 'package:mukbang_ttaradamgi/theme.dart';
import 'package:mukbang_ttaradamgi/widgets/common.dart';
import 'package:provider/provider.dart';

void main() {
  test('홈 인기조합은 저장소에 글이 더 있어도 다섯 개만 불러온다', () async {
    final flow = AppFlow(
      postRepository: MockPostRepository(delay: Duration.zero),
    );

    await flow.loadPopularPosts();

    expect(flow.popularPosts, hasLength(5));
  });

  testWidgets('홈 Best 5가 요기족보 목록의 대표 이미지 URL을 사용한다', (tester) async {
    const thumbnailUrl = 'https://cdn.example.com/posts/popular.jpg';
    final flow = AppFlow();
    flow.popularPosts = [
      YogijokboPost.fromListJson(const {
        'postId': 1,
        'title': '대표 이미지가 있는 인기 조합',
        'body': '게시글에 올린 음식 사진이 홈에도 보여야 한다.',
        'thumbnailUrl': thumbnailUrl,
        'authorNickName': '요기요',
        'likeCount': 10,
      }),
    ];

    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppFlow>.value(
        value: flow,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(body: YogiyoHomeScreen()),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('실시간 인기조합 Best 5'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RemoteOrAssetImage && widget.imageUrl == thumbnailUrl,
      ),
      findsOneWidget,
    );
  });
}
