import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kazumi/bean/settings/visual_effects_config.dart';
import 'package:kazumi/bean/widget/cached_procedural_texture.dart';

class PopularCarouselFloor extends StatelessWidget {
  const PopularCarouselFloor({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final effects = VisualEffectsConfig.of(context);
    final floorScale = effects.floorLightScale;
    if (Theme.of(context).brightness != Brightness.dark || floorScale <= 0) {
      return child;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _CarouselFloorPainter(
                percent: effects.floorLightPercent,
                scale: floorScale,
              ),
              isComplex: true,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _CarouselFloorPainter extends CustomPainter {
  const _CarouselFloorPainter({
    required this.percent,
    required this.scale,
  });

  final int percent;
  final double scale;

  static final CachedProceduralTexture _texture = CachedProceduralTexture(
    width: 320,
    height: 180,
  );
  static final Paint _blitPaint = Paint()..filterQuality = FilterQuality.low;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final image = _texture.resolve(
      percent,
      (offscreen, textureSize) => _paintFloor(offscreen, textureSize, scale),
    );
    canvas.drawImageRect(
      image,
      _texture.sourceRect,
      Offset.zero & size,
      _blitPaint,
    );
  }

  // Rasterize all 159 radial floor washes once per strength level into a fixed
  // 320x180 GPU texture so window resizing only scales one texture.
  static void _paintFloor(Canvas canvas, Size size, double scale) {
    canvas.save();
    canvas.scale(size.width, size.height);
    Color scaled(Color color) =>
        color.withValues(alpha: (color.a * scale).clamp(0.0, 1.0));

    _wash(
      canvas,
      Rect.fromCenter(
        center: const Offset(0.25, 0.26),
        width: 0.30,
        height: 0.27,
      ),
      scaled(const Color(0x50613B61)),
    );
    _wash(
      canvas,
      Rect.fromCenter(
        center: const Offset(0.74, 0.46),
        width: 0.32,
        height: 0.23,
      ),
      scaled(const Color(0x48744255)),
    );
    _wash(
      canvas,
      Rect.fromCenter(
        center: const Offset(0.46, 0.88),
        width: 0.49,
        height: 0.24,
      ),
      scaled(const Color(0x52544B78)),
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
        final alpha =
            ((0.04 + random.nextDouble() * 0.08) * (1 - drift.abs()) * scale)
                .clamp(0.0, 1.0);
        _wash(
          canvas,
          Rect.fromCenter(
            center: center,
            width: (0.008 + random.nextDouble() * 0.057) * distance,
            height: (0.003 + random.nextDouble() * 0.011) * distance,
          ),
          tint.withValues(alpha: alpha),
        );
      }
    }
    canvas.restore();
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
  bool shouldRepaint(_CarouselFloorPainter oldDelegate) =>
      oldDelegate.percent != percent;
}
