import 'package:flutter/foundation.dart';

import 'api/api_client.dart';
import 'api/mukbang_api.dart';
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
  orders, // 결제 내역 (요기족보 작성 진입점)
  home, // 공유 안내
  keyword, // 취향 설정
  analyzing, // 분석 중
  combo, // 영상에 나온 조합
  comboList, // 여러 매장 비교
  storeMenu, // 매장 메뉴 전체 (메뉴 수정하기)
  cart, // 장바구니 (여러 매장 묶음 결제)
  orderDone, // 주문 접수 완료
  failed, // 실패 안내
  jokboHome, // 요기족보 홈 (실시간 인기 + 목록)
  jokboDetail, // 조합 상세
  jokboOrder, // 나도 주문하기
  jokboCompose, // 족보 작성 (조합 공유)
}

/// 화면 전환과 분석·주문 파이프라인.
///
/// 회의(2026-08-04) 결정에 따라 **장바구니를 여기서 들고 있는다.** 백엔드가
/// 장바구니를 저장하지 않으므로, 사용자가 고른 것은 결제 버튼을 누를 때까지 이
/// 객체 안에만 있다. 앱을 껐다 켜면 사라진다 — 명세가 "프론트가 상태를 들고 있다가
/// 주문 시점에 통째로 POST" 라고 정한 범위 그대로다.
class AppFlow extends ChangeNotifier {
  AppFlow({
    ComboRepository? repository,
    LocationService? locationService,
    PostRepository? postRepository,
    OrderRepository? orderRepository,
  })  : _repository = repository ?? _defaultComboRepository(),
        _locationService = locationService ?? const GeolocatorLocationService(),
        _postRepository = postRepository ?? MockPostRepository(),
        _orderRepository = orderRepository ?? _defaultOrderRepository();

  /// `.env` 에 서버 주소가 있으면 실제 API, 없으면 더미.
  ///
  /// 백엔드가 아직 없어서 기본값이 더미다. 서버가 올라오면 `.env` 의
  /// `API_BASE_URL` 만 채우면 되고 코드는 손대지 않는다.
  static ComboRepository _defaultComboRepository() =>
      Env.hasApiBaseUrl ? ApiComboRepository(_api()) : const MockComboRepository();

  static OrderRepository _defaultOrderRepository() =>
      Env.hasApiBaseUrl ? ApiOrderRepository(_api()) : MockOrderRepository();

  static MukbangApi _api() => MukbangApi(ApiClient(baseUrl: Env.apiBaseUrl));

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

  /// 마지막 분석 결과. `exactMatches` + `combos` 를 그대로 들고 있는다.
  AnalysisResult analysis = const AnalysisResult.empty();

  /// 카드를 넘겨 볼 순서. 영상에 나온 브랜드가 앞, 비슷한 곳이 뒤다.
  List<ComboSuggestion> get suggestions => analysis.all;

  int selectedComboIndex = 0;

  /// 이번 분석의 입력(원문 텍스트·링크·플랫폼).
  /// 서버에 분석을 넘길 때 추출 결과와 함께 보내야 하므로 버리지 않고 들고 있는다.
  AnalysisSource? source;

  /// 마지막 분석의 AI 추출 결과. [source] 와 짝이다.
  ExtractionResult? extraction;

  ComboSuggestion? get selectedCombo =>
      selectedComboIndex >= 0 && selectedComboIndex < suggestions.length
          ? suggestions[selectedComboIndex]
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
  /// 조합만")에 도달했을 때 이미 준비돼 있어야 흐름이 끊기지 않는다.
  void completeLogin() {
    _setStage(AppStage.yogiyoHome);
    refreshLocation();
    loadPopularPosts();
  }

  /// 요기요 메인 홈의 "요기족보 실시간 인기조합" 차트에 쓸 목록.
  List<YogijokboPost> popularPosts = [];

  Future<void> loadPopularPosts() async {
    final page = await _postRepository.list(sort: PostSort.popular);
    popularPosts = page.items;
    notifyListeners();
  }

  /// 퀵메뉴 "먹방요기" — 공유 안내 화면으로 간다.
  void openShareGuide() => _setStage(AppStage.home);

  void backToYogiyoHome() => _setStage(AppStage.yogiyoHome);

  // ── 결제 내역 ──────────────────────────────────────────────────────────────

