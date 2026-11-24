import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Rasterizes a procedural Canvas drawing once per key into a small resident
/// GPU [ui.Image], avoiding Skia/Impeller RasterCache invalidation when the
/// painting widget is stretched across resizing viewports.
class CachedProceduralTexture {
  CachedProceduralTexture({required this.width, required this.height})
      : assert(width > 0 && height > 0);

  final int width;
  final int height;

  int? _key;
  ui.Image? _image;

  Rect get sourceRect => Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());

  ui.Image resolve(int key, void Function(Canvas canvas, Size size) paint) {
    final existing = _image;
    if (existing != null && _key == key) {
      return existing;
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    paint(canvas, Size(width.toDouble(), height.toDouble()));
    final picture = recorder.endRecording();
    final nextImage = picture.toImageSync(width, height);
    picture.dispose();

    _key = key;
    _image = nextImage;
    if (existing != null) {
      // Dispose after the current frame submits its new scene so the rasterizer
      // never samples a disposed texture mid-frame.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        existing.dispose();
      });
    }
    return nextImage;
  }
}
