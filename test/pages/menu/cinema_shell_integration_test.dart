import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/bangumi/bangumi_tag.dart';
import 'package:kazumi/modules/search/search_history_module.dart';
import 'package:kazumi/pages/menu/cinema_backdrop.dart';
import 'package:kazumi/pages/menu/cinema_navigation_bars.dart';
import 'package:kazumi/pages/menu/cinema_search_bar.dart';
import 'package:kazumi/pages/menu/cinema_top_bar.dart';
import 'package:kazumi/pages/menu/menu.dart';
import 'package:kazumi/pages/popular/popular_controller.dart';
import 'package:kazumi/pages/popular/popular_dashboard.dart';
import 'package:kazumi/pages/popular/popular_page.dart';
import 'package:kazumi/repositories/search_history_repository.dart';
import 'package:kazumi/services/platform/desktop_window_config.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/utils/device.dart';
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
    tempDir = await Directory.systemTemp.createTemp('kazumi_cinema_shell_');
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

  group('Cinema Shell Integration (CS-05)', () {
    testWidgets(
      'landscape dark shell supports 3-tab toggle-to-home, category dropdown, search params, history, and close deduplication',
      (t) async {
        final popularController = _FakePopularController();
        final historyRepo = _FakeSearchHistoryRepository([
          SearchHistory('葬送的芙莉莲', 100),
        ]);
        Uri? lastSearchUri;
        var historyOpened = false;

        await _pumpCinemaShell(
          t,
          size: const Size(1280, 800),
          brightness: Brightness.dark,
          popularController: popularController,
          historyRepository: historyRepo,
          onSearchRoute: (uri) => lastSearchUri = uri,
          onHistoryRoute: () => historyOpened = true,
        );

        // Dark mode uses CinemaBackdrop with CustomPaint & transparent PopularPage.
        expect(find.byType(CinemaBackdrop), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(CinemaBackdrop),
            matching: find.byType(CustomPaint),
          ),
          findsWidgets,
        );
        expect(find.byType(CinemaSideRail), findsOneWidget);
        expect(find.byType(CinemaBottomBar), findsNothing);
        expect(find.byType(CinemaTopBar), findsOneWidget);
        expect(find.byType(PopularDashboard), findsOneWidget);
        expect(find.text('立即观看'), findsOneWidget);

        // On Home: none of the 3 side rail buttons are highlighted.
        expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
        expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
        expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
        expect(
          find.byKey(const ValueKey('top-nav-indicator-首页-true')),
          findsOneWidget,
        );

        // Tap timeline -> enters timeline, highlights timeline, persists top bar,
        // and suppresses duplicate CloseButton inside nested SysAppBar.
        await t.tap(find.byTooltip('时间表'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 250));
        expect(find.text('stub-timeline'), findsOneWidget);
        expect(find.byIcon(Icons.calendar_today_rounded), findsOneWidget);
        expect(find.byType(CinemaSearchBar), findsOneWidget);
        expect(
          find.byKey(const ValueKey('top-nav-indicator-首页-false')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(SysAppBar),
            matching: find.byType(CloseButton),
          ),
          findsNothing,
        );

        // Tap timeline again -> toggles back to Home.
        await t.tap(find.byTooltip('时间表'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 250));
        expect(find.byType(PopularDashboard), findsOneWidget);
        expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);

        // Switch settings -> collect -> tap collect again to return Home.
        await t.tap(find.byTooltip('设置'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 250));
        expect(find.text('stub-my'), findsOneWidget);
        await t.tap(find.byTooltip('喜欢'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 250));
        expect(find.text('stub-collect'), findsOneWidget);
        await t.tap(find.byTooltip('喜欢'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 250));
        expect(find.byType(PopularDashboard), findsOneWidget);

        // Open category dropdown: must NOT contain '热门番组', selecting '日常'
        // switches to tag grid and updates label to '分类 · 日常'.
        await t.tap(find.text('分类'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 300));
        expect(find.text('热门番组'), findsNothing);
        await t.tap(find.text('日常').last);
        await t.pump();
        await t.pump(const Duration(milliseconds: 300));

        expect(popularController.currentTag, '日常');
        expect(find.text('分类 · 日常'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('top-nav-indicator-分类 · 日常-true')),
          findsOneWidget,
        );
        expect(find.byType(SliverGrid), findsOneWidget);

        // Navigate to Settings tab, then tap '首页' in top bar -> returns directly
        // to PopularDashboard and clears category tag.
        await t.tap(find.byTooltip('设置'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 250));
        expect(find.text('stub-my'), findsOneWidget);

        await t.tap(find.text('首页'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 300));
        expect(popularController.currentTag, isEmpty);
        expect(find.byType(PopularDashboard), findsOneWidget);
        expect(
          find.byKey(const ValueKey('top-nav-indicator-首页-true')),
          findsOneWidget,
        );

        // From a non-home tab, selecting a category jumps directly to tag grid.
        await t.tap(find.byTooltip('设置'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 250));
        expect(find.text('stub-my'), findsOneWidget);

        await t.tap(find.text('分类'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 300));
        await t.tap(find.text('奇幻').last);
        await t.pump();
        await t.pump(const Duration(milliseconds: 300));
        expect(popularController.currentTag, '奇幻');
        expect(find.text('分类 · 奇幻'), findsOneWidget);
        expect(find.byType(SliverGrid), findsOneWidget);

        await t.tap(find.text('首页'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 300));
        expect(popularController.currentTag, isEmpty);
        expect(find.byType(PopularDashboard), findsOneWidget);

        // Open top search bar -> secondary filter -> apply query + hideWatched.
        await t.tap(find.byType(TextField));
        await t.pump();
        await t.pump(const Duration(milliseconds: 200));
        await t.tap(find.text('按条件查找'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 200));
        await t.tap(find.text('题材标签'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 250));
        await t.tap(find.widgetWithText(FilterChip, '奇幻'));
        await t.pump();
        await t.dragUntilVisible(
          find.text('收藏状态'),
          find.descendant(
            of: find.byKey(const ValueKey('cinema-search-secondary-panel')),
            matching: find.byType(ListView),
          ),
          const Offset(0, -180),
        );
        await t.tap(find.text('收藏状态'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 250));
        await t.ensureVisible(find.text('隐藏看过的番剧'));
        await t.pump();
        await t.tap(find.text('隐藏看过的番剧'));
        await t.pump();
        await t.tap(find.text('查看结果'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 300));

        expect(lastSearchUri, isNotNull);
        expect(lastSearchUri!.path, '/search/');
        expect(lastSearchUri!.queryParameters['query'], 'tag:奇幻');
        expect(lastSearchUri!.queryParameters['hideWatched'], '1');
        expect(lastSearchUri!.queryParameters['hideAbandoned'], isNull);

        // Pop search route back to shell, then open history from top-left rail button.
        await t.tap(find.byTooltip('Back'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 300));

        await t.tap(find.byTooltip('历史记录'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 300));
        expect(historyOpened, isTrue);

        // Independent pushed root route (history) keeps SysAppBar's CloseButton
        // when running in borderless desktop mode.
        if (isDesktop() && !DesktopWindowConfig.showWindowButton) {
          expect(
            find.descendant(
              of: find.byType(SysAppBar),
              matching: find.byType(CloseButton),
            ),
            findsOneWidget,
          );
        }
        expect(t.takeException(), isNull);
      },
    );

    testWidgets(
      'portrait light shell uses CinemaBottomBar, top-left history button, and light theme palette',
      (t) async {
        final popularController = _FakePopularController();
        final historyRepo = _FakeSearchHistoryRepository(const []);
        var historyOpened = false;

        await _pumpCinemaShell(
          t,
          size: const Size(390, 844),
          brightness: Brightness.light,
          popularController: popularController,
          historyRepository: historyRepo,
          onHistoryRoute: () => historyOpened = true,
        );

        expect(find.byType(CinemaSideRail), findsNothing);
        expect(find.byType(CinemaBottomBar), findsOneWidget);
        expect(find.byType(CinemaTopBar), findsOneWidget);
        expect(find.byTooltip('历史记录'), findsOneWidget);
        expect(find.byType(PopularDashboard), findsOneWidget);

        // Toggle collect -> tap collect again -> back to Home.
        await t.tap(find.text('喜欢'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 250));
        expect(find.text('stub-collect'), findsOneWidget);

        await t.tap(find.text('喜欢'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 250));
        expect(find.byType(PopularDashboard), findsOneWidget);

        // Top-left history button opens history route.
        await t.tap(find.byTooltip('历史记录'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 300));
        expect(historyOpened, isTrue);
        expect(t.takeException(), isNull);
      },
    );
  });
}

