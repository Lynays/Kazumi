import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';

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

  static final _blur = ui.ImageFilter.blur(
    sigmaX: 1.25,
    sigmaY: 1.85,
    tileMode: TileMode.decal,
  );
  static final _darkForegroundFade = _makeFade(0.46);
  static final _lightForegroundFade = _makeFade(0.19);
  static final _darkBackgroundFade = _makeFade(0.27);
  static final _lightBackgroundFade = _makeFade(0.09);

  @override
  Widget build(BuildContext context) {
    if (size.isEmpty || depth <= 0) return const SizedBox.shrink();
    if (cover.isEmpty) return SizedBox(height: depth);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fade = foreground
        ? (isDark ? _darkForegroundFade : _lightForegroundFade)
        : (isDark ? _darkBackgroundFade : _lightBackgroundFade);
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
              child: ImageFiltered(imageFilter: _blur, child: mirror),
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
