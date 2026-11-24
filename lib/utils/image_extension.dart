import 'package:flutter/material.dart';

extension ImageExtension on num {
  int cacheSize(BuildContext context, {int bucket = 64}) {
    assert(bucket > 0);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final scaled = this * dpr;
    if (!scaled.isFinite || scaled <= 0) return bucket;
    final rawPx = scaled.round();
    if (rawPx <= 0) return bucket;
    // Quantize upward to fixed physical pixel buckets so continuous window
    // resizing does not miss ImageCache on every 1px delta.
    return ((rawPx + bucket - 1) ~/ bucket) * bucket;
  }
}
