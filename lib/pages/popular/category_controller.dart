import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/request/apis/bangumi_api.dart';
import 'package:kazumi/services/network/bangumi_acceleration.dart';
import 'package:kazumi/utils/constants.dart';

/// Top-level browse mode hosted inside the Cinema shell's primary route (index 0).
enum PopularBrowseMode {
  home,
  categoryOverview,
  categoryDetail,
}

/// Raw paginated response for a single category tag fetch.
@immutable
class CategoryPageResult {
  const CategoryPageResult({
    required this.items,
    required this.rawCount,
    required this.failed,
  });

  final List<BangumiItem> items;
  final int rawCount;
  final bool failed;
}

typedef CategoryPageFetcher = Future<CategoryPageResult> Function({
  required String tag,
  required int limit,
  required int offset,
  required bool useMirror,
});

/// Immutable snapshot of a single category tag's deduplicated item stream.
@immutable
class CategoryTagFeed {
  const CategoryTagFeed({
    required this.tag,
    this.items = const <BangumiItem>[],
    this.nextRawOffset = 0,
    this.isLoading = false,
    this.hasError = false,
    this.isExhausted = false,
    this.lastUseMirror,
    this.consecutiveEmptyPages = 0,
  });

  final String tag;
  final List<BangumiItem> items;
  final int nextRawOffset;
  final bool isLoading;
  final bool hasError;
  final bool isExhausted;
  final bool? lastUseMirror;
  final int consecutiveEmptyPages;

  BangumiItem? get featured => items.isEmpty ? null : items.first;

  List<BangumiItem> get mosaic => items.length <= 1
      ? const <BangumiItem>[]
      : items.sublist(1, math.min(10, items.length));

  int get gridCount => math.max(0, items.length - 10);

  CategoryTagFeed copyWith({
    List<BangumiItem>? items,
    int? nextRawOffset,
    bool? isLoading,
    bool? hasError,
    bool? isExhausted,
    bool? lastUseMirror,
    bool clearLastUseMirror = false,
    int? consecutiveEmptyPages,
  }) {
    return CategoryTagFeed(
      tag: tag,
      items: items ?? this.items,
      nextRawOffset: nextRawOffset ?? this.nextRawOffset,
      isLoading: isLoading ?? this.isLoading,
      hasError: hasError ?? this.hasError,
      isExhausted: isExhausted ?? this.isExhausted,
      lastUseMirror:
          clearLastUseMirror ? null : (lastUseMirror ?? this.lastUseMirror),
      consecutiveEmptyPages:
          consecutiveEmptyPages ?? this.consecutiveEmptyPages,
    );
  }
}

/// Manages the Cinema category browsing state machine (`home` /
/// `categoryOverview` / `categoryDetail`), per-tag deduplicated feeds,
/// dual-channel ordered heat pagination, bounded request scheduling, and
/// scroll position memory.
class CategoryController extends ChangeNotifier {
  CategoryController({
    List<String>? tags,
    CategoryPageFetcher? pageFetcher,
    bool Function()? mirrorEnabledProvider,
    int maxConcurrentRowLoads = 2,
    int pageSize = defaultPageSize,
  })  : _tags = List<String>.unmodifiable(tags ?? defaultAnimeTags),
        _pageFetcher = pageFetcher ?? _defaultPageFetcher,
        _mirrorEnabledProvider =
            mirrorEnabledProvider ?? _defaultMirrorEnabledProvider,
        _maxConcurrentLoads = math.max(1, maxConcurrentRowLoads),
        _pageSize = math.max(1, pageSize);

  static const int defaultPageSize = 24;

  final List<String> _tags;
  final CategoryPageFetcher _pageFetcher;
  final bool Function() _mirrorEnabledProvider;
  final int _maxConcurrentLoads;
  final int _pageSize;

  PopularBrowseMode _mode = PopularBrowseMode.home;
  String _activeTag = '';
  bool _disposed = false;
  bool _deferredNotifyScheduled = false;

  double overviewScrollOffset = 0.0;
  final Map<String, double> rowScrollOffsets = <String, double>{};

  final Map<String, CategoryTagFeed> _feeds = <String, CategoryTagFeed>{};
  final Map<String, Set<int>> _seenIds = <String, Set<int>>{};
  final Map<String, int> _feedGenerations = <String, int>{};

  final List<String> _pendingQueue = <String>[];
  final Set<String> _priorityTags = <String>{};
  final Set<String> _inFlightTags = <String>{};
  final Map<String, int> _inFlightGenerations = <String, int>{};
  final Map<String, bool> _inFlightUseMirror = <String, bool>{};
  final Map<String, Completer<void>> _pendingCompleters =
      <String, Completer<void>>{};
  final Map<String, bool> _replacementHighPriority = <String, bool>{};
  final Map<String, Completer<void>> _replacementCompleters =
      <String, Completer<void>>{};

