import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/modules/collect/collect_type.dart';
import 'package:kazumi/modules/search/search_history_module.dart';
import 'package:kazumi/pages/search/search_controller.dart';
import 'package:kazumi/pages/search/search_filter_panel.dart';
import 'package:kazumi/pages/search/search_page.dart';
import 'package:kazumi/repositories/collect_repository.dart';
import 'package:kazumi/repositories/search_history_repository.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/utils/search_parser.dart';
import 'package:logger/logger.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

void main() {
  late Directory tempDir;
  late PathProviderPlatform originalPathProvider;
  late Level originalLogLevel;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    originalLogLevel = Logger.level;
    Logger.level = Level.off;
    tempDir = await Directory.systemTemp.createTemp(
      'kazumi_search_panel_test_',
    );
    originalPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _TestPaths(tempDir.path);
    Hive.init(tempDir.path);
    await GStorage.init();
  });

  tearDownAll(() async {
    Logger.level = originalLogLevel;
    await Hive.close();
    PathProviderPlatform.instance = originalPathProvider;
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  group('search filter formatting helpers', () {
    test('formats sort labels and falls back to heat label', () {
      expect(formatSearchSortLabel('heat'), '热度');
      expect(formatSearchSortLabel('rank'), '排名');
      expect(formatSearchSortLabel('score'), '评分');
      expect(formatSearchSortLabel('match'), '匹配');
      expect(formatSearchSortLabel('unknown'), '热度');
    });

    test('formats filter summary and readable query', () {
      const state = SearchFilterState(
        keyword: '葬送的芙莉莲',
        tags: ['奇幻', '治愈'],
        sort: 'score',
        season: '2023Q4',
        scoreRange: SearchDoubleRange(min: 8, max: 10),
        rankRange: SearchIntRange(min: 1, max: 500),
        weekdays: [5],
      );
      expect(
        formatSearchFilterSummary(state),
        '奇幻 · 治愈 · 2023Q4 · 评分 8..10 · 排名 1..500 · 周五',
      );
      expect(
        formatReadableSearchQuery(SearchParser.fromFilterState(state)),
        '葬送的芙莉莲 · 奇幻 · 治愈 · 2023Q4 · 评分 8..10 · 排名 1..500 · 周五 · 评分排序',
      );
    });
  });

  group('SearchFilterPanel', () {
    testWidgets('edits sort, tags, hide toggles and applies result', (t) async {
      SearchFilterResult? applied;
      var closeCount = 0;

      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 380,
                height: 540,
                child: SearchFilterPanel(
                  showDragHandle: false,
                  initialState: const SearchFilterState(keyword: '孤独摇滚'),
                  initialNotShowWatched: false,
                  initialNotShowAbandoned: false,
                  onApply: (result) => applied = result,
                  onClose: () => closeCount++,
                ),
              ),
            ),
          ),
        ),
      );

      // Change sort to score.
      await t.tap(find.text('按热度排序'));
      await t.pumpAndSettle();
      await t.tap(find.text('按评分排序').last);
      await t.pumpAndSettle();

      // Expand genre tags and pick a tag + custom tag.
      await t.tap(find.text('题材标签'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilterChip, '日常'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.byType(TextField));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), '音乐');
      await t.ensureVisible(find.byTooltip('添加标签'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('添加标签'));
      await t.pumpAndSettle();

      // Expand collection status and toggle hide watched / abandoned.
      final collectionHeader = find.text('收藏状态');
      await t.dragUntilVisible(
        collectionHeader,
        find.byType(ListView),
        const Offset(0, -180),
      );
      await t.tap(collectionHeader);
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('隐藏看过的番剧'));
      await t.pumpAndSettle();
      await t.tap(find.text('隐藏看过的番剧'));
      await t.ensureVisible(find.text('隐藏抛弃的番剧'));
      await t.pumpAndSettle();
      await t.tap(find.text('隐藏抛弃的番剧'));
      await t.pumpAndSettle();

      // Apply filters.
      await t.tap(find.text('查看结果'));
      await t.pumpAndSettle();

      expect(applied, isNotNull);
      expect(applied!.filterState.keyword, '孤独摇滚');
      expect(applied!.filterState.sort, 'score');
      expect(applied!.filterState.tags, containsAll(['日常', '音乐']));
      expect(applied!.notShowWatched, isTrue);
      expect(applied!.notShowAbandoned, isTrue);

      // Close button triggers onClose.
      await t.tap(find.byTooltip('关闭'));
      await t.pump();
      expect(closeCount, 1);
      expect(t.takeException(), isNull);
    });

    testWidgets('resets filters while preserving keyword and id', (t) async {
      SearchFilterResult? applied;

      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                height: 540,
                child: SearchFilterPanel(
                  showDragHandle: true,
                  initialState: const SearchFilterState(
                    keyword: '进击的巨人',
                    tags: ['热血'],
                    sort: 'rank',
                    weekdays: [1, 6],
                  ),
                  initialNotShowWatched: true,
                  initialNotShowAbandoned: true,
                  onApply: (result) => applied = result,
                  onClose: () {},
                ),
              ),
            ),
          ),
        ),
      );

      await t.tap(find.text('重置'));
      await t.pumpAndSettle();
      await t.tap(find.text('查看结果'));
      await t.pumpAndSettle();

      expect(applied, isNotNull);
      expect(applied!.filterState.keyword, '进击的巨人');
      expect(applied!.filterState.sort, 'heat');
      expect(applied!.filterState.tags, isEmpty);
      expect(applied!.filterState.weekdays, isEmpty);
      expect(applied!.notShowWatched, isFalse);
      expect(applied!.notShowAbandoned, isFalse);
      expect(t.takeException(), isNull);
    });

    testWidgets(
      'SearchPage applies initialNotShowWatched and initialNotShowAbandoned before submit',
      (t) async {
        final controller = _RecordingSearchController();

        await t.pumpWidget(
          MaterialApp(
            home: SearchPage(
              controller: controller,
              initialQuery: '芙莉莲 tag:奇幻',
              initialNotShowWatched: true,
              initialNotShowAbandoned: true,
            ),
          ),
        );
        await t.pump();

        expect(controller.notShowWatchedBangumis, isTrue);
        expect(controller.notShowAbandonedBangumis, isTrue);
        expect(controller.recordedQueries, ['芙莉莲 tag:奇幻']);
        expect(controller.watchedAtSubmit, [true]);
        expect(controller.abandonedAtSubmit, [true]);
        expect(t.takeException(), isNull);
      },
    );
  });
}

