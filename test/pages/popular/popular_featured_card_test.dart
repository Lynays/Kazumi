import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/bangumi/bangumi_tag.dart';
import 'package:kazumi/pages/popular/popular_featured_card.dart';

void main() {
  group('PopularFeaturedCard', () {
    testWidgets('renders TOP 1 badge, title, score, summary and cover', (
      t,
    ) async {
      final item = _item(
        1,
        name: 'Original Title',
        nameCn: '葬送的芙莉莲',
        summary: '勇者一行打倒魔王之后\n的故事。',
        score: 9.2,
        images: const {'large': 'https://example.com/frieren.jpg'},
      );
      await _pumpCard(t, item);

      expect(find.text('TOP 1'), findsOneWidget);
      expect(find.text('当前热门'), findsOneWidget);
      expect(find.textContaining('今日第一'), findsNothing);
      expect(find.text('葬送的芙莉莲'), findsOneWidget);
      expect(find.text('9.2'), findsOneWidget);
      expect(find.text('勇者一行打倒魔王之后 的故事。'), findsOneWidget);
      expect(find.text('查看详情'), findsOneWidget);

      final imgs = t.widgetList<NetworkImgLayer>(find.byType(NetworkImgLayer));
      expect(imgs.length, 1);
      expect(imgs.first.src, 'https://example.com/frieren.jpg');
      expect(find.byType(ShaderMask), findsWidgets);
    });

    testWidgets('falls back when image, nameCn, score and summary miss', (
      t,
    ) async {
      final item = _item(2, name: 'Fallback Anime Title', nameCn: '');
      await _pumpCard(t, item, size: const Size(360, 190));

      expect(find.text('Fallback Anime Title'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsNothing);
      expect(
        t.widget<NetworkImgLayer>(find.byType(NetworkImgLayer)).src,
        isEmpty,
      );
      expect(t.takeException(), isNull);
    });

    testWidgets('handles extra-long title and tight height cleanly', (t) async {
      final item = _item(
        3,
        nameCn: '这是一段非常非常非常长的动画标题用于验证在桌面窄容器和紧凑高度下不会发生布局溢出' * 2,
        summary: '简介内容' * 20,
        score: 8.4,
      );
      await _pumpCard(t, item, size: const Size(320, 130));

      expect(find.text('TOP 1'), findsOneWidget);
      expect(find.text('查看详情'), findsOneWidget);
      expect(t.takeException(), isNull);

      await _pumpCard(t, item, size: const Size(320, 120));
      expect(find.text('TOP 1'), findsOneWidget);
      expect(find.text('8.4'), findsOneWidget);
      expect(find.text('查看详情'), findsNothing);
      expect(t.takeException(), isNull);

      await _pumpCard(t, item, size: const Size(320, 96));
      expect(find.text('TOP 1'), findsOneWidget);
      expect(find.text('查看详情'), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('exposes semantics and pushes /info/ on tap', (t) async {
      final semantics = t.ensureSemantics();
      addTearDown(semantics.dispose);

      final item = _item(42, nameCn: '孤独摇滚！', score: 8.9);
      Object? pushedArgs;
      await _pumpCard(
        t,
        item,
        size: const Size(600, 240),
        onInfo: (args) => pushedArgs = args,
      );

      final node = t.getSemantics(find.byType(PopularFeaturedCard));
      expect(node.label, contains('当前热门 TOP 1，孤独摇滚！'));

      await t.tap(find.byType(InkWell));
      await t.pumpAndSettle();
      expect(identical(pushedArgs, item), isTrue);
      expect(find.text('info-route'), findsOneWidget);
    });
  });
}

Future<void> _pumpCard(
  WidgetTester tester,
  BangumiItem item, {
  Size size = const Size(640, 260),
  void Function(Object?)? onInfo,
}) async {
  final box = SizedBox(
    width: size.width,
    height: size.height,
    child: PopularFeaturedCard(item: item),
  );
  final module = createModule(
    register: (c) => c
      ..route(
        '/',
        child: (_, _) => Scaffold(body: Center(child: box)),
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
      module: module,
      child: Builder(
        builder: (ctx) =>
            MaterialApp.router(routerConfig: ModularApp.routerConfigOf(ctx)),
      ),
    ),
  );
}

BangumiItem _item(
  int id, {
  String name = 'Anime',
  String nameCn = '测试番剧',
  String summary = '',
  double score = 0,
  Map<String, String> images = const {},
}) => BangumiItem(
  id: id,
  type: 2,
  name: name,
  nameCn: nameCn,
  summary: summary,
  airDate: '2026-01-01',
  airWeekday: 1,
  rank: 0,
  images: images,
  tags: const <BangumiTag>[],
  alias: const <String>[],
  ratingScore: score,
  votes: 0,
  votesCount: const <int>[],
  info: '',
);
