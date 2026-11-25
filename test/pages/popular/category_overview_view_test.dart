import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/bean/widget/window_resize_scope.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/bangumi/bangumi_tag.dart';
import 'package:kazumi/pages/menu/route_visibility.dart';
import 'package:kazumi/pages/popular/category_controller.dart';
import 'package:kazumi/pages/popular/category_overview_view.dart';
import 'package:kazumi/pages/popular/popular_carousel_floor.dart';
import 'package:kazumi/pages/popular/popular_carousel_strip.dart';
import 'package:kazumi/utils/constants.dart';

void main() {
  group('CategoryOverviewView', () {
    testWidgets(
      'virtualizes 15 defaultAnimeTags rows, opens detail on label tap, and pauses cruise on resize/cover',
      (t) async {
        t.view.physicalSize = const Size(1280, 720);
        t.view.devicePixelRatio = 1.0;
        addTearDown(t.view.reset);

        final controller = CategoryController(
          tags: defaultAnimeTags,
          mirrorEnabledProvider: () => true,
          pageFetcher: ({
            required tag,
            required limit,
            required offset,
            required useMirror,
          }) async {
            final base = defaultAnimeTags.indexOf(tag) * 100;
            return CategoryPageResult(
              items: List.generate(18, (i) => _item(base + i + 1, tag)),
              rawCount: 18,
              failed: false,
            );
          },
        );
        addTearDown(controller.dispose);
        controller.openCategoryOverview();

        Widget buildHost({required bool covered}) => WindowResizeScope(
          child: MaterialApp(
            theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
            home: RouteVisibility(
              isCovered: covered,
              child: Scaffold(
                body: LayoutBuilder(
                  builder: (_, constraints) => CategoryOverviewView(
                    controller: controller,
                    viewportHeight: constraints.maxHeight,
                  ),
                ),
              ),
            ),
          ),
        );

        await t.pumpWidget(buildHost(covered: false));
        await t.pump();
        await t.pump(const Duration(milliseconds: 50));

        // Single viewport-fixed floor glow wraps the vertical scroll view.
        expect(find.byType(PopularCarouselFloor), findsOneWidget);

        // SliverFixedExtentList must virtualize the 15 rows (never mount all 15).
        final mountedStrips = find.byType(PopularCarouselStrip).evaluate().length;
        expect(mountedStrips, greaterThanOrEqualTo(3));
        expect(mountedStrips, lessThan(defaultAnimeTags.length));

        expect(find.text('日常'), findsOneWidget);
        expect(find.text('原创'), findsOneWidget);

        // Visible row cruises automatically with the single Ticker.
        final firstStrip = t.widget<PopularCarouselStrip>(
          find.byType(PopularCarouselStrip).first,
        );
        await t.pump(const Duration(milliseconds: 80));
        await t.pump(const Duration(milliseconds: 80));
        final scrolled = firstStrip.controller.offset;
        expect(scrolled, greaterThan(0));

        // Window resize pauses cruise cleanly.
        t.view.physicalSize = const Size(1340, 720);
        await t.pump(const Duration(milliseconds: 50));
        final duringResize = firstStrip.controller.offset;
        await t.pump(const Duration(milliseconds: 60));
        expect(firstStrip.controller.offset, duringResize);

        // Route coverage also pauses cruise.
        await t.pumpWidget(buildHost(covered: true));
        await t.pump(const Duration(milliseconds: 200));
        final whileCovered = firstStrip.controller.offset;
        await t.pump(const Duration(milliseconds: 100));
        expect(firstStrip.controller.offset, whileCovered);

        // Restore uncovered state and tap the top-left category label -> enters detail.
        await t.pumpWidget(buildHost(covered: false));
        await t.pump(const Duration(milliseconds: 200));
        await t.tap(find.text('日常'));
        await t.pump();
        expect(controller.mode, PopularBrowseMode.categoryDetail);
        expect(controller.activeTag, '日常');
        expect(t.takeException(), isNull);
      },
    );

    testWidgets('shows per-row retry button when a row fails and recovers on tap', (
      t,
    ) async {
      t.view.physicalSize = const Size(1280, 720);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);

      var failFirst = true;
      final controller = CategoryController(
        tags: const ['日常', '原创'],
        mirrorEnabledProvider: () => true,
        pageFetcher: ({
          required tag,
          required limit,
          required offset,
          required useMirror,
        }) async {
          if (tag == '日常' && failFirst) {
            return const CategoryPageResult(
              items: <BangumiItem>[],
              rawCount: 0,
              failed: true,
            );
          }
          return CategoryPageResult(
            items: List.generate(12, (i) => _item(i + 1, tag)),
            rawCount: 12,
            failed: false,
          );
        },
      );
      addTearDown(controller.dispose);
      controller.openCategoryOverview();

      await t.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
          home: Scaffold(
            body: CategoryOverviewView(
              controller: controller,
              viewportHeight: 720,
            ),
          ),
        ),
      );
      await t.pump();
      await t.pump(const Duration(milliseconds: 50));

      expect(find.text('重试'), findsOneWidget);
      failFirst = false;
      await t.tap(find.text('重试'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 50));

      expect(find.text('重试'), findsNothing);
      expect(controller.feedFor('日常').items.length, 12);
      expect(t.takeException(), isNull);
    });

    testWidgets(
      'fast vertical scroll unmounting queued rows does not trigger locked-tree setState',
      (t) async {
        t.view.physicalSize = const Size(1280, 640);
        t.view.devicePixelRatio = 1.0;
        addTearDown(t.view.reset);

        final gates = <String, Completer<CategoryPageResult>>{};
        final controller = CategoryController(
          tags: defaultAnimeTags,
          maxConcurrentRowLoads: 2,
          mirrorEnabledProvider: () => true,
          pageFetcher: ({
            required tag,
            required limit,
            required offset,
            required useMirror,
          }) {
            return gates
                .putIfAbsent(tag, Completer<CategoryPageResult>.new)
                .future;
          },
        );
        addTearDown(() {
          for (final gate in gates.values) {
            if (!gate.isCompleted) {
              gate.complete(
                const CategoryPageResult(
                  items: <BangumiItem>[],
                  rawCount: 0,
                  failed: false,
                ),
              );
            }
          }
          controller.dispose();
        });
        controller.openCategoryOverview();

        await t.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
            home: ListenableBuilder(
              listenable: controller,
              builder: (_, _) => Scaffold(
                body: CategoryOverviewView(
                  controller: controller,
                  viewportHeight: 640,
                ),
              ),
            ),
          ),
        );
        await t.pump();
        await t.pump(const Duration(milliseconds: 20));

        // First 2 rows saturate maxConcurrentRowLoads=2; rows 3..4 are queued
        // with isLoading=true. Scroll rapidly to bottom so queued rows unmount
        // during finalizeTree and invoke cancelPendingRowLoad().
        final scrollFinder = find.byKey(
          const ValueKey('category-overview-scroll'),
        );
        for (var i = 0; i < 6; i++) {
          await t.drag(scrollFinder, const Offset(0, -600));
          await t.pump();
        }
        await t.pump(const Duration(milliseconds: 50));

        expect(t.takeException(), isNull);
      },
    );

    testWidgets(
      'disposing or covering a row mid-fade-out reset does not notify ValueListenableBuilder while tree is locked',
      (t) async {
        t.view.physicalSize = const Size(1280, 640);
        t.view.devicePixelRatio = 1.0;
        addTearDown(t.view.reset);

        final controller = CategoryController(
          tags: const ['日常'],
          mirrorEnabledProvider: () => true,
          pageFetcher: ({
            required tag,
            required limit,
            required offset,
            required useMirror,
          }) async {
            return CategoryPageResult(
              items: List.generate(18, (i) => _item(i + 1, tag)),
              rawCount: 18,
              failed: false,
            );
          },
        );
        addTearDown(controller.dispose);
        controller.openCategoryOverview();

        Widget buildHost({required bool showOverview, required bool covered}) =>
            MaterialApp(
              theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
              home: RouteVisibility(
                isCovered: covered,
                child: Scaffold(
                  body: showOverview
                      ? CategoryOverviewView(
                          controller: controller,
                          viewportHeight: 640,
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            );

        await t.pumpWidget(buildHost(showOverview: true, covered: false));
        await t.pump();
        await t.pump(const Duration(milliseconds: 50));

        // Jump the single visible row right to the end so the next tick starts
        // the 180ms fade-out reset (opacity -> 0.0).
        final strip = t.widget<PopularCarouselStrip>(
          find.byType(PopularCarouselStrip).first,
        );
        strip.controller.jumpTo(strip.controller.position.maxScrollExtent - 0.1);
        await t.pump(const Duration(milliseconds: 30));
        await t.pump(const Duration(milliseconds: 30));

        final fadingOpacity = t.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity).first,
        );
        expect(fadingOpacity.opacity, 0.0);

        // Cover route during build/didChangeDependencies while opacity is 0.0.
        await t.pumpWidget(buildHost(showOverview: true, covered: true));
        await t.pump();
        expect(t.takeException(), isNull);
        expect(
          t.widget<AnimatedOpacity>(find.byType(AnimatedOpacity).first).opacity,
          1.0,
        );

        // Trigger another fade-out reset, then unmount the whole view during
        // finalizeTree while opacity is still 0.0.
        await t.pumpWidget(buildHost(showOverview: true, covered: false));
        await t.pump();
        await t.pump(const Duration(milliseconds: 50));
        final strip2 = t.widget<PopularCarouselStrip>(
          find.byType(PopularCarouselStrip).first,
        );
        strip2.controller.jumpTo(
          strip2.controller.position.maxScrollExtent - 0.1,
        );
        await t.pump(const Duration(milliseconds: 30));
        await t.pump(const Duration(milliseconds: 30));
        expect(
          t.widget<AnimatedOpacity>(find.byType(AnimatedOpacity).first).opacity,
          0.0,
        );

        await t.pumpWidget(buildHost(showOverview: false, covered: false));
        await t.pump();
        expect(t.takeException(), isNull);
      },
    );
  });
}

BangumiItem _item(int id, String tag) => BangumiItem(
  id: id,
  type: 2,
  name: '$tag $id',
  nameCn: '$tag番剧 $id',
  summary: '测试简介 $id',
  airDate: '2026-01-01',
  airWeekday: 1,
  rank: id,
  images: const <String, String>{},
  tags: const <BangumiTag>[],
  alias: const <String>[],
  ratingScore: 8.6,
  votes: 100,
  votesCount: const <int>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
  info: '',
);