  List<String> get tags => _tags;
  PopularBrowseMode get mode => _mode;
  String get activeTag => _activeTag;
  bool get isCategoryActive => _mode != PopularBrowseMode.home;
  int get inFlightCount => _inFlightTags.length;

  static bool _defaultMirrorEnabledProvider() =>
      BangumiAcceleration.current == BangumiAcceleration.mirror;

  static Future<CategoryPageResult> _defaultPageFetcher({
    required String tag,
    required int limit,
    required int offset,
    required bool useMirror,
  }) async {
    if (useMirror) {
      final page = await BangumiApi.getBangumiMirrorPopularPage(
        tag: tag,
        limit: limit,
        offset: offset,
      );
      if (page == null) {
        return const CategoryPageResult(
          items: <BangumiItem>[],
          rawCount: 0,
          failed: true,
        );
      }
      return CategoryPageResult(
        items: page.items,
        rawCount: page.rawCount,
        failed: false,
      );
    }

    final page = await BangumiApi.bangumiSearch(
      '',
      tags: <String>[tag],
      limit: limit,
      offset: offset,
      sort: 'heat',
    );
    if (page == null) {
      return const CategoryPageResult(
        items: <BangumiItem>[],
        rawCount: 0,
        failed: true,
      );
    }
    return CategoryPageResult(
      items: page.items,
      rawCount: page.rawCount,
      failed: false,
    );
  }

  CategoryTagFeed feedFor(String tag) {
    return _feeds.putIfAbsent(tag, () => CategoryTagFeed(tag: tag));
  }

  void openHome() {
    if (_mode == PopularBrowseMode.home && _activeTag.isEmpty) return;
    _mode = PopularBrowseMode.home;
    _activeTag = '';
    _priorityTags.clear();
    _notifySafe();
  }

  void openCategoryOverview() {
    if (_mode == PopularBrowseMode.categoryOverview && _activeTag.isEmpty) {
      return;
    }
    _mode = PopularBrowseMode.categoryOverview;
    _activeTag = '';
    _priorityTags.clear();
    _notifySafe();
  }

  void openCategoryDetail(String tag) {
    final normalized = tag.trim();
    if (normalized.isEmpty) {
      openCategoryOverview();
      return;
    }
    final changed = _mode != PopularBrowseMode.categoryDetail ||
        _activeTag != normalized;
    _mode = PopularBrowseMode.categoryDetail;
    _activeTag = normalized;
    _priorityTags
      ..clear()
      ..add(normalized);
    if (changed) {
      _notifySafe();
    }
    final feed = _syncAccelerationMode(normalized);
    if (feed.items.isEmpty && !feed.isExhausted) {
      unawaited(loadMoreDetail(normalized));
    }
  }

  /// Handles system back navigation inside the category hierarchy:
  /// `categoryDetail -> categoryOverview -> home`.
  bool handleBack() {
    switch (_mode) {
      case PopularBrowseMode.categoryDetail:
        openCategoryOverview();
        return true;
      case PopularBrowseMode.categoryOverview:
        openHome();
        return true;
      case PopularBrowseMode.home:
        return false;
    }
  }

  /// Enqueues the first page for a visible overview row using LIFO ordering so
  /// newly visible rows jump ahead of stale offscreen rows while staying behind
  /// any active detail request.
  Future<void> ensureRowLoaded(String tag) {
    if (_disposed || tag.isEmpty) return Future<void>.value();
    final feed = _syncAccelerationMode(tag);
    if (feed.items.isNotEmpty || feed.isExhausted || feed.hasError) {
      return _pendingCompleters[tag]?.future ?? Future<void>.value();
    }
    return _enqueueFetch(tag, highPriority: false);
  }

  /// Drops an unstarted overview row request when that row scrolls out of view.
  void cancelPendingRowLoad(String tag) {
    if (_disposed || _priorityTags.contains(tag)) {
      return;
    }
    if (_inFlightTags.contains(tag)) {
      final hadReplacement = _replacementHighPriority.remove(tag) != null;
      final replacementCompleter = _replacementCompleters.remove(tag);
      if (replacementCompleter != null && !replacementCompleter.isCompleted) {
        replacementCompleter.complete();
      }
      if (hadReplacement) {
        final current = _feeds[tag];
        if (current != null && current.isLoading) {
          _feeds[tag] = current.copyWith(isLoading: false);
          _notifySafe();
        }
      }
      return;
    }
    final removed = _pendingQueue.remove(tag);
    if (!removed) return;
    final completer = _pendingCompleters.remove(tag);
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
    final current = _feeds[tag];
    if (current != null && current.isLoading) {
      _feeds[tag] = current.copyWith(isLoading: false);
      _notifySafe();
    }
  }

