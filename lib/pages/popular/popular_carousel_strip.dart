import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/utils/constants.dart';

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
            ?.copyWith(fontWeight: FontWeight.w700);
    final cardTitleStyle =
        (compact ? theme.textTheme.labelSmall : theme.textTheme.bodySmall)
            ?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w600,
              height: 1.2,
            );
    final scaler = MediaQuery.textScalerOf(context);
    final titleGap = compact ? 4.0 : 6.0;
    final lineH =
        (cardTitleStyle?.fontSize ?? (compact ? 11.0 : 12.0)) *
        (cardTitleStyle?.height ?? 1.2);
    final titleBandH = titleGap + scaler.scale(lineH) + 2;

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
                        final vPad = (cardH * 0.045).clamp(4.0, 10.0);
                        final posterH = (cardH - vPad * 2 - titleBandH).clamp(
                          40.0,
                          cardH,
                        );
                        final posterW = (posterH * (compact ? 0.74 : 0.68))
                            .clamp(compact ? 42.0 : 62.0, 220.0);
                        return _fadeMask(
                          0.02,
                          horizontalOnly: true,
                          child: ScrollConfiguration(
                            behavior: const _StripScrollBehavior(),
                            child: ListView.separated(
                              controller: controller,
                              scrollDirection: Axis.horizontal,
                              padding: EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: vPad,
                              ),
                              itemCount: items.length,
                              separatorBuilder: (_, _) =>
                                  SizedBox(width: compact ? 8 : 12),
                              itemBuilder: (_, i) => RepaintBoundary(
                                child: _StripCard(
                                  item: items[i],
                                  posterSize: Size(posterW, posterH),
                                  titleGap: titleGap,
                                  compact: compact,
                                  titleStyle: cardTitleStyle,
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
    required this.titleGap,
    required this.compact,
    required this.titleStyle,
  });

  final BangumiItem item;
  final Size posterSize;
  final double titleGap;
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
    final showScore =
        !widget.compact && item.ratingScore > 0 && size.width >= 88;

    return Tooltip(
      message: title,
      child: Semantics(
        button: true,
        label: title,
        child: SizedBox(
          width: size.width,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: StyleString.mdRadius,
                hoverColor: Colors.transparent,
                onTap: () => context.pushNamed('/info/', arguments: item),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AnimatedScale(
                        scale: _hovered && !reduceMotion ? 1.07 : 1.0,
                        duration: reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        child: RepaintBoundary(
                          child: _fadeMask(
                            0.07,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                NetworkImgLayer(
                                  src: cover,
                                  width: size.width,
                                  height: size.height,
                                  borderRadius: StyleString.mdRadius,
                                ),
                                if (showScore)
                                  Positioned(
                                    top: 6,
                                    right: 6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0x99000000),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        item.ratingScore.toStringAsFixed(1),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
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
                    SizedBox(height: widget.titleGap),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: widget.titleStyle,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _fadeMask(
  double edge, {
  bool horizontalOnly = false,
  required Widget child,
}) {
  Widget axis(bool vertical, Widget inner) => ShaderMask(
    blendMode: BlendMode.dstIn,
    shaderCallback: (r) => LinearGradient(
      begin: vertical ? Alignment.topCenter : Alignment.centerLeft,
      end: vertical ? Alignment.bottomCenter : Alignment.centerRight,
      colors: const [
        Colors.transparent,
        Colors.white,
        Colors.white,
        Colors.transparent,
      ],
      stops: [0.0, edge, 1.0 - edge, 1.0],
    ).createShader(r),
    child: inner,
  );
  return horizontalOnly ? axis(false, child) : axis(false, axis(true, child));
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
