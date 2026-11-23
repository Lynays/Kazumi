import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/search/search_history_module.dart';
import 'package:kazumi/pages/menu/cinema_search_bar.dart';
import 'package:kazumi/repositories/search_history_repository.dart';

void main() {
  group('computeCinemaSearchOverlayLayout', () {
    test('places secondary panel on the right when desktop space allows', () {
      final layout = computeCinemaSearchOverlayLayout(
        anchorRect: const Rect.fromLTWH(240, 12, 420, 40),
        viewport: const Size(1280, 800),
      );

      expect(layout.secondaryPlacement, CinemaSecondaryPlacement.right);
      expect(layout.secondaryRect.left, greaterThan(layout.primaryRect.right));
      expect(layout.secondaryRect.right, lessThanOrEqualTo(1268));
      expect(layout.secondaryRect.bottom, lessThanOrEqualTo(788));
    });

    test('falls back to left side when right side is tight on desktop', () {
      final layout = computeCinemaSearchOverlayLayout(
        anchorRect: const Rect.fromLTWH(640, 12, 360, 40),
        viewport: const Size(1080, 720),
      );

      expect(layout.secondaryPlacement, CinemaSecondaryPlacement.left);
      expect(layout.secondaryRect.right, lessThan(layout.primaryRect.left));
      expect(layout.secondaryRect.left, greaterThanOrEqualTo(12));
    });

    test('stacks secondary panel below on narrow portrait screens', () {
      final layout = computeCinemaSearchOverlayLayout(
        anchorRect: const Rect.fromLTWH(56, 12, 270, 40),
        viewport: const Size(390, 844),
      );

      expect(layout.secondaryPlacement, CinemaSecondaryPlacement.below);
      expect(layout.stackedLeft, greaterThanOrEqualTo(12));
      expect(layout.stackedLeft + layout.stackedWidth, lessThanOrEqualTo(378));
    });
  });

  group('CinemaSearchBar', () {
    testWidgets(
      'opens primary dropdown, manages recent histories, and submits on tap',
      (t) async {
        final repo = _FakeSearchHistoryRepository([
          SearchHistory('葬送的芙莉莲', 300),
          SearchHistory('tag:日常 sort:score', 200),
          SearchHistory('孤独摇滚', 100),
        ]);
        final submits = <CinemaSearchSubmit>[];

        await _pumpSearchBar(
          t,
          repo: repo,
          size: const Size(1280, 800),
          onSubmit: submits.add,
        );

        await t.tap(find.byType(TextField));
        await t.pumpAndSettle();

        expect(find.text('按条件查找'), findsOneWidget);
        expect(find.text('题材、放送时间与评分'), findsOneWidget);
        expect(find.text('最近搜索'), findsOneWidget);
        expect(find.text('葬送的芙莉莲'), findsOneWidget);
        expect(find.text('日常 · 评分排序'), findsOneWidget);

        // Manage -> delete single item.
        await t.tap(find.text('管理'));
        await t.pumpAndSettle();
        expect(find.text('完成'), findsOneWidget);
        expect(find.text('清空'), findsOneWidget);

        await t.tap(find.byTooltip('删除这条搜索记录').first);
        await t.pumpAndSettle();
        expect(find.text('葬送的芙莉莲'), findsNothing);
        expect(repo.histories.length, 2);

        // Done exits manage mode; tapping a history submits and closes overlay.
        await t.tap(find.text('完成'));
        await t.pumpAndSettle();
        await t.tap(find.text('孤独摇滚'));
        await t.pumpAndSettle();

        expect(submits.length, 1);
        expect(submits.single.query, '孤独摇滚');
        expect(find.text('按条件查找'), findsNothing);

        // Reopen and clear all histories.
        await t.tap(find.byType(TextField));
        await t.pumpAndSettle();
        await t.tap(find.text('管理'));
        await t.pumpAndSettle();
        await t.tap(find.text('清空'));
        await t.pumpAndSettle();
        expect(repo.histories, isEmpty);
        expect(find.text('最近搜索'), findsNothing);
        expect(t.takeException(), isNull);
      },
    );

    testWidgets(
      'opens secondary filter panel beside primary on desktop, handles Esc hierarchy, and forwards filter result',
      (t) async {
        final repo = _FakeSearchHistoryRepository([
          SearchHistory('进击的巨人', 100),
        ]);
        final submits = <CinemaSearchSubmit>[];

        await _pumpSearchBar(
          t,
          repo: repo,
          size: const Size(1280, 800),
          onSubmit: submits.add,
        );

        await t.tap(find.byType(TextField));
        await t.pumpAndSettle();
        await t.tap(find.text('按条件查找'));
        await t.pumpAndSettle();

        final primaryRect = t.getRect(
          find.byKey(const ValueKey('cinema-search-primary-panel')),
        );
        final secondaryRect = t.getRect(
          find.byKey(const ValueKey('cinema-search-secondary-panel')),
        );
        expect(secondaryRect.left, greaterThan(primaryRect.right));
        expect(secondaryRect.right, lessThanOrEqualTo(1280));
        expect(secondaryRect.bottom, lessThanOrEqualTo(800));

        // Esc closes secondary first, leaving primary open.
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('cinema-search-secondary-panel')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('cinema-search-primary-panel')),
          findsOneWidget,
        );

        // Reopen secondary, pick tag + hideWatched, and submit.
        await t.tap(find.text('按条件查找'));
        await t.pumpAndSettle();
        await t.tap(find.text('题材标签'));
        await t.pumpAndSettle();
        await t.tap(find.widgetWithText(FilterChip, '奇幻'));
        await t.pumpAndSettle();

        await t.dragUntilVisible(
          find.text('收藏状态'),
          find.descendant(
            of: find.byKey(const ValueKey('cinema-search-secondary-panel')),
            matching: find.byType(ListView),
          ),
          const Offset(0, -180),
        );
        await t.tap(find.text('收藏状态'));
        await t.pumpAndSettle();
        await t.ensureVisible(find.text('隐藏看过的番剧'));
        await t.pumpAndSettle();
        await t.tap(find.text('隐藏看过的番剧'));
        await t.pumpAndSettle();

        await t.tap(find.text('查看结果'));
        await t.pumpAndSettle();

        expect(submits.length, 1);
        expect(submits.single.query, 'tag:奇幻');
        expect(submits.single.hideWatched, isTrue);
        expect(submits.single.hideAbandoned, isFalse);
        expect(
          find.byKey(const ValueKey('cinema-search-primary-panel')),
          findsNothing,
        );
        expect(t.takeException(), isNull);
      },
    );

    testWidgets(
      'stacks secondary filter panel below primary without overflow on narrow screen',
      (t) async {
        final repo = _FakeSearchHistoryRepository([
          SearchHistory('药屋少女的呢喃', 100),
        ]);

        await _pumpSearchBar(
          t,
          repo: repo,
          size: const Size(390, 760),
          alignment: Alignment.topCenter,
          barWidth: 280,
          onSubmit: (_) {},
        );

        await t.tap(find.byType(TextField));
        await t.pumpAndSettle();
        await t.tap(find.text('按条件查找'));
        await t.pumpAndSettle();

        final primaryRect = t.getRect(
          find.byKey(const ValueKey('cinema-search-primary-panel')),
        );
        final secondaryRect = t.getRect(
          find.byKey(const ValueKey('cinema-search-secondary-panel')),
        );
        expect(secondaryRect.top, greaterThanOrEqualTo(primaryRect.bottom));
        expect(secondaryRect.right, lessThanOrEqualTo(390));
        expect(secondaryRect.bottom, lessThanOrEqualTo(760));

        // Tapping outside dismisses both panels.
        await t.tapAt(const Offset(4, 750));
        await t.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('cinema-search-primary-panel')),
          findsNothing,
        );
        expect(t.takeException(), isNull);
      },
    );

    testWidgets('supports image search callback and closes dropdown cleanly', (
      t,
    ) async {
      final repo = _FakeSearchHistoryRepository(const []);
      final submits = <CinemaSearchSubmit>[];
      var imageSearchCalls = 0;

      await _pumpSearchBar(
        t,
        repo: repo,
        size: const Size(1024, 700),
        onSubmit: submits.add,
        onImageSearch: () async {
          imageSearchCalls++;
          return '魔法少女小圆';
        },
      );

      await t.tap(find.byTooltip('以图搜番'));
      await t.pumpAndSettle();

      expect(imageSearchCalls, 1);
      expect(submits.length, 1);
      expect(submits.single.query, '魔法少女小圆');
      expect(t.takeException(), isNull);
    });
  });
}

