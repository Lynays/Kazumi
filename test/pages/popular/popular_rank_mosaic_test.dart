import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/bangumi/bangumi_tag.dart';
import 'package:kazumi/pages/popular/popular_rank_mosaic.dart';

void main() {
  group('PopularRankMosaic', () {
    testWidgets('renders 9 editorial portrait/landscape & 0/1/5/11 items', (
      t,
    ) async {
      await _pumpMosaic(t, const [], size: const Size(480, 260));
      expect(find.text('暂无榜单拼贴'), findsOneWidget);

      for (final count in const [1, 5, 11]) {
        final items = List.generate(count, (i) => _item(i + 2));
        await _pumpMosaic(t, items, size: const Size(480, 260));
        expect(find.textContaining('TOP 1'), findsNothing);
        final tiles = find.byType(InkWell);
        final expectedCount = count > 9 ? 9 : count;
        expect(tiles, findsNWidgets(expectedCount));

        final origin = t.getTopLeft(find.byType(PopularRankMosaic));
        final rects = List.generate(
          expectedCount,
          (i) => t.getRect(tiles.at(i)).shift(-origin),
        );
        for (var i = 0; i < rects.length; i++) {
          expect(rects[i].left, greaterThanOrEqualTo(-0.5));
          expect(rects[i].top, greaterThanOrEqualTo(-0.5));
          expect(rects[i].right, lessThanOrEqualTo(480.5));
          expect(rects[i].bottom, lessThanOrEqualTo(260.5));
          for (var j = i + 1; j < rects.length; j++) {
            final overlap = rects[i].intersect(rects[j]);
            expect(overlap.width <= 0 || overlap.height <= 0, isTrue);
          }
        }
        if (count > 9) {
          expect(rects[0].height, greaterThan(rects[0].width));
          expect(rects[1].width, greaterThan(rects[1].height));
          expect(find.text('#10'), findsOneWidget);
          expect(find.text('#11'), findsNothing);
        }
        expect(t.takeException(), isNull);
      }
    });

    testWidgets('hovers to 1.2x without tooltip/title, reflows & falls back', (
      t,
    ) async {
      final items = List.generate(9, (i) => _item(i + 2));
      await _pumpMosaic(t, items, size: const Size(480, 260));
      final first = t.getRect(find.byType(InkWell).first);

      final gesture = await t.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await gesture.addPointer(location: const Offset(1, 1));
      await t.pump();
      await gesture.moveTo(t.getCenter(find.byType(InkWell).first));
      await t.pumpAndSettle();
      expect(find.byType(Tooltip), findsNothing);
      expect(
        t.widgetList<AnimatedScale>(find.byType(AnimatedScale)).last.scale,
        1.20,
      );
      await gesture.moveTo(const Offset(1, 1));
      await t.pumpAndSettle();

      await _pumpMosaic(t, items, size: const Size(700, 220));
      expect(t.getRect(find.byType(InkWell).first), isNot(first));

      await _pumpMosaic(t, items, size: const Size(180, 150));
      expect(find.byType(ListView), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('exposes semantics and opens /info/ for tapped rank item', (
      t,
    ) async {
      final semantics = t.ensureSemantics();
      try {
        final items = List.generate(4, (i) => _item(i + 2));
        Object? pushedArgs;
        await _pumpMosaic(
          t,
          items,
          size: const Size(480, 260),
          onInfo: (args) => pushedArgs = args,
        );

        expect(find.bySemanticsLabel(RegExp('热门第 3 名，番剧 3')), findsOneWidget);
        await t.tap(find.byType(InkWell).at(1));
        await t.pumpAndSettle();
        expect(identical(pushedArgs, items[1]), isTrue);
        expect(find.text('info-route'), findsOneWidget);
      } finally {
        semantics.dispose();
      }
    });
  });
}

Future<void> _pumpMosaic(
  WidgetTester t,
  List<BangumiItem> items, {
  required Size size,
  void Function(Object?)? onInfo,
}) async {
  final module = createModule(
    register: (c) => c
      ..route(
        '/',
        child: (_, _) => Scaffold(
          body: Center(
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: PopularRankMosaic(items: items),
            ),
          ),
        ),
      )
      ..route(
        '/info/',
        child: (_, s) {
          onInfo?.call(s.arguments);
          return const Scaffold(body: Text('info-route'));
        },
      ),
  );
  await t.pumpWidget(
    ModularApp(
      key: UniqueKey(),
      module: module,
      child: Builder(
        builder: (ctx) =>
            MaterialApp.router(routerConfig: ModularApp.routerConfigOf(ctx)),
      ),
    ),
  );
  await t.pumpAndSettle();
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