  /// `GET v1/orders` 의 카드들. 카드 하나 = 결제 하나 = 영상 하나다.
  List<OrderSummary> orders = [];

  /// 결제 목록 다음 커서. null 이면 더 없다.
  String? ordersNextCursor;

  Future<void> openOrders() async {
    _setStage(AppStage.orders);
    await loadOrders();
  }

  Future<void> loadOrders() async {
    final page = await _orderRepository.list();
    orders = page.orders;
    ordersNextCursor = page.nextCursor;
    notifyListeners();
  }

  Future<void> loadMoreOrders() async {
    final cursor = ordersNextCursor;
    if (cursor == null) return;
    final page = await _orderRepository.list(cursor: cursor);
    orders = [...orders, ...page.orders];
    ordersNextCursor = page.nextCursor;
    notifyListeners();
  }

  /// 이 결제로 이미 족보를 썼는지. 서버가 알려주지 않아 앱이 기억한 값이다.
  bool isPostedToJokbo(int checkoutId) => _orderRepository.isPostedToJokbo(checkoutId);

  /// 결제 내역에서 족보 작성으로. 그 결제의 조합과 출처 영상을 그대로 들고 간다.
  Future<void> composeFromOrder(OrderSummary order) async {
    final detail = await _orderRepository.detail(order.checkoutId);
    if (detail == null) return;

    composeCart = detail.toCart();
    composeSource = detail.source == null
        ? null
        : PostSource(
            platform: detail.source!.platform == SourceKind.instagram
                ? PostPlatform.instagram
                : PostPlatform.youtube,
            title: detail.source!.title,
            url: detail.source!.url,
            thumbnailUrl: detail.source!.thumbnailUrl,
          );
    composeCheckoutId = detail.checkoutId;
    _setStage(AppStage.jokboCompose);
  }

  /// 작성 완료 시 어떤 결제에서 왔는지 표시하기 위해 들고 있는다.
  int? composeCheckoutId;

