import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/bean/card/palette_card.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/settings/settings_list.dart';
import 'package:kazumi/bean/settings/theme_provider.dart';
import 'package:kazumi/bean/widget/media_error_widget.dart';
import 'package:kazumi/navigation.dart';
import 'package:kazumi/pages/menu/cinema_tokens.dart';
import 'package:kazumi/pages/settings/theme_settings_page.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/utils/theme.dart';
import 'package:logger/logger.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

void main() {
  group('Theme color helpers', () {
    test('treats default and legacy green hex as default theme color', () {
      expect(isDefaultThemeColor(null), isTrue);
      expect(isDefaultThemeColor(''), isTrue);
      expect(isDefaultThemeColor('default'), isTrue);
      expect(
        isDefaultThemeColor(Colors.green.toARGB32().toRadixString(16)),
        isTrue,
      );
      expect(
        isDefaultThemeColor(
          Colors.green.toARGB32().toRadixString(16).toUpperCase(),
        ),
        isTrue,
      );
      expect(resolveCustomThemeColor('default'), isNull);
      expect(
        resolveCustomThemeColor(Colors.green.toARGB32().toRadixString(16)),
        isNull,
      );
    });

    test('parses explicit non-default custom colors', () {
      final blueHex = Colors.blue.toARGB32().toRadixString(16);
      expect(isDefaultThemeColor(blueHex), isFalse);
      expect(resolveCustomThemeColor(blueHex), Color(Colors.blue.toARGB32()));
    });
  });

  group('buildAppTheme', () {
    test('uses unified Home TOP 1 cinema red palette in dark mode by default', () {
      final dark = buildAppTheme(
        brightness: Brightness.dark,
        fontFamily: null,
      );

      expect(dark.brightness, Brightness.dark);
      expect(dark.colorScheme.primary, CinemaTokens.darkAccent);
      expect(dark.colorScheme.onPrimary, CinemaTokens.darkOnAccent);
      expect(dark.colorScheme.primaryContainer, cinemaDarkPrimaryContainer);
      expect(dark.colorScheme.onPrimaryContainer, cinemaDarkOnPrimaryContainer);
      expect(dark.colorScheme.secondaryContainer, cinemaDarkSecondaryContainer);
      expect(
        dark.colorScheme.onSecondaryContainer,
        cinemaDarkOnSecondaryContainer,
      );
      expect(
        dark.floatingActionButtonTheme.backgroundColor,
        CinemaTokens.darkAccent,
      );
      expect(
        dark.floatingActionButtonTheme.foregroundColor,
        CinemaTokens.darkOnAccent,
      );
      expect(dark.tabBarTheme.indicatorColor, CinemaTokens.darkAccent);
      expect(dark.tabBarTheme.labelColor, cinemaDarkTextAccent);
    });

    test('preserves white onPrimary on cinema red when OLED enhance is enabled', () {
      final oledDark = buildAppTheme(
        brightness: Brightness.dark,
        fontFamily: null,
        oledEnhance: true,
      );

      expect(oledDark.scaffoldBackgroundColor, Colors.black);
      expect(oledDark.colorScheme.surface, Colors.black);
      expect(oledDark.colorScheme.onSurface, Colors.white);
      expect(oledDark.colorScheme.primary, CinemaTokens.darkAccent);
      expect(oledDark.colorScheme.onPrimary, Colors.white);
      expect(
        oledDark.floatingActionButtonTheme.backgroundColor,
        CinemaTokens.darkAccent,
      );
      expect(
        oledDark.floatingActionButtonTheme.foregroundColor,
        Colors.white,
      );
    });

    test('keeps green default theme in light mode', () {
      final light = buildAppTheme(
        brightness: Brightness.light,
        fontFamily: null,
      );
      final expectedLight = ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: Colors.green,
      );

      expect(light.colorScheme.primary, expectedLight.colorScheme.primary);
      expect(light.floatingActionButtonTheme.backgroundColor, isNull);
    });

    test('respects explicit custom color in dark mode and OLED onPrimary', () {
      final customDark = buildAppTheme(
        brightness: Brightness.dark,
        fontFamily: null,
        customColor: Colors.blue,
      );
      final expectedBlueDark = ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.blue,
      );

      expect(
        customDark.colorScheme.primary,
        expectedBlueDark.colorScheme.primary,
      );
      expect(customDark.floatingActionButtonTheme.backgroundColor, isNull);

      final customOled = oledDarkTheme(customDark);
      expect(customOled.colorScheme.onPrimary, Colors.black);
    });
  });

  group('Cinema dark mode widget rendering', () {
    testWidgets('styles FAB, FilledButton, TonalButton, TextButton, and Switch in cinema red', (
      t,
    ) async {
      final darkTheme = buildAppTheme(
        brightness: Brightness.dark,
        fontFamily: null,
      );

      await t.pumpWidget(
        MaterialApp(
          theme: darkTheme,
          home: Scaffold(
            body: Column(
              children: [
                FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.favorite_border),
                  label: const Text('未追'),
                ),
                FilledButton.tonal(
                  onPressed: () {},
                  child: const Text('热度优先'),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text('加载更多'),
                ),
                Switch(value: true, onChanged: (_) {}),
              ],
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () {},
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('开始观看'),
            ),
          ),
        ),
      );

      // FAB ("开始观看") matches TOP 1 red with white foreground.
      final fabMaterial = t.widget<Material>(
        find.descendant(
          of: find.byType(FloatingActionButton),
          matching: find.byType(Material),
        ).first,
      );
      expect(fabMaterial.color, CinemaTokens.darkAccent);
      expect(fabMaterial.textStyle?.color, Colors.white);

      // FilledButton ("未追") matches TOP 1 red with white foreground.
      final filledMaterial = t.widget<Material>(
        find.descendant(
          of: find.widgetWithText(FilledButton, '未追'),
          matching: find.byType(Material),
        ).first,
      );
      expect(filledMaterial.color, CinemaTokens.darkAccent);
      expect(filledMaterial.textStyle?.color, Colors.white);

      // FilledButton.tonal ("热度优先") uses deep cinema crimson container.
      final tonalMaterial = t.widget<Material>(
        find.descendant(
          of: find.widgetWithText(FilledButton, '热度优先'),
          matching: find.byType(Material),
        ).first,
      );
      expect(tonalMaterial.color, cinemaDarkSecondaryContainer);
      expect(tonalMaterial.textStyle?.color, cinemaDarkOnSecondaryContainer);

      // TextButton uses high-contrast cinema text red.
      final textBtnMaterial = t.widget<Material>(
        find.descendant(
          of: find.widgetWithText(TextButton, '加载更多'),
          matching: find.byType(Material),
        ).first,
      );
      expect(textBtnMaterial.textStyle?.color, cinemaDarkTextAccent);

      // Switch selected thumb stays bright when idle and when hovered.
      final switchThumb = darkTheme.switchTheme.thumbColor!;
      expect(switchThumb.resolve({WidgetState.selected}), Colors.white);
      expect(
        switchThumb.resolve({WidgetState.selected, WidgetState.hovered}),
        cinemaDarkOnPrimaryContainer,
      );
    });

    testWidgets('MediaErrorWidget keeps cinema dark red in dark mode', (t) async {
      final darkTheme = buildAppTheme(
        brightness: Brightness.dark,
        fontFamily: null,
      );
      late Color primaryInsideError;

      await t.pumpWidget(
        MaterialApp(
          theme: darkTheme,
          home: Scaffold(
            body: Column(
              children: [
                const MediaErrorWidget(
                  title: '播放失败',
                  errMsg: '测试错误',
                  icon: Icons.error_outline_rounded,
                ),
                Builder(
                  builder: (context) {
                    primaryInsideError = Theme.of(context).colorScheme.primary;
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
        ),
      );

      final errorContext = t.element(find.text('播放失败'));
      expect(Theme.of(errorContext).colorScheme.primary, CinemaTokens.darkAccent);
      expect(primaryInsideError, CinemaTokens.darkAccent);
    });
  });

  group('ThemeSettingsPage dark mode defaults', () {
    late Directory tempDir;
    late PathProviderPlatform originalPathProvider;
    late Level originalLogLevel;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      originalLogLevel = Logger.level;
      Logger.level = Level.off;
      tempDir = await Directory.systemTemp.createTemp('kazumi_theme_test_');
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
      await GStorage.putSetting(SettingsKeys.themeColor, 'default');
      await GStorage.putSetting(SettingsKeys.oledEnhance, false);
      await GStorage.putSetting(SettingsKeys.useSystemFont, false);
      await GStorage.putSetting(SettingsKeys.useDynamicColor, false);
    });

    testWidgets(
      'preserves default cinema red across OLED/font toggles and shows red default swatch in dark mode',
      (t) async {
        t.view.physicalSize = const Size(1000, 1200);
        t.view.devicePixelRatio = 1.0;
        addTearDown(t.view.reset);

        final themeProvider = ThemeProvider();
        themeProvider.setTheme(
          buildAppTheme(brightness: Brightness.light, fontFamily: null),
          buildAppTheme(brightness: Brightness.dark, fontFamily: null),
          notify: false,
        );

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
            navigatorKey: rootNavigatorKey,
            navigatorObservers: [KazumiDialog.observer],
            provide: (scoped) {
              scoped.addChangeNotifier<ThemeProvider>(() => themeProvider);
            },
            child: Builder(
              builder: (ctx) => MaterialApp.router(
                theme: themeProvider.light,
                darkTheme: themeProvider.dark,
                themeMode: ThemeMode.dark,
                routerConfig: ModularApp.routerConfigOf(ctx),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();

        // Trigger Hive-writing callbacks inside runAsync so Hive's disk lock
        // completes in the real async zone rather than FakeAsync.
        Future<void> toggleSwitchTile(String title) async {
          await t.ensureVisible(find.text(title));
          final tileFinder = find.ancestor(
            of: find.text(title),
            matching: find.byWidgetPredicate((w) => w is SettingsTile),
          );
          final tile = t.widget<SettingsTile<dynamic>>(tileFinder);
          await t.runAsync(() async {
            tile.onToggle!(null);
            await Future<void>.delayed(const Duration(milliseconds: 50));
          });
          await t.pumpAndSettle();
        }

        Future<void> tapPaletteOption(String label) async {
          final gestureFinder = find.ancestor(
            of: find.text(label),
            matching: find.byType(GestureDetector),
          ).first;
          final gesture = t.widget<GestureDetector>(gestureFinder);
          await t.runAsync(() async {
            gesture.onTap!();
            await Future<void>.delayed(const Duration(milliseconds: 50));
          });
          await t.pumpAndSettle();
        }

        // Toggle system font -> should NOT clobber themeColor with green hex.
        await toggleSwitchTile('使用系统字体');
        expect(GStorage.getSetting(SettingsKeys.themeColor), 'default');
        expect(themeProvider.dark.colorScheme.primary, CinemaTokens.darkAccent);
        expect(themeProvider.dark.colorScheme.onPrimary, Colors.white);

        // Toggle OLED enhance -> stays 'default' and keeps cinema red + white onPrimary.
        await toggleSwitchTile('OLED优化');
        expect(GStorage.getSetting(SettingsKeys.themeColor), 'default');
        expect(themeProvider.dark.scaffoldBackgroundColor, Colors.black);
        expect(themeProvider.dark.colorScheme.primary, CinemaTokens.darkAccent);
        expect(themeProvider.dark.colorScheme.onPrimary, Colors.white);

        // Open color palette dialog -> first ("默认") swatch shows cinema red in dark mode.
        await t.ensureVisible(find.text('配色方案'));
        await t.tap(find.text('配色方案'));
        await t.pumpAndSettle();

        final defaultCard = t.widget<PaletteCard>(find.byType(PaletteCard).first);
        expect(defaultCard.color, CinemaTokens.darkAccent);
        expect(defaultCard.selected, isTrue);

        // Select custom color ("蓝色"), then reset back to "默认".
        await tapPaletteOption('蓝色');
        expect(
          GStorage.getSetting(SettingsKeys.themeColor),
          Colors.blue.toARGB32().toRadixString(16),
        );
        expect(
          themeProvider.dark.colorScheme.primary,
          isNot(CinemaTokens.darkAccent),
        );

        await t.tap(find.text('配色方案'));
        await t.pumpAndSettle();
        await tapPaletteOption('默认');
        expect(GStorage.getSetting(SettingsKeys.themeColor), 'default');
        expect(themeProvider.dark.colorScheme.primary, CinemaTokens.darkAccent);
        expect(themeProvider.dark.colorScheme.onPrimary, Colors.white);

        KazumiDialog.dismiss();
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
