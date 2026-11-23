import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/bean/widget/bangumi_mirror_error_widget.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/bangumi/bangumi_tag.dart';
import 'package:kazumi/pages/popular/popular_controller.dart';
import 'package:kazumi/pages/popular/popular_dashboard.dart';
import 'package:kazumi/pages/popular/popular_page.dart';
import 'package:kazumi/services/storage/storage.dart';
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
      'kazumi_popular_page_test_',
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

  group('PopularPage PR-10 integration', () {
    testWidgets(
      'bounds trend prefetch to 70 unique items, 5 pages max, blocks duplicate in-flight calls, and ref-counts views',
      (t) async {
        final gate = Completer<void>();
        final controller = _FakePopularController(
          onTrendPage: (offset) async {
            if (offset == 0) {
              await gate.future;
            }
            return List.generate(24, (i) => _item(offset + i + 1));
          },
        );
        controller.attachTrendView();

        final first = controller.queryBangumiByTrend();
        final duplicate = controller.queryBangumiByTrend();
        gate.complete();
        await Future.wait([first, duplicate]);

        expect(controller.trendOffsets, [0, 24, 48]);
        expect(controller.trendList.length, 70);
        expect(controller.trendList.map((e) => e.id).toSet().length, 70);
        expect(controller.isLoadingMore, isFalse);
        expect(controller.isTimeOut, isFalse);

        var cappedBatch = 0;
        final cappedController = _FakePopularController(
          onTrendPage: (_) async {
            final start = cappedBatch * 10;
            cappedBatch++;
            return List.generate(24, (i) => _item(start + (i % 10) + 1));
          },
        );
        cappedController.attachTrendView();
        await cappedController.queryBangumiByTrend();

        expect(cappedController.trendOffsets.length, 5);
        expect(cappedController.trendList.length, 50);

        cappedController.attachTrendView();
        cappedController.detachTrendView();
        await cappedController.queryBangumiByTrend();
        expect(cappedController.trendOffsets.length, 5);

        cappedController.detachTrendView();
        cappedController.detachTrendView();
        await cappedController.queryBangumiByTrend();
        cappedController.attachTrendView();
        await cappedController.queryBangumiByTrend(type: 'init');
        expect(cappedController.trendOffsets.length, 10);
      },
    );

    testWidgets(
      'switches between PopularDashboard and tag SliverGrid and disables trend scroll pagination',
      (t) async {
        final controller = _FakePopularController(
          onTrendPage: (offset) async =>
              List.generate(24, (i) => _item(offset + i + 1)),
          onTagPage: (_, offset) async =>
              List.generate(24, (i) => _item(1000 + offset + i + 1)),
        );

        await _pumpPopularPage(t, controller, size: const Size(1280, 420));

        expect(find.byType(PopularDashboard), findsOneWidget);
        expect(find.byType(SliverAppBar), findsNothing);
        expect(find.byType(SliverGrid), findsNothing);
        expect(find.byType(FloatingActionButton), findsNothing);
        expect(controller.trendList.length, 70);

        final trendCallsBeforeScroll = controller.trendOffsets.length;
        await t.drag(find.byType(CustomScrollView), const Offset(0, -300));
        await t.pump();
        expect(controller.trendOffsets.length, trendCallsBeforeScroll);

        // External shell switches to a category tag.
        controller.setCurrentTag('日常');
        await controller.queryBangumiByTag(type: 'init');
        await t.pump();
        await t.pump(const Duration(milliseconds: 300));

        expect(controller.currentTag, '日常');
        expect(find.byType(PopularDashboard), findsNothing);
        expect(find.byType(SliverGrid), findsOneWidget);
        expect(find.byType(FloatingActionButton), findsOneWidget);
        expect(controller.tagOffsets.length, 1);

        await t.drag(find.byType(CustomScrollView), const Offset(0, -700));
        await t.pump();
        await t.drag(find.byType(CustomScrollView), const Offset(0, -700));
        await t.pump();
        expect(controller.tagOffsets.length, 2);
        expect(controller.scrollOffset, greaterThan(0.0));

        // External shell returns to Home: MobX reaction must reset scrollOffset to 0.
        controller.setCurrentTag('');
        controller.clearBangumiList();
        await controller.queryBangumiByTrend(
          type: controller.trendList.isEmpty ? 'init' : 'add',
        );
        await t.pump();
        await t.pump(const Duration(milliseconds: 300));

        expect(controller.currentTag, isEmpty);
        expect(controller.scrollOffset, 0.0);
        expect(find.byType(PopularDashboard), findsOneWidget);
        expect(find.byType(SliverGrid), findsNothing);
        expect(find.byType(FloatingActionButton), findsNothing);
        expect(controller.bangumiList, isEmpty);
        expect(controller.trendOffsets.length, trendCallsBeforeScroll);
        expect(t.takeException(), isNull);
      },
    );

    testWidgets(
      'retries trend load cleanly after initial timeout when switching tags and returning',
      (t) async {
        var shouldFailTrend = true;
        final controller = _FakePopularController(
          onTrendPage: (offset) async {
            if (shouldFailTrend) return const <BangumiItem>[];
            return List.generate(24, (i) => _item(offset + i + 1));
          },
          onTagPage: (_, offset) async =>
              List.generate(24, (i) => _item(2000 + offset + i + 1)),
        );

        await _pumpPopularPage(t, controller, size: const Size(1280, 640));

        expect(controller.isTimeOut, isTrue);
        expect(find.byType(BangumiMirrorErrorWidget), findsOneWidget);

        shouldFailTrend = false;
        controller.setCurrentTag('日常');
        await controller.queryBangumiByTag(type: 'init');
        await t.pump();
        await t.pump(const Duration(milliseconds: 300));
        expect(controller.currentTag, '日常');

        controller.setCurrentTag('');
        controller.clearBangumiList();
        await controller.queryBangumiByTrend(
          type: controller.trendList.isEmpty ? 'init' : 'add',
        );
        await t.pump();
        await t.pump(const Duration(milliseconds: 300));

        expect(controller.currentTag, isEmpty);
        expect(controller.isTimeOut, isFalse);
        expect(controller.trendList, isNotEmpty);
        expect(find.byType(PopularDashboard), findsOneWidget);
        expect(t.takeException(), isNull);
      },
    );

    testWidgets(
      'retries failed trend page at the same offset after partial success',
      (t) async {
        var failSecondPage = true;
        final controller = _FakePopularController(
          onTrendPage: (offset) async {
            if (failSecondPage && offset == 24) {
              return const <BangumiItem>[];
            }
            return List.generate(24, (i) => _item(offset + i + 1));
          },
        );
        controller.attachTrendView();

        await controller.queryBangumiByTrend();
        expect(controller.trendOffsets, [0, 24]);
        expect(controller.trendList.length, 24);
        expect(controller.isTimeOut, isFalse);

        failSecondPage = false;
        await controller.queryBangumiByTrend();
        expect(controller.trendOffsets, [0, 24, 24, 48]);
        expect(controller.trendList.length, 70);
        expect(controller.isTimeOut, isFalse);

        final shortController = _FakePopularController(
          onTrendPage: (offset) async => List.generate(
            offset == 0 ? 24 : 12,
            (i) => _item(offset + i + 1),
          ),
        );
        shortController.attachTrendView();

        await shortController.queryBangumiByTrend();
        await shortController.queryBangumiByTrend();
        expect(shortController.trendOffsets, [0, 24]);
        expect(shortController.trendList.length, 36);
      },
    );
  });
}

