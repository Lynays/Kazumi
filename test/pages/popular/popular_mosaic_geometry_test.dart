import 'dart:math' as math;
import 'dart:ui' show Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/pages/popular/popular_mosaic_geometry.dart';

void main() {
  final topNineWeights = List<double>.generate(
    9,
    (i) => math.pow(9 - i, 0.7).toDouble(),
  );

  group('PopularMosaicGeometry TOP 2-10 layout invariants', () {
    final viewports = <(Size, double)>[
      (const Size(300, 200), 0.93),
      (const Size(500, 300), 0.95),
      (const Size(800, 200), 0.95),
      (const Size(400, 400), 0.94),
      (const Size(240, 480), 0.93),
    ];

    for (final (size, minRawCoverage) in viewports) {
      test('lays out 9 irregular non-overlapping cards in $size', () {
        const gap = 4.0;
        final rects = PopularMosaicGeometry.layout(
          size,
          topNineWeights,
          gap: gap,
        );

        expect(rects.length, 9);
        expect(rects.first.left, 0);
        expect(rects.first.top, 0);

        for (final rect in rects) {
          _expectFiniteInBounds(rect, size);
        }
        _expectPairwiseSeparated(rects, minGap: gap - 1e-6);

        for (var i = 0; i < rects.length - 1; i++) {
          expect(
            _area(rects[i]),
            greaterThanOrEqualTo(_area(rects[i + 1])),
            reason: 'card $i should be >= card ${i + 1} in $size',
          );
        }

        // Restored raw cells tile 100% of the canvas; raw cards keep high coverage.
        final restoredArea = rects.fold<double>(
          0,
          (sum, r) => sum + _area(_restoreHalfGap(r, size, gap)),
        );
        final rawArea = rects.fold<double>(0, (sum, r) => sum + _area(r));
        final totalArea = size.width * size.height;

        expect(restoredArea / totalArea, closeTo(1.0, 1e-5));
        expect(rawArea / totalArea, greaterThanOrEqualTo(minRawCoverage));

        // Ensure layout is irregular rather than a uniform grid.
        expect(_area(rects.first), greaterThan(_area(rects.last) * 3));
        final distinctSizes = rects
            .map((r) => '${r.width.round()}x${r.height.round()}')
            .toSet();
        expect(distinctSizes.length, greaterThan(4));
      });
    }
  });

  group('PopularMosaicGeometry proportionality, determinism, and isolation', () {
    test('matches exact weight proportions for counts 1..9 with gap = 0', () {
      const size = Size(500, 300);
      final totalArea = size.width * size.height;

      for (var count = 1; count <= 9; count++) {
        final weights = topNineWeights.take(count).toList();
        final weightSum = weights.fold<double>(0, (s, w) => s + w);
        final rects = PopularMosaicGeometry.layout(size, weights, gap: 0);

        expect(rects.length, count);
        _expectPairwiseSeparated(rects, minGap: -1e-9);

        var areaSum = 0.0;
        for (var i = 0; i < count; i++) {
          _expectFiniteInBounds(rects[i], size);
          final area = _area(rects[i]);
          areaSum += area;
          expect(area, closeTo(totalArea * (weights[i] / weightSum), 1e-5));
        }
        expect(areaSum / totalArea, closeTo(1.0, 1e-6));
      }
    });

    test('single item fills the entire container even when gap > 0', () {
      final rects = PopularMosaicGeometry.layout(const Size(500, 300), const [
        5.0,
      ], gap: 8);
      expect(rects, [const Rect.fromLTWH(0, 0, 500, 300)]);
    });

    test(
      'is deterministic, does not mutate input, and returns unmodifiable list',
      () {
        final input = List<double>.from(topNineWeights);
        final first = PopularMosaicGeometry.layout(const Size(500, 300), input);
        final second = PopularMosaicGeometry.layout(
          const Size(500, 300),
          input,
        );

        expect(input, topNineWeights);
        expect(first, second);
        expect(() => first.add(Rect.zero), throwsUnsupportedError);
      },
    );
  });

  group('PopularMosaicGeometry edge cases and validation', () {
    test(
      'returns empty list for empty weights or non-positive/invalid sizes',
      () {
        expect(
          PopularMosaicGeometry.layout(const Size(500, 300), const []),
          isEmpty,
        );
        for (final badSize in const [
          Size.zero,
          Size(-10, 100),
          Size(100, -10),
          Size(double.infinity, 200),
          Size(300, double.nan),
        ]) {
          expect(
            PopularMosaicGeometry.layout(badSize, const [3, 2, 1]),
            isEmpty,
          );
        }
      },
    );

    test(
      'throws ArgumentError on invalid gap or non-positive/non-finite weights',
      () {
        for (final badGap in const [-1.0, double.nan, double.infinity]) {
          expect(
            () => PopularMosaicGeometry.layout(const Size(300, 200), const [
              2,
              1,
            ], gap: badGap),
            throwsArgumentError,
          );
        }
        for (final badWeights in const [
          [0.0],
          [3.0, -1.0],
          [2.0, double.nan],
          [2.0, double.infinity],
        ]) {
          expect(
            () =>
                PopularMosaicGeometry.layout(const Size(300, 200), badWeights),
            throwsArgumentError,
          );
        }
      },
    );

    test('clamps gap safely on tiny positive viewports without overlap', () {
      for (final tinySize in const [Size(6, 6), Size(10, 4)]) {
        final rects = PopularMosaicGeometry.layout(
          tinySize,
          topNineWeights,
          gap: 4,
        );
        expect(rects.length, 9);
        for (final rect in rects) {
          _expectFiniteInBounds(rect, tinySize);
        }
        _expectPairwiseSeparated(rects, minGap: 0);
      }
    });

    test('handles extreme weight magnitudes without overflow or underflow', () {
      for (final extreme in const [
        [1e200, 5e199, 1e199],
        [1e-200, 5e-201, 1e-201],
      ]) {
        final rects = PopularMosaicGeometry.layout(
          const Size(320, 200),
          extreme,
          gap: 0,
        );
        expect(rects.length, 3);
        for (final rect in rects) {
          _expectFiniteInBounds(rect, const Size(320, 200));
        }
        _expectPairwiseSeparated(rects, minGap: -1e-9);
        expect(_area(rects[0]), closeTo(40000, 1e-4));
        expect(_area(rects[1]), closeTo(20000, 1e-4));
        expect(_area(rects[2]), closeTo(4000, 1e-4));
      }
    });
  });
}