  /// Retries a single tag after an error or acceleration mode switch.
  Future<void> retryTag(String tag) {
    if (_disposed || tag.isEmpty) return Future<void>.value();
    final current = _syncAccelerationMode(tag);
    if (_isInFlightCurrent(tag)) {
      return _pendingCompleters[tag]?.future ?? Future<void>.value();
    }
    if (current.hasError) {
      _feeds[tag] = current.copyWith(hasError: false);
      _notifySafe();
    }
    final isDetailTag =
        _mode == PopularBrowseMode.categoryDetail && _activeTag == tag;
    return _enqueueFetch(tag, highPriority: isDetailTag);
  }

  /// Retries all tags that currently failed with empty content.
  void retryFailedTags(Iterable<String> tags) {
    for (final tag in tags) {
      final feed = feedFor(tag);
      if (feed.hasError && feed.items.isEmpty) {
        unawaited(retryTag(tag));
      }
    }
  }

  /// Loads the next page for a category detail view at highest queue priority,
  /// without any 70-item cap.
  Future<void> loadMoreDetail(String tag) {
    if (_disposed || tag.isEmpty) return Future<void>.value();
    final feed = _syncAccelerationMode(tag);
    if (feed.isExhausted) {
      return Future<void>.value();
    }
    if (_isInFlightCurrent(tag)) {
      return _pendingCompleters[tag]?.future ?? Future<void>.value();
    }
    if (feed.hasError) {
      _feeds[tag] = feed.copyWith(hasError: false);
      _notifySafe();
    }
    _priorityTags.add(tag);
    return _enqueueFetch(tag, highPriority: true);
  }

  bool _isInFlightCurrent(String tag) {
    return _inFlightTags.contains(tag) &&
        _inFlightGenerations[tag] == (_feedGenerations[tag] ?? 0);
  }

  /// Resets the tag feed when the user toggled Bangumi acceleration mode so
  /// mirror offsets and official Bangumi offsets are never mixed.
  CategoryTagFeed _syncAccelerationMode(String tag) {
    final current = feedFor(tag);
    final useMirror = _mirrorEnabledProvider();
    final inFlightMode = _isInFlightCurrent(tag) ? _inFlightUseMirror[tag] : null;
    final modeChanged =
        (current.lastUseMirror != null && current.lastUseMirror != useMirror) ||
        (inFlightMode != null && inFlightMode != useMirror);
    if (modeChanged) {
      _feedGenerations[tag] = (_feedGenerations[tag] ?? 0) + 1;
      _seenIds[tag] = <int>{};
      final reset = CategoryTagFeed(tag: tag);
      _feeds[tag] = reset;
      rowScrollOffsets.remove(tag);
      _notifySafe();
      return reset;
    }
    return current;
  }

  Future<void> _scheduleStaleReplacement(
    String tag, {
    required bool highPriority,
  }) {
    _replacementHighPriority[tag] =
        (_replacementHighPriority[tag] ?? false) || highPriority;
    final completer = _replacementCompleters.putIfAbsent(
      tag,
      Completer<void>.new,
    );
    final current = feedFor(tag);
    if (!current.isLoading || current.hasError) {
      _feeds[tag] = current.copyWith(isLoading: true, hasError: false);
      _notifySafe();
    }
    return completer.future;
  }

  Future<void> _enqueueFetch(String tag, {required bool highPriority}) {
    if (_inFlightTags.contains(tag)) {
      if (_isInFlightCurrent(tag)) {
        return _pendingCompleters[tag]?.future ?? Future<void>.value();
      }
      return _scheduleStaleReplacement(tag, highPriority: highPriority);
    }

    final existingCompleter = _pendingCompleters[tag];

    _pendingQueue.remove(tag);
    if (highPriority) {
      _pendingQueue.insert(0, tag);
    } else {
      // Insert right after any priority detail requests in LIFO order so
      // currently visible rows load before stale offscreen rows.
      var insertAt = 0;
      while (insertAt < _pendingQueue.length &&
          _priorityTags.contains(_pendingQueue[insertAt])) {
        insertAt++;
      }
      _pendingQueue.insert(insertAt, tag);
    }

    final completer =
        existingCompleter ?? (_pendingCompleters[tag] = Completer<void>());
    final current = feedFor(tag);
    if (!current.isLoading || current.hasError) {
      _feeds[tag] = current.copyWith(isLoading: true, hasError: false);
      _notifySafe();
    }

    _pumpQueue();
    return completer.future;
  }

