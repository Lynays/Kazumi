import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/bangumi/bangumi_tag.dart';
import 'package:kazumi/pages/popular/popular_carousel_strip.dart';

void main() {
  group('PopularCarouselStrip', () {
    testWidgets('renders 0/1/20 items without header and overlaid title', (
      t,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      for (final count in const [0, 1, 20]) {
        for (final height in const [96.0, 220.0]) {
          final items = List.generate(count, (i) => _item(i + 1, score: 8.5));
          await _pumpStrip(t, items, controller, width: 640, height: height);
          expect(find.text('TOP 11-30'), findsNothing);
          if (count == 0) {
            expect(find.text('暂无更多热门番剧'), findsOneWidget);
          } else {
            final posterRect = t.getRect(find.byType(NetworkImgLayer).first);
            final titleRect = t.getRect(find.text('番剧 1'));
            expect(titleRect.bottom, lessThanOrEqualTo(posterRect.bottom + 1));
            expect(titleRect.top, greaterThanOrEqualTo(posterRect.top));
          }
          expect(t.takeException(), isNull);
        }
      }
    });

    testWidgets('does not dispose external ScrollController', (t) async {
      final controller = ScrollController();
      final items = List.generate(12, (i) => _item(i + 1));
      await _pumpStrip(t, items, controller, width: 480, label: '热门精选');
      expect(find.text('热门精选'), findsOneWidget);

      await t.pumpWidget(const SizedBox.shrink());
      expect(() => controller.dispose(), returnsNormally);
    });

    testWidgets('ignores animateTo and detects user drag', (t) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      var starts = 0;
      var ends = 0;
      final items = List.generate(20, (i) => _item(i + 1));

      await _pumpStrip(
        t,
        items,
        controller,
        width: 360,
        onStart: () => starts++,
        onEnd: () => ends++,
      );

      controller.animateTo(
        180,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
      await t.pumpAndSettle();
      expect(controller.offset, 180);
      expect(starts, 0);
      expect(ends, 0);

      await t.drag(find.byType(ListView), const Offset(-140, 0));
      expect(starts, 1);
      await t.pumpAndSettle();
      expect(ends, 1);
    });

    testWidgets('hover zooms poster and pauses, exit restores, tap navigates', (
      t,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final items = List.generate(6, (i) => _item(i + 11));
      var starts = 0;
      var ends = 0;
      Object? pushedArgs;

      await _pumpStrip(
        t,
        items,
        controller,
        onStart: () => starts++,
        onEnd: () => ends++,
        onInfo: (args) => pushedArgs = args,
      );

      double firstScale() {
        final transform = t.widget<Transform>(
          find
              .ancestor(
                of: find.byType(NetworkImgLayer).first,
                matching: find.byType(Transform),
              )
              .first,
        );
        return transform.transform.storage[0];
      }

      double firstTitleOpacity() => t
          .widget<Opacity>(
            find
                .ancestor(
                  of: find.text('番剧 11'),
                  matching: find.byType(Opacity),
                )
                .first,
          )
          .opacity;

      final gesture = await t.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await gesture.addPointer(location: const Offset(1, 1));
      await t.pump();
      await gesture.moveTo(t.getCenter(find.byType(NetworkImgLayer).first));
      await t.pumpAndSettle();
      expect(starts, 1);
      expect(ends, 0);
      expect(find.byType(Tooltip), findsNothing);
      expect(firstScale(), closeTo(1.2, 1e-4));
      expect(firstTitleOpacity(), closeTo(0.0, 1e-4));

      await gesture.moveTo(const Offset(1, 1));
      await t.pumpAndSettle();
      expect(ends, 1);
      expect(firstScale(), closeTo(1.0, 1e-4));
      expect(firstTitleOpacity(), closeTo(1.0, 1e-4));

      await t.tap(find.text('番剧 11'));
      await t.pumpAndSettle();
      expect(identical(pushedArgs, items.first), isTrue);
      expect(find.text('info-route'), findsOneWidget);
    });
  });
}

Future<void> _pumpStrip(
  WidgetTester tester,
  List<BangumiItem> items,
  ScrollController controller, {
  double width = 500,
  double height = 180,
  String label = '',
  VoidCallback? onStart,
  VoidCallback? onEnd,
  void Function(Object?)? onInfo,
}) async {
  final strip = SizedBox(
    width: width,
    child: PopularCarouselStrip(
      items: items,
      controller: controller,
      height: height,
      label: label,
      onUserInteractionStart: onStart ?? () {},
      onUserInteractionEnd: onEnd ?? () {},
    ),
  );
  final module = createModule(
    register: (c) => c
      ..route(
        '/',
        child: (_, _) => Scaffold(body: Center(child: strip)),
      )
      ..route(
        '/info/',
        child: (_, s) {
          onInfo?.call(s.arguments);
          return const Scaffold(body: Text('info-route'));
        },
      ),
  );
  await tester.pumpWidget(
    ModularApp(
      key: UniqueKey(),
      module: module,
      child: Builder(
        builder: (ctx) =>
            MaterialApp.router(routerConfig: ModularApp.routerConfigOf(ctx)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

BangumiItem _item(int id, {double score = 0}) => BangumiItem(
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
  ratingScore: score,
  votes: 0,
  votesCount: const <int>[],
  info: '',
);
