import 'package:flutter/foundation.dart';

import 'models/analysis_source.dart';
import 'models/combo.dart';
import 'models/order.dart';
import 'models/post.dart';
import 'models/preference.dart';
import 'models/user_location.dart';
import 'repository/combo_repository.dart';
import 'repository/order_repository.dart';
import 'repository/post_repository.dart';
import 'env.dart';
import 'services/gemini_extractor.dart';
import 'services/location_service.dart';
import 'services/metadata_fetcher.dart';

enum AppStage {
  login, // 로그인 (앱 첫 진입)
  yogiyoHome, // 요기요 메인 홈 (배너·검색·카테고리·요기족보 차트)
  orders, // 주문내역 (요기족보 작성 진입점)
  home, // 공유 안내
  keyword, // 취향 설정
  analyzing, // 분석 중
  combo, // 가장 유사한 조합 하나
  comboList, // 여러 매장 비교
  storeMenu, // 매장 메뉴 전체 (메뉴 추가하기)
  failed, // 실패 안내
  jokboHome, // 요기족보 홈 (실시간 인기 + 목록)
  jokboDetail, // 조합 상세
  jokboOrder, // 나도 주문하기
  jokboCompose, // 족보 작성 (조합 공유)
}

/// iOS 앱 AppFlowModel 을 Dart 로 옮긴 것. 화면 전환과 분석 파이프라인을 담당한다.
class AppFlow extends ChangeNotifier {
  AppFlow({
    ComboRepository? repository,
    LocationService? locationService,
    PostRepository? postRepository,
    OrderRepository? orderRepository,
  })  : _repository = repository ?? const MockComboRepository(),
        _locationService = locationService ?? const GeolocatorLocationService(),
        _postRepository = postRepository ?? MockPostRepository(),
        _orderRepository = orderRepository ?? MockOrderRepository();

  final ComboRepository _repository;
  final LocationService _locationService;
  final PostRepository _postRepository;
  final OrderRepository _orderRepository;

  AppStage _stage = AppStage.login;
  AppStage get stage => _stage;

  String _pendingLink = '';
  String _failureMessage = '';
  String get failureMessage => _failureMessage;

  TastePreference preference = TastePreference();
  ComboSort sort = ComboSort.similarity;

  List<ComboRecommendation> recommendations = [];
  int selectedComboIndex = 0;

  /// 이번 분석의 입력(원문 텍스트·링크·플랫폼).
  /// 서버에 분석을 넘길 때 추출 결과와 함께 보내야 하므로 버리지 않고 들고 있는다.
  /// 분석을 시작하기 전이거나 텍스트 수집 단계에서 실패하면 null.
  AnalysisSource? source;

  /// 마지막 분석의 AI 추출 결과. `source` 와 짝이다.
  ExtractionResult? extraction;

  ComboRecommendation? get selectedCombo =>
      selectedComboIndex >= 0 && selectedComboIndex < recommendations.length
          ? recommendations[selectedComboIndex]
          : null;

  void _setStage(AppStage next) {
    _stage = next;
    notifyListeners();
  }

  /// 링크를 받으면 바로 분석하지 않고 취향 설정 화면을 먼저 보여준다.
  void start(String link) {
    _pendingLink = link;
    _setStage(AppStage.keyword);
  }

  /// 로그인 완료. 실제 인증이 붙기 전까지는 화면 흐름만 이어준다.
  ///
  /// 곧바로 위치를 1회 수집한다. 좌표를 쓰는 화면(요기족보 목록의 "내 위치에서 가능한
  /// 조합만", 나도 주문하기)에 도달했을 때 이미 준비돼 있어야 흐름이 끊기지 않는다.
  /// 화면 전환을 기다리게 하지 않으려고 await 하지 않고 넘긴다 — 권한 팝업은 홈 위에 뜬다.
  void completeLogin() {
    _setStage(AppStage.yogiyoHome);
    refreshLocation();
    loadPopularPosts();
  }

  /// 요기요 메인 홈의 "요기족보 실시간 인기조합" 차트에 쓸 목록.
  List<YogijokboPost> popularPosts = [];

  Future<void> loadPopularPosts() async {
    popularPosts = await _postRepository.list(sort: PostSort.popular);
    notifyListeners();
  }

