import 'dart:math' as math;

import 'package:kazumi/modules/bangumi/bangumi_item.dart';

const int _featuredCount = 1;
const int _mosaicCount = 9;
const int _rowSize = 20;
const int _rowCount = 3;
const int _maxPopularItems =
    _featuredCount + _mosaicCount + _rowSize * _rowCount;

/// Partitioned snapshot of the popular anime trend list (at most 70 unique items).
class PopularSections {
  const PopularSections({
    required this.featured,
    required this.mosaic,
    required this.rows,
  });

  /// TOP 1 item, or `null` when no popular items are available.
  final BangumiItem? featured;

  /// TOP 2-10 items (length 0..9).
  final List<BangumiItem> mosaic;

  /// Always contains 3 rows corresponding to TOP 11-30, 31-50, and 51-70.
  final List<List<BangumiItem>> rows;
}

/// Deduplicates [items] stably by [BangumiItem.id] in input order, takes at most
/// 70 entries, and splits them into 1 / 9 / 20 / 20 / 20 unmodifiable sections.
PopularSections splitPopularItems(List<BangumiItem> items) {
  final seenIds = <int>{};
  final unique = <BangumiItem>[];
  for (final item in items) {
    if (seenIds.add(item.id)) {
      unique.add(item);
      if (unique.length == _maxPopularItems) {
        break;
      }
    }
  }

  const rowsStart = _featuredCount + _mosaicCount;
  final rows = List<List<BangumiItem>>.unmodifiable(
    List<List<BangumiItem>>.generate(_rowCount, (rowIndex) {
      final start = rowsStart + rowIndex * _rowSize;
      return _unmodifiableSlice(unique, start, start + _rowSize);
    }, growable: false),
  );

  return PopularSections(
    featured: unique.isEmpty ? null : unique.first,
    mosaic: _unmodifiableSlice(unique, _featuredCount, rowsStart),
    rows: rows,
  );
}

List<BangumiItem> _unmodifiableSlice(
  List<BangumiItem> source,
  int start,
  int end,
) {
  if (start >= source.length || end <= start) {
    return List<BangumiItem>.unmodifiable(const <BangumiItem>[]);
  }
  final clampedEnd = math.min(end, source.length);
  return List<BangumiItem>.unmodifiable(source.getRange(start, clampedEnd));
}