  /// "다시 주문" — 결제 상세를 장바구니로 되돌려 장바구니 화면을 연다.
  ///
  /// 결제 상세는 매장 정보를 세 개(id·이름·배달비)만 준다. 그대로 그리면 평점·최소
  /// 주문 금액이 0으로 보이므로, 매장마다 GET menus 로 온전한 정보를 다시 받아 채운다.
  /// 매장이 두세 곳이라 호출 수가 문제되지 않는다.
  Future<void> reorderFromHistory(OrderSummary order) async {
    final detail = await _orderRepository.detail(order.checkoutId);
    if (detail == null) return;

    final restored = detail.toCart();
    for (final store in restored.stores) {
      final menus = await _safeMenus(store.restaurantId);
      if (menus != null) store.hydrate(menus);
    }

    cart = restored;
    _setStage(AppStage.cart);
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

  void backToCombo() => _setStage(AppStage.combo);

  void backToHome() {
    analysis = const AnalysisResult.empty();
    selectedComboIndex = 0;
    source = null;
    extraction = null;
    cart = Cart();
    _setStage(AppStage.home);
  }

  void showComboList() => _setStage(AppStage.comboList);

  void selectCombo(int comboId) {
    final i = suggestions.indexWhere((c) => c.id == comboId);
    if (i < 0) return;
    selectedComboIndex = i;
    notifyListeners();
  }

  // ── 장바구니 (다중 매장 묶음) ───────────────────────────────────────────────

  /// 결제 전까지 앱이 들고 있는 장바구니. 서버에 저장되지 않는다.
  Cart cart = Cart();

  /// 분석 결과에서 고른 조합들을 장바구니에 담고 장바구니 화면을 연다.
  ///
  /// 영상에 나온 브랜드가 여러 개면 기본으로 전부 담는다 — 떡볶이+핫도그 영상이면
  /// 두 가게가 담긴 채로 시작한다. 그게 회의에서 정한 "한 번에 결제" 의 기본값이다.
  void openCartFromAnalysis() {
    final selected = analysis.exactMatches.isEmpty
        // 영상 브랜드를 못 찾았으면 지금 보고 있는 카드를 담는다.
        ? [if (selectedCombo != null) selectedCombo!.toStoreCart()]
        : analysis.exactStoreCarts;

    cart = Cart(source: _cartSource(), stores: selected);
    _setStage(AppStage.cart);
  }

  /// 카드 하나만 장바구니에 담는다. 비교 목록에서 고른 대안 매장이 여기로 온다.
  void addSuggestionToCart(ComboSuggestion suggestion) {
    cart.source ??= _cartSource();
    final store = cart.storeOf(suggestion.id);
    if (store == null) {
      cart.stores = [...cart.stores, suggestion.toStoreCart()];
    } else {
      // 이미 담긴 가게면 메뉴만 합친다. 같은 메뉴는 수량이 올라간다.
      for (final line in suggestion.items) {
        final existing = store.lineOf(line.menuId);
        if (existing != null) {
          existing.quantity += line.quantity;
        } else {
          store.lines = [...store.lines, line.copy()];
        }
      }
    }
    notifyListeners();
  }

  /// 장바구니에 담긴 가게인지. 비교 목록 체크박스가 쓴다.
  bool isInCart(int restaurantId) => cart.storeOf(restaurantId) != null;

  /// 체크박스 토글. 담겨 있으면 빼고, 없으면 담는다.
  void toggleSuggestionInCart(ComboSuggestion suggestion) {
    if (isInCart(suggestion.id)) {
      removeStoreFromCart(suggestion.id);
    } else {
      addSuggestionToCart(suggestion);
    }
  }

  void removeStoreFromCart(int restaurantId) {
    cart.stores = [for (final s in cart.stores) if (s.restaurantId != restaurantId) s];
    notifyListeners();
  }

  void openCart() => _setStage(AppStage.cart);

  /// 장바구니 수량 변경. 마지막 메뉴를 빼면 그 가게도 함께 사라진다 —
  /// 이름만 남으면 배달비가 총액에 계속 붙어 금액이 틀린다.
  void changeCartQuantity({
    required int restaurantId,
    required int menuId,
    required int delta,
  }) {
    final store = cart.storeOf(restaurantId);
    if (store == null) return;
    store.changeQuantity(menuId: menuId, delta: delta);
    cart.pruneEmptyStores();
    notifyListeners();
  }

  /// 조합 카드의 수량 변경.
  ///
  /// 이미 담긴 매장이면 장바구니 쪽을 고친다 — 카드와 장바구니가 다른 수량을
  /// 보여주면 어느 쪽이 결제되는지 알 수 없다. 아직 안 담긴 매장은 카드만 고친다.
  void changeSuggestionQuantity({
    required ComboSuggestion combo,
    required int menuId,
    required int delta,
  }) {
    final store = cart.storeOf(combo.id);
    if (store != null) {
      store.changeQuantity(menuId: menuId, delta: delta);
      cart.pruneEmptyStores();
      notifyListeners();
      return;
    }

    final line = combo.lineOf(menuId);
    if (line == null) return;
    final next = line.quantity + delta;
    // 담기지 않은 카드에서는 줄을 없애지 않는다. 분석 결과가 사라지면
    // 체크를 눌러 담을 대상 자체가 없어진다.
    if (next <= 0) return;
    line.quantity = next;
    notifyListeners();
  }

  /// 옵션 변경 시트에서 고른 것들을 반영한다.
  void updateLineOptions({
    required int restaurantId,
    required int menuId,
    required List<MenuOption> chosen,
    SpiceLevel? spice,
  }) {
    final line = cart.storeOf(restaurantId)?.lineOf(menuId);
    if (line == null) return;
    line.applySelection(chosen);
    if (spice != null) line.selectedSpice = spice;
    notifyListeners();
  }

  /// 출처 영상을 주문 요청에 실을 형태로. 분석에 쓴 링크를 그대로 재사용한다.
  OrderSource? _cartSource() {
    final s = source;
    if (s == null) return null;
    return OrderSource(
      platform: s.platform == SourcePlatform.instagram
          ? SourceKind.instagram
          : SourceKind.youtube,
      url: s.url,
      thumbnailUrl: _lastThumbnailUrl,
      title: extraction?.primaryRestaurantName ?? '',
    );
  }

  // ── 결제 ──────────────────────────────────────────────────────────────────

  /// 결제 진행 중인지. 버튼을 두 번 눌러 주문이 두 건 생기지 않게 막는다.
  bool isCheckingOut = false;

  /// `POST v1/orders` 의 응답. 완료 화면이 그린다.
  OrderReceipt? receipt;

  /// 장바구니를 통째로 보낸다. 가게가 여러 곳이어도 요청은 한 번이다.
  ///
  /// 응답에 `orderId` 가 없어 완료 화면에서 특정 상세로 갈 수 없다. 목록으로만 간다
  /// (`docs/api-spec.md` 확인 필요 항목).
  Future<void> checkout() async {
    if (isCheckingOut || !cart.canCheckout) return;

    isCheckingOut = true;
    notifyListeners();

    try {
      receipt = await _orderRepository.create(cart);
      cart = Cart();
      _setStage(AppStage.orderDone);
    } on ApiException catch (e) {
      _fail(_checkoutFailureMessage(e));
    } on NetworkException {
      _fail('주문을 보내지 못했어요.\n연결을 확인하고 다시 시도해 주세요.');
    } finally {
      isCheckingOut = false;
      notifyListeners();
    }
  }

  /// 주문 실패 안내. 400 은 대개 프론트가 계산한 값이 서버와 어긋난 경우다 —
  /// 서버가 menuId 로 다시 계산하므로 사용자가 할 수 있는 건 다시 담는 것뿐이다.
  static String _checkoutFailureMessage(ApiException e) => switch (e.statusCode) {
        400 => '주문 내용을 다시 확인해 주세요.\n메뉴나 가격이 바뀌었을 수 있어요.',
        404 => '지금은 주문할 수 없는 메뉴가 있어요.',
        _ => '주문에 실패했어요.\n잠시 후 다시 시도해 주세요.',
      };

  /// 완료 화면에서 결제 내역으로.
  Future<void> openOrdersFromReceipt() async {
    receipt = null;
    await openOrders();
  }

  // ── 매장 메뉴 (메뉴 수정하기) ───────────────────────────────────────────────

  /// 메뉴를 담을 대상 매장 id. 매장 메뉴 화면이 어디에서 열렸는지 기억한다.
  int? storeMenuRestaurantId;
  Restaurant? storeMenuRestaurant;
  List<Menu> storeMenuItems = [];

  /// 매장 메뉴를 닫았을 때 돌아갈 화면.
  AppStage _storeMenuOrigin = AppStage.cart;

  Future<void> openStoreMenu(int restaurantId) async {
    storeMenuRestaurantId = restaurantId;
    storeMenuRestaurant = null;
    storeMenuItems = [];
    _storeMenuOrigin = _stage;
    _setStage(AppStage.storeMenu);

    final menus = await _safeMenus(restaurantId);
    if (menus == null) {
      // 404 이거나 못 불러왔다. 화면은 빈 목록으로 두고 조합은 그대로 남긴다.
      notifyListeners();
      return;
    }
    storeMenuRestaurant = menus.restaurant;
    storeMenuItems = menus.menus;
    notifyListeners();
  }

  void closeStoreMenu() => _setStage(_storeMenuOrigin);

  /// 매장 메뉴의 + 버튼. 이미 담긴 메뉴면 수량만 올린다.
  void addMenuToCart(Menu menu) {
    final restaurant = storeMenuRestaurant ??
        (storeMenuRestaurantId == null
            ? null
            : cart.storeOf(storeMenuRestaurantId!)?.restaurant);
    if (restaurant == null) return;

    cart.source ??= _cartSource();
    cart.ensureStore(restaurant).add(menu);
    notifyListeners();
  }

  /// 그 메뉴가 장바구니에 몇 개 담겼는지. 매장 메뉴 화면이 수량을 보여준다.
  int cartQuantityOf(int menuId) {
    final id = storeMenuRestaurantId;
    if (id == null) return 0;
    return cart.storeOf(id)?.lineOf(menuId)?.quantity ?? 0;
  }

  /// 메뉴 조회 실패를 화면 흐름으로 삼키지 않고 null 로 바꾼다.
  Future<RestaurantMenus?> _safeMenus(int restaurantId) async {
    try {
      return await _repository.menus(restaurantId);
    } on ApiException {
      return null;
    } on NetworkException {
      return null;
    } on ApiNotConfiguredException {
      return null;
    }
  }

  void updatePreference(TastePreference next) {
    preference = next;
    notifyListeners();
  }

  void updateSort(ComboSort next) {
    sort = next;
    notifyListeners();
  }

  /// 정렬을 적용한 비교 목록.
  List<ComboSuggestion> get sortedSuggestions => sort.apply(suggestions);

  /// 취향 설정 화면을 필터로 다시 열었는지.
  ///
  /// 시안의 "필터"(681:6194)는 키워드 선택 화면과 구조가 같다 — 디자이너가 같은
  /// 화면을 재사용했다. 그래서 화면을 새로 만들지 않고 이 깃발로 갈라 쓴다.
  bool _keywordIsFilter = false;

  /// 마지막 분석의 썸네일. 필터를 다시 걸 때 같은 이미지를 써야 카드가 바뀌지 않는다.
  String? _lastThumbnailUrl;

  /// 비교 목록의 필터 칩. 취향 설정 화면을 필터로 다시 연다.
  void openFilter() {
    _keywordIsFilter = true;
    _setStage(AppStage.keyword);
  }

  /// 취향 설정에서 "적용하기"를 누르면 실제 분석을 시작한다.
  /// 필터로 열렸을 때는 AI 를 다시 부르지 않고 분석만 다시 요청한다 —
  /// 영상에서 뽑은 내용은 그대로이고 취향만 바뀌었다.
  Future<void> applyPreferenceAndAnalyze() async {
    if (_keywordIsFilter) {
      _keywordIsFilter = false;
      return _reapplyPreference();
    }
    return _analyze();
  }

  Future<void> _reapplyPreference() async {
    final result = extraction;
    final input = source;
    if (result == null || input == null) {
      _setStage(AppStage.comboList);
      return;
    }

    _setStage(AppStage.analyzing);
    final analyzed = await _requestAnalysis(input, result);
    if (analyzed == null) return;

    analysis = analyzed;
    selectedComboIndex = 0;
    _setStage(AppStage.comboList);
  }

  Future<void> _analyze() async {
    final link = _pendingLink;
    // 이전 분석의 입력·결과가 남아 새 링크의 것으로 오인되지 않게 먼저 비운다.
    source = null;
    extraction = null;
    analysis = const AnalysisResult.empty();
    _setStage(AppStage.analyzing);

    final uri = Uri.tryParse(link);
    if (uri == null || !uri.scheme.startsWith('http')) {
      _fail('올바른 링크가 아니에요');
      return;
    }

    // 명세의 `source.platform` 은 INSTAGRAM | YOUTUBE 두 값만 받는다.
    // 그 밖의 링크는 보낼 수 없으므로 텍스트를 긁기 전에 막는다.
    final platform = SourcePlatform.fromUrl(uri);
    if (!platform.isSupported) {
      _fail('인스타그램과 유튜브 링크만 분석할 수 있어요');
      return;
    }

    String text;
    String? thumbnailUrl;
    try {
      final metadata = await const MetadataFetcher().fetch(uri);
      text = metadata.combinedText;
      thumbnailUrl = metadata.imageUrl;
      _lastThumbnailUrl = thumbnailUrl;
    } catch (_) {
      _fail('게시물 내용을 가져오지 못했어요.\n잠시 후 다시 시도해 주세요.');
      return;
    }

    // Gemini 에 넣은 텍스트를 그대로 보관한다. 서버로 분석을 넘길 때
    // 추출 결과만으로는 부족하고 원문이 함께 필요하다.
    final input = AnalysisSource.fromUrl(url: uri, rawText: text);
    source = input;

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

    final analyzed = await _requestAnalysis(input, result);
    if (analyzed == null) return;

    analysis = analyzed;
    selectedComboIndex = 0;
    _setStage(AppStage.combo);
  }

  /// `POST v1/analyses` 호출. 실패하면 실패 화면으로 보내고 null 을 준다.
  ///
  /// 결과가 0개인 것은 실패가 아니지만(명세가 200 + 빈 배열) 보여줄 화면이 없어
  /// 같은 안내로 처리한다.
  Future<AnalysisResult?> _requestAnalysis(
    AnalysisSource input,
    ExtractionResult result,
  ) async {
    AnalysisResult analyzed;
    try {
      analyzed = await _repository.analyze(
        source: input,
        extraction: result,
        thumbnailUrl: _lastThumbnailUrl,
        preference: preference,
      );
    } on ApiException {
      _fail('조합을 찾는 데 실패했어요.\n잠시 후 다시 시도해 주세요.');
      return null;
    } on NetworkException {
      _fail('서버에 연결하지 못했어요.\n연결을 확인하고 다시 시도해 주세요.');
      return null;
    } on ApiNotConfiguredException {
      _fail('서버 주소가 설정되지 않았어요.\n.env 의 API_BASE_URL 을 확인해 주세요.');
      return null;
    }

    if (analyzed.isEmpty) {
      _fail('조건에 맞는 조합을 찾지 못했어요.');
      return null;
    }
    return analyzed;
  }

  // ── 요기족보 ───────────────────────────────────────────────────────────────

  List<YogijokboPost> posts = [];
  bool postsLoading = false;

  PostSort postSort = PostSort.popular;

  /// "내 위치에서 가능한 조합만" 체크박스.
  ///
  /// 서버는 반경 5km 로 고정해 판정한다 (명세: `orderableHere` 는 lat/lng 기준 5km).
  /// 이 깃발은 그 판정을 목록에서 걸러낼지 여부다.
  bool orderableOnly = false;

  YogijokboPost? selectedPost;
  List<PostComment> postComments = [];

  /// 지금 위치에서 주문할 수 없는 조합인지.
  bool orderUnavailable = false;

  /// 작성 화면이 공유할 조합.
  Cart? composeCart;

  /// 작성 화면 상단 영상 카드에 쓸 출처.
  PostSource? composeSource;

  /// 반환된 Future 는 목록 로딩이 끝날 때 완료된다. 화면은 기다리지 않아도 되지만
  /// 테스트가 로딩 완료를 기다릴 수 있어야 한다.
  Future<void> openJokbo() {
    _setStage(AppStage.jokboHome);
    return loadPosts();
  }

  /// 다음 페이지 커서. null 이면 더 없다 (api-yogijokbo.md 1번).
  String? postsNextCursor;

  Future<void> loadPosts() async {
    postsLoading = true;
    notifyListeners();

    final page = await _postRepository.list(
      sort: postSort,
      orderableOnly: orderableOnly,
      location: location,
    );
    posts = page.items;
    postsNextCursor = page.nextCursor;

    postsLoading = false;
    notifyListeners();
  }

  /// 목록 끝에서 다음 페이지를 이어 붙인다.
  Future<void> loadMorePosts() async {
    final cursor = postsNextCursor;
    if (cursor == null || postsLoading) return;

    postsLoading = true;
    notifyListeners();

    final page = await _postRepository.list(
      sort: postSort,
      orderableOnly: orderableOnly,
      location: location,
      cursor: cursor,
    );
    posts = [...posts, ...page.items];
    postsNextCursor = page.nextCursor;

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

    // 상세 응답에는 orderableHere 가 없다. 목록에서 알던 값을 물려준다.
    for (final list in [posts, popularPosts]) {
      final known = list.where((p) => p.id == postId);
      if (known.isNotEmpty) {
        post.orderableHere = known.first.orderableHere;
        break;
      }
    }

    selectedPost = post;
    postComments = [];
    commentsNextCursor = null;
    _setStage(AppStage.jokboDetail);

    // 댓글은 화면을 띄운 뒤 채운다. 상세 응답이 댓글을 내려주지 않아 별도 호출이다.
    await loadComments(postId);
  }

  /// 댓글 다음 페이지 커서.
  String? commentsNextCursor;

  Future<void> loadComments(String postId) async {
    final page = await _postRepository.comments(postId);
    postComments = page.items;
    commentsNextCursor = page.nextCursor;
    notifyListeners();
  }

  Future<void> loadMoreComments() async {
    final post = selectedPost;
    final cursor = commentsNextCursor;
    if (post == null || cursor == null) return;

    final page = await _postRepository.comments(post.id, cursor: cursor);
    postComments = [...postComments, ...page.items];
    commentsNextCursor = page.nextCursor;
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
    await _toggleLikeOf(post);
  }

  /// 목록에서 누른 좋아요. 시안(681:8066)의 목록 행에도 좋아요 버튼이 있어
  /// 글을 열지 않고 바로 누를 수 있어야 한다.
  Future<void> toggleLikeOn(String postId) async {
    for (final list in [posts, popularPosts]) {
      final i = list.indexWhere((p) => p.id == postId);
      if (i >= 0) return _toggleLikeOf(list[i]);
    }
  }

  Future<void> _toggleLikeOf(YogijokboPost post) async {
    // 낙관적 업데이트. 서버가 변경 후 카운트를 돌려주므로 응답으로 덮어쓴다.
    post.likedByMe = !post.likedByMe;
    post.likeCount += post.likedByMe ? 1 : -1;
    notifyListeners();

    // 명세는 좋아요와 취소를 다른 엔드포인트로 나눈다. 둘 다 멱등이라
    // 낙관적 업데이트가 서버 상태와 어긋나도 응답으로 맞춰진다.
    final result = post.likedByMe
        ? await _postRepository.like(post.id)
        : await _postRepository.unlike(post.id);
    post.likeCount = result.likeCount;
    post.likedByMe = result.likedByMe;
    notifyListeners();
  }

  Future<void> submitComment(String body) async {
    final post = selectedPost;
    final trimmed = body.trim();
    if (post == null || trimmed.isEmpty) return;

    // 201 은 본문이 없다. 서버가 매긴 id·작성시각을 알 수 없어 다시 받아온다.
    await _postRepository.addComment(post.id, trimmed);
    await loadComments(post.id);
    post.commentCount = postComments.length;
    notifyListeners();
  }

  /// "나도 주문하기".
  ///
  /// 전용 API 가 없다 (api-yogijokbo.md "나도 주문하기 흐름"). 게시글의 조합이 이미
  /// 장바구니 모양이라 그것을 복사해 장바구니 화면으로 넘긴다. 복사본이라 장바구니에서
  /// 수량을 바꿔도 게시글 스냅샷은 그대로다.
  ///
  /// 매장이 여러 곳인 글이면 그대로 여러 가게가 담긴 장바구니가 된다.
  Future<void> startReorder() async {
    final post = selectedPost;
    if (post == null) return;

    cart = post.toCart();
    if (post.source != null) {
      cart.source = OrderSource(
        platform: post.source!.platform == PostPlatform.instagram
            ? SourceKind.instagram
            : SourceKind.youtube,
        url: post.source!.url,
        thumbnailUrl: post.source!.thumbnailUrl,
        title: post.source!.title,
      );
    }
    orderUnavailable = !post.orderableHere;
    _setStage(AppStage.jokboOrder);
  }

  void backToPostDetail() {
    orderUnavailable = false;
    _setStage(AppStage.jokboDetail);
  }

  void cancelCompose() {
    composeCart = null;
    composeSource = null;
    composeCheckoutId = null;
    _setStage(AppStage.orders);
  }

  /// 작성 완료. 서버는 postId 만 돌려주므로 그 id 로 상세를 열어 확인시켜 준다
  /// (api-yogijokbo.md 3번 흐름).
  ///
  /// 조합 내용은 보내지 않는다. checkoutId 만 보내면 서버가 결제 스냅샷에서 읽어 붙인다.
  Future<void> submitPost({required String title, required String body}) async {
    final checkoutId = composeCheckoutId;
    if (checkoutId == null || title.trim().isEmpty) return;

    final postId = await _postRepository.create(
      checkoutId: checkoutId,
      title: title.trim(),
      body: body.trim(),
      // 사진 첨부(갤러리·카메라)는 이번 범위가 아니다. 명세상 0장도 허용된다.
    );

    await _orderRepository.markPosted(checkoutId);
    composeCart = null;
    composeSource = null;
    composeCheckoutId = null;
    await openPost(postId);
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

/// 결제 상세로 되돌린 장바구니의 매장 정보를 온전한 값으로 채운다.
///
/// 결제 상세는 매장 id·이름·배달비만 준다. GET menus 로 받은 매장으로 갈아끼우면
/// 평점·최소 주문 금액·거리가 화면에 제대로 나온다. 옵션 후보도 같은 이유로 채운다 —
/// 주문 상세의 `selectedOptions` 는 고른 것만이라 시트를 열면 후보가 부족하다.
extension on StoreCart {
  void hydrate(RestaurantMenus menus) {
    restaurant = menus.restaurant;
    final byId = {for (final m in menus.menus) m.menuId: m};
    lines = [
      for (final line in lines)
        if (byId[line.menuId] case final menu?)
          CartLine(
            menuId: line.menuId,
            name: line.name,
            menuType: menu.menuType,
            price: line.price,
            quantity: line.quantity,
            imageUrl: menu.imageUrl,
            imagePath: menu.imagePath,
            spiceLevel: menu.spiceLevel,
            spiceAdjustable: menu.spiceAdjustable,
            selectedSpice: line.selectedSpice,
            // 후보 전체를 넣고, 그때 고른 것만 다시 체크한다.
            options: [
              for (final option in menu.options)
                option.copyWith(
                  selected: line.selectedOptions.any((s) => s.isSameAs(option)),
                ),
            ],
          )
        else
          line,
    ];
  }
}
