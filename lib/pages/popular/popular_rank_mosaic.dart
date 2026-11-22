import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/pages/popular/popular_floor_reflection.dart';
import 'package:kazumi/pages/popular/popular_mosaic_geometry.dart';

/// Weighted irregular mosaic grid for Popular TOP 2-10 anime.
class PopularRankMosaic extends StatefulWidget {
  const PopularRankMosaic({super.key, required this.items});

  static const double floorReflectionDepth = 18;
  static const double minReflectionHeight = 200;

  final List<BangumiItem> items;

  @override
  State<PopularRankMosaic> createState() => _PopularRankMosaicState();
}

class _PopularRankMosaicState extends State<PopularRankMosaic> {
  static const double _gap = 8.0;
  int? _hoveredIndex;

  List<Rect> _layoutRects(Size size, int count) {
    if (count == 9) {
      return _editorialNineLayout(size.width, size.height);
    }
    final weights = List<double>.generate(
      count,
      (i) => math.pow(10 - i, 1.15).toDouble(),
      growable: false,
    );
    return PopularMosaicGeometry.layout(size, weights, gap: _gap);
  }

  List<Rect> _editorialNineLayout(double w, double h) {
    const g = _gap;
    final col0W = (w - g) * 0.28;
    final rx = col0W + g;
    final rw = w - rx;
    final topH = (h - g) * 0.69;
    final botY = topH + g;
    final botH = h - botY;
    final midW = (rw - g) * 0.51;
    final fx = rx + midW + g;
    final farW = rw - midW - g;
    final h3 = (topH - g) * 0.55;
    final w5 = (farW - g) * 0.53;
    final netBotW = rw - g * 3;
    const botShares = [0.31, 0.26, 0.23, 0.20];
    final rects = <Rect>[
      Rect.fromLTWH(0, 0, col0W, h),
      Rect.fromLTWH(rx, 0, midW, h3),
      Rect.fromLTWH(rx, h3 + g, midW, topH - h3 - g),
      Rect.fromLTWH(fx, 0, w5, topH),
      Rect.fromLTWH(fx + w5 + g, 0, farW - w5 - g, topH),
    ];
    var x = rx;
    for (var i = 0; i < botShares.length; i++) {
      final bw = i == botShares.length - 1 ? (w - x) : netBotW * botShares[i];
      rects.add(Rect.fromLTWH(x, botY, bw, botH));
      x += bw + g;
    }
    return rects;
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.items.take(9).toList(growable: false);
    if (visible.isEmpty) {
      return Center(
        child: Text(
          '暂无榜单拼贴',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (ctx, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        if (!w.isFinite || !h.isFinite || w < 240 || h < 140) {
          return _buildNarrowFallback(ctx, visible, h);
        }

        const reflectH = PopularRankMosaic.floorReflectionDepth;
        final hasFloorReflect = h >= PopularRankMosaic.minReflectionHeight;
        final gridH = hasFloorReflect ? h - reflectH : h;
        final rects = _layoutRects(Size(w, gridH), visible.length);
        var minSide = double.infinity;
        for (final r in rects) {
          minSide = math.min(minSide, math.min(r.width, r.height));
        }
        if (rects.length != visible.length || minSide < 42) {
          return _buildNarrowFallback(ctx, visible, h);
        }

        final order = <int>[
          for (var i = 0; i < visible.length; i++)
            if (i != _hoveredIndex) i,
          if (_hoveredIndex != null && _hoveredIndex! < visible.length)
            _hoveredIndex!,
        ];

        return SizedBox(
          width: w,
          height: h,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (hasFloorReflect)
                for (var i = 0; i < visible.length; i++)
                  if ((rects[i].bottom - gridH).abs() < 2.0)
                    Positioned(
                      left: rects[i].left,
                      top: gridH,
                      width: rects[i].width,
                      height: reflectH,
                      child: PopularFloorReflection(
                        cover: _mosaicCover(visible[i]),
                        size: rects[i].size,
                        depth: reflectH,
                      ),
                    ),
              for (final i in order)
                Positioned.fromRect(
                  key: ValueKey(visible[i].id),
                  rect: rects[i],
                  child: _MosaicTile(
                    item: visible[i],
                    rank: i + 2,
                    size: rects[i].size,
                    hovered: _hoveredIndex == i,
                    anyHovered: _hoveredIndex != null,
                    onHover: (v) => _setHover(i, v),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _setHover(int i, bool v) => setState(
    () => _hoveredIndex = v ? i : (_hoveredIndex == i ? null : _hoveredIndex),
  );

  Widget _buildNarrowFallback(
    BuildContext context,
    List<BangumiItem> items,
    double maxH,
  ) {
    final h = maxH.isFinite && maxH > 0 ? maxH : 150.0;
    final tileH = (h - 16).clamp(48.0, 200.0);
    final tileW = (tileH * 0.72).clamp(68.0, 148.0);
    return SizedBox(
      height: h,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: const {PointerDeviceKind.touch, PointerDeviceKind.mouse},
        ),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (_, i) => SizedBox(
            width: tileW,
            height: tileH,
            child: _MosaicTile(
              item: items[i],
              rank: i + 2,
              size: Size(tileW, tileH),
              hovered: _hoveredIndex == i,
              anyHovered: _hoveredIndex != null,
              onHover: (v) => _setHover(i, v),
            ),
          ),
        ),
      ),
    );
  }
}

class _MosaicTile extends StatelessWidget {
  const _MosaicTile({
    required this.item,
    required this.rank,
    required this.size,
    required this.hovered,
    required this.anyHovered,
    required this.onHover,
  });

  final BangumiItem item;
  final int rank;
  final Size size;
  final bool hovered;
  final bool anyHovered;
  final ValueChanged<bool> onHover;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cn = item.nameCn.trim();
    final raw = item.name.trim();
    final title = cn.isNotEmpty ? cn : (raw.isNotEmpty ? raw : '未知番剧');
    final cover = _mosaicCover(item);
    final tiny = size.width < 58 || size.height < 52;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final radius = BorderRadius.circular(14);
    final tier = rank == 2 ? 0 : (rank <= 6 ? 1 : 2);
    final leadCaption = tier == 0 && size.width >= 120 && size.height >= 120;
    final summary = leadCaption
        ? item.summary.replaceAll(RegExp(r'\s+'), ' ').trim()
        : '';
    final rankFontSize = tiny ? 10.0 : (tier == 2 ? 12.0 : 16.0);
    final titleFontSize = leadCaption
        ? 22.0
        : (size.width >= 150 ? 16.0 : 13.0);
    final textScaler = MediaQuery.textScalerOf(context);
    final captionTop = 12 + textScaler.scale(rankFontSize) * 1.2;
    final captionPadding = size.height < 100 ? 8.0 : 24.0;
    final captionHeight = size.height - captionTop - captionPadding - 8;
    final titleLineHeight = textScaler.scale(titleFontSize) * 1.2;
    final summaryHeight = 4 + textScaler.scale(13) * 1.2;
    final showTitle = size.width >= 64 && captionHeight >= titleLineHeight;
    final showSummary =
        summary.isNotEmpty && captionHeight >= titleLineHeight + summaryHeight;
    final titleSpace = captionHeight - (showSummary ? summaryHeight : 0);
    final titleLines = titleSpace >= titleLineHeight * 2 ? 2 : 1;
    final baseDim = tier == 0
        ? 0.0
        : (tier == 1 ? (isDark ? 0.04 : 0.0) : (isDark ? 0.09 : 0.03));
    final dimAlpha = (!hovered && anyHovered && isDark)
        ? (baseDim + 0.10).clamp(0.0, 0.28)
        : baseDim;
    final animDur = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 200);

    return Semantics(
      button: true,
      label: '热门第 $rank 名，$title',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => onHover(true),
        onExit: (_) => onHover(false),
        child: AnimatedContainer(
          duration: animDur,
          curve: Curves.easeOutCubic,
          transformAlignment: Alignment.center,
          transform: hovered && !reduceMotion
              ? (Matrix4.identity()
                  ..setEntry(3, 2, 0.0014)
                  ..rotateX(-0.06))
              : Matrix4.identity(),
          child: AnimatedScale(
            scale: hovered && !reduceMotion ? 1.20 : 1.0,
            duration: animDur,
            curve: Curves.easeOutCubic,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                boxShadow: _tileShadows(isDark, hovered, tier),
              ),
              child: ClipRRect(
                borderRadius: radius,
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    borderRadius: radius,
                    hoverColor: Colors.transparent,
                    onTap: () => context.pushNamed('/info/', arguments: item),
                    child: RepaintBoundary(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          NetworkImgLayer(
                            src: cover,
                            width: size.width,
                            height: size.height,
                            borderRadius: radius,
                          ),
                          if (dimAlpha > 0)
                            IgnorePointer(
                              child: AnimatedOpacity(
                                opacity: hovered ? 0.0 : dimAlpha,
                                duration: reduceMotion
                                    ? Duration.zero
                                    : const Duration(milliseconds: 180),
                                child: const ColoredBox(
                                  color: Color(0xFF07090C),
                                ),
                              ),
                            ),
                          if (showTitle)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: AnimatedOpacity(
                                opacity: hovered ? 0.0 : 1.0,
                                duration: reduceMotion
                                    ? Duration.zero
                                    : const Duration(milliseconds: 140),
                                child: Container(
                                  padding: EdgeInsets.fromLTRB(
                                    10,
                                    captionPadding,
                                    10,
                                    8,
                                  ),
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [
                                        Color(0xF408080D),
                                        Color(0x9C08080D),
                                        Color(0x0008080D),
                                      ],
                                      stops: [0.0, 0.50, 1.0],
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        maxLines: titleLines,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: titleFontSize,
                                          fontWeight: leadCaption
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                          height: 1.2,
                                        ),
                                      ),
                                      if (showSummary)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 4,
                                          ),
                                          child: Text(
                                            summary,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Color(0xD9F6F1FA),
                                              fontSize: 13,
                                              height: 1.2,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          Positioned(
                            top: 4,
                            left: tiny ? 4 : 6,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: tiny ? 4 : 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xB80A090E),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '#$rank',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: rankFontSize,
                                  height: 1.2,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          IgnorePointer(
                            child: DecoratedBox(
                              decoration: _tileSheen(isDark, hovered, tier),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _mosaicCover(BangumiItem item) =>
    const ['large', 'common', 'medium', 'small', 'grid']
        .map((key) => item.images[key]?.trim() ?? '')
        .firstWhere((url) => url.isNotEmpty, orElse: () => '');

List<BoxShadow> _tileShadows(bool isDark, bool hovered, int tier) {
  final (blur, y, a) = hovered
      ? (26.0, 12.0, isDark ? 0.82 : 0.28)
      : switch (tier) {
          0 => (20.0, 9.0, isDark ? 0.68 : 0.22),
          1 => (14.0, 6.0, isDark ? 0.56 : 0.16),
          _ => (9.0, 4.0, isDark ? 0.42 : 0.12),
        };
  return [
    BoxShadow(
      color: Colors.black.withValues(alpha: a),
      blurRadius: blur,
      spreadRadius: -2,
      offset: Offset(0, y),
    ),
    if (hovered || tier == 0)
      BoxShadow(
        color: isDark
            ? Color.fromRGBO(179, 130, 255, hovered ? 0.26 : 0.20)
            : Colors.black.withValues(alpha: 0.12),
        blurRadius: 16,
        spreadRadius: -4,
        offset: const Offset(0, -1),
      ),
  ];
}

BoxDecoration _tileSheen(bool isDark, bool hovered, int tier) {
  final g = hovered
      ? (isDark ? 0.26 : 0.36)
      : (tier == 0 ? (isDark ? 0.14 : 0.26) : (isDark ? 0.06 : 0.16));
  return BoxDecoration(
    borderRadius: BorderRadius.circular(14),
    border: Border.all(
      color: isDark && tier == 0
          ? const Color(0xFFD69CF8).withValues(alpha: hovered ? 0.72 : 0.38)
          : Colors.white.withValues(
              alpha: isDark ? (hovered ? 0.32 : 0.11) : 0.28,
            ),
      width: 0.85,
    ),
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withValues(alpha: g),
        Colors.transparent,
        Colors.transparent,
        const Color(0x52020306),
      ],
      stops: const [0.0, 0.22, 0.72, 1.0],
    ),
  );
}
