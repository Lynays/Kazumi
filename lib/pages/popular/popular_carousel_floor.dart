import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class PopularCarouselFloor extends StatelessWidget {
  const PopularCarouselFloor({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).brightness != Brightness.dark) return child;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _CarouselFloorPainter(),
                isComplex: true,
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _CarouselFloorPainter extends CustomPainter {
  const _CarouselFloorPainter();

  static final ui.Picture _floorPicture = _recordFloor();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width, size.height);
    canvas.drawPicture(_floorPicture);
    canvas.restore();
  }

  // Record the gradients once in normalized coordinates so the same picture
  // can be replayed at different viewport sizes.
  static ui.Picture _recordFloor() {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    _wash(
      canvas,
      Rect.fromCenter(
        center: const Offset(0.25, 0.26),
        width: 0.30,
        height: 0.27,
      ),
      const Color(0x50613B61),
    );
    _wash(
      canvas,
      Rect.fromCenter(
        center: const Offset(0.74, 0.46),
        width: 0.32,
        height: 0.23,
      ),
      const Color(0x48744255),
    );
    _wash(
      canvas,
      Rect.fromCenter(
        center: const Offset(0.46, 0.88),
        width: 0.49,
        height: 0.24,
      ),
      const Color(0x52544B78),
    );
    // Reflected light breaks into wider patches toward the viewer.
    final random = math.Random(31);
    for (final source in const [
      Offset(0.18, 0.24),
      Offset(0.57, 0.28),
      Offset(0.78, 0.54),
      Offset(0.32, 0.57),
      Offset(0.23, 0.86),
      Offset(0.68, 0.85),
    ]) {
      for (var i = 0; i < 26; i++) {
        final drift = random.nextDouble() - random.nextDouble();
        final spread = random.nextDouble() - random.nextDouble();
        final distance = 0.6 + source.dy;
        final center = Offset(
          source.dx + drift * 0.095 * distance,
          source.dy + spread * 0.053 * distance,
        );
        final tint = source.dx < 0.4
            ? const Color(0xFF935264)
            : const Color(0xFF776994);
        _wash(
          canvas,
          Rect.fromCenter(
            center: center,
            width: (0.008 + random.nextDouble() * 0.057) * distance,
            height: (0.003 + random.nextDouble() * 0.011) * distance,
          ),
          tint.withValues(
            alpha: (0.04 + random.nextDouble() * 0.08) * (1 - drift.abs()),
          ),
        );
      }
    }
    return recorder.endRecording();
  }

  static void _wash(Canvas canvas, Rect bounds, Color color) {
    canvas.save();
    canvas.translate(bounds.center.dx, bounds.center.dy);
    canvas.scale(bounds.width / 2, bounds.height / 2);
    const pool = Rect.fromLTWH(-1, -1, 2, 2);
    canvas.drawOval(
      pool,
      Paint()
        ..shader = RadialGradient(
          radius: 0.5,
          colors: [
            color,
            color.withValues(alpha: color.a * 0.52),
            color.withValues(alpha: 0),
          ],
          stops: const [0, 0.48, 1],
        ).createShader(pool),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CarouselFloorPainter oldDelegate) => false;
}
