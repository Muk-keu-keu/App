import 'package:flutter/foundation.dart';

import 'models/analysis_source.dart';
import 'models/combo.dart';
import 'models/preference.dart';
import 'repository/combo_repository.dart';
import 'env.dart';
import 'services/gemini_extractor.dart';
import 'services/metadata_fetcher.dart';

enum AppStage {
  login, // 로그인 (앱 첫 진입)
  home, // 공유 안내
  keyword, // 취향 설정
  analyzing, // 분석 중
  combo, // 가장 유사한 조합 하나
  comboList, // 여러 매장 비교
  failed, // 실패 안내
}

/// iOS 앱 AppFlowModel 을 Dart 로 옮긴 것. 화면 전환과 분석 파이프라인을 담당한다.
class AppFlow extends ChangeNotifier {
  AppFlow({ComboRepository? repository}) : _repository = repository ?? const MockComboRepository();

  final ComboRepository _repository;

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
  void completeLogin() => _setStage(AppStage.home);

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

    ExtractionResult? result;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        result = await GeminiExtractor(apiKey: Env.geminiApiKey).extract(text);
        break;
      } catch (_) {
        // 1회 자동 재시도
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

  void _fail(String message) {
    _failureMessage = message;
    _setStage(AppStage.failed);
  }
}