  /// 퀵메뉴 "먹방요기" — 공유 안내 화면으로 간다.
  void openShareGuide() => _setStage(AppStage.home);

  void backToYogiyoHome() => _setStage(AppStage.yogiyoHome);

  // ── 주문내역 ───────────────────────────────────────────────────────────────

  List<OrderHistoryItem> orders = [];

  Future<void> openOrders() async {
    _setStage(AppStage.orders);
    orders = await _orderRepository.list();
    notifyListeners();
  }

  /// 주문 이력에서 족보 작성으로. 그 주문의 조합과 출처 영상을 그대로 들고 간다.
  /// 회의록에서 정한 작성 진입점이다.
  void composeFromOrder(OrderHistoryItem order) {
    composeCombo = order.combo.copy();
    composeSource = order.sourceVideoTitle.isEmpty
        ? null
        : PostSource(videoTitle: order.sourceVideoTitle, videoUrl: '');
    composeOrderId = order.orderId;
    _setStage(AppStage.jokboCompose);
  }

  /// 작성 완료 시 어떤 주문에서 왔는지 표시하기 위해 들고 있는다.
  String? composeOrderId;

  /// "다시 주문" — 주문 화면을 그 조합으로 연다.
  void reorderFromHistory(OrderHistoryItem order) {
    orderCombo = order.combo.copy();
    orderUnavailable = false;
    _setStage(AppStage.jokboOrder);
  }

  UserLocation? location;

  /// 마지막 위치 수집 실패 원인. 성공하면 null.
  LocationFailure? locationFailure;

  bool _isLocating = false;
  bool get isLocating => _isLocating;

  /// 다시 물어봐도 소용없어 주소 직접 입력이 필요한 상태인지.
  bool get needsAddressInput =>
      location == null &&
      (locationFailure == LocationFailure.deniedForever ||
          locationFailure == LocationFailure.serviceDisabled);

  /// 기기 좌표를 가져온다. 실패해도 흐름을 막지 않는다 —
  /// 위치는 보조 정보이고, 없으면 주소 직접 입력으로 메꾼다.
  Future<void> refreshLocation() async {
    if (_isLocating) return;
    _isLocating = true;
    notifyListeners();

    final result = await _locationService.current();
    if (result.isSuccess) {
      location = result.location;
      locationFailure = null;
    } else {
      locationFailure = result.failure;
    }

    _isLocating = false;
    notifyListeners();
  }

  /// 권한 거부 시 사용자가 주소를 직접 입력한 경우.
  ///
  /// 좌표를 모르는 상태이므로 서버가 주소로 좌표를 찾아야 한다. 앱은 문자열만 들고
  /// 있고 lat/lng 는 0 으로 둔다 — 아무 좌표나 지어내면 엉뚱한 매장이 걸린다.
  void setManualAddress(String address) {
    final trimmed = address.trim();
    if (trimmed.isEmpty) return;
    location = UserLocation(
      lat: 0,
      lng: 0,
      origin: LocationOrigin.manual,
      address: trimmed,
    );
    locationFailure = null;
    notifyListeners();
  }

  /// 디버그 빌드의 좌표 override. 시연 더미가 강남·용산 기준이라
  /// 리허설 장소가 달라도 화면이 맞게 나오도록 쓴다.
  void applyDebugLocation(UserLocation preset) {
    location = preset;
    locationFailure = null;
    notifyListeners();
  }

  /// 장바구니에서 결과 화면으로 돌아간다.
  void backToCombo() => _setStage(AppStage.combo);

  void backToHome() {
    recommendations = [];
    selectedComboIndex = 0;
    source = null;
    extraction = null;
    _setStage(AppStage.home);
  }

  void showComboList() => _setStage(AppStage.comboList);

  void selectCombo(String comboId) {
    final i = recommendations.indexWhere((c) => c.id == comboId);
    if (i < 0) return;
    selectedComboIndex = i;
    notifyListeners();
  }

  void changeQuantity({required String comboId, required String itemId, required int delta}) {
    final ci = recommendations.indexWhere((c) => c.id == comboId);
    if (ci < 0) return;
    final items = recommendations[ci].items;
    final ii = items.indexWhere((e) => e.id == itemId);
    if (ii < 0) return;

    final next = items[ii].quantity + delta;
    if (next <= 0) {
      items.removeAt(ii);
    } else {
      items[ii].quantity = next;
    }
    notifyListeners();
  }

