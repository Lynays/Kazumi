import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/bangumi/bangumi_tag.dart';
import 'package:kazumi/pages/popular/popular_sections.dart';

void main() {
  group('splitPopularItems boundary counts', () {
    final cases =
        <
          ({
            int count,
            int? featuredId,
            List<int> mosaicIds,
            List<List<int>> rowIds,
          })
        >[
          (count: 0, featuredId: null, mosaicIds: [], rowIds: [[], [], []]),
          (count: 1, featuredId: 1, mosaicIds: [], rowIds: [[], [], []]),
          (
            count: 9,
            featuredId: 1,
            mosaicIds: _range(2, 9),
            rowIds: [[], [], []],
          ),
          (
            count: 10,
            featuredId: 1,
            mosaicIds: _range(2, 10),
            rowIds: [[], [], []],
          ),
          (
            count: 11,
            featuredId: 1,
            mosaicIds: _range(2, 10),
            rowIds: [
              [11],
              [],
              [],
            ],
          ),
          (
            count: 24,
            featuredId: 1,
            mosaicIds: _range(2, 10),
            rowIds: [_range(11, 24), [], []],
          ),
          (
            count: 50,
            featuredId: 1,
            mosaicIds: _range(2, 10),
            rowIds: [_range(11, 30), _range(31, 50), []],
          ),
          (
            count: 69,
            featuredId: 1,
            mosaicIds: _range(2, 10),
            rowIds: [_range(11, 30), _range(31, 50), _range(51, 69)],
          ),
          (
            count: 70,
            featuredId: 1,
            mosaicIds: _range(2, 10),
            rowIds: [_range(11, 30), _range(31, 50), _range(51, 70)],
          ),
          (
            count: 72,
            featuredId: 1,
            mosaicIds: _range(2, 10),
            rowIds: [_range(11, 30), _range(31, 50), _range(51, 70)],
          ),
          (
            count: 100,
            featuredId: 1,
            mosaicIds: _range(2, 10),
            rowIds: [_range(11, 30), _range(31, 50), _range(51, 70)],
          ),
        ];

    for (final c in cases) {
      test('partitions ${c.count} unique items into 1/9/20/20/20', () {
        final input = List<BangumiItem>.generate(c.count, (i) => _item(i + 1));
        final sections = splitPopularItems(input);

        expect(sections.featured?.id, c.featuredId);
        expect(_ids(sections.mosaic), c.mosaicIds);
        expect(sections.rows.length, 3);
        for (var i = 0; i < 3; i++) {
          expect(_ids(sections.rows[i]), c.rowIds[i]);
        }
      });
    }
  });

  group('splitPopularItems deduplication and order preservation', () {
    test('deduplicates stably by id keeping first occurrence', () {
      final first1 = _item(1, nameCn: '第一条');
      final dup1 = _item(1, nameCn: '重复一');
      final first2 = _item(2, nameCn: '第二条');
      final dup2 = _item(2, nameCn: '重复二');
      final third = _item(3, nameCn: '第三条');

      final sections = splitPopularItems([first1, dup1, first2, third, dup2]);

      expect(identical(sections.featured, first1), isTrue);
      expect(sections.mosaic.length, 2);
      expect(identical(sections.mosaic[0], first2), isTrue);
      expect(identical(sections.mosaic[1], third), isTrue);
      expect(sections.rows.every((row) => row.isEmpty), isTrue);
    });

    test('deduplicates before capping at 70 when input has >70 entries', () {
      final input = <BangumiItem>[
        for (var id = 1; id <= 30; id++) _item(id),
        for (var id = 1; id <= 15; id++) _item(id, nameCn: 'dup-$id'),
        for (var id = 31; id <= 75; id++) _item(id),
      ];

      final sections = splitPopularItems(input);
      final all = <BangumiItem>[
        if (sections.featured != null) sections.featured!,
        ...sections.mosaic,
        for (final row in sections.rows) ...row,
      ];

      expect(all.length, 70);
      expect(_ids(all), _range(1, 70));
      expect(_ids(all).toSet().length, 70);
    });

    test(
      'preserves input order instead of sorting by rank, score, or title',
      () {
        final top = _item(101, nameCn: 'Z番', rank: 999, score: 4.1);
        final second = _item(102, nameCn: 'A番', rank: 1, score: 9.8);
        final sameTitle = _item(103, nameCn: 'A番', rank: 2, score: 9.5);

        final sections = splitPopularItems([top, second, sameTitle]);

        expect(sections.featured?.id, 101);
        expect(_ids(sections.mosaic), [102, 103]);
      },
    );
  });

  group('splitPopularItems immutability and isolation', () {
    test('does not mutate input and isolates returned snapshots', () {
      final input = List<BangumiItem>.generate(15, (i) => _item(i + 1));
      final sections = splitPopularItems(input);

      input[0] = _item(999);
      input.removeRange(1, 5);
      input.add(_item(888));

      expect(sections.featured?.id, 1);
      expect(_ids(sections.mosaic), _range(2, 10));
      expect(_ids(sections.rows[0]), _range(11, 15));
      expect(sections.rows[1], isEmpty);
      expect(sections.rows[2], isEmpty);
      expect(() => sections.mosaic.add(_item(777)), throwsUnsupportedError);
      expect(() => sections.rows.add(const []), throwsUnsupportedError);
      for (final row in sections.rows) {
        expect(() => row.add(_item(777)), throwsUnsupportedError);
      }
    });

    test('never shares mutable row lists across calls or empty sections', () {
      final a = splitPopularItems(const []);
      final b = splitPopularItems([_item(1)]);
      const emptyConst = PopularSections(
        featured: null,
        mosaic: [],
        rows: [[], [], []],
      );

      expect(a.rows.length, 3);
      expect(b.rows.length, 3);
      expect(identical(a.rows, b.rows), isFalse);
      expect(identical(a.rows[0], a.rows[1]), isFalse);
      expect(identical(emptyConst.featured, a.featured), isTrue);
    });
  });
}

List<int> _range(int start, int end) =>
    List<int>.generate(end - start + 1, (i) => start + i);

List<int> _ids(List<BangumiItem> items) =>
    items.map((item) => item.id).toList();

BangumiItem _item(int id, {String? nameCn, int rank = 0, double score = 0}) {
  return BangumiItem(
    id: id,
    type: 2,
    name: 'Anime $id',
    nameCn: nameCn ?? '番剧 $id',
    summary: '',
    airDate: '2026-01-01',
    airWeekday: 1,
    rank: rank,
    images: const <String, String>{},
    tags: const <BangumiTag>[],
    alias: const <String>[],
    ratingScore: score,
    votes: 0,
    votesCount: const <int>[],
    info: '',
  );
}
