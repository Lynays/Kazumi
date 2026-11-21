import 'dart:math' as math;
import 'dart:ui' show Rect, Size;

/// Pure geometry layout engine for the Popular A.2 TOP 2-10 weighted mosaic.
abstract final class PopularMosaicGeometry {
  static const double _edgeEpsilon = 1e-6;

  /// Computes deterministic, non-overlapping rectangles inside [size] whose
  /// areas are proportional to [weights] while preserving input order.
  ///
  /// Throws an [ArgumentError] if [gap] is negative or non-finite, or if any
  /// entry in [weights] is non-positive or non-finite. Returns an empty
  /// unmodifiable list when [weights] is empty or [size] has non-positive or
  /// non-finite dimensions.
  static List<Rect> layout(Size size, List<double> weights, {double gap = 4}) {
    if (!gap.isFinite || gap < 0) {
      throw ArgumentError.value(gap, 'gap', 'Must be finite and >= 0.');
    }
    for (var i = 0; i < weights.length; i++) {
      final w = weights[i];
      if (!w.isFinite || w <= 0) {
        throw ArgumentError.value(w, 'weights[$i]', 'Must be finite and > 0.');
      }
    }

    if (weights.isEmpty ||
        !size.width.isFinite ||
        !size.height.isFinite ||
        size.width <= 0 ||
        size.height <= 0) {
      return const <Rect>[];
    }

    final totalArea = size.width * size.height;
    if (!totalArea.isFinite || totalArea <= 0) {
      return const <Rect>[];
    }

    if (weights.length == 1) {
      return List<Rect>.unmodifiable(<Rect>[
        Rect.fromLTWH(0, 0, size.width, size.height),
      ]);
    }

    final areas = _scaleWeightsToAreas(weights, totalArea);
    final rawRects = _squarify(size, areas);
    return _applyInteriorGap(size, rawRects, gap);
  }

  static List<double> _scaleWeightsToAreas(
    List<double> weights,
    double totalArea,
  ) {
    var maxWeight = weights.first;
    for (var i = 1; i < weights.length; i++) {
      if (weights[i] > maxWeight) {
        maxWeight = weights[i];
      }
    }

    var normalizedSum = 0.0;
    final normalized = List<double>.generate(weights.length, (i) {
      final value = weights[i] / maxWeight;
      normalizedSum += value;
      return value;
    }, growable: false);

    return List<double>.generate(
      normalized.length,
      (i) => totalArea * (normalized[i] / normalizedSum),
      growable: false,
    );
  }

  static List<Rect> _squarify(Size size, List<double> areas) {
    final rects = List<Rect>.filled(areas.length, Rect.zero, growable: false);
    var remLeft = 0.0;
    var remTop = 0.0;
    final remRight = size.width;
    final remBottom = size.height;

    var start = 0;
    while (start < areas.length) {
      final remWidth = remRight - remLeft;
      final remHeight = remBottom - remTop;
      final isVertical = remWidth >= remHeight;
      final side = isVertical ? remHeight : remWidth;

      var remainingSum = 0.0;
      for (var i = start; i < areas.length; i++) {
        remainingSum += areas[i];
      }

      var end = start + 1;
      var stripSum = areas[start];
      var currentWorst = _worstAspectRatio(areas, start, end, stripSum, side);
      while (end < areas.length) {
        final candidateSum = stripSum + areas[end];
        final candidateWorst = _worstAspectRatio(
          areas,
          start,
          end + 1,
          candidateSum,
          side,
        );
        if (candidateWorst > currentWorst) {
          break;
        }
        stripSum = candidateSum;
        currentWorst = candidateWorst;
        end++;
      }

      final isLastStrip = end == areas.length;
      final ratio = remainingSum > 0
          ? (stripSum / remainingSum).clamp(0.0, 1.0)
          : 1.0;

      if (isVertical) {
        final stripRight = isLastStrip ? remRight : remLeft + remWidth * ratio;
        var cursorY = remTop;
        for (var i = start; i < end; i++) {
          final itemBottom = (i == end - 1)
              ? remBottom
              : cursorY + remHeight * (areas[i] / stripSum);
          rects[i] = Rect.fromLTRB(remLeft, cursorY, stripRight, itemBottom);
          cursorY = itemBottom;
        }
        remLeft = stripRight;
      } else {
        final stripBottom = isLastStrip
            ? remBottom
            : remTop + remHeight * ratio;
        var cursorX = remLeft;
        for (var i = start; i < end; i++) {
          final itemRight = (i == end - 1)
              ? remRight
              : cursorX + remWidth * (areas[i] / stripSum);
          rects[i] = Rect.fromLTRB(cursorX, remTop, itemRight, stripBottom);
          cursorX = itemRight;
        }
        remTop = stripBottom;
      }

      start = end;
    }

    return rects;
  }

  static double _worstAspectRatio(
    List<double> areas,
    int start,
    int end,
    double stripSum,
    double side,
  ) {
    if (stripSum <= 0 || side <= 0) {
      return double.infinity;
    }
    final thickness = stripSum / side;
    if (thickness <= 0) {
      return double.infinity;
    }
    var worst = 0.0;
    for (var i = start; i < end; i++) {
      final length = side * (areas[i] / stripSum);
      if (length <= 0) {
        return double.infinity;
      }
      final ratio = math.max(length / thickness, thickness / length);
      if (ratio > worst) {
        worst = ratio;
      }
    }
    return worst;
  }

  static List<Rect> _applyInteriorGap(
    Size size,
    List<Rect> rawRects,
    double gap,
  ) {
    if (gap == 0) {
      return List<Rect>.unmodifiable(rawRects);
    }

    final epsX = math.min(_edgeEpsilon, size.width * 1e-4);
    final epsY = math.min(_edgeEpsilon, size.height * 1e-4);

    var effectiveGap = gap;
    for (final rect in rawRects) {
      final xEdges =
          (rect.left <= epsX ? 0.0 : 0.5) +
          ((size.width - rect.right) <= epsX ? 0.0 : 0.5);
      final yEdges =
          (rect.top <= epsY ? 0.0 : 0.5) +
          ((size.height - rect.bottom) <= epsY ? 0.0 : 0.5);
      if (xEdges > 0) {
        effectiveGap = math.min(effectiveGap, (rect.width * 0.5) / xEdges);
      }
      if (yEdges > 0) {
        effectiveGap = math.min(effectiveGap, (rect.height * 0.5) / yEdges);
      }
    }

    final halfGap = effectiveGap * 0.5;
    return List<Rect>.unmodifiable(
      List<Rect>.generate(rawRects.length, (i) {
        final rect = rawRects[i];
        final left = rect.left <= epsX ? 0.0 : rect.left + halfGap;
        final top = rect.top <= epsY ? 0.0 : rect.top + halfGap;
        final right = (size.width - rect.right) <= epsX
            ? size.width
            : rect.right - halfGap;
        final bottom = (size.height - rect.bottom) <= epsY
            ? size.height
            : rect.bottom - halfGap;
        return Rect.fromLTRB(left, top, right, bottom);
      }, growable: false),
    );
  }
}
