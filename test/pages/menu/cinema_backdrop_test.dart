import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/pages/menu/cinema_backdrop.dart';
import 'package:kazumi/pages/menu/cinema_tokens.dart';

void main() {
  group('CinemaPalette', () {
    testWidgets('uses dark cinema palette in dark theme', (t) async {
      late CinemaPalette palette;
      await t.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
          home: Builder(
            builder: (context) {
              palette = CinemaPalette.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(palette.isCinemaDark, isTrue);
      expect(palette.canvas, const Color(0xFF09090D));
      expect(palette.railSurface, const Color(0xFF08080C));
      expect(palette.accent, const Color(0xFFE4152A));
      expect(palette.onAccent, Colors.white);
    });

    testWidgets('falls back to ColorScheme in light theme', (t) async {
      final lightTheme = ThemeData(
        brightness: Brightness.light,
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
      );
      late CinemaPalette palette;
      await t.pumpWidget(
        MaterialApp(
          theme: lightTheme,
          home: Builder(
            builder: (context) {
              palette = CinemaPalette.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final colors = lightTheme.colorScheme;
      expect(palette.isCinemaDark, isFalse);
      expect(palette.canvas, colors.surface);
      expect(palette.railSurface, colors.surfaceContainer);
      expect(palette.railBorder, colors.outlineVariant);
      expect(palette.panelSurface, colors.surfaceContainerHigh);
      expect(palette.panelBorder, colors.outlineVariant);
      expect(palette.accent, colors.primary);
      expect(palette.onAccent, colors.onPrimary);
      expect(palette.textPrimary, colors.onSurface);
      expect(palette.textSecondary, colors.onSurfaceVariant);
      expect(palette.iconMuted, colors.onSurfaceVariant);
    });
  });

  group('CinemaBackdrop', () {
    testWidgets('paints pre-rasterized GPU texture CustomPaint in dark mode', (
      t,
    ) async {
      await t.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
          home: const CinemaBackdrop(child: Text('cinema-child')),
        ),
      );

      expect(find.text('cinema-child'), findsOneWidget);
      final backdropFinder = find.byType(CinemaBackdrop);
      final customPaintFinder = find.descendant(
        of: backdropFinder,
        matching: find.byType(CustomPaint),
      );
      expect(customPaintFinder, findsOneWidget);
      expect(
        find.descendant(
          of: backdropFinder,
          matching: find.byType(RepaintBoundary),
        ),
        findsNothing,
      );

      final customPaint = t.widget<CustomPaint>(customPaintFinder);
      expect(customPaint.painter, isNotNull);
      expect(customPaint.painter!.shouldRepaint(customPaint.painter!), isFalse);
      expect(t.takeException(), isNull);
    });

    testWidgets('uses plain themed ColoredBox without glow in light mode', (
      t,
    ) async {
      final lightTheme = ThemeData(
        brightness: Brightness.light,
        colorSchemeSeed: Colors.green,
        useMaterial3: true,
      );
      await t.pumpWidget(
        MaterialApp(
          theme: lightTheme,
          home: const CinemaBackdrop(child: Text('light-child')),
        ),
      );

      expect(find.text('light-child'), findsOneWidget);
      final backdropFinder = find.byType(CinemaBackdrop);
      expect(
        find.descendant(of: backdropFinder, matching: find.byType(CustomPaint)),
        findsNothing,
      );
      final coloredBox = t.widget<ColoredBox>(
        find.descendant(of: backdropFinder, matching: find.byType(ColoredBox)),
      );
      expect(coloredBox.color, lightTheme.colorScheme.surface);
      expect(t.takeException(), isNull);
    });

    testWidgets('handles zero-size layout without exceptions in dark mode', (
      t,
    ) async {
      await t.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
          home: const Center(
            child: SizedBox.shrink(
              child: CinemaBackdrop(child: SizedBox.shrink()),
            ),
          ),
        ),
      );

      expect(t.takeException(), isNull);
    });
  });
}
