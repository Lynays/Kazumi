import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:kazumi/bean/settings/visual_effects_config.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/pages/popular/popular_floor_reflection.dart';

/// Reusable horizontal carousel row for the Popular showcase.
///
/// The caller owns [controller] and animation scheduling; this widget never
/// disposes [controller] and ignores programmatic scroll notifications.
class PopularCarouselStrip extends StatelessWidget {
  const PopularCarouselStrip({
    super.key,
    required this.items,
    required this.controller,
    required this.height,
    this.label = '',
    required this.onUserInteractionStart,
    required this.onUserInteractionEnd,
  });

  final List<BangumiItem> items;
  final ScrollController controller;
  final double height;
  final String label;
  final VoidCallback onUserInteractionStart;
  final VoidCallback onUserInteractionEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final safeHeight = height.isFinite && height > 0 ? height : 140.0;
    final compact = safeHeight < 120;
    final header = label.trim();
    final headerStyle =
        (compact ? theme.textTheme.labelMedium : theme.textTheme.titleSmall)
            ?.copyWith(fontWeight: FontWeight.w600);
    final cardTitleStyle =
        (compact ? theme.textTheme.bodySmall : theme.textTheme.bodyMedium)
            ?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w500,
              height: 1.15,
            );

    return _StripInteractionShell(
      onStart: onUserInteractionStart,
      onEnd: onUserInteractionEnd,
      child: SizedBox(
        height: safeHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (header.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  header,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: headerStyle,
                ),
              ),
              SizedBox(height: compact ? 4 : 6),
            ],
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Text(
                        '暂无更多热门番剧',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (_, c) {
                        final cardH = c.maxHeight;
                        if (cardH <= 0 || !cardH.isFinite) {
                          return const SizedBox.shrink();
                        }
                        final vPad = cardH * 0.065;
                        final rawH = cardH - vPad * 2;
                        // Floor-quantize to 2px steps so posterH + reflectH
                        // never exceeds rawH and subpixel jitter avoids
                        // unnecessary child delegate rebuilds.
                        final posterH = math
                            .max(1.0, ((rawH * 0.79) / 2.0).floor() * 2.0)
                            .clamp(1.0, rawH);
                        final reflectH = math.max(
                          0.0,
                          ((rawH - posterH) / 2.0).floor() * 2.0,
                        );
                        final gap = compact ? 12.0 : 18.0;
                        const sidePadding = 16.0;
                        final viewportWidth = c.hasBoundedWidth
                            ? c.maxWidth
                            : MediaQuery.sizeOf(context).width;
                        final rawPosterW = math
                            .max(
                              posterH * (compact ? 1.28 : 1.22),
                              (viewportWidth - sidePadding * 2 - gap * 9) / 10,
                            )
                            .clamp(compact ? 56.0 : 88.0, 220.0);
                        final posterW = ((rawPosterW / 2.0).floor() * 2.0)
                            .clamp(compact ? 56.0 : 88.0, 220.0);
                        return SizedBox(
                          width: viewportWidth,
                          child: _viewportFade(
                            theme.scaffoldBackgroundColor,
                            ScrollConfiguration(
                              behavior: const _StripScrollBehavior(),
                              child: ListView.custom(
                                controller: controller,
                                scrollDirection: Axis.horizontal,
                                scrollCacheExtent:
                                    const ScrollCacheExtent.pixels(80.0),
                                padding: EdgeInsets.symmetric(
                                  horizontal: sidePadding,
                                  vertical: vPad,
                                ),
                                itemExtentBuilder: (i, _) =>
                                    i.isEven ? posterW : gap,
                                semanticChildCount: items.length,
                                childrenDelegate: _StripItemsDelegate(
                                  (_, i) => i.isOdd
                                      ? const SizedBox.shrink()
                                      : _StripCard(
                                          item: items[i ~/ 2],
                                          posterSize: Size(posterW, posterH),
                                          reflectHeight: reflectH,
                                          compact: compact,
                                          titleStyle: cardTitleStyle,
                                        ),
                                  items: items,
                                  posterWidth: posterW,
                                  posterHeight: posterH,
                                  reflectHeight: reflectH,
                                  compact: compact,
                                  titleStyle: cardTitleStyle,
                                  gap: gap,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StripItemsDelegate extends SliverChildBuilderDelegate {
  _StripItemsDelegate(
    super.builder, {
    required this.items,
    required this.posterWidth,
    required this.posterHeight,
    required this.reflectHeight,
    required this.compact,
    required this.titleStyle,
    required double gap,
  }) : _scrollExtent =
           items.length * posterWidth + (items.length - 1) * gap,
       super(
         childCount: items.length * 2 - 1,
         semanticIndexCallback: (_, index) => index.isEven ? index ~/ 2 : null,
       );

  final List<BangumiItem> items;
  final double posterWidth;
  final double posterHeight;
  final double reflectHeight;
  final bool compact;
  final TextStyle? titleStyle;
  final double _scrollExtent;

  // With alternating extents, Flutter can still estimate the unseen tail.
  @override
  double estimateMaxScrollOffset(
    int firstIndex,
    int lastIndex,
    double leadingScrollOffset,
    double trailingScrollOffset,
  ) => _scrollExtent;

  @override
  bool shouldRebuild(covariant _StripItemsDelegate oldDelegate) =>
      !identical(items, oldDelegate.items) ||
      posterWidth != oldDelegate.posterWidth ||
      posterHeight != oldDelegate.posterHeight ||
      reflectHeight != oldDelegate.reflectHeight ||
      compact != oldDelegate.compact ||
      titleStyle != oldDelegate.titleStyle;
}

class _StripInteractionShell extends StatefulWidget {
  const _StripInteractionShell({
    required this.onStart,
    required this.onEnd,
    required this.child,
  });

  final VoidCallback onStart;
  final VoidCallback onEnd;
  final Widget child;

  @override
  State<_StripInteractionShell> createState() => _StripInteractionShellState();
}

class _StripInteractionShellState extends State<_StripInteractionShell> {
  bool _scrolling = false;
  bool _hovering = false;
  bool _focused = false;
  bool _active = false;

  void _sync() {
    final next = _scrolling || _hovering || _focused;
    if (next == _active) return;
    _active = next;
    (next ? widget.onStart : widget.onEnd)();
  }

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0) return false;
    if (n is ScrollStartNotification && n.dragDetails != null) {
      _scrolling = true;
    } else if (n is UserScrollNotification) {
      _scrolling = n.direction != ScrollDirection.idle;
    } else if (n is ScrollEndNotification) {
      _scrolling = false;
    } else {
      return false;
    }
    _sync();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _update(() => _hovering = true),
      onExit: (_) => _update(() => _hovering = false),
      child: Focus(
        skipTraversal: true,
        canRequestFocus: false,
        onFocusChange: (v) => _update(() => _focused = v),
        child: NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: widget.child,
        ),
      ),
    );
  }

  void _update(VoidCallback mutate) {
    mutate();
    _sync();
  }
}

class _StripCard extends StatefulWidget {
  const _StripCard({
    required this.item,
    required this.posterSize,
    required this.reflectHeight,
    required this.compact,
    required this.titleStyle,
  });

  final BangumiItem item;
  final Size posterSize;
  final double reflectHeight;
  final bool compact;
  final TextStyle? titleStyle;

  @override
  State<_StripCard> createState() => _StripCardState();
}

class _StripCardState extends State<_StripCard>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  bool _reduceMotion = false;
  AnimationController? _hoverController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextReduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion != nextReduceMotion) {
      _reduceMotion = nextReduceMotion;
      if (_reduceMotion && _hoverController != null) {
        _hoverController!.value = 0.0;
      }
    }
  }

  void _setHovered(bool value) {
    if (_hovered == value) return;
    _hovered = value;
    if (_reduceMotion) {
      setState(() {});
      return;
    }
    if (value) {
      final created = _hoverController == null;
      final controller = _hoverController ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 200),
        reverseDuration: const Duration(milliseconds: 200),
      );
      controller.forward();
      if (created) {
        setState(() {});
      }
    } else {
      _hoverController?.reverse();
    }
  }

  @override
  void dispose() {
    _hoverController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final size = widget.posterSize;
    final cn = item.nameCn.trim();
    final raw = item.name.trim();
    final title = cn.isNotEmpty ? cn : (raw.isNotEmpty ? raw : '未知番剧');
    final cover = const ['large', 'common', 'medium', 'small', 'grid']
        .map((k) => item.images[k]?.trim() ?? '')
        .firstWhere((u) => u.isNotEmpty, orElse: () => '');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardEffectsScale = VisualEffectsConfig.of(context).cardEffectsScale;
    final radius = BorderRadius.circular(12);
    final lineHeight =
        MediaQuery.textScalerOf(
          context,
        ).scale(widget.titleStyle?.fontSize ?? 12) *
        1.15;
    final titleBottom = math.min(8.0, size.height * 0.12);
    final titleSpace = size.height - titleBottom;
    final titleLines = widget.compact || titleSpace < lineHeight * 2 ? 1 : 2;
    final titleTop = math.min(26.0, titleSpace - titleLines * lineHeight);
    final posterImage = NetworkImgLayer(
      src: cover,
      width: size.width,
      height: size.height,
      borderRadius: BorderRadius.zero,
    );
    final titleBanner = titleSpace >= lineHeight
        ? Container(
            padding: EdgeInsets.fromLTRB(
              8,
              titleTop,
              8,
              titleBottom,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Color(0xF506080C),
                  Color(0x9A06080C),
                  Color(0x0006080C),
                ],
                stops: [0.0, 0.52, 1.0],
              ),
            ),
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: titleLines,
              overflow: TextOverflow.ellipsis,
              style: widget.titleStyle,
            ),
          )
        : null;

    return Semantics(
      button: true,
      label: title,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          hoverColor: Colors.transparent,
          splashColor: Colors.transparent,
          onTap: () => context.pushNamed('/info/', arguments: item),
          child: SizedBox(
            width: size.width,
            height: size.height + widget.reflectHeight,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: size.width,
                  height: size.height,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    onEnter: (_) => _setHovered(true),
                    onExit: (_) => _setHovered(false),
                    child: AnimatedBuilder(
                      animation: _hoverController ?? kAlwaysDismissedAnimation,
                      child: posterImage,
                      builder: (context, child) {
                        final rawT = _reduceMotion
                            ? 0.0
                            : (_hoverController?.value ?? 0.0);
                        final t = rawT == 0.0
                            ? 0.0
                            : Curves.easeOutCubic.transform(rawT);
                        final scale = 1.0 + 0.20 * t;
                        final transform = t == 0.0
                            ? Matrix4.identity()
                            : (Matrix4.identity()
                                ..setEntry(3, 2, 0.0014)
                                ..translateByDouble(
                                  0,
                                  -size.height * 0.06 * t,
                                  0,
                                  1,
                                )
                                ..rotateX(-0.07 * t)
                                ..scaleByDouble(scale, scale, 1.0, 1.0));
                        final titleOpacity = _reduceMotion
                            ? (_hovered ? 0.0 : 1.0)
                            : (1.0 - (rawT / 0.7).clamp(0.0, 1.0));
                        final hoverVisual = _reduceMotion
                            ? _hovered
                            : rawT > 0.5;
                        return Transform(
                          alignment: Alignment.center,
                          transform: transform,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: radius,
                              boxShadow: _stripShadows(
                                isDark,
                                hoverVisual,
                                cardEffectsScale,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: radius,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  child!,
                                  if (cardEffectsScale > 0)
                                    IgnorePointer(
                                      child: DecoratedBox(
                                        decoration: _stripSheen(
                                          isDark,
                                          hoverVisual,
                                          radius,
                                          cardEffectsScale,
                                        ),
                                      ),
                                    ),
                                  if (titleBanner != null)
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      bottom: 0,
                                      child: Opacity(
                                        opacity: titleOpacity,
                                        child: titleBanner,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                PopularFloorReflection(
                  cover: cover,
                  size: size,
                  depth: widget.reflectHeight,
                  foreground: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget _viewportFade(Color bg, Widget child) {
  final clear = bg.withValues(alpha: 0.0);
  Widget edge(bool left) => Positioned(
    top: 0,
    bottom: 0,
    left: left ? 0 : null,
    right: left ? null : 0,
    width: 36,
    child: IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: left ? Alignment.centerLeft : Alignment.centerRight,
            end: left ? Alignment.centerRight : Alignment.centerLeft,
            colors: [
              bg.withValues(alpha: 0.64),
              bg.withValues(alpha: 0.26),
              clear,
            ],
            stops: const [0.0, 0.36, 1.0],
          ),
        ),
      ),
    ),
  );
  return Stack(children: [child, edge(true), edge(false)]);
}

class _StripScrollBehavior extends MaterialScrollBehavior {
  const _StripScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}

List<BoxShadow>? _stripShadows(bool isDark, bool hovered, double scale) {
  if (scale <= 0) return null;
  return [
    BoxShadow(
      color: Colors.black.withValues(
        alpha: ((isDark ? (hovered ? 0.75 : 0.58) : (hovered ? 0.28 : 0.16)) *
                scale)
            .clamp(0.0, 1.0),
      ),
      blurRadius: hovered ? 28 : 19,
      spreadRadius: -4,
      offset: Offset(0, hovered ? 12 : 6),
    ),
    if (hovered)
      BoxShadow(
        color: isDark
            ? Color.fromRGBO(190, 212, 255, (0.26 * scale).clamp(0.0, 1.0))
            : Colors.black.withValues(alpha: (0.14 * scale).clamp(0.0, 1.0)),
        blurRadius: 18,
        spreadRadius: -4,
        offset: const Offset(0, -1),
      ),
  ];
}

BoxDecoration _stripSheen(
  bool isDark,
  bool hovered,
  BorderRadius radius,
  double scale,
) =>
    BoxDecoration(
      borderRadius: radius,
      border: Border.all(
        color: Colors.white.withValues(
          alpha: ((isDark ? (hovered ? 0.30 : 0.09) : 0.30) * scale)
              .clamp(0.0, 1.0),
        ),
        width: 0.85,
      ),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(
            alpha: ((isDark ? (hovered ? 0.22 : 0.08) : 0.26) * scale)
                .clamp(0.0, 1.0),
          ),
          Colors.transparent,
          Colors.transparent,
          const Color(0xFF020306).withValues(
            alpha: ((0x5A / 255.0) * scale).clamp(0.0, 1.0),
          ),
        ],
        stops: const [0.0, 0.24, 0.70, 1.0],
      ),
    );
