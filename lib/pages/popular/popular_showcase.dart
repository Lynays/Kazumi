import 'package:flutter/material.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/pages/popular/popular_featured_card.dart';
import 'package:kazumi/pages/popular/popular_rank_mosaic.dart';
import 'package:kazumi/utils/constants.dart';

/// Arranges the featured card and rank mosaic in a golden-ratio split.
class PopularShowcase extends StatelessWidget {
  const PopularShowcase({
    super.key,
    required this.featured,
    required this.mosaic,
    this.mosaicFloorSpace = 0,
  });

  static const double _gap = 12.0;
  static const double _golden = 0.618;
  static const double _narrowBreak = 720.0;

  final BangumiItem? featured;
  final List<BangumiItem> mosaic;

  /// Space for the mosaic's reflections below the main card.
  final double mosaicFloorSpace;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth.isFinite && c.maxWidth > 0 ? c.maxWidth : 1012.0;
        final boundedH = c.hasBoundedHeight && c.maxHeight.isFinite;
        final leftWidget = featured == null
            ? const _ShowcasePlaceholder()
            : PopularFeaturedCard(item: featured!);

        if (w < _narrowBreak && mosaic.isNotEmpty) {
          final netH = boundedH
              ? (c.maxHeight - _gap).clamp(120.0, double.infinity)
              : 0.0;
          final topH = boundedH ? netH * 0.56 : 200.0;
          final bottomH = boundedH ? netH - topH : 160.0;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: topH, child: leftWidget),
              const SizedBox(height: _gap),
              SizedBox(
                height: bottomH,
                child: PopularRankMosaic(items: mosaic),
              ),
            ],
          );
        }

        final netW = w - _gap;
        final leftW = netW * _golden;
        final rightW = netW - leftW;
        final requestedFloorSpace = mosaic.isEmpty
            ? 0.0
            : mosaicFloorSpace.clamp(
                0.0,
                PopularRankMosaic.floorReflectionDepth,
              );
        final height = boundedH ? c.maxHeight : 240.0 + requestedFloorSpace;
        final floorSpace = height >= PopularRankMosaic.minReflectionHeight
            ? requestedFloorSpace
            : 0.0;
        return SizedBox(
          width: w,
          height: height,
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                right: mosaic.isEmpty ? 0 : rightW + _gap,
                bottom: floorSpace,
                child: leftWidget,
              ),
              if (mosaic.isNotEmpty)
                Positioned(
                  top: 0,
                  right: 0,
                  bottom: 0,
                  width: rightW,
                  child: PopularRankMosaic(items: mosaic),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Composes the showcase and carousels over a shared reflection.
class PopularShowcaseWithCarousels extends StatelessWidget {
  const PopularShowcaseWithCarousels({
    super.key,
    required this.featured,
    required this.mosaic,
    required this.showcaseHeight,
    required this.gap,
    required this.carousels,
  });

  final BangumiItem? featured;
  final List<BangumiItem> mosaic;
  final double showcaseHeight;
  final double gap;
  final Widget carousels;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < PopularShowcase._narrowBreak) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PopularShowcase(featured: featured, mosaic: mosaic),
              SizedBox(height: gap),
              carousels,
            ],
          );
        }

        // The first 5 dp of the mirror lie within the main card's height.
        final mirrorOverhang = gap.clamp(
          0.0,
          PopularRankMosaic.floorReflectionDepth - 5,
        );
        final floorSpace =
            mosaic.isEmpty ||
                showcaseHeight + mirrorOverhang <
                    PopularRankMosaic.minReflectionHeight
            ? 0.0
            : mirrorOverhang;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            if (Theme.of(context).brightness == Brightness.dark &&
                mosaic.isNotEmpty &&
                showcaseHeight >= _ShowcaseFloor.aboveCardBottom)
              Positioned(
                top: showcaseHeight - _ShowcaseFloor.aboveCardBottom,
                left: 0,
                right: 0,
                child: const _ShowcaseFloor(),
              ),
            Padding(
              padding: EdgeInsets.only(top: showcaseHeight + gap),
              child: carousels,
            ),
            // Expanded mosaic cards paint above the first carousel.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: showcaseHeight + floorSpace,
              child: PopularShowcase(
                featured: featured,
                mosaic: mosaic,
                mosaicFloorSpace: floorSpace,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ShowcaseFloor extends StatelessWidget {
  const _ShowcaseFloor();

  static const double aboveCardBottom = 56;

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 120,
      child: IgnorePointer(
        child: RepaintBoundary(
          child: CustomPaint(painter: _ShowcaseFloorShade()),
        ),
      ),
    );
  }
}

class _ShowcaseFloorShade extends CustomPainter {
  const _ShowcaseFloorShade();

  @override
  void paint(Canvas canvas, Size size) {
    const edgeInset = 12.0;
    final w = size.width + edgeInset * 2;
    final h = size.height;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(-edgeInset, 0);
    final shade = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.55),
      width: w,
      height: h * 0.54,
    );
    canvas.drawOval(
      shade,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00020409), Color(0x32020408), Color(0x00020409)],
          stops: [0, 0.56, 1],
        ).createShader(shade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );
    final reflectedLight = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.16, h * 0.58),
        width: w * 0.20,
        height: h * 0.30,
      ),
      reflectedLight..color = const Color(0x6A8E445E),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.61, h * 0.55),
        width: w * 0.15,
        height: h * 0.30,
      ),
      reflectedLight..color = const Color(0x796B5B89),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.40, h * 0.54),
        width: w * 0.12,
        height: h * 0.15,
      ),
      reflectedLight..color = const Color(0x555E536C),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.095, h * 0.48),
        width: w * 0.065,
        height: h * 0.075,
      ),
      Paint()
        ..color = const Color(0x658C334D)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ShowcaseFloorShade oldDelegate) => false;
}

class _ShowcasePlaceholder extends StatelessWidget {
  const _ShowcasePlaceholder();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: StyleString.mdRadius,
      ),
      child: Center(
        child: Text(
          '暂无热门推荐',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
      ),
    );
  }
}
