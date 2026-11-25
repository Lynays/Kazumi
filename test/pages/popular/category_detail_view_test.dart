import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/bean/card/bangumi_card.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/bangumi/bangumi_tag.dart';
import 'package:kazumi/pages/popular/category_controller.dart';
import 'package:kazumi/pages/popular/category_detail_view.dart';
import 'package:kazumi/pages/popular/popular_featured_card.dart';
import 'package:kazumi/pages/popular/popular_rank_mosaic.dart';
import 'package:kazumi/pages/popular/popular_showcase.dart';

void main() {
  group('CategoryDetailView', () {
    testWidgets(
      'renders Top 1-10 golden showcase + #11+ grid without duplicates, paginates past 70, and returns to overview',
      (t) async {
        t.view.physicalSize = const Size(1280, 720);
        t.view.devicePixelRatio = 1.0;
        addTearDown(t.view.reset);

        final requestedOffsets = <int>[];
        final controller = CategoryController(
          mirrorEnabledProvider: () => true,
          pageFetcher: ({
            required tag,
            required limit,
            required offset,
            required useMirror,
          }) async {
            requestedOffsets.add(offset);
            if (offset >= 96) {
              return const CategoryPageResult(
                items: <BangumiItem>[],
                rawCount: 0,
                failed: false,
              );
            }
            return CategoryPageResult(
              items: List.generate(limit, (i) => _item(offset + i + 1)),
              rawCount: limit,
              failed: false,
            );
          },
        );
        addTearDown(controller.dispose);
        controller.overviewScrollOffset = 420.0;
        controller.openCategoryDetail('奇幻');

        await t.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
            home: LayoutBuilder(
              builder: (_, constraints) => CategoryDetailView(
                controller: controller,
                tag: '奇幻',
                viewportWidth: constraints.maxWidth,
                viewportHeight: constraints.maxHeight,
              ),
            ),
          ),
        );
        await t.pump();
        await t.pump(const Duration(milliseconds: 50));

        // Zone A: TOP 1 featured card + TOP 2-10 rank mosaic inside PopularShowcaseStage,
        // matching homepage PopularDashboard height formula (no in-body breadcrumb deduction).
        final stage = t.widget<PopularShowcaseStage>(
          find.byType(PopularShowcaseStage),
        );
        expect(stage.showcaseHeight, closeTo((720.0 - 4.0 - 12.0) / 3.0, 0.01));
        expect(find.text('全部类别'), findsNothing);
        expect(find.byType(PopularFeaturedCard), findsOneWidget);
        expect(find.byType(PopularRankMosaic), findsOneWidget);
        expect(find.text('番剧 1'), findsWidgets);

        // Zone B: SliverGrid starts strictly at #11 (items[10]) with 6 columns at 1280px.
        final grid = t.widget<SliverGrid>(find.byType(SliverGrid));
        final delegate =
            grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
        expect(delegate.crossAxisCount, 6);

        final firstGridCard = t.widget<BangumiCardV>(
          find.byType(BangumiCardV).first,
        );
        expect(firstGridCard.bangumiItem.id, 11);
        expect(firstGridCard.coverWidth, isNotNull);
        expect(firstGridCard.coverHeight, isNotNull);

        // Scroll down repeatedly to load past 70 items (4 pages = 96 items).
        for (var i = 0; i < 8; i++) {
          await t.drag(find.byType(CustomScrollView), const Offset(0, -900));
          await t.pump();
          await t.pump(const Duration(milliseconds: 30));
        }

        expect(controller.feedFor('奇幻').items.length, 96);
        expect(controller.feedFor('奇幻').gridCount, 86);
        expect(requestedOffsets, containsAll([0, 24, 48, 72]));
        expect(find.byType(FloatingActionButton), findsOneWidget);

        // Tap back-to-top FAB cleanly.
        await t.tap(find.byType(FloatingActionButton));
        await t.pumpAndSettle();
        expect(controller.overviewScrollOffset, 420.0);
        expect(t.takeException(), isNull);
      },
    );

    testWidgets(
      'auto-fills next page on tall screens when initial 24 items do not fill viewport',
      (t) async {
        t.view.physicalSize = const Size(1440, 2200);
        t.view.devicePixelRatio = 1.0;
        addTearDown(t.view.reset);

        final requestedOffsets = <int>[];
        final controller = CategoryController(
          mirrorEnabledProvider: () => true,
          pageFetcher: ({
            required tag,
            required limit,
            required offset,
            required useMirror,
          }) async {
            requestedOffsets.add(offset);
            if (offset >= 72) {
              return const CategoryPageResult(
                items: <BangumiItem>[],
                rawCount: 0,
                failed: false,
              );
            }
            return CategoryPageResult(
              items: List.generate(limit, (i) => _item(offset + i + 1)),
              rawCount: limit,
              failed: false,
            );
          },
        );
        addTearDown(controller.dispose);
        controller.openCategoryDetail('日常');

        await t.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
            home: LayoutBuilder(
              builder: (_, constraints) => CategoryDetailView(
                controller: controller,
                tag: '日常',
                viewportWidth: constraints.maxWidth,
                viewportHeight: constraints.maxHeight,
              ),
            ),
          ),
        );
        await t.pump();
        await t.pump(const Duration(milliseconds: 50));
        await t.pump(const Duration(milliseconds: 50));

        // Initial 24 items (14 grid cards in 6 cols = 3 rows) leave <200px overflow
        // on a 1440x1400 viewport, so post-frame auto-fill pulls at least page 2.
        expect(requestedOffsets.length, greaterThanOrEqualTo(2));
        expect(controller.feedFor('日常').items.length, greaterThanOrEqualTo(48));
        expect(t.takeException(), isNull);
      },
    );
  });
}

BangumiItem _item(int id) => BangumiItem(
  id: id,
  type: 2,
  name: 'Anime $id',
  nameCn: '番剧 $id',
  summary: '测试简介 $id',
  airDate: '2026-01-01',
  airWeekday: 1,
  rank: id,
  images: const <String, String>{},
  tags: const <BangumiTag>[],
  alias: const <String>[],
  ratingScore: 8.8,
  votes: 100,
  votesCount: const <int>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
  info: '',
);
