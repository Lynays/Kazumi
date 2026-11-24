import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:kazumi/bean/widget/media_query_size_selector.dart';
import 'package:kazumi/bean/widget/window_resize_scope.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/bangumi/bangumi_tag.dart';
import 'package:kazumi/modules/collect/collect_layout.dart';
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:kazumi/pages/collect/collect_library_view.dart';
import 'package:kazumi/pages/info/info_tabview.dart';
import 'package:kazumi/pages/menu/route_visibility.dart';
import 'package:kazumi/pages/popular/popular_carousel_region.dart';
import 'package:kazumi/pages/popular/popular_controller.dart';
import 'package:kazumi/pages/popular/popular_featured_card.dart';
import 'package:kazumi/pages/popular/popular_floor_reflection.dart';
import 'package:kazumi/pages/popular/popular_page.dart';
import 'package:kazumi/utils/image_extension.dart';

void main() {
  group('P0: Image cache quantization & placeholder reuse', () {
    testWidgets('cacheSize quantizes upward to bucket and ignores MediaQuery.size', (
      t,
    ) async {
      var buildCount = 0;
      late int bucketA;
      late int bucketB;
      late int bucketZero;
      late int bucketInf;

      Widget buildApp(Size size, double dpr) => MediaQuery(
        data: MediaQueryData(size: size, devicePixelRatio: dpr),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              buildCount++;
              bucketA = 100.cacheSize(context);
              bucketB = 105.cacheSize(context);
              bucketZero = 0.cacheSize(context);
              bucketInf = double.infinity.cacheSize(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      await t.pumpWidget(buildApp(const Size(1280, 800), 1.0));
      expect(buildCount, 1);
      expect(bucketA, 128);
      expect(bucketB, 128);
      expect(bucketZero, 64);
      expect(bucketInf, 64);

      // Resizing the window without changing DPR must not trigger rebuilds
      // through cacheSize.
      await t.pumpWidget(buildApp(const Size(1400, 900), 1.0));
      // Parent widget rebuilt Builder directly, so test isolation via Stateful child.
      var isolatedBuilds = 0;
      final child = _CacheSizeProbe(onBuild: () => isolatedBuilds++);
      await t.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(1000, 700), devicePixelRatio: 1.5),
          child: Directionality(textDirection: TextDirection.ltr, child: child),
        ),
      );
      expect(isolatedBuilds, 1);

      await t.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(1200, 720), devicePixelRatio: 1.5),
          child: Directionality(textDirection: TextDirection.ltr, child: child),
        ),
      );
      expect(isolatedBuilds, 1);

      await t.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(1200, 720), devicePixelRatio: 2.0),
          child: Directionality(textDirection: TextDirection.ltr, child: child),
        ),
      );
      expect(isolatedBuilds, 2);
    });

    testWidgets('NetworkImgLayer placeholder uses fixed cacheWidth 160', (
      t,
    ) async {
      await t.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                NetworkImgLayer(src: '', width: 111, height: 167),
                NetworkImgLayer(src: '', width: 223, height: 311),
              ],
            ),
          ),
        ),
      );

      final images = t.widgetList<Image>(find.byType(Image)).toList();
      expect(images, hasLength(2));
      for (final img in images) {
        final provider = img.image;
        expect(provider, isA<ResizeImage>());
        final resized = provider as ResizeImage;
        expect(resized.width, 160);
        expect(resized.height, isNull);
      }
    });

    testWidgets(
      'NetworkImgLayer defaults to FilterQuality.medium and skips ClipRRect for zero radius',
      (t) async {
        const layer = NetworkImgLayer(
          src: 'https://example.com/poster.jpg',
          width: 120,
          height: 180,
          borderRadius: BorderRadius.zero,
        );
        expect(layer.filterQuality, FilterQuality.medium);

        await t.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(child: layer),
            ),
          ),
        );
        expect(
          find.descendant(
            of: find.byType(NetworkImgLayer),
            matching: find.byType(ClipRRect),
          ),
          findsNothing,
        );
      },
    );
  });

  group('P0: FreezeLayoutWhenCovered', () {
    testWidgets(
      'blocks MediaQuery and layout updates while covered and resumes when uncovered',
      (t) async {
        t.view.physicalSize = const Size(1600, 1000);
        t.view.devicePixelRatio = 1.0;
        addTearDown(t.view.reset);

        var mediaQueryBuilds = 0;
        var layoutBuilds = 0;
        Size? seenMediaSize;
        BoxConstraints? seenConstraints;

        final subtree = _ResizeObserverSubtree(
          onMediaBuild: (size) {
            mediaQueryBuilds++;
            seenMediaSize = size;
          },
          onLayoutBuild: (constraints) {
            layoutBuilds++;
            seenConstraints = constraints;
          },
        );

        Widget buildHost({required Size size, required bool isCovered}) =>
            MediaQuery(
              data: MediaQueryData(size: size, devicePixelRatio: 1.0),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox.fromSize(
                    size: size,
                    child: FreezeLayoutWhenCovered(
                      isCovered: isCovered,
                      child: subtree,
                    ),
                  ),
                ),
              ),
            );

        await t.pumpWidget(buildHost(size: const Size(1000, 700), isCovered: false));
        expect(mediaQueryBuilds, 1);
        expect(layoutBuilds, 1);
        expect(seenMediaSize, const Size(1000, 700));
        expect(seenConstraints?.biggest, const Size(1000, 700));

        // Cover route, then resize window several times.
        await t.pumpWidget(buildHost(size: const Size(1000, 700), isCovered: true));
        final buildsWhenCovered = mediaQueryBuilds;
        final layoutsWhenCovered = layoutBuilds;

        for (final nextSize in const [
          Size(1020, 705),
          Size(1100, 740),
          Size(1280, 820),
        ]) {
          await t.pumpWidget(buildHost(size: nextSize, isCovered: true));
        }
        expect(mediaQueryBuilds, buildsWhenCovered);
        expect(layoutBuilds, layoutsWhenCovered);
        expect(seenMediaSize, const Size(1000, 700));
        expect(seenConstraints?.biggest, const Size(1000, 700));
        expect(t.takeException(), isNull);

        // Uncover route -> immediately receives new MediaQuery & constraints.
        await t.pumpWidget(buildHost(size: const Size(1280, 820), isCovered: false));
        expect(seenMediaSize, const Size(1280, 820));
        expect(seenConstraints?.biggest, const Size(1280, 820));
        expect(t.takeException(), isNull);
      },
    );

    testWidgets(
      'freezes via TickerMode when an opaque PageRoute is pushed over a ModalBottomSheetRoute',
      (t) async {
        t.view.physicalSize = const Size(1000, 700);
        t.view.devicePixelRatio = 1.0;
        addTearDown(t.view.reset);

        var mediaQueryBuilds = 0;
        var layoutBuilds = 0;
        Size? seenMediaSize;
        BoxConstraints? seenConstraints;
        final navKey = GlobalKey<NavigatorState>();

        await t.pumpWidget(
          MaterialApp(
            navigatorKey: navKey,
            home: FreezeLayoutWhenCovered(
              // Simulate RouteObserver<PageRoute<void>> missing didPushNext
              // when a PopupRoute sits between two PageRoutes.
              isCovered: false,
              child: _ResizeObserverSubtree(
                onMediaBuild: (size) {
                  mediaQueryBuilds++;
                  seenMediaSize = size;
                },
                onLayoutBuild: (constraints) {
                  layoutBuilds++;
                  seenConstraints = constraints;
                },
              ),
            ),
          ),
        );
        expect(seenMediaSize, const Size(1000, 700));
        expect(seenConstraints?.biggest, const Size(1000, 700));

        // 1. Open translucent ModalBottomSheetRoute (PopupRoute) -> underlying
        // page stays visible and still updates when window resizes.
        showModalBottomSheet<void>(
          context: navKey.currentContext!,
          builder: (_) => const SizedBox(height: 200, child: Text('sheet')),
        );
        await t.pumpAndSettle();
        t.view.physicalSize = const Size(1060, 720);
        await t.pumpAndSettle();
        expect(seenMediaSize, const Size(1060, 720));
        expect(seenConstraints?.biggest, const Size(1060, 720));

        // 2. Push opaque PageRoute directly on top of the open bottom sheet.
        navKey.currentState!.push(
          MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('video'))),
        );
        await t.pumpAndSettle();

        final buildsUnderVideo = mediaQueryBuilds;
        final layoutsUnderVideo = layoutBuilds;

        for (final nextSize in const [
          Size(1120, 740),
          Size(1240, 800),
          Size(1360, 860),
        ]) {
          t.view.physicalSize = nextSize;
          await t.pump();
        }
        expect(mediaQueryBuilds, buildsUnderVideo);
        expect(layoutBuilds, layoutsUnderVideo);
        expect(seenMediaSize, const Size(1060, 720));
        expect(seenConstraints?.biggest, const Size(1060, 720));

        // 3. Pop opaque PageRoute back to the sheet -> underlying page unfreezes.
        navKey.currentState!.pop();
        await t.pumpAndSettle();
        expect(seenMediaSize, const Size(1360, 860));
        expect(seenConstraints?.biggest, const Size(1360, 860));
        expect(t.takeException(), isNull);
      },
    );
  });

  group('P1/P2: MediaQuerySizeSelector', () {
    testWidgets(
      'rebuilds only when selected breakpoint flips or parent/theme changes',
      (t) async {
        var builderRuns = 0;
        bool? lastCompact;

        final selector = MediaQuerySizeSelector<bool>(
          select: (size) => size.width < 600,
          builder: (context, compact, _) {
            builderRuns++;
            lastCompact = compact;
            return Text(compact ? 'compact' : 'wide');
          },
        );

        Widget buildHost(Size size) => MediaQuery(
          data: MediaQueryData(size: size, devicePixelRatio: 1.0),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: selector,
          ),
        );

        await t.pumpWidget(buildHost(const Size(1000, 800)));
        expect(builderRuns, 1);
        expect(lastCompact, isFalse);

        for (final w in const [1020.0, 1150.0, 750.0, 600.0]) {
          await t.pumpWidget(buildHost(Size(w, 800)));
        }
        expect(builderRuns, 1);

        // Cross breakpoint -> triggers exactly 1 rebuild.
        await t.pumpWidget(buildHost(const Size(599, 800)));
        expect(builderRuns, 2);
        expect(lastCompact, isTrue);

        // Stay below breakpoint -> no rebuilds.
        await t.pumpWidget(buildHost(const Size(420, 800)));
        expect(builderRuns, 2);
      },
    );
  });

  group('P1: PopularPage optimizations', () {
    test('PopularController.popularSections caches result until trendList mutates', () {
      final controller = PopularController();
      controller.trendList.addAll(List.generate(15, (i) => _item(i + 1)));

      final first = controller.popularSections;
      final second = controller.popularSections;
      expect(identical(first, second), isTrue);
      expect(first.featured?.id, 1);
      expect(first.mosaic.length, 9);
      expect(first.rows.first.length, 5);

      controller.trendList.add(_item(16));
      final third = controller.popularSections;
      expect(identical(first, third), isFalse);
      expect(third.rows.first.length, 6);
    });

    testWidgets(
      'PopularFloorReflection suspends offscreen ShaderMask during active window resize and restores after debounce',
      (t) async {
        t.view.physicalSize = const Size(800, 600);
        t.view.devicePixelRatio = 1.0;
        addTearDown(t.view.reset);

        await t.pumpWidget(
          const WindowResizeScope(
            child: MaterialApp(
              home: Scaffold(
                body: PopularFloorReflection(
                  cover: 'https://example.com/poster.jpg',
                  size: Size(120, 160),
                  depth: 24,
                ),
              ),
            ),
          ),
        );
        expect(find.byType(ShaderMask), findsOneWidget);
        expect(find.byType(ImageFiltered), findsNothing);

        // Start resizing window -> reflection temporarily suspends offscreen mask.
        t.view.physicalSize = const Size(840, 600);
        await t.pump();
        expect(find.byType(ShaderMask), findsNothing);
        expect(
          t.getSize(find.byType(PopularFloorReflection)),
          const Size(120, 24),
        );

        // After 150ms debounce elapses -> transparent reflection restores.
        await t.pump(const Duration(milliseconds: 160));
        expect(find.byType(ShaderMask), findsOneWidget);
      },
    );

    testWidgets('PopularFeaturedCard avoids ShaderMask and dynamic RepaintBoundary', (
      t,
    ) async {
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 640,
              height: 260,
              child: PopularFeaturedCard(item: _item(1)),
            ),
          ),
        ),
      );
      expect(find.byType(ShaderMask), findsNothing);
      expect(
        find.descendant(
          of: find.byType(PopularFeaturedCard),
          matching: find.byType(RepaintBoundary),
        ),
        findsNothing,
      );
      expect(t.takeException(), isNull);
    });

    testWidgets(
      'PopularPage contentGrid uses LayoutBuilder width instead of MediaQuery.sizeOf',
      (t) async {
        t.view.physicalSize = const Size(1280, 800);
        t.view.devicePixelRatio = 1.0;
        addTearDown(t.view.reset);

        final controller = _StubPopularController()
          ..setCurrentTag('日常')
          ..bangumiList.addAll(List.generate(6, (i) => _item(i + 1)));

        await t.pumpWidget(
          MaterialApp(
            home: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 500,
                height: 700,
                child: PopularPage(controller: controller),
              ),
            ),
          ),
        );
        await t.pump();

        final grid = t.widget<SliverGrid>(find.byType(SliverGrid));
        final delegate =
            grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
        // Content width is 500 (<= 600 compact breakpoint), so 3 columns even
        // though the outer window MediaQuery width is 1280 (> 840 medium).
        expect(delegate.crossAxisCount, 3);
        expect(delegate.mainAxisExtent, closeTo(500 / 3 / 0.65 + 32.0, 0.5));
        expect(t.takeException(), isNull);
      },
    );

    testWidgets(
      'PopularCarouselRegion pauses during window resize and when covered',
      (t) async {
        t.view.physicalSize = const Size(640, 560);
        t.view.devicePixelRatio = 1.0;
        addTearDown(t.view.reset);

        final rows = List.generate(
          3,
          (r) => List.generate(16, (i) => _item(r * 20 + i + 11)),
        );

        Widget buildHost({required bool covered}) => MaterialApp(
          home: RouteVisibility(
            isCovered: covered,
            child: Scaffold(
              body: SizedBox(
                width: 480,
                height: 500,
                child: PopularCarouselRegion(rows: rows),
              ),
            ),
          ),
        );

        await t.pumpWidget(buildHost(covered: false));
        await t.pump();
        final c0 = t.widget<ListView>(find.byType(ListView).first).controller!;
        await t.pump(const Duration(milliseconds: 50));
        await t.pump(const Duration(milliseconds: 50));
        final beforeResize = c0.offset;
        expect(beforeResize, greaterThan(0));

        // Simulate window resize -> auto-scroll pauses during debounce window.
        t.view.physicalSize = const Size(700, 560);
        await t.pump(const Duration(milliseconds: 50));
        await t.pump(const Duration(milliseconds: 50));
        expect(c0.offset, beforeResize);

        // After 150ms debounce elapses, auto-scroll resumes.
        await t.pump(const Duration(milliseconds: 100));
        await t.pump();
        await t.pump(const Duration(milliseconds: 50));
        await t.pump(const Duration(milliseconds: 50));
        expect(c0.offset, greaterThan(beforeResize));

        // Covered route stops auto-scroll and ignores metrics updates.
        await t.pumpWidget(buildHost(covered: true));
        await t.pump();
        final whileCovered = c0.offset;
        t.view.physicalSize = const Size(760, 560);
        await t.pump(const Duration(milliseconds: 250));
        expect(c0.offset, whileCovered);
        expect(t.takeException(), isNull);
      },
    );
  });

  group('P2: CollectLibraryView list mode avoids IntrinsicHeight', () {
    testWidgets('uses SliverGrid without IntrinsicHeight in multi-column list mode', (
      t,
    ) async {
      final entries = List.generate(
        6,
        (i) => CollectedBangumi(_item(i + 1), DateTime(2026, 1, i + 1), 1),
      );

      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1200,
              height: 800,
              child: CollectLibraryView(
                entries: entries,
                showRating: true,
                onOpen: (_) {},
                onChangeType: (_, _) {},
                canEdit: (_) => true,
                layout: CollectLayout.list,
                onLayoutChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();

      expect(find.byType(SliverGrid), findsOneWidget);
      expect(find.byType(IntrinsicHeight), findsNothing);
      expect(t.takeException(), isNull);
    });
  });

  group('P1: InfoPage tab layout optimizations', () {
    testWidgets('InfoTabView constrains width via ConstrainedBox across resizes', (
      t,
    ) async {
      t.view.physicalSize = const Size(1400, 800);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);

      final longItem = BangumiItem(
        id: 1,
        type: 2,
        name: 'Long Anime',
        nameCn: '测试长简介番剧',
        summary: List.filled(20, '这是一段用于测试多行折叠简介与宽度约束的文本。').join('\n'),
        airDate: '2026-01-01',
        airWeekday: 1,
        rank: 1,
        images: const <String, String>{},
        tags: const <BangumiTag>[],
        alias: const <String>[],
        ratingScore: 8.6,
        votes: 100,
        votesCount: const <int>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
        info: '',
      );

      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DefaultTabController(
              length: 5,
              child: Builder(
                builder: (context) {
                  final tabController = DefaultTabController.of(context);
                  return NestedScrollView(
                    headerSliverBuilder: (context, _) => [
                      SliverOverlapAbsorber(
                        handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                          context,
                        ),
                        sliver: const SliverToBoxAdapter(
                          child: SizedBox(height: 10),
                        ),
                      ),
                    ],
                    body: InfoTabView(
                      commentsQueryTimeout: false,
                      commentsHasLoaded: true,
                      charactersQueryTimeout: false,
                      charactersIsEmpty: true,
                      staffQueryTimeout: false,
                      staffIsEmpty: true,
                      relationsQueryTimeout: false,
                      relationsIsLoading: false,
                      relationsHasLoaded: true,
                      tabController: tabController,
                      loadMoreComments: ({bool loadMore = false}) async {},
                      loadCharacters: () async {},
                      loadStaff: () async {},
                      loadRelations: () async {},
                      bangumiItem: longItem,
                      commentsList: const [],
                      commentsIsLoading: false,
                      onWriteReview: () {},
                      characterList: const [],
                      staffList: const [],
                      relationList: const [],
                      isLoading: false,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('加载更多'), findsOneWidget);
      final selectableRectWide = t.getRect(find.byType(SelectableText));
      expect(selectableRectWide.width, closeTo(950.0, 0.5));

      // Shrink window below 982px -> adapts cleanly without overflow.
      t.view.physicalSize = const Size(500, 800);
      await t.pumpAndSettle();
      final selectableRectNarrow = t.getRect(find.byType(SelectableText));
      expect(selectableRectNarrow.width, closeTo(468.0, 0.5));
      expect(t.takeException(), isNull);
    });
  });
}

class _CacheSizeProbe extends StatelessWidget {
  const _CacheSizeProbe({required this.onBuild});

  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    onBuild();
    120.cacheSize(context);
    return const SizedBox.shrink();
  }
}

class _ResizeObserverSubtree extends StatelessWidget {
  const _ResizeObserverSubtree({
    required this.onMediaBuild,
    required this.onLayoutBuild,
  });

  final ValueChanged<Size> onMediaBuild;
  final ValueChanged<BoxConstraints> onLayoutBuild;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    onMediaBuild(size);
    return LayoutBuilder(
      builder: (_, constraints) {
        onLayoutBuild(constraints);
        return const SizedBox.expand();
      },
    );
  }
}

class _StubPopularController extends PopularController {
  @override
  Future<List<BangumiItem>> fetchTrendPage({
    required bool useMirror,
    required int limit,
    required int offset,
  }) async => const <BangumiItem>[];

  @override
  Future<List<BangumiItem>> fetchTagPage({
    required bool useMirror,
    required String tag,
    required int offset,
  }) async => const <BangumiItem>[];
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
  ratingScore: 8.6,
  votes: 100,
  votesCount: const <int>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
  info: '',
);
