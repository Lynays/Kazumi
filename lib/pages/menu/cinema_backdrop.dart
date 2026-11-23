import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:kazumi/pages/menu/cinema_tokens.dart';

/// 公共影院底板：深色模式绘制预缓存黑红光晕，浅色模式使用默认主题底色。
class CinemaBackdrop extends StatelessWidget {
  const CinemaBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = CinemaPalette.of(context);
    if (!palette.isCinemaDark) {
      return ColoredBox(color: palette.canvas, child: child);
    }

    return Stack(
      children: [
        const Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _CinemaBackdropPainter(),
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

class _CinemaBackdropPainter extends CustomPainter {
  const _CinemaBackdropPainter();

  static final ui.Picture _backdropPicture = _recordBackdrop();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    canvas.scale(size.width, size.height);
    canvas.drawPicture(_backdropPicture);
    canvas.restore();
  }

  /// Records the atmospheric dark-crimson backdrop once in normalized space so
  /// resizing or scrolling never reallocates radial shaders.
  static ui.Picture _recordBackdrop() {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 1, 1),
      Paint()..color = CinemaTokens.darkCanvas,
    );

    // Top-left muted crimson glow.
    _paintGlow(
      canvas,
      Rect.fromCenter(
        center: const Offset(0.14, 0.14),
        width: 0.78,
        height: 0.68,
      ),
      const Color(0x408F1426),
    );
    // Mid-left-of-center deeper crimson warmth.
    _paintGlow(
      canvas,
      Rect.fromCenter(
        center: const Offset(0.32, 0.42),
        width: 0.64,
        height: 0.56,
      ),
      const Color(0x286B1020),
    );
    // Top-right subtle cool night-slate transition.
    _paintGlow(
      canvas,
      Rect.fromCenter(
        center: const Offset(0.86, 0.18),
        width: 0.62,
        height: 0.56,
      ),
      const Color(0x361B2338),
    );
    // Lower ambient wash to soften transition toward carousels.
    _paintGlow(
      canvas,
      Rect.fromCenter(
        center: const Offset(0.58, 0.88),
        width: 0.80,
        height: 0.48,
      ),
      const Color(0x22231629),
    );

    return recorder.endRecording();
  }

  static void _paintGlow(Canvas canvas, Rect bounds, Color color) {
    canvas.save();
    canvas.translate(bounds.center.dx, bounds.center.dy);
    canvas.scale(bounds.width / 2, bounds.height / 2);
    const unit = Rect.fromLTWH(-1, -1, 2, 2);
    canvas.drawOval(
      unit,
      Paint()
        ..shader = RadialGradient(
          radius: 0.5,
          colors: [
            color,
            color.withValues(alpha: color.a * 0.45),
            color.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(unit),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CinemaBackdropPainter oldDelegate) => false;
}
