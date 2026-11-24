import 'package:flutter/material.dart';
import 'package:kazumi/bean/settings/visual_effects_config.dart';
import 'package:kazumi/bean/widget/cached_procedural_texture.dart';
import 'package:kazumi/pages/menu/cinema_tokens.dart';

/// 公共影院底板：深色模式绘制预光栅化黑红光晕纹理，浅色模式使用默认主题底色。
class CinemaBackdrop extends StatelessWidget {
  const CinemaBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = CinemaPalette.of(context);
    final effects = VisualEffectsConfig.of(context);
    final glowScale = effects.backdropGlowScale;
    if (!palette.isCinemaDark || glowScale <= 0) {
      return ColoredBox(color: palette.canvas, child: child);
    }

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _CinemaBackdropPainter(
                percent: effects.backdropGlowPercent,
                scale: glowScale,
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

class _CinemaBackdropPainter extends CustomPainter {
  const _CinemaBackdropPainter({
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
      (offscreen, textureSize) => _paintBackdrop(offscreen, textureSize, scale),
    );
    canvas.drawImageRect(
      image,
      _texture.sourceRect,
      Offset.zero & size,
      _blitPaint,
    );
  }

  /// Rasterizes the atmospheric dark-crimson backdrop once per strength level
  /// into a fixed 320x180 GPU texture so resizing only scales a single image.
  static void _paintBackdrop(Canvas canvas, Size size, double scale) {
    canvas.save();
    canvas.scale(size.width, size.height);

    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 1, 1),
      Paint()..color = CinemaTokens.darkCanvas,
    );

    Color scaled(Color color) =>
        color.withValues(alpha: (color.a * scale).clamp(0.0, 1.0));

    // Top-left muted crimson glow.
    _paintGlow(
      canvas,
      Rect.fromCenter(
        center: const Offset(0.14, 0.14),
        width: 0.78,
        height: 0.68,
      ),
      scaled(const Color(0x408F1426)),
    );
    // Mid-left-of-center deeper crimson warmth.
    _paintGlow(
      canvas,
      Rect.fromCenter(
        center: const Offset(0.32, 0.42),
        width: 0.64,
        height: 0.56,
      ),
      scaled(const Color(0x286B1020)),
    );
    // Top-right subtle cool night-slate transition.
    _paintGlow(
      canvas,
      Rect.fromCenter(
        center: const Offset(0.86, 0.18),
        width: 0.62,
        height: 0.56,
      ),
      scaled(const Color(0x361B2338)),
    );
    // Lower ambient wash to soften transition toward carousels.
    _paintGlow(
      canvas,
      Rect.fromCenter(
        center: const Offset(0.58, 0.88),
        width: 0.80,
        height: 0.48,
      ),
      scaled(const Color(0x22231629)),
    );

    canvas.restore();
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
  bool shouldRepaint(covariant _CinemaBackdropPainter oldDelegate) =>
      oldDelegate.percent != percent;
}
