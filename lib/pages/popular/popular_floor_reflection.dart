import 'package:flutter/material.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:kazumi/bean/settings/visual_effects_config.dart';
import 'package:kazumi/bean/widget/window_resize_scope.dart';

class PopularFloorReflection extends StatelessWidget {
  const PopularFloorReflection({
    super.key,
    required this.cover,
    required this.size,
    required this.depth,
    this.foreground = false,
  });

  final String cover;
  final Size size;
  final double depth;
  final bool foreground;

  static final Map<int, ShaderCallback> _fadeCache = <int, ShaderCallback>{};

  static ShaderCallback _fadeFor({
    required bool foreground,
    required bool isDark,
    required int percent,
    required double scale,
  }) {
    final key = percent * 4 + (foreground ? 2 : 0) + (isDark ? 1 : 0);
    return _fadeCache.putIfAbsent(key, () {
      final base = foreground
          ? (isDark ? 0.46 : 0.19)
          : (isDark ? 0.27 : 0.09);
      return _makeFade((base * scale).clamp(0.0, 1.0));
    });
  }

  @override
  Widget build(BuildContext context) {
    if (size.isEmpty || depth <= 0) return const SizedBox.shrink();
    final effects = VisualEffectsConfig.of(context);
    final scale = effects.reflectionScale;
    final isResizing = WindowResizeScope.isResizingOf(context);
    if (cover.isEmpty || scale <= 0 || isResizing) {
      return SizedBox(width: size.width, height: depth);
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fade = _fadeFor(
      foreground: foreground,
      isDark: isDark,
      percent: effects.reflectionPercent,
      scale: scale,
    );
    final mirror = ClipRect(
      child: OverflowBox(
        alignment: Alignment.topCenter,
        minHeight: size.height,
        maxHeight: size.height,
        child: Transform.scale(
          scaleY: foreground ? 0.54 : 0.42,
          alignment: Alignment.topCenter,
          child: Transform.flip(
            flipY: true,
            child: NetworkImgLayer(
              src: cover,
              width: size.width,
              height: size.height,
              borderRadius: BorderRadius.zero,
              filterQuality: FilterQuality.low,
              color: isDark ? const Color(0xFFE2D5DF) : null,
              colorBlendMode: BlendMode.modulate,
            ),
          ),
        ),
      ),
    );

    return IgnorePointer(
      child: SizedBox(
        width: size.width,
        height: depth,
        child: RepaintBoundary(
          child: ClipOval(
            clipper: const _ReflectionOval(),
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: fade,
              child: mirror,
            ),
          ),
        ),
      ),
    );
  }

  // Keep the shader callback stable when the neighboring card rebuilds.
  static ShaderCallback _makeFade(double strength) {
    final gradient = RadialGradient(
      center: Alignment.topCenter,
      radius: 1,
      transform: const _FloorFade(),
      colors: [
        Colors.white.withValues(alpha: strength),
        Colors.white.withValues(alpha: strength * 0.74),
        Colors.white.withValues(alpha: strength * 0.29),
        const Color(0x00FFFFFF),
      ],
      stops: const [0.0, 0.32, 0.69, 0.99],
    );
    return gradient.createShader;
  }
}

class _ReflectionOval extends CustomClipper<Rect> {
  const _ReflectionOval();

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(0, -size.height, size.width, size.height);

  @override
  bool shouldReclip(_ReflectionOval oldClipper) => false;
}

class _FloorFade extends GradientTransform {
  const _FloorFade();

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    if (bounds.isEmpty) return null;
    final center = bounds.center.dx;
    final scale = bounds.width * 0.66 / bounds.shortestSide;
    return Matrix4.identity()
      ..translateByDouble(center, 0, 0, 1)
      ..scaleByDouble(scale, 1, 1, 1)
      ..translateByDouble(-center, 0, 0, 1);
  }
}