  void replaceItems({required String comboId, required List<ComboItem> items}) {
    final ci = recommendations.indexWhere((c) => c.id == comboId);
    if (ci < 0) return;
    recommendations[ci].items = items;
    notifyListeners();
  }

  /// 옵션 변경 시트에서 고른 것들을 반영한다.
  /// 표시용 문구와 단가를 함께 다시 계산해야 카드의 금액이 맞는다.
  void updateItemOptions({
    required String comboId,
    required String itemId,
    required List<MenuOptionChoice> choices,
  }) {
    final ci = recommendations.indexWhere((c) => c.id == comboId);
    if (ci < 0) return;
    final items = recommendations[ci].items;
    final ii = items.indexWhere((e) => e.id == itemId);
    if (ii < 0) return;

    final extra = choices.fold(0, (sum, c) => sum + c.extraPrice);
    final base = items[ii].unitPrice - _extraOf(items[ii]);
    items[ii].options = choices.map((c) => c.name).join(', ');
    items[ii].unitPrice = base + extra;
    notifyListeners();
  }

  /// 지금 붙어 있는 옵션들의 추가금. 옵션을 바꿀 때 기본가를 되찾는 데 쓴다.
  int _extraOf(ComboItem item) {
    final chosen = item.options.split(',').map((e) => e.trim()).toSet();
    var sum = 0;
    for (final g in item.optionGroups) {
      for (final c in g.choices) {
        if (chosen.contains(c.name)) sum += c.extraPrice;
      }
    }
    return sum;
  }

  // ── 매장 메뉴 (메뉴 추가하기) ───────────────────────────────────────────────

  /// 메뉴를 담을 대상 조합. 매장 메뉴 화면이 어느 조합에서 열렸는지 기억한다.
  ComboRecommendation? storeMenuCombo;
  List<MenuItem> storeMenuItems = [];

  /// 매장 메뉴를 닫았을 때 돌아갈 화면. 조합 카드와 비교 목록 양쪽에서 열린다.
  AppStage _storeMenuOrigin = AppStage.combo;

  Future<void> openStoreMenu(ComboRecommendation combo) async {
    storeMenuCombo = combo;
    storeMenuItems = [];
    _storeMenuOrigin = _stage;
    _setStage(AppStage.storeMenu);
    storeMenuItems = await _repository.menu(combo.store.id);
    notifyListeners();
  }

  void closeStoreMenu() => _setStage(_storeMenuOrigin);

  /// 매장 메뉴의 + 버튼. 이미 담긴 메뉴면 수량만 올린다.
  void addMenuToCombo(MenuItem menu) {
    final combo = storeMenuCombo;
    if (combo == null) return;
    final i = combo.items.indexWhere((e) => e.id == menu.id);
    if (i >= 0) {
      combo.items[i].quantity += 1;
    } else {
      combo.items.add(menu.toComboItem());
    }
    notifyListeners();
  }

  void updatePreference(TastePreference next) {
    preference = next;
    notifyListeners();
  }

  void updateSort(ComboSort next) {
    sort = next;
    notifyListeners();
  }