double _area(Rect rect) => rect.width * rect.height;

void _expectFiniteInBounds(Rect rect, Size bounds) {
  expect(rect.left.isFinite, isTrue);
  expect(rect.top.isFinite, isTrue);
  expect(rect.right.isFinite, isTrue);
  expect(rect.bottom.isFinite, isTrue);
  expect(rect.width, greaterThan(0));
  expect(rect.height, greaterThan(0));
  expect(rect.left, greaterThanOrEqualTo(0));
  expect(rect.top, greaterThanOrEqualTo(0));
  expect(rect.right, lessThanOrEqualTo(bounds.width + 1e-9));
  expect(rect.bottom, lessThanOrEqualTo(bounds.height + 1e-9));
}

void _expectPairwiseSeparated(List<Rect> rects, {required double minGap}) {
  for (var i = 0; i < rects.length; i++) {
    for (var j = i + 1; j < rects.length; j++) {
      final a = rects[i];
      final b = rects[j];
      final sepX = math.max(a.left - b.right, b.left - a.right);
      final sepY = math.max(a.top - b.bottom, b.top - a.bottom);
      expect(
        math.max(sepX, sepY),
        greaterThanOrEqualTo(minGap),
        reason: 'cards $i ($a) and $j ($b) overlap or violate gap $minGap',
      );
    }
  }
}

Rect _restoreHalfGap(Rect rect, Size bounds, double gap) {
  final half = gap * 0.5;
  return Rect.fromLTRB(
    rect.left <= 1e-6 ? 0.0 : rect.left - half,
    rect.top <= 1e-6 ? 0.0 : rect.top - half,
    (bounds.width - rect.right) <= 1e-6 ? bounds.width : rect.right + half,
    (bounds.height - rect.bottom) <= 1e-6 ? bounds.height : rect.bottom + half,
  );
}
