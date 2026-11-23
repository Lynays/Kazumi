import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/pages/menu/cinema_tokens.dart';
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
                        final reflectH = rawH * 0.21;
                        final posterH = rawH - reflectH;
                        final gap = compact ? 12.0 : 18.0;
                        const sidePadding = 16.0;
                        final viewportWidth = c.hasBoundedWidth
                            ? c.maxWidth
                            : MediaQuery.sizeOf(context).width;
                        final posterW = math
                            .max(
                              posterH * (compact ? 1.28 : 1.22),
                              (viewportWidth - sidePadding * 2 - gap * 9) / 10,
                            )
                            .clamp(compact ? 56.0 : 88.0, 220.0);
                        final fadeColor = theme.brightness == Brightness.dark
                            ? CinemaPalette.of(context).canvas
                            : theme.scaffoldBackgroundColor;
                        return SizedBox(
                          width: viewportWidth,
                          child: _viewportFade(
                            fadeColor,
                            ScrollConfiguration(
                              behavior: const _StripScrollBehavior(),
                              child: ListView.custom(
                                controller: controller,
                                scrollDirection: Axis.horizontal,
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
                                  itemCount: items.length,
                                  posterWidth: posterW,
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
    required int itemCount,
    required double posterWidth,
    required double gap,
  }) : _scrollExtent = itemCount * posterWidth + (itemCount - 1) * gap,
       super(
         childCount: itemCount * 2 - 1,
         semanticIndexCallback: (_, index) => index.isEven ? index ~/ 2 : null,
       );

  final double _scrollExtent;

  // With alternating extents, Flutter can still estimate the unseen tail.
  @override
  double estimateMaxScrollOffset(
    int firstIndex,
    int lastIndex,
    double leadingScrollOffset,
    double trailingScrollOffset,
  ) => _scrollExtent;
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

class _StripCardState extends State<_StripCard> {
  bool _hovered = false;

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
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(12);
    final animDur = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 200);
    final lineHeight =
        MediaQuery.textScalerOf(
          context,
        ).scale(widget.titleStyle?.fontSize ?? 12) *
        1.15;
    final titleBottom = math.min(8.0, size.height * 0.12);
    final titleSpace = size.height - titleBottom;
    final titleLines = widget.compact || titleSpace < lineHeight * 2 ? 1 : 2;
    final titleTop = math.min(26.0, titleSpace - titleLines * lineHeight);

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
                    onEnter: (_) => setState(() => _hovered = true),
                    onExit: (_) => setState(() => _hovered = false),
                    child: AnimatedContainer(
                      duration: animDur,
                      curve: Curves.easeOutCubic,
                      transformAlignment: Alignment.center,
                      transform: _hovered && !reduceMotion
                          ? (Matrix4.identity()
                              ..setEntry(3, 2, 0.0014)
                              ..translateByDouble(0, -size.height * 0.06, 0, 1)
                              ..rotateX(-0.07))
                          : Matrix4.identity(),
                      child: AnimatedScale(
                        scale: _hovered && !reduceMotion ? 1.20 : 1.0,
                        duration: animDur,
                        curve: Curves.easeOutCubic,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: radius,
                            boxShadow: _stripShadows(isDark, _hovered),
                          ),
                          child: ClipRRect(
                            borderRadius: radius,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                NetworkImgLayer(
                                  src: cover,
                                  width: size.width,
                                  height: size.height,
                                  borderRadius: radius,
                                ),
                                IgnorePointer(
                                  child: DecoratedBox(
                                    decoration: _stripSheen(
                                      isDark,
                                      _hovered,
                                      radius,
                                    ),
                                  ),
                                ),
                                if (titleSpace >= lineHeight)
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 0,
                                    child: AnimatedOpacity(
                                      opacity: _hovered ? 0.0 : 1.0,
                                      duration: reduceMotion
                                          ? Duration.zero
                                          : const Duration(milliseconds: 140),
                                      child: Container(
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
                                      ),
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

List<BoxShadow> _stripShadows(bool isDark, bool hovered) => [
  BoxShadow(
    color: Colors.black.withValues(
      alpha: isDark ? (hovered ? 0.75 : 0.58) : (hovered ? 0.28 : 0.16),
    ),
    blurRadius: hovered ? 28 : 19,
    spreadRadius: -4,
    offset: Offset(0, hovered ? 12 : 6),
  ),
  if (hovered)
    BoxShadow(
      color: isDark
          ? const Color.fromRGBO(190, 212, 255, 0.26)
          : Colors.black.withValues(alpha: 0.14),
      blurRadius: 18,
      spreadRadius: -4,
      offset: const Offset(0, -1),
    ),
];

BoxDecoration _stripSheen(bool isDark, bool hovered, BorderRadius radius) =>
    BoxDecoration(
      borderRadius: radius,
      border: Border.all(
        color: Colors.white.withValues(
          alpha: isDark ? (hovered ? 0.30 : 0.09) : 0.30,
        ),
        width: 0.85,
      ),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(
            alpha: isDark ? (hovered ? 0.22 : 0.08) : 0.26,
          ),
          Colors.transparent,
          Colors.transparent,
          const Color(0x5A020306),
        ],
        stops: const [0.0, 0.24, 0.70, 1.0],
      ),
    );