Future<void> _pumpPopularPage(
  WidgetTester t,
  PopularController controller, {
  required Size size,
}) async {
  t.view.physicalSize = const Size(1440, 900);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);

  await t.pumpWidget(
    MaterialApp(
      home: Center(
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: PopularPage(controller: controller),
        ),
      ),
    ),
  );
  await t.pump();
  await t.pump(const Duration(milliseconds: 300));
}

class _FakePopularController extends PopularController {
  _FakePopularController({
    required this.onTrendPage,
    Future<List<BangumiItem>> Function(String tag, int offset)? onTagPage,
  }) : _onTagPage = onTagPage;

  final Future<List<BangumiItem>> Function(int offset) onTrendPage;
  final Future<List<BangumiItem>> Function(String tag, int offset)? _onTagPage;
  final List<int> trendOffsets = <int>[];
  final List<int> tagOffsets = <int>[];

  @override
  Future<List<BangumiItem>> fetchTrendPage({
    required bool useMirror,
    required int limit,
    required int offset,
  }) {
    trendOffsets.add(offset);
    return onTrendPage(offset);
  }

  @override
  Future<List<BangumiItem>> fetchTagPage({
    required bool useMirror,
    required String tag,
    required int offset,
  }) {
    tagOffsets.add(offset);
    return _onTagPage?.call(tag, offset) ??
        Future<List<BangumiItem>>.value(const <BangumiItem>[]);
  }
}

class _TestPaths extends PathProviderPlatform {
  _TestPaths(this.path);
  final String path;

  @override
  Future<String?> getApplicationSupportPath() async => path;
}

BangumiItem _item(int id) => BangumiItem(
  id: id,
  type: 2,
  name: 'Anime $id',
  nameCn: '番剧 $id',
  summary: '',
  airDate: '2026-01-01',
  airWeekday: 1,
  rank: 0,
  images: const <String, String>{},
  tags: const <BangumiTag>[],
  alias: const <String>[],
  ratingScore: 8.5,
  votes: 0,
  votesCount: const <int>[],
  info: '',
);
