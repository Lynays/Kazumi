import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/bangumi/bangumi_tag.dart';
import 'package:kazumi/pages/popular/popular_carousel_region.dart';
import 'package:kazumi/pages/popular/popular_dashboard.dart';
import 'package:kazumi/pages/popular/popular_featured_card.dart';
import 'package:kazumi/pages/popular/popular_sections.dart';

void main() {
  group('PopularDashboard', () {
    testWidgets(
      'splits desktop viewport into 1/3 showcase, 12dp gap, and 2/3 carousels',
      (t) async {
        final sections = splitPopularItems(
          List.generate(70, (i) => _item(i + 1)),
        );
        await _pumpDashboard(t, sections, size: const Size(1280, 732));

        final heroRect = t.getRect(find.byType(PopularFeaturedCard));
        final carouselRect = t.getRect(find.byType(PopularCarouselRegion));
        expect(heroRect.height, closeTo(240.0, 0.5));
        expect(carouselRect.height, closeTo(480.0, 0.5));
        expect(carouselRect.top - heroRect.bottom, closeTo(12.0, 0.5));
        expect(_verticalScrollPosition(t).maxScrollExtent, 0.0);
        expect(t.takeException(), isNull);
      },
    );

    testWidgets(
      'fits mid-height desktop without scrollbar and scrolls on short viewport',
      (t) async {
        final sections = splitPopularItems(
          List.generate(70, (i) => _item(i + 1)),
        );
        await _pumpDashboard(t, sections, size: const Size(1280, 600));

        final heroRect = t.getRect(find.byType(PopularFeaturedCard));
        final carouselRect = t.getRect(find.byType(PopularCarouselRegion));
        expect(heroRect.height, closeTo(200.0, 0.5));
        expect(carouselRect.height, closeTo(388.0, 0.5));
        expect(_verticalScrollPosition(t).maxScrollExtent, 0.0);
        expect(t.takeException(), isNull);

        await _pumpDashboard(t, sections, size: const Size(1080, 300));
        final pos = _verticalScrollPosition(t);
        expect(pos.maxScrollExtent, closeTo(116.0, 0.5));

        await t.drag(find.byType(SingleChildScrollView), const Offset(0, -100));
        await t.pump();
        expect(pos.pixels, greaterThan(0.0));
        expect(t.takeException(), isNull);
      },
    );

    testWidgets(
      'handles narrow viewport, empty sections, and non-finite viewportHeight',
      (t) async {
        final sections = splitPopularItems(
          List.generate(70, (i) => _item(i + 1)),
        );
        await _pumpDashboard(t, sections, size: const Size(480, 700));
        expect(find.byType(PopularDashboard), findsOneWidget);
        expect(t.takeException(), isNull);

        final empty = splitPopularItems(const <BangumiItem>[]);
        await _pumpDashboard(t, empty, size: const Size(1080, 640));
        expect(find.text('暂无热门推荐'), findsOneWidget);
        expect(t.takeException(), isNull);

        for (final badHeight in const [double.infinity, double.nan, -50.0]) {
          await _pumpDashboard(
            t,
            sections,
            size: const Size(1080, 640),
            viewportHeight: badHeight,
          );
          expect(find.byType(PopularDashboard), findsOneWidget);
          expect(t.takeException(), isNull);
        }
      },
    );

    testWidgets('uses the outer scroll view when hosted in a sliver', (
      t,
    ) async {
      final outer = ScrollController();
      addTearDown(outer.dispose);
      final sections = splitPopularItems(
        List.generate(70, (i) => _item(i + 1)),
      );
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 780,
                height: 300,
                child: CustomScrollView(
                  controller: outer,
                  slivers: [
                    SliverToBoxAdapter(
                      child: PopularDashboard(
                        sections: sections,
                        viewportHeight: 300,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(SingleChildScrollView), findsNothing);
      expect(outer.position.maxScrollExtent, closeTo(116, 0.5));
      await t.drag(find.byType(CustomScrollView), const Offset(0, -100));
      await t.pump();
      expect(outer.offset, greaterThan(0.0));
      expect(t.takeException(), isNull);
    });
  });
}

ScrollPosition _verticalScrollPosition(WidgetTester t) {
  final scrollable = t.state<ScrollableState>(
    find
        .descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  expect(scrollable.position.axis, Axis.vertical);
  return scrollable.position;
}

Future<void> _pumpDashboard(
  WidgetTester t,
  PopularSections sections, {
  required Size size,
  double? viewportHeight,
}) async {
  t.view.physicalSize = const Size(1440, 900);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);

  await t.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: PopularDashboard(
              sections: sections,
              viewportHeight: viewportHeight ?? size.height,
            ),
          ),
        ),
      ),
    ),
  );
  await t.pump();
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
  ratingScore: 8.7,
  votes: 0,
  votesCount: const <int>[],
  info: '',
);