  void _pumpQueue() {
    while (!_disposed &&
        _inFlightTags.length < _maxConcurrentLoads &&
        _pendingQueue.isNotEmpty) {
      final tag = _pendingQueue.removeAt(0);
      if (_inFlightTags.contains(tag)) continue;
      _inFlightTags.add(tag);
      unawaited(_runFetch(tag));
    }
  }

  Future<void> _runFetch(String tag) async {
    final useMirror = _mirrorEnabledProvider();
    final feed = _syncAccelerationMode(tag);
    final generation = _feedGenerations[tag] ?? 0;
    final offset = feed.nextRawOffset;
    _inFlightGenerations[tag] = generation;
    _inFlightUseMirror[tag] = useMirror;

    if (!feed.isLoading || feed.hasError) {
      _feeds[tag] = feed.copyWith(isLoading: true, hasError: false);
      _notifySafe();
    }

    CategoryPageResult result;
    try {
      result = await _pageFetcher(
        tag: tag,
        limit: _pageSize,
        offset: offset,
        useMirror: useMirror,
      );
    } catch (_) {
      result = const CategoryPageResult(
        items: <BangumiItem>[],
        rawCount: 0,
        failed: true,
      );
    }

    _inFlightTags.remove(tag);
    _inFlightGenerations.remove(tag);
    _inFlightUseMirror.remove(tag);
    final completer = _pendingCompleters.remove(tag);
    final replacementHighPriority = _replacementHighPriority.remove(tag);
    final replacementCompleter = _replacementCompleters.remove(tag);
    final stillCurrent = !_disposed && (_feedGenerations[tag] ?? 0) == generation;

    if (stillCurrent) {
      final latest = feedFor(tag);
      if (result.failed) {
        _feeds[tag] = latest.copyWith(
          isLoading: false,
          hasError: true,
        );
      } else {
        final seen = _seenIds.putIfAbsent(
          tag,
          () => latest.items.map((item) => item.id).toSet(),
        );
        final appended = <BangumiItem>[];
        for (final item in result.items) {
          if (seen.add(item.id)) {
            appended.add(item);
          }
        }
        final nextItems = appended.isEmpty
            ? latest.items
            : List<BangumiItem>.unmodifiable(<BangumiItem>[
                ...latest.items,
                ...appended,
              ]);
        final nextRawOffset = latest.nextRawOffset + result.rawCount;
        final nextEmptyPages =
            appended.isEmpty ? latest.consecutiveEmptyPages + 1 : 0;
        final exhausted = result.rawCount == 0 ||
            result.rawCount < _pageSize ||
            nextEmptyPages >= 2;

        _feeds[tag] = latest.copyWith(
          items: nextItems,
          nextRawOffset: nextRawOffset,
          isLoading: false,
          hasError: false,
          isExhausted: exhausted,
          lastUseMirror: useMirror,
          consecutiveEmptyPages: nextEmptyPages,
        );
      }
      _notifySafe();
    }

    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }

    if (!_disposed) {
      if (replacementHighPriority != null) {
        if (replacementCompleter != null && !replacementCompleter.isCompleted) {
          _pendingCompleters[tag] = replacementCompleter;
        }
        unawaited(_enqueueFetch(tag, highPriority: replacementHighPriority));
      } else {
        if (replacementCompleter != null && !replacementCompleter.isCompleted) {
          replacementCompleter.complete();
        }
        _pumpQueue();
      }
    } else if (replacementCompleter != null &&
        !replacementCompleter.isCompleted) {
      replacementCompleter.complete();
    }
  }

  bool get _isInPersistentCallbacks {
    try {
      return SchedulerBinding.instance.schedulerPhase ==
          SchedulerPhase.persistentCallbacks;
    } catch (_) {
      return false;
    }
  }

  void _notifySafe() {
    if (_disposed) return;
    if (_isInPersistentCallbacks) {
      if (_deferredNotifyScheduled) return;
      _deferredNotifyScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _deferredNotifyScheduled = false;
        if (!_disposed) {
          notifyListeners();
        }
      });
      return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _pendingQueue.clear();
    _priorityTags.clear();
    _inFlightGenerations.clear();
    _inFlightUseMirror.clear();
    _replacementHighPriority.clear();
    for (final completer in _pendingCompleters.values) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
    _pendingCompleters.clear();
    for (final completer in _replacementCompleters.values) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
    _replacementCompleters.clear();
    super.dispose();
  }
}
