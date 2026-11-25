import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/bangumi/bangumi_tag.dart';
import 'package:kazumi/pages/popular/category_controller.dart';
import 'package:kazumi/utils/constants.dart';

void main() {
  group('CategoryController', () {
    test(
      'advances nextRawOffset by rawCount, deduplicates cross-page IDs, and resets on acceleration toggle',
      () async {
        var useMirror = false;
        final requests = <(String, int, bool)>[];
        final controller = CategoryController(
          mirrorEnabledProvider: () => useMirror,
          pageFetcher: ({
            required tag,
            required limit,
            required offset,
            required useMirror,
          }) async {
            requests.add((tag, offset, useMirror));
            if (!useMirror) {
              // Direct mode returns rawCount=24 even when 4 items lacked nameCn
              // and 2 IDs overlap across pages.
              if (offset == 0) {
                return CategoryPageResult(
                  items: List.generate(20, (i) => _item(i + 1)),
                  rawCount: 24,
                  failed: false,
                );
              }
              return CategoryPageResult(
                items: <BangumiItem>[
                  _item(19),
                  _item(20),
                  ...List.generate(18, (i) => _item(21 + i)),
                ],
                rawCount: 24,
                failed: false,
              );
            }
            return CategoryPageResult(
              items: List.generate(12, (i) => _item(500 + offset + i + 1)),
              rawCount: 12,
              failed: false,
            );
          },
        );

        await controller.loadMoreDetail('日常');
        var feed = controller.feedFor('日常');
        expect(feed.items.length, 20);
        expect(feed.nextRawOffset, 24);
        expect(feed.isExhausted, isFalse);

        await controller.loadMoreDetail('日常');
        feed = controller.feedFor('日常');
        expect(feed.items.length, 38);
        expect(feed.items.map((e) => e.id).toSet().length, 38);
        expect(feed.nextRawOffset, 48);
        expect(requests, [('日常', 0, false), ('日常', 24, false)]);

        // Toggle acceleration mode -> resets cursor and items without mixing offsets.
        useMirror = true;
        await controller.loadMoreDetail('日常');
        feed = controller.feedFor('日常');
        expect(feed.items.length, 12);
        expect(feed.items.first.id, 501);
        expect(feed.nextRawOffset, 12);
        expect(feed.isExhausted, isTrue);
        expect(requests.last, ('日常', 0, true));

        controller.dispose();
      },
    );

    test(
      'supports unlimited detail pagination beyond 70 items with disjoint featured/mosaic/grid slices',
      () async {
        final controller = CategoryController(
          mirrorEnabledProvider: () => true,
          pageFetcher: ({
            required tag,
            required limit,
            required offset,
            required useMirror,
          }) async {
            return CategoryPageResult(
              items: List.generate(limit, (i) => _item(offset + i + 1)),
              rawCount: limit,
              failed: false,
            );
          },
        );

        for (var page = 0; page < 5; page++) {
          await controller.loadMoreDetail('奇幻');
        }

        final feed = controller.feedFor('奇幻');
        expect(feed.items.length, 120);
        expect(feed.featured?.id, 1);
        expect(feed.mosaic.map((e) => e.id).toList(), [2, 3, 4, 5, 6, 7, 8, 9, 10]);
        expect(feed.gridCount, 110);
        final gridIds = List.generate(
          feed.gridCount,
          (i) => feed.items[10 + i].id,
        );
        expect(gridIds.first, 11);
        expect(gridIds.last, 120);
        final topIds = {feed.featured!.id, ...feed.mosaic.map((e) => e.id)};
        expect(topIds.intersection(gridIds.toSet()), isEmpty);

        controller.dispose();
      },
    );

    test(
      'caps concurrent row loads to 2 and preempts queue for active detail tag',
      () async {
        var active = 0;
        var peak = 0;
        final dispatchedOrder = <String>[];
        final gates = <String, Completer<CategoryPageResult>>{};

        final controller = CategoryController(
          tags: defaultAnimeTags,
          maxConcurrentRowLoads: 2,
          mirrorEnabledProvider: () => true,
          pageFetcher: ({
            required tag,
            required limit,
            required offset,
            required useMirror,
          }) {
            active++;
            if (active > peak) peak = active;
            dispatchedOrder.add(tag);
            final gate = Completer<CategoryPageResult>();
            gates[tag] = gate;
            return gate.future.whenComplete(() => active--);
          },
        );

        expect(controller.tags.length, 15);
        final futures = <Future<void>>[];
        for (final tag in defaultAnimeTags) {
          futures.add(controller.ensureRowLoaded(tag));
        }
        expect(peak, 2);
        expect(controller.inFlightCount, 2);
        expect(dispatchedOrder, [defaultAnimeTags[0], defaultAnimeTags[1]]);

        // Opening detail for a queued tag must jump strictly to the front.
        controller.openCategoryDetail('机战');

        // Complete the first in-flight row -> '机战' must dispatch next.
        gates[defaultAnimeTags[0]]!.complete(
          CategoryPageResult(
            items: [_item(1)],
            rawCount: 24,
            failed: false,
          ),
        );
        await Future<void>.delayed(Duration.zero);
        expect(dispatchedOrder[2], '机战');
        expect(peak, 2);

        // Cancel an unstarted queued row and finish everything cleanly.
        controller.cancelPendingRowLoad(defaultAnimeTags[3]);
        while (gates.values.any((c) => !c.isCompleted)) {
          for (final entry in gates.entries.toList()) {
            if (!entry.value.isCompleted) {
              entry.value.complete(
                CategoryPageResult(
                  items: [_item(entry.key.hashCode & 0xFFFF)],
                  rawCount: 24,
                  failed: false,
                ),
              );
            }
          }
          await Future<void>.delayed(Duration.zero);
        }
        await Future.wait(futures);
        expect(peak, lessThanOrEqualTo(2));
        expect(dispatchedOrder.contains(defaultAnimeTags[3]), isFalse);

        controller.dispose();
      },
    );

    test('handles navigation state machine and back stack transitions', () {
      final controller = CategoryController(
        mirrorEnabledProvider: () => true,
        pageFetcher: ({
          required tag,
          required limit,
          required offset,
          required useMirror,
        }) async => CategoryPageResult(
          items: [_item(1)],
          rawCount: 1,
          failed: false,
        ),
      );

      expect(controller.mode, PopularBrowseMode.home);
      expect(controller.handleBack(), isFalse);

      controller.openCategoryOverview();
      expect(controller.mode, PopularBrowseMode.categoryOverview);
      expect(controller.isCategoryActive, isTrue);

      controller.openCategoryDetail('校园');
      expect(controller.mode, PopularBrowseMode.categoryDetail);
      expect(controller.activeTag, '校园');

      expect(controller.handleBack(), isTrue);
      expect(controller.mode, PopularBrowseMode.categoryOverview);
      expect(controller.activeTag, isEmpty);

      expect(controller.handleBack(), isTrue);
      expect(controller.mode, PopularBrowseMode.home);
      expect(controller.isCategoryActive, isFalse);

      controller.dispose();
    });

    testWidgets('resolves CategoryController from Modular singleton without int DI errors', (
      t,
    ) async {
      CategoryController? resolved;
      final testRoot = createModule(
        register: (c) {
          c
            ..addSingleton<CategoryController>(() => CategoryController())
            ..route(
              '/probe',
              child: (_, _) {
                resolved = inject<CategoryController>();
                return const SizedBox.shrink();
              },
            );
        },
      );

      await t.pumpWidget(
        ModularApp(
          key: UniqueKey(),
          module: testRoot,
          initialRoute: '/probe',
          child: Builder(
            builder: (ctx) => WidgetsApp.router(
              color: const Color(0xFF000000),
              routerConfig: ModularApp.routerConfigOf(ctx),
            ),
          ),
        ),
      );
      await t.pump();

      expect(resolved, isNotNull);
      expect(resolved!.tags, defaultAnimeTags);
      expect(t.takeException(), isNull);
    });

    test(
      'queues a new-generation replacement fetch when acceleration toggles during an in-flight detail page',
      () async {
        var useMirror = false;
        final requests = <(String, int, bool)>[];
        final stalePage2Gate = Completer<CategoryPageResult>();
        final replacementGate = Completer<CategoryPageResult>();

        final controller = CategoryController(
          mirrorEnabledProvider: () => useMirror,
          pageFetcher: ({
            required tag,
            required limit,
            required offset,
            required useMirror,
          }) async {
            requests.add((tag, offset, useMirror));
            if (!useMirror && offset == 0) {
              return CategoryPageResult(
                items: List.generate(24, (i) => _item(i + 1)),
                rawCount: 24,
                failed: false,
              );
            }
            if (!useMirror && offset == 24) {
              return stalePage2Gate.future;
            }
            return replacementGate.future;
          },
        );

        // 1. Populate page 1 under direct mode.
        await controller.loadMoreDetail('日常');
        expect(controller.feedFor('日常').items.length, 24);
        expect(controller.feedFor('日常').lastUseMirror, isFalse);

        // 2. Start page 2 (in-flight under direct mode).
        final stalePage2Future = controller.loadMoreDetail('日常');
        expect(controller.inFlightCount, 1);

        // 3. Toggle acceleration mode while page 2 is still in-flight and reopen detail.
        useMirror = true;
        controller.openCategoryDetail('日常');
        final resetFeed = controller.feedFor('日常');
        expect(resetFeed.items, isEmpty);
        expect(resetFeed.isLoading, isTrue);
        expect(resetFeed.hasError, isFalse);

        // Additional detail loadMore calls while stale drains share the replacement future.
        var replacementResolved = false;
        final replacementFuture = controller
            .loadMoreDetail('日常')
            .whenComplete(() => replacementResolved = true);

        // 4. Stale page 2 finishes -> discarded, replacement mirror fetch dispatches immediately.
        stalePage2Gate.complete(
          CategoryPageResult(
            items: List.generate(24, (i) => _item(100 + i)),
            rawCount: 24,
            failed: false,
          ),
        );
        await stalePage2Future;
        await Future<void>.delayed(Duration.zero);

        expect(replacementResolved, isFalse);
        expect(requests, [
          ('日常', 0, false),
          ('日常', 24, false),
          ('日常', 0, true),
        ]);
        expect(controller.feedFor('日常').items, isEmpty);
        expect(controller.feedFor('日常').isLoading, isTrue);

        // 5. Replacement mirror fetch completes -> feed populated cleanly.
        replacementGate.complete(
          CategoryPageResult(
            items: List.generate(12, (i) => _item(500 + i + 1)),
            rawCount: 12,
            failed: false,
          ),
        );
        await replacementFuture;

        final finalFeed = controller.feedFor('日常');
        expect(replacementResolved, isTrue);
        expect(finalFeed.items.length, 12);
        expect(finalFeed.items.first.id, 501);
        expect(finalFeed.lastUseMirror, isTrue);
        expect(finalFeed.isLoading, isFalse);
        expect(finalFeed.hasError, isFalse);

        controller.dispose();
      },
    );

    test(
      'queues and can cancel a stale overview replacement fetch when acceleration toggles mid-load',
      () async {
        var useMirror = false;
        final requests = <(String, int, bool)>[];
        final staleGate = Completer<CategoryPageResult>();

        final controller = CategoryController(
          mirrorEnabledProvider: () => useMirror,
          pageFetcher: ({
            required tag,
            required limit,
            required offset,
            required useMirror,
          }) async {
            requests.add((tag, offset, useMirror));
            if (!useMirror) {
              return staleGate.future;
            }
            return CategoryPageResult(
              items: [_item(901)],
              rawCount: 1,
              failed: false,
            );
          },
        );

        final firstLoad = controller.ensureRowLoaded('恋爱');
        expect(controller.inFlightCount, 1);

        // Toggle acceleration while first overview fetch is still in-flight.
        useMirror = true;
        final replacement = controller.ensureRowLoaded('恋爱');
        expect(controller.feedFor('恋爱').isLoading, isTrue);

        // Scrolling the overview row away cancels the queued replacement cleanly.
        controller.cancelPendingRowLoad('恋爱');
        await replacement;
        expect(controller.feedFor('恋爱').isLoading, isFalse);

        // When the stale request finishes, it is discarded and no replacement runs.
        staleGate.complete(
          CategoryPageResult(
            items: [_item(1)],
            rawCount: 1,
            failed: false,
          ),
        );
        await firstLoad;
        await Future<void>.delayed(Duration.zero);

        expect(requests, [('恋爱', 0, false)]);
        expect(controller.feedFor('恋爱').items, isEmpty);
        expect(controller.feedFor('恋爱').isLoading, isFalse);

        controller.dispose();
      },
    );
  });
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
  ratingScore: 8.5,
  votes: 100,
  votesCount: const <int>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
  info: '',
);