class _TestPaths extends PathProviderPlatform {
  _TestPaths(this.path);
  final String path;

  @override
  Future<String?> getApplicationSupportPath() async => path;
}

class _RecordingSearchController extends SearchPageController {
  _RecordingSearchController()
    : super(_NoopCollectRepository(), _NoopSearchHistoryRepository());

  final List<String> recordedQueries = <String>[];
  final List<bool> watchedAtSubmit = <bool>[];
  final List<bool> abandonedAtSubmit = <bool>[];

  @override
  Future<void> searchBangumi(String input, {String type = 'add'}) async {
    recordedQueries.add(input);
    watchedAtSubmit.add(notShowWatchedBangumis);
    abandonedAtSubmit.add(notShowAbandonedBangumis);
  }
}

class _NoopCollectRepository implements ICollectRepository {
  @override
  Set<int> getBangumiIdsByType(CollectType type) => const {};

  @override
  Set<int> getBangumiIdsByTypes(List<CollectType> types) => const {};

  @override
  bool getTimelineNotShowAbandonedBangumis() => false;

  @override
  Future<void> updateTimelineNotShowAbandonedBangumis(bool value) async {}

  @override
  bool getTimelineNotShowWatchedBangumis() => false;

  @override
  Future<void> updateTimelineNotShowWatchedBangumis(bool value) async {}

  @override
  bool getTimelineOnlyShowWatchingBangumis() => false;

  @override
  Future<void> updateTimelineOnlyShowWatchingBangumis(bool value) async {}

  @override
  bool getPrivateMode() => false;
}

class _NoopSearchHistoryRepository implements ISearchHistoryRepository {
  @override
  Future<void> clearAllHistories() async {}

  @override
  Future<void> deleteDuplicates(String keyword) async {}

  @override
  Future<void> deleteHistory(SearchHistory history) async {}

  @override
  Future<void> deleteOldest() async {}

  @override
  List<SearchHistory> getAllHistories() => const [];

  @override
  bool isHistoryFull(int maxCount) => false;

  @override
  Future<bool> saveHistory(String keyword) async => true;
}
