import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/utils/constants.dart';

/// Reusable horizontal carousel row for Popular B.1-B.3.
///
/// The caller owns [controller] and animation scheduling; this widget never
/// disposes [controller] and ignores programmatic scroll notifications.
class PopularCarouselStrip extends StatelessWidget {
  const PopularCarouselStrip({
    super.key,
    required this.items,
    required this.controller,
    required this.height,
    required this.label,
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
    final safeHeight = height.isFinite && height > 0 ? height : 140.0;
    final compact = safeHeight < 120;
    final titleStyle =
        (compact ? theme.textTheme.labelMedium : theme.textTheme.titleSmall)
            ?.copyWith(fontWeight: FontWeight.w700);

    return _StripInteractionShell(
      onStart: onUserInteractionStart,
      onEnd: onUserInteractionEnd,
      child: SizedBox(
        height: safeHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: titleStyle,
              ),
            ),
            SizedBox(height: compact ? 4 : 6),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Text(
                        '暂无更多热门番剧',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (_, c) {
                        final cardH = c.maxHeight;
                        if (cardH <= 0 || !cardH.isFinite) {
                          return const SizedBox.shrink();
                        }
                        final cardW = (cardH * (compact ? 0.76 : 0.68)).clamp(
                          compact ? 44.0 : 64.0,
                          220.0,
                        );
                        return ScrollConfiguration(
                          behavior: const _StripScrollBehavior(),
                          child: ListView.separated(
                            controller: controller,
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            itemCount: items.length,
                            separatorBuilder: (_, _) =>
                                SizedBox(width: compact ? 8 : 10),
                            itemBuilder: (_, i) => _StripCard(
                              item: items[i],
                              w: cardW,
                              h: cardH,
                              compact: compact,
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
      _sync();
    } else if (n is UserScrollNotification) {
      _scrolling = n.direction != ScrollDirection.idle;
      _sync();
    } else if (n is ScrollEndNotification && _scrolling) {
      _scrolling = false;
      _sync();
    }
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

class _StripCard extends StatelessWidget {
  const _StripCard({
    required this.item,
    required this.w,
    required this.h,
    required this.compact,
  });

  final BangumiItem item;
  final double w;
  final double h;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cn = item.nameCn.trim();
    final raw = item.name.trim();
    final title = cn.isNotEmpty ? cn : (raw.isNotEmpty ? raw : '未知番剧');
    final cover = const ['large', 'common', 'medium', 'small', 'grid']
        .map((k) => item.images[k]?.trim() ?? '')
        .firstWhere((u) => u.isNotEmpty, orElse: () => '');
    final titleStyle =
        (compact ? theme.textTheme.labelSmall : theme.textTheme.bodySmall)
            ?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              height: 1.2,
            );

    return Tooltip(
      message: title,
      child: Semantics(
        button: true,
        label: title,
        child: SizedBox(
          width: w,
          height: h,
          child: Material(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: StyleString.mdRadius,
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                NetworkImgLayer(
                  src: cover,
                  width: w,
                  height: h,
                  borderRadius: BorderRadius.zero,
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0xD9000000), Color(0x00000000)],
                      stops: [0.0, 0.58],
                    ),
                  ),
                ),
                if (!compact && item.ratingScore > 0 && w >= 88)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xA6000000),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
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
                  ),
                Positioned(
                  left: 6,
                  right: 6,
                  bottom: 6,
                  child: Text(
                    title,
                    maxLines: (!compact && h >= 140) ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                  ),
                ),
                Positioned.fill(
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      onTap: () => context.pushNamed('/info/', arguments: item),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
