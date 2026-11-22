import 'dart:math';
import 'package:kazumi/request/apis/bangumi_api.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/services/network/bangumi_acceleration.dart';
import 'package:mobx/mobx.dart';

part 'popular_controller.g.dart';

class PopularController = _PopularController with _$PopularController;

abstract class _PopularController with Store {
  static const int _trendPageSize = 24;
  static const int _trendTarget = 70;
  static const int _maxTrendPages = 5;

  int _trendPagesRequested = 0;
  int _trendNextOffset = 0;
  int _activeTrendViews = 0;
  bool _trendExhausted = false;
  bool _loadingTrend = false;
  Object? _tagRequest;

  @observable
  String currentTag = '';

  @observable
  ObservableList<BangumiItem> bangumiList = ObservableList.of([]);

  @observable
  ObservableList<BangumiItem> trendList = ObservableList.of([]);

  double scrollOffset = 0.0;

  @observable
  bool isLoadingMore = false;

  @observable
  bool isTimeOut = false;

  bool get _bangumiMirrorEnabled =>
      BangumiAcceleration.current == BangumiAcceleration.mirror;

  bool get _canPrefetchTrend =>
      currentTag.isEmpty &&
      _activeTrendViews > 0 &&
      !_trendExhausted &&
      trendList.length < _trendTarget &&
      _trendPagesRequested < _maxTrendPages;

  void attachTrendView() {
    _activeTrendViews++;
  }

  void detachTrendView() {
    if (_activeTrendViews > 0) {
      _activeTrendViews--;
    }
  }

  /// Exposed as a non-`@action` helper so integration tests can stub trend
  /// responses without touching MobX generated code.
  Future<List<BangumiItem>> fetchTrendPage({
    required bool useMirror,
    required int limit,
    required int offset,
  }) => useMirror
      ? BangumiApi.getBangumiMirrorPopularSubjects(limit: limit, offset: offset)
      : BangumiApi.getBangumiTrendsList(limit: limit, offset: offset);

  /// Exposed as a non-`@action` helper so integration tests can stub tag
  /// responses without touching MobX generated code.
  Future<List<BangumiItem>> fetchTagPage({
    required bool useMirror,
    required String tag,
    required int offset,
  }) => useMirror
      ? BangumiApi.getBangumiMirrorPopularSubjects(tag: tag, offset: offset)
      : BangumiApi.getBangumiList(rank: Random().nextInt(8000) + 1, tag: tag);

  void setCurrentTag(String s) {
    if (currentTag == s) return;
    _tagRequest = null;
    runInAction(() {
      currentTag = s;
      isLoadingMore = s.isEmpty && _loadingTrend;
      isTimeOut =
          s.isEmpty &&
          (_trendExhausted || _trendPagesRequested > 0) &&
          trendList.isEmpty;
    });
  }

  void clearBangumiList() {
    bangumiList.clear();
  }

  // Async actions commit each segment between awaits as one transaction,
  // batching the completion writes into a single notification.
  @action
  Future<void> queryBangumiByTrend({String type = 'add'}) async {
    if (_loadingTrend || currentTag.isNotEmpty || _activeTrendViews == 0) {
      return;
    }
    if (type == 'init') {
      trendList.clear();
      _trendPagesRequested = 0;
      _trendNextOffset = 0;
      _trendExhausted = false;
    }
    if (!_canPrefetchTrend) return;

    _loadingTrend = true;
    isLoadingMore = true;
    isTimeOut = false;
    try {
      final useMirror = _bangumiMirrorEnabled;
      final seenIds = trendList.map((item) => item.id).toSet();
      while (_canPrefetchTrend) {
        final offset = _trendNextOffset;
        _trendPagesRequested++;
        final result = await fetchTrendPage(
          useMirror: useMirror,
          limit: _trendPageSize,
          offset: offset,
        );
        if (result.isEmpty) {
          // BangumiApi swallows network errors and returns []; stop this pass
          // without advancing _trendNextOffset or marking exhausted so a later
          // reopen/tag-return retries the failed offset (still capped by _maxTrendPages).
          break;
        }
        _trendNextOffset += _trendPageSize;
        trendList.addAll(
          result
              .where((item) => seenIds.add(item.id))
              .take(_trendTarget - trendList.length),
        );
        _trendExhausted = result.length < _trendPageSize;
      }
    } finally {
      _loadingTrend = false;
      if (currentTag.isEmpty) {
        isLoadingMore = false;
        isTimeOut = trendList.isEmpty;
      }
    }
  }

  @action
  Future<void> queryBangumiByTag({String type = 'add'}) async {
    final tag = currentTag;
    if (tag.isEmpty || _tagRequest != null) return;
    final request = Object();
    _tagRequest = request;
    if (type == 'init') {
      bangumiList.clear();
    }
    isLoadingMore = true;
    isTimeOut = false;
    try {
      final result = await fetchTagPage(
        useMirror: _bangumiMirrorEnabled,
        tag: tag,
        offset: bangumiList.length,
      );
      if (_tagRequest == request) {
        bangumiList.addAll(result);
        isTimeOut = bangumiList.isEmpty;
      }
    } finally {
      if (_tagRequest == request) {
        _tagRequest = null;
        isLoadingMore = false;
      }
    }
  }
}