Future<void> _pumpSearchBar(
  WidgetTester t, {
  required ISearchHistoryRepository repo,
  required Size size,
  required ValueChanged<CinemaSearchSubmit> onSubmit,
  Future<String?> Function()? onImageSearch,
  Alignment alignment = Alignment.topLeft,
  double barWidth = 420,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);

  await t.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.only(top: 12, left: 24, right: 24),
          child: Align(
            alignment: alignment,
            child: SizedBox(
              width: barWidth,
              child: CinemaSearchBar(
                historyRepository: repo,
                onSubmit: onSubmit,
                onImageSearch: onImageSearch ?? () async => null,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

class _FakeSearchHistoryRepository implements ISearchHistoryRepository {
  _FakeSearchHistoryRepository(List<SearchHistory> initial)
    : histories = List<SearchHistory>.from(initial);

  final List<SearchHistory> histories;

  @override
  List<SearchHistory> getAllHistories() => List<SearchHistory>.from(histories);

  @override
  Future<void> clearAllHistories() async => histories.clear();

  @override
  Future<void> deleteDuplicates(String keyword) async =>
      histories.removeWhere((h) => h.keyword == keyword);

  @override
  Future<void> deleteHistory(SearchHistory history) async =>
      histories.removeWhere((h) => h.key == history.key);

  @override
  Future<void> deleteOldest() async {
    if (histories.isNotEmpty) histories.removeLast();
  }

  @override
  bool isHistoryFull(int maxCount) => histories.length >= maxCount;

  @override
  Future<bool> saveHistory(String keyword) async {
    histories.insert(
      0,
      SearchHistory(keyword, DateTime.now().millisecondsSinceEpoch),
    );
    return true;
  }
}