Future<void> _pumpCinemaShell(
  WidgetTester t, {
  required Size size,
  required Brightness brightness,
  required PopularController popularController,
  required ISearchHistoryRepository historyRepository,
  ValueChanged<Uri>? onSearchRoute,
  VoidCallback? onHistoryRoute,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);

  final module = createModule(
    register: (c) {
      c
        ..addSingleton<PopularController>(() => popularController)
        ..addSingleton<ISearchHistoryRepository>(() => historyRepository)
        ..route(
          '/tab',
          child: (_, state) => ScaffoldMenu(
            location: state.uri.path,
            popularController: popularController,
            historyRepository: historyRepository,
          ),
          children: (sub) {
            sub
              ..route(
                '/popular/',
                transition: TransitionType.none,
                child: (_, _) => PopularPage(controller: popularController),
              )
              ..route(
                '/timeline/',
                transition: TransitionType.none,
                child: (_, _) => const Scaffold(
                  appBar: SysAppBar(title: Text('时间表')),
                  body: Center(child: Text('stub-timeline')),
                ),
              )
              ..route(
                '/collect/',
                transition: TransitionType.none,
                child: (_, _) => const Scaffold(
                  appBar: SysAppBar(title: Text('追番')),
                  body: Center(child: Text('stub-collect')),
                ),
              )
              ..route(
                '/my/',
                transition: TransitionType.none,
                child: (_, _) => const Scaffold(
                  appBar: SysAppBar(title: Text('我的')),
                  body: Center(child: Text('stub-my')),
                ),
              );
          },
        )
        ..route(
          '/search/',
          child: (context, state) {
            onSearchRoute?.call(state.uri);
            return Scaffold(
              appBar: AppBar(
                leading: IconButton(
                  tooltip: 'Back',
                  onPressed: () => context.maybePop(),
                  icon: const Icon(Icons.arrow_back),
                ),
                title: const Text('search-route'),
              ),
              body: Text(state.uri.toString()),
            );
          },
        )
        ..route(
          '/settings/history/',
          child: (_, _) {
            onHistoryRoute?.call();
            return const Scaffold(
              appBar: SysAppBar(title: Text('历史记录页')),
              body: Center(child: Text('history-route')),
            );
          },
        );
    },
  );

  await t.pumpWidget(
    ModularApp(
      key: UniqueKey(),
      module: module,
      initialRoute: '/tab/popular/',
      child: Builder(
        builder: (ctx) => MaterialApp.router(
          theme: ThemeData(
            brightness: brightness,
            colorSchemeSeed: Colors.green,
            useMaterial3: true,
          ),
          routerConfig: ModularApp.routerConfigOf(ctx),
        ),
      ),
    ),
  );
  await t.pump();
  await t.pump(const Duration(milliseconds: 300));
}

class _TestPaths extends PathProviderPlatform {
  _TestPaths(this.path);
  final String path;

  @override
  Future<String?> getApplicationSupportPath() async => path;
}

class _FakePopularController extends PopularController {
  @override
  Future<List<BangumiItem>> fetchTrendPage({
    required bool useMirror,
    required int limit,
    required int offset,
  }) async => List.generate(24, (i) => _item(offset + i + 1));

  @override
  Future<List<BangumiItem>> fetchTagPage({
    required bool useMirror,
    required String tag,
    required int offset,
  }) async => List.generate(24, (i) => _item(1000 + offset + i + 1));
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
  Future<bool> saveHistory(String keyword) async => true;
}

BangumiItem _item(int id) => BangumiItem(
  id: id,
  type: 2,
  name: 'Anime $id',
  nameCn: '番剧 $id',
  summary: '测试简介 $id',
  airDate: '2026-01-01',
  airWeekday: 1,
  rank: 0,
  images: const <String, String>{},
  tags: const <BangumiTag>[],
  alias: const <String>[],
  ratingScore: 8.8,
  votes: 0,
  votesCount: const <int>[],
  info: '',
);
