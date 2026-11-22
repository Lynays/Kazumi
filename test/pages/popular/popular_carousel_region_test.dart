import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/bangumi/bangumi_tag.dart';
import 'package:kazumi/pages/popular/popular_carousel_region.dart';
import 'package:kazumi/pages/popular/popular_carousel_strip.dart';

void main() {
  group('PopularCarouselRegion', () {
    testWidgets('stacks 3 rows vertically with >=0.85 ratio & own drag', (
      t,
    ) async {
      final rows = List.generate(
        3,
        (r) => List.generate(16, (i) => _item(r * 20 + i + 11)),
      );
      await _pumpRegion(t, rows, size: const Size(640, 560));

      final strips = find.byType(PopularCarouselStrip);
      expect(strips, findsNWidgets(3));
      final r0 = t.getRect(strips.at(0));
      final r1 = t.getRect(strips.at(1));
      final r2 = t.getRect(strips.at(2));
      expect(r0.top, lessThan(r1.top));
      expect(r1.top, lessThan(r2.top));
      expect(r0.left, closeTo(r1.left, 0.5));
      expect(r1.height / r0.height, greaterThanOrEqualTo(0.85));

      final lists = find.byType(ListView);
      final c0 = t.widget<ListView>(lists.at(0)).controller!;
      final c1 = t.widget<ListView>(lists.at(1)).controller!;
      final before0 = c0.offset;
      await t.drag(lists.at(0), const Offset(-160, 0));
      await t.pump();
      expect(c0.offset, greaterThan(before0));
      expect(c1.hasClients, isTrue);
    });

    testWidgets('cruises at staggered speeds and skips empty rows', (t) async {
      final rows = [
        List.generate(16, (i) => _item(i + 11)),
        const <BangumiItem>[],
        List.generate(16, (i) => _item(i + 51)),
      ];
      await _pumpRegion(t, rows, size: const Size(480, 560));
      await t.pump();

      final lists = find.byType(ListView);
      final c0 = t.widget<ListView>(lists.at(0)).controller!;
      final c2 = t.widget<ListView>(lists.at(1)).controller!;
      final s0 = c0.offset;
      final s2 = c2.offset;
      expect(s2, greaterThan(s0));

      for (var i = 0; i < 20; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      final d0 = c0.offset - s0;
      final d2 = c2.offset - s2;
      expect(d0, greaterThan(5));
      expect(d2, greaterThan(d0));
    });

    testWidgets('pauses only hovered row, obeys reduce-motion & disposes', (
      t,
    ) async {
      final rows = List.generate(
        3,
        (r) => List.generate(16, (i) => _item(r * 20 + i + 11)),
      );
      await _pumpRegion(t, rows, size: const Size(480, 560));
      await t.pump();

      final lists = find.byType(ListView);
      final c0 = t.widget<ListView>(lists.at(0)).controller!;
      final c2 = t.widget<ListView>(lists.at(2)).controller!;

      final gesture = await t.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await gesture.addPointer(location: const Offset(1, 1));
      await t.pump();
      await gesture.moveTo(
        t.getCenter(find.byType(PopularCarouselStrip).first),
      );
      await t.pump();
      final p0 = c0.offset;
      final p2 = c2.offset;

      for (var i = 0; i < 15; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(c0.offset, p0);
      expect(c2.offset, greaterThan(p2));

      await gesture.moveTo(const Offset(1, 1));
      await _pumpRegion(
        t,
        rows,
        size: const Size(480, 560),
        disableAnimations: true,
      );
      final r0 = c0.offset;
      for (var i = 0; i < 10; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(c0.offset, r0);

      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(seconds: 2));
      expect(t.takeException(), isNull);
    });
  });
}

Future<void> _pumpRegion(
  WidgetTester t,
  List<List<BangumiItem>> rows, {
  required Size size,
  bool disableAnimations = false,
}) async {
  await t.pumpWidget(
    MaterialApp(
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(disableAnimations: disableAnimations),
        child: child!,
      ),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: PopularCarouselRegion(rows: rows),
          ),
        ),
      ),
    ),
  );
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
  ratingScore: 8.6,
  votes: 0,
  votesCount: const <int>[],
  info: '',
);
