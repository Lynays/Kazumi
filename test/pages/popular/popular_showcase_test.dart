import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/bangumi/bangumi_tag.dart';
import 'package:kazumi/pages/popular/popular_featured_card.dart';
import 'package:kazumi/pages/popular/popular_rank_mosaic.dart';
import 'package:kazumi/pages/popular/popular_showcase.dart';

void main() {
  group('PopularShowcase', () {
    testWidgets('splits wide layout into exact 61.8/38.2 with 12px gap', (
      t,
    ) async {
      final featured = _item(1);
      final mosaic = List.generate(9, (i) => _item(i + 2));
      await _pumpShowcase(t, featured, mosaic, size: const Size(1012, 260));

      final heroRect = t.getRect(find.byType(PopularFeaturedCard));
      final mosaicRect = t.getRect(find.byType(PopularRankMosaic));
      expect(heroRect.width, closeTo(618.0, 0.5));
      expect(mosaicRect.width, closeTo(382.0, 0.5));
      expect(mosaicRect.left - heroRect.right, closeTo(12.0, 0.5));
      expect(heroRect.height, closeTo(260.0, 0.5));
      expect(t.takeException(), isNull);
    });

    testWidgets('stacks vertically on narrow screens without overflow', (
      t,
    ) async {
      final featured = _item(1);
      final mosaic = List.generate(5, (i) => _item(i + 2));
      await _pumpShowcase(t, featured, mosaic, size: const Size(360, 420));

      final heroRect = t.getRect(find.byType(PopularFeaturedCard));
      final mosaicRect = t.getRect(find.byType(PopularRankMosaic));
      expect(mosaicRect.top - heroRect.bottom, closeTo(12.0, 0.5));
      expect(heroRect.width, closeTo(360.0, 0.5));
      expect(mosaicRect.width, closeTo(360.0, 0.5));
      expect(t.takeException(), isNull);
    });

    testWidgets('handles missing featured, missing mosaic, and empty state', (
      t,
    ) async {
      final mosaic = List.generate(4, (i) => _item(i + 2));
      await _pumpShowcase(t, null, mosaic, size: const Size(1012, 240));
      expect(find.byType(PopularFeaturedCard), findsNothing);
      expect(find.byType(PopularRankMosaic), findsOneWidget);
      expect(find.text('暂无热门推荐'), findsOneWidget);

      await _pumpShowcase(t, _item(1), const [], size: const Size(1012, 240));
      expect(find.byType(PopularRankMosaic), findsNothing);
      expect(t.getRect(find.byType(PopularFeaturedCard)).width, 1012.0);

      await _pumpShowcase(t, null, const [], size: const Size(800, 220));
      expect(find.text('暂无热门推荐'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });
}

Future<void> _pumpShowcase(
  WidgetTester t,
  BangumiItem? featured,
  List<BangumiItem> mosaic, {
  required Size size,
}) async {
  t.view.physicalSize = const Size(1280, 720);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);

  await t.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: PopularShowcase(featured: featured, mosaic: mosaic),
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
  ratingScore: 8.8,
  votes: 0,
  votesCount: const <int>[],
  info: '',
);
