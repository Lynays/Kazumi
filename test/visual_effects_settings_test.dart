import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:kazumi/bean/settings/settings_list.dart';
import 'package:kazumi/bean/settings/theme_provider.dart';
import 'package:kazumi/bean/settings/visual_effects_config.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/bangumi/bangumi_tag.dart';
import 'package:kazumi/pages/menu/cinema_backdrop.dart';
import 'package:kazumi/pages/popular/popular_carousel_floor.dart';
import 'package:kazumi/pages/popular/popular_featured_card.dart';
import 'package:kazumi/pages/popular/popular_floor_reflection.dart';
import 'package:kazumi/pages/settings/theme_settings_page.dart';
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
    tempDir = await Directory.systemTemp.createTemp('kazumi_visual_effects_');
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

  setUp(() async {
    await VisualEffectsConfig.defaults.saveToStorage();
  });

  group('VisualEffectsConfig', () {
    test('uses 70% as 1.0x baseline and scales 0%..150% cleanly', () {
      const defaults = VisualEffectsConfig.defaults;
      expect(defaults.isDefault, isTrue);
      expect(defaults.isUniform, isTrue);
      expect(defaults.overallPercent, 70);
      expect(defaults.reflectionScale, closeTo(1.0, 1e-6));
      expect(defaults.backdropGlowScale, closeTo(1.0, 1e-6));
      expect(defaults.floorLightScale, closeTo(1.0, 1e-6));
      expect(defaults.cardEffectsScale, closeTo(1.0, 1e-6));
      expect(defaults.headerBlurScale, closeTo(1.0, 1e-6));

      final off = VisualEffectsConfig.uniform(0.0);
      expect(off.reflectionScale, 0.0);
      expect(off.overallPercent, 0);
      expect(off.isUniform, isTrue);
      expect(off.isDefault, isFalse);

      final max = VisualEffectsConfig.uniform(1.5);
      expect(max.reflectionScale, closeTo(1.5 / 0.7, 1e-6));
      expect(max.overallPercent, 150);

      final custom = defaults.copyWith(reflection: 0.2, backdropGlow: 1.5);
      expect(custom.isUniform, isFalse);
      expect(custom.isDefault, isFalse);
      expect(custom.overallPercent, 76);
      expect(VisualEffectsConfig.clampLevel(double.nan), 0.7);
      expect(VisualEffectsConfig.clampLevel(-1.0), 0.0);
      expect(VisualEffectsConfig.clampLevel(2.5), 1.5);
    });

    test('persists and reloads all five channels via GStorage', () async {
      const saved = VisualEffectsConfig(
        reflection: 0.25,
        backdropGlow: 1.25,
        floorLight: 0.0,
        cardEffects: 0.50,
        headerBlur: 1.50,
      );
      await saved.saveToStorage();

      final loaded = VisualEffectsConfig.fromStorage();
      expect(loaded, saved);
    });
  });

  group('Visual effects widgets respond to VisualEffectsScope', () {
    testWidgets('PopularFloorReflection skips rendering when reflection is 0%', (
      t,
    ) async {
      await t.pumpWidget(
        const VisualEffectsScope(
          config: VisualEffectsConfig(reflection: 0.0),
          child: MaterialApp(
            home: Scaffold(
              body: PopularFloorReflection(
                cover: 'https://example.com/cover.jpg',
                size: Size(120, 160),
                depth: 24,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(ShaderMask), findsNothing);
      expect(find.byType(NetworkImgLayer), findsNothing);
      expect(t.getSize(find.byType(PopularFloorReflection)), const Size(120, 24));
    });

    testWidgets('CinemaBackdrop omits CustomPaint when backdropGlow is 0%', (
      t,
    ) async {
      await t.pumpWidget(
        VisualEffectsScope(
          config: const VisualEffectsConfig(backdropGlow: 0.0),
          child: MaterialApp(
            theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
            home: const CinemaBackdrop(child: Text('body')),
          ),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(CinemaBackdrop),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );
      expect(find.text('body'), findsOneWidget);
    });

    testWidgets('PopularCarouselFloor omits CustomPaint when floorLight is 0%', (
      t,
    ) async {
      await t.pumpWidget(
        VisualEffectsScope(
          config: const VisualEffectsConfig(floorLight: 0.0),
          child: MaterialApp(
            theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
            home: const PopularCarouselFloor(child: Text('carousel')),
          ),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(PopularCarouselFloor),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );
      expect(find.text('carousel'), findsOneWidget);
    });

    testWidgets('PopularFeaturedCard disables CTA glow shadow when cardEffects is 0%', (
      t,
    ) async {
      await t.pumpWidget(
        VisualEffectsScope(
          config: const VisualEffectsConfig(cardEffects: 0.0),
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 640,
                height: 260,
                child: PopularFeaturedCard(item: _item(1)),
              ),
            ),
          ),
        ),
      );

      final ctaContainer = t.widget<Container>(
        find
            .ancestor(
              of: find.text('立即观看'),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = ctaContainer.decoration as BoxDecoration;
      expect(decoration.boxShadow, isNull);
    });

    testWidgets('effect widgets render safely at 150% intensity', (t) async {
      await t.pumpWidget(
        VisualEffectsScope(
          config: VisualEffectsConfig.uniform(1.5),
          child: MaterialApp(
            theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
            home: Scaffold(
              body: CinemaBackdrop(
                child: PopularCarouselFloor(
                  child: Column(
                    children: [
                      SizedBox(
                        width: 640,
                        height: 220,
                        child: PopularFeaturedCard(item: _item(2)),
                      ),
                      const PopularFloorReflection(
                        cover: 'cover-placeholder',
                        size: Size(120, 160),
                        depth: 24,
                        foreground: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(t.takeException(), isNull);
      expect(find.byType(ShaderMask), findsOneWidget);
    });
  });

  group('ThemeSettingsPage visual effects controls', () {
    testWidgets(
      'shows 70% master slider, expands individual sliders, customizes, unifies, and resets',
      (t) async {
        t.view.physicalSize = const Size(1000, 1200);
        t.view.devicePixelRatio = 1.0;
        addTearDown(t.view.reset);

        final themeProvider = ThemeProvider();
        final module = createModule(
          register: (c) => c.route(
            '/',
            child: (_, _) => const ThemeSettingsPage(),
          ),
        );

        await t.pumpWidget(
          ModularApp(
            key: UniqueKey(),
            module: module,
            provide: (scoped) {
              scoped.addChangeNotifier<ThemeProvider>(() => themeProvider);
            },
            child: Builder(
              builder: (ctx) => MaterialApp.router(
                routerConfig: ModularApp.routerConfigOf(ctx),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();

        expect(find.text('视觉特效'), findsOneWidget);
        expect(find.text('视觉特效强度'), findsOneWidget);
        expect(find.text('70%'), findsOneWidget);
        expect(find.text('单项特效调节'), findsOneWidget);
        expect(find.text('海报底部倒影'), findsNothing);

        // Expand individual effect sliders.
        await t.tap(find.text('单项特效调节'));
        await t.pumpAndSettle();

        expect(find.text('海报底部倒影'), findsOneWidget);
        expect(find.text('影院背景光晕'), findsOneWidget);
        expect(find.text('舞台地面反光'), findsOneWidget);
        expect(find.text('卡片阴影与光泽'), findsOneWidget);
        expect(find.text('详情页背景虚化'), findsOneWidget);

        // Adjust reflection slider independently to 0%.
        final sliders = find.byType(Slider);
        expect(sliders, findsNWidgets(6));
        final reflectionSlider = t.widget<Slider>(sliders.at(1));
        await t.runAsync(() async {
          reflectionSlider.onChanged!(0.0);
          await Future<void>.delayed(const Duration(milliseconds: 20));
        });
        await t.pumpAndSettle();

        expect(themeProvider.visualEffects.value.reflectionPercent, 0);
        expect(themeProvider.visualEffects.value.backdropGlowPercent, 70);
        expect(themeProvider.visualEffects.value.isUniform, isFalse);
        expect(find.text('已自定义'), findsOneWidget);
        expect(VisualEffectsConfig.fromStorage().reflectionPercent, 0);

        // Adjust master slider to 150% -> unifies all five channels.
        final masterSlider = t.widget<Slider>(sliders.first);
        expect(masterSlider.max, 1.5);
        expect(masterSlider.divisions, 30);
        await t.runAsync(() async {
          masterSlider.onChanged!(1.5);
          await Future<void>.delayed(const Duration(milliseconds: 20));
        });
        await t.pumpAndSettle();

        expect(themeProvider.visualEffects.value.isUniform, isTrue);
        expect(themeProvider.visualEffects.value.overallPercent, 150);
        expect(themeProvider.visualEffects.value.reflectionPercent, 150);
        expect(find.text('150%'), findsWidgets);
        expect(VisualEffectsConfig.fromStorage().overallPercent, 150);

        // Trigger reset tile inside runAsync so Hive's disk write completes
        // in the real async zone rather than FakeAsync.
        await t.ensureVisible(find.text('恢复默认特效强度'));
        final resetTileFinder = find.ancestor(
          of: find.text('恢复默认特效强度'),
          matching: find.byWidgetPredicate((w) => w is SettingsTile),
        );
        final resetTile = t.widget<SettingsTile<dynamic>>(resetTileFinder);
        expect(resetTile.enabled, isTrue);
        await t.runAsync(() async {
          resetTile.onPressed!(t.element(resetTileFinder));
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await t.pumpAndSettle();

        expect(themeProvider.visualEffects.value.isDefault, isTrue);
        expect(themeProvider.visualEffects.value.overallPercent, 70);
        expect(VisualEffectsConfig.fromStorage().isDefault, isTrue);
      },
    );
  });
}

class _TestPaths extends PathProviderPlatform {
  _TestPaths(this.path);
  final String path;

  @override
  Future<String?> getApplicationSupportPath() async => path;

  @override
  Future<String?> getTemporaryPath() async => path;
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
