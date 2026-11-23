import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/pages/menu/cinema_nav_logic.dart';
import 'package:kazumi/pages/menu/cinema_navigation_bars.dart';

void main() {
  group('cinema_nav_logic', () {
    test('resolveCinemaNavTap handles all 3-tab state transitions', () {
      // Home -> each tab.
      expect(
        resolveCinemaNavTap(
          currentRouteIndex: 0,
          tapped: CinemaNavTab.timeline,
        ),
        1,
      );
      expect(
        resolveCinemaNavTap(currentRouteIndex: 0, tapped: CinemaNavTab.collect),
        2,
      );
      expect(
        resolveCinemaNavTap(
          currentRouteIndex: 0,
          tapped: CinemaNavTab.settings,
        ),
        3,
      );

      // Same tab -> back to home (0).
      expect(
        resolveCinemaNavTap(
          currentRouteIndex: 1,
          tapped: CinemaNavTab.timeline,
        ),
        0,
      );
      expect(
        resolveCinemaNavTap(currentRouteIndex: 2, tapped: CinemaNavTab.collect),
        0,
      );
      expect(
        resolveCinemaNavTap(
          currentRouteIndex: 3,
          tapped: CinemaNavTab.settings,
        ),
        0,
      );

      // Cross-tab switching.
      expect(
        resolveCinemaNavTap(currentRouteIndex: 3, tapped: CinemaNavTab.collect),
        2,
      );
      expect(
        resolveCinemaNavTap(
          currentRouteIndex: 2,
          tapped: CinemaNavTab.timeline,
        ),
        1,
      );
      expect(
        resolveCinemaNavTap(
          currentRouteIndex: 1,
          tapped: CinemaNavTab.settings,
        ),
        3,
      );
    });

    test(
      'activeCinemaNavTab returns null on home and matching enum otherwise',
      () {
        expect(activeCinemaNavTab(0), isNull);
        expect(activeCinemaNavTab(1), CinemaNavTab.timeline);
        expect(activeCinemaNavTab(2), CinemaNavTab.collect);
        expect(activeCinemaNavTab(3), CinemaNavTab.settings);
        expect(activeCinemaNavTab(99), isNull);
      },
    );
  });

  group('CinemaClockText', () {
    testWidgets('formats HH:mm, refreshes on minute turn, and disposes timer', (
      t,
    ) async {
      var now = DateTime(2026, 11, 23, 9, 5, 45);
      await t.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
          home: Scaffold(
            body: Center(child: CinemaClockText(nowProvider: () => now)),
          ),
        ),
      );

      expect(find.text('09:05'), findsOneWidget);

      // Advance to the next minute boundary (15 seconds later).
      now = DateTime(2026, 11, 23, 9, 6, 0);
      await t.pump(const Duration(seconds: 15));
      expect(find.text('09:06'), findsOneWidget);

      // Disposing cancels timer cleanly (FakeAsync asserts no pending timers).
      await t.pumpWidget(const SizedBox.shrink());
      expect(t.takeException(), isNull);
    });
  });

  group('CinemaSideRail', () {
    testWidgets(
      'highlights none on home, switches active tab, and fires callbacks',
      (t) async {
        final semantics = t.ensureSemantics();
        try {
          CinemaNavTab? lastTapped;
          var historyTapped = 0;

          Future<void> pumpRail(
            CinemaNavTab? active,
            Brightness brightness,
          ) async {
            await t.pumpWidget(
              MaterialApp(
                theme: ThemeData(brightness: brightness, useMaterial3: true),
                home: Scaffold(
                  body: CinemaSideRail(
                    activeTab: active,
                    onTabTap: (tab) => lastTapped = tab,
                    onHistoryTap: () => historyTapped++,
                  ),
                ),
              ),
            );
          }

          await pumpRail(null, Brightness.dark);

          expect(find.byIcon(Icons.history_rounded), findsOneWidget);
          expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
          expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
          expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
          expect(find.byIcon(Icons.calendar_today_rounded), findsNothing);
          expect(find.byIcon(Icons.favorite_rounded), findsNothing);
          expect(find.byIcon(Icons.settings_rounded), findsNothing);

          // Minimum 48x48 hit target for each action.
          expect(
            t.getSize(find.byTooltip('历史记录')).height,
            greaterThanOrEqualTo(48),
          );
          expect(
            t.getSize(find.byTooltip('时间表')).height,
            greaterThanOrEqualTo(48),
          );

          await t.tap(find.byTooltip('历史记录'));
          await t.pump();
          expect(historyTapped, 1);

          await t.tap(find.byTooltip('设置'));
          await t.pump();
          expect(lastTapped, CinemaNavTab.settings);

          await pumpRail(CinemaNavTab.settings, Brightness.light);
          expect(find.byIcon(Icons.settings_rounded), findsOneWidget);
          expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
          expect(t.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  });

  group('CinemaBottomBar', () {
    testWidgets(
      'supports activeTab == null and renders in light and dark mode',
      (t) async {
        CinemaNavTab? lastTapped;

        for (final brightness in [Brightness.dark, Brightness.light]) {
          await t.pumpWidget(
            MaterialApp(
              theme: ThemeData(brightness: brightness, useMaterial3: true),
              home: Scaffold(
                bottomNavigationBar: CinemaBottomBar(
                  activeTab: null,
                  onTabTap: (tab) => lastTapped = tab,
                ),
              ),
            ),
          );

          expect(find.text('时间表'), findsOneWidget);
          expect(find.text('喜欢'), findsOneWidget);
          expect(find.text('设置'), findsOneWidget);
          expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
          expect(find.byIcon(Icons.favorite_rounded), findsNothing);
          expect(t.takeException(), isNull);
        }

        await t.tap(find.text('喜欢'));
        await t.pump();
        expect(lastTapped, CinemaNavTab.collect);

        await t.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
            home: Scaffold(
              bottomNavigationBar: CinemaBottomBar(
                activeTab: CinemaNavTab.collect,
                onTabTap: (tab) => lastTapped = tab,
              ),
            ),
          ),
        );
        expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
        expect(t.takeException(), isNull);
      },
    );
  });
}