  /// 취향 설정에서 "적용하기"를 누르면 실제 분석을 시작한다.
  Future<void> applyPreferenceAndAnalyze() async {
    final link = _pendingLink;
    // 이전 분석의 입력·결과가 남아 새 링크의 것으로 오인되지 않게 먼저 비운다.
    source = null;
    extraction = null;
    _setStage(AppStage.analyzing);

    final uri = Uri.tryParse(link);
    if (uri == null || !uri.scheme.startsWith('http')) {
      _fail('올바른 링크가 아니에요');
      return;
    }

    String text;
    String? thumbnailUrl;
    try {
      final metadata = await const MetadataFetcher().fetch(uri);
      text = metadata.combinedText;
      thumbnailUrl = metadata.imageUrl;
    } catch (_) {
      _fail('게시물 내용을 가져오지 못했어요.\n잠시 후 다시 시도해 주세요.');
      return;
    }

    // Gemini 에 넣은 텍스트를 그대로 보관한다. 서버로 분석을 넘길 때
    // 추출 결과만으로는 부족하고 원문이 함께 필요하다.
    source = AnalysisSource.fromUrl(url: uri, rawText: text);

    // 호출 전에 키를 확인한다. 없거나 템플릿 값이면 네트워크를 태울 필요가 없고,
    // "잠시 후 다시 시도"는 거짓말이 된다 — 키 문제는 재시도로 낫지 않는다.
    if (!Env.hasGeminiKey) {
      _fail(_keyProblemMessage);
      return;
    }

    ExtractionResult? result;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        result = await GeminiExtractor(apiKey: Env.geminiApiKey).extract(text);
        break;
      } on GeminiAuthException {
        // 키가 거부됐다. 재시도해도 같은 결과라 즉시 포기한다.
        _fail(_keyProblemMessage);
        return;
      } catch (_) {
        // 그 밖의 실패(네트워크·타임아웃)는 1회 자동 재시도
      }
    }
    if (result == null) {
      _fail('AI 분석에 실패했어요.\n잠시 후 다시 시도해 주세요.');
      return;
    }
    extraction = result;

    final combos = await _repository.recommend(
      extraction: result,
      thumbnailUrl: thumbnailUrl,
      preference: preference,
    );
    if (combos.isEmpty) {
      _fail('조건에 맞는 조합을 찾지 못했어요.');
      return;
    }

    recommendations = combos;
    selectedComboIndex = 0;
    _setStage(AppStage.combo);
  }

  Future<List<MenuItem>> storeMenu(String storeId) => _repository.menu(storeId);

  // ── 요기족보 ───────────────────────────────────────────────────────────────

  List<YogijokboPost> posts = [];
  bool postsLoading = false;

  PostSort postSort = PostSort.popular;

  /// "내 위치에서 가능한 조합만" 체크박스.
  bool orderableOnly = false;

  YogijokboPost? selectedPost;
  List<PostComment> postComments = [];

  /// "나도 주문하기" 로 받은, 현재 시점으로 다시 계산한 조합.
  /// 게시글 스냅샷과 별개다 — 여기서 수량을 바꿔도 게시글은 그대로여야 한다.
  ComboRecommendation? orderCombo;

  /// 지금 위치에서 주문할 수 없는 조합인지.
  bool orderUnavailable = false;

  /// 작성 화면이 공유할 조합. 분석 결과에서 넘어온다.
  ComboRecommendation? composeCombo;

  /// 작성 화면 상단 영상 카드에 쓸 출처. 분석에 쓴 링크를 그대로 재사용한다.
  PostSource? composeSource;

  /// 반환된 Future 는 목록 로딩이 끝날 때 완료된다. 화면은 기다리지 않아도 되지만
  /// 테스트가 로딩 완료를 기다릴 수 있어야 한다.
  Future<void> openJokbo() {
    _setStage(AppStage.jokboHome);
    return loadPosts();
  }

  Future<void> loadPosts() async {
    postsLoading = true;
    notifyListeners();

    posts = await _postRepository.list(
      sort: postSort,
      orderableOnly: orderableOnly,
      location: location,
    );

    postsLoading = false;
    notifyListeners();
  }

  Future<void> updatePostSort(PostSort next) async {
    if (postSort == next) return;
    postSort = next;
    await loadPosts();
  }

  Future<void> toggleOrderableOnly() async {
    orderableOnly = !orderableOnly;
    await loadPosts();
  }

  Future<void> openPost(String postId) async {
    final post = await _postRepository.detail(postId);
    if (post == null) return;
    selectedPost = post;
    postComments = [];
    _setStage(AppStage.jokboDetail);

    // 댓글은 화면을 띄운 뒤 채운다. 목록 API 가 댓글을 내려주지 않아 별도 호출이다.
    postComments = await _postRepository.comments(postId);
    notifyListeners();
  }

  void backToJokboHome() {
    selectedPost = null;
    postComments = [];
    _setStage(AppStage.jokboHome);
  }

  Future<void> toggleLike() async {
    final post = selectedPost;
    if (post == null) return;

    // 낙관적 업데이트. 서버가 변경 후 카운트를 돌려주므로 응답으로 덮어쓴다.
    post.likedByMe = !post.likedByMe;
    post.likeCount += post.likedByMe ? 1 : -1;
    notifyListeners();

    final result = await _postRepository.toggleLike(post.id);
    post.likeCount = result.likeCount;
    post.likedByMe = result.likedByMe;
    notifyListeners();
  }

  Future<void> submitComment(String body) async {
    final post = selectedPost;
    final trimmed = body.trim();
    if (post == null || trimmed.isEmpty) return;

    final comment = await _postRepository.addComment(post.id, trimmed);
    postComments = [...postComments, comment];
    post.commentCount = postComments.length;
    notifyListeners();
  }

  /// "나도 주문하기". 스냅샷이 지금도 주문 가능한지 서버가 재확인한다.
  Future<void> startReorder() async {
    final post = selectedPost;
    if (post == null) return;

    final result = await _postRepository.reorder(postId: post.id, location: location);
    orderCombo = result.combo;
    orderUnavailable = !result.orderable;
    _setStage(AppStage.jokboOrder);
  }

  void backToPostDetail() {
    orderCombo = null;
    orderUnavailable = false;
    _setStage(AppStage.jokboDetail);
  }

  /// 주문 화면의 수량 변경. 게시글 스냅샷이 아니라 복사본을 고친다.
  void changeOrderQuantity({required String itemId, required int delta}) {
    final combo = orderCombo;
    if (combo == null) return;
    final i = combo.items.indexWhere((e) => e.id == itemId);
    if (i < 0) return;

    final next = combo.items[i].quantity + delta;
    if (next <= 0) {
      combo.items.removeAt(i);
    } else {
      combo.items[i].quantity = next;
    }
    notifyListeners();
  }

  /// 분석 결과를 요기족보에 공유하러 간다.
  /// 영상 카드는 분석에 쓴 링크(`source`)를 그대로 재사용한다.
  void openCompose() {
    final combo = selectedCombo;
    if (combo == null) return;
    composeCombo = combo.copy();
    composeSource = _composeSourceFromAnalysis();
    _setStage(AppStage.jokboCompose);
  }

  PostSource? _composeSourceFromAnalysis() {
    final src = source;
    if (src == null) return null;
    // 영상 제목이 없으면 AI 요약을 대신 쓴다. 링크만 있는 카드는 무엇인지 알 수 없다.
    final title = extraction?.summary.isNotEmpty == true
        ? extraction!.summary
        : src.rawText.split('\n').last;
    return PostSource(videoTitle: title, videoUrl: src.url);
  }

  void cancelCompose() {
    composeCombo = null;
    composeSource = null;
    _setStage(AppStage.combo);
  }

  /// 작성 완료. 공유한 글을 바로 열어 결과를 확인시켜 준다.
  Future<void> submitPost({required String title, required String body}) async {
    final combo = composeCombo;
    if (combo == null || title.trim().isEmpty) return;

    final post = await _postRepository.create(
      title: title.trim(),
      body: body.trim(),
      // 사진 첨부는 조합 이미지를 그대로 쓴다. 갤러리 연동은 이번 범위가 아니다.
      imagePaths: combo.items.map((e) => e.imagePath).toList(),
      combo: combo,
      source: composeSource,
    );

    composeCombo = null;
    composeSource = null;
    selectedPost = post;
    postComments = [];
    _setStage(AppStage.jokboDetail);
  }

  /// 키 문제일 때 보여줄 문구.
  ///
  /// 개발·디버그 빌드에서는 원인을 그대로 알려준다. 이 화면이 "잠시 후 다시
  /// 시도해 주세요"로 보이면 네트워크 문제로 오해해 시연 중에 원인을 못 찾는다.
  /// 릴리즈 빌드에서는 사용자에게 `.env` 를 말할 수 없으니 담당자 확인을 안내한다.
  static String get _keyProblemMessage => kDebugMode
      ? 'Gemini API 키가 설정되지 않았어요.\n'
          '.env 의 GEMINI_API_KEY 를 실제 키로 채우고 다시 빌드해 주세요.'
      : '지금 AI 분석을 쓸 수 없어요.\n담당자에게 문의해 주세요.';

  void _fail(String message) {
    _failureMessage = message;
    _setStage(AppStage.failed);
  }
}
