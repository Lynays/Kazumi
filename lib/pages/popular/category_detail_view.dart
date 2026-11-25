import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kazumi/bean/card/bangumi_card.dart';
import 'package:kazumi/bean/widget/bangumi_mirror_error_widget.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/pages/popular/category_controller.dart';
import 'package:kazumi/pages/popular/popular_showcase.dart';
import 'package:kazumi/utils/constants.dart';

/// Level-2 Single Category Detail page:
/// - Zone A: Golden-ratio [PopularShowcaseStage] for Top 1 + Top 2–10, matching
///   the homepage [PopularDashboard] showcase height pixel-for-pixel (back
///   control lives in the persistent [CinemaTopBar]).
/// - Zone B: Responsive 3 / 5 / 6 column [BangumiCardV] infinite [SliverGrid]
///   starting strictly at item index 10 (#11+), with no 70-item cap.
class CategoryDetailView extends StatefulWidget {
  const CategoryDetailView({
    super.key,
    required this.controller,
    required this.tag,
    required this.viewportWidth,
    required this.viewportHeight,
  });

  final CategoryController controller;
  final String tag;
  final double viewportWidth;
  final double viewportHeight;

  @override
  State<CategoryDetailView> createState() => _CategoryDetailViewState();
}

class _CategoryDetailViewState extends State<CategoryDetailView> {
  static const double _progressHeight = 4.0;
  static const double _sectionGap = 12.0;
  static const double _minShowcaseHeight = 200.0;
  static const double _scrollToTopThreshold = 280.0;
  static const double _prefetchExtent = 360.0;
  static const int _maxAutoFillPages = 6;

  late final ScrollController _scrollController;
  final ValueNotifier<bool> _showScrollToTop = ValueNotifier<bool>(false);
  late CategoryTagFeed _feed;
  bool _fillCheckScheduled = false;
  int _autoFillCount = 0;

  // Cached Zone-A subtree so pagination updates to Zone B never rebuild
  // TOP 1 / Mosaic / Floor reflections.
  Widget? _cachedShowcaseSliver;
  BangumiItem? _cachedFeatured;
  int _cachedMosaicCount = -1;
  int? _cachedMosaicFirstId;
  double _cachedShowcaseHeight = -1;
  bool _cachedShowcaseSkeleton = false;

  @override
  void initState() {
    super.initState();
    _feed = widget.controller.feedFor(widget.tag);
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    widget.controller.addListener(_onControllerChanged);
    _scheduleViewportFillCheck();
  }

  @override
  void didUpdateWidget(CategoryDetailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
    if (oldWidget.tag != widget.tag || oldWidget.controller != widget.controller) {
      _feed = widget.controller.feedFor(widget.tag);
      _cachedShowcaseSliver = null;
      _autoFillCount = 0;
      _showScrollToTop.value = false;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0.0);
      }
      _scheduleViewportFillCheck();
    } else if (oldWidget.viewportWidth != widget.viewportWidth ||
        oldWidget.viewportHeight != widget.viewportHeight) {
      _scheduleViewportFillCheck();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _showScrollToTop.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    final next = widget.controller.feedFor(widget.tag);
    if (next == _feed) return;
    final prev = _feed;
    _feed = next;

    final finishedLoading = prev.isLoading && !next.isLoading;
    final structuralChange =
        !identical(prev.items, next.items) ||
        (prev.items.isEmpty &&
            (prev.isLoading != next.isLoading ||
                prev.hasError != next.hasError));
    // Only rebuild the main CustomScrollView when items or initial empty/error
    // state actually changed; top progress bar and bottom footer listen
    // independently so toggling isLoading during scroll never rebuilds the grid.
    if (structuralChange) {
      setState(() {});
    }
    if (finishedLoading && !next.hasError && !next.isExhausted) {
      _scheduleViewportFillCheck();
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final shouldShowFab = pos.pixels > _scrollToTopThreshold;
    if (shouldShowFab != _showScrollToTop.value) {
      _showScrollToTop.value = shouldShowFab;
    }
    if (pos.pixels > 0) {
      _autoFillCount = 0;
    }
    if (pos.hasContentDimensions &&
        pos.pixels >= pos.maxScrollExtent - _prefetchExtent &&
        !_feed.isLoading &&
        !_feed.isExhausted &&
        !_feed.hasError) {
      unawaited(widget.controller.loadMoreDetail(widget.tag));
    }
  }

  void _scheduleViewportFillCheck() {
    if (_fillCheckScheduled) return;
    _fillCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fillCheckScheduled = false;
      if (!mounted) return;
      final feed = widget.controller.feedFor(widget.tag);
      if (feed.isLoading || feed.isExhausted || feed.hasError) return;
      if (feed.items.isEmpty) {
        unawaited(widget.controller.loadMoreDetail(widget.tag));
        return;
      }
      if (!_scrollController.hasClients ||
          !_scrollController.position.hasContentDimensions) {
        return;
      }
      final pos = _scrollController.position;
      if (pos.maxScrollExtent - pos.pixels <= 200.0 &&
          _autoFillCount < _maxAutoFillPages) {
        _autoFillCount++;
        unawaited(widget.controller.loadMoreDetail(widget.tag));
      }
    });
  }

  Widget _showcaseSliver({
    required double showcaseHeight,
    required bool showSkeleton,
  }) {
    final featured = _feed.featured;
    final mosaic = _feed.mosaic;
    final mosaicFirstId = mosaic.isEmpty ? null : mosaic.first.id;
    final unchanged =
        _cachedShowcaseSliver != null &&
        identical(_cachedFeatured, featured) &&
        _cachedMosaicCount == mosaic.length &&
        _cachedMosaicFirstId == mosaicFirstId &&
        _cachedShowcaseHeight == showcaseHeight &&
        _cachedShowcaseSkeleton == showSkeleton;
    if (unchanged) {
      return _cachedShowcaseSliver!;
    }
    _cachedFeatured = featured;
    _cachedMosaicCount = mosaic.length;
    _cachedMosaicFirstId = mosaicFirstId;
    _cachedShowcaseHeight = showcaseHeight;
    _cachedShowcaseSkeleton = showSkeleton;
    return _cachedShowcaseSliver = SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        StyleString.cardSpace,
        0,
        StyleString.cardSpace,
        0,
      ),
      sliver: SliverToBoxAdapter(
        child: PopularShowcaseStage(
          featured: featured,
          mosaic: mosaic,
          showcaseHeight: showcaseHeight,
          bottomGap: _sectionGap,
          isLoading: showSkeleton,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final safeHeight = widget.viewportHeight.isFinite && widget.viewportHeight > 0
        ? widget.viewportHeight
        : 640.0;
    final availableWidth =
        widget.viewportWidth.isFinite && widget.viewportWidth > 0
        ? widget.viewportWidth
        : 0.0;
    final showcaseHeight = math.max(
      _minShowcaseHeight,
      (safeHeight - _progressHeight - _sectionGap) / 3.0,
    );

    final showInitialError =
        _feed.items.isEmpty && _feed.hasError && !_feed.isLoading;
    final showInitialSkeleton = _feed.items.isEmpty && _feed.isLoading;

    return Scaffold(
      backgroundColor: isDark ? Colors.transparent : null,
      body: CustomScrollView(
        key: ValueKey('category-detail-scroll-${widget.tag}'),
        controller: _scrollController,
        scrollCacheExtent: const ScrollCacheExtent.pixels(280.0),
        slivers: [
          SliverToBoxAdapter(
            child: ListenableBuilder(
              listenable: widget.controller,
              builder: (_, _) {
                final loading = widget.controller.feedFor(widget.tag).isLoading;
                return AnimatedOpacity(
                  opacity: loading ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 220),
                  child: loading
                      ? const LinearProgressIndicator(
                          minHeight: _progressHeight,
                        )
                      : const SizedBox(height: _progressHeight),
                );
              },
            ),
          ),
          if (showInitialError)
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: StyleString.cardSpace,
              ),
              sliver: SliverToBoxAdapter(
                child: SizedBox(
                  height: 400,
                  child: BangumiMirrorErrorWidget(
                    onRetry: () => widget.controller.retryTag(widget.tag),
                    onSettingsReturned: () =>
                        widget.controller.retryTag(widget.tag),
                  ),
                ),
              ),
            )
          else ...[
            _showcaseSliver(
              showcaseHeight: showcaseHeight,
              showSkeleton: showInitialSkeleton,
            ),
            _buildRemainderGrid(
              context,
              availableWidth: availableWidth,
              showSkeleton: showInitialSkeleton,
            ),
            SliverToBoxAdapter(
              child: ListenableBuilder(
                listenable: widget.controller,
                builder: (context, _) => _buildFooter(
                  context,
                  widget.controller.feedFor(widget.tag),
                ),
              ),
            ),
          ],
        ],
      ),
      floatingActionButton: ValueListenableBuilder<bool>(
        valueListenable: _showScrollToTop,
        builder: (_, visible, _) {
          if (!visible) return const SizedBox.shrink();
          return FloatingActionButton(
            onPressed: () => _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOut,
            ),
            child: const Icon(Icons.arrow_upward),
          );
        },
      ),
    );
  }

  Widget _buildRemainderGrid(
    BuildContext context, {
    required double availableWidth,
    required bool showSkeleton,
  }) {
    final childCount = showSkeleton ? 10 : _feed.gridCount;
    if (childCount <= 0) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    int crossCount = 3;
    if (availableWidth > LayoutBreakpoint.compact['width']!) {
      crossCount = 5;
    }
    if (availableWidth > LayoutBreakpoint.medium['width']!) {
      crossCount = 6;
    }
    final contentWidth = math.max(
      0.0,
      availableWidth - StyleString.cardSpace * 2 - 16.0,
    );
    final cardWidth = math.max(
      1.0,
      (contentWidth - (crossCount - 1) * StyleString.cardSpace) / crossCount,
    );
    final coverHeight = cardWidth / 0.65;
    final mainAxisExtent =
        contentWidth / crossCount / 0.65 +
        MediaQuery.textScalerOf(context).scale(32.0);

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        StyleString.cardSpace + 8,
        4,
        StyleString.cardSpace + 8,
        8,
      ),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          mainAxisSpacing: StyleString.cardSpace - 2,
          crossAxisSpacing: StyleString.cardSpace,
          crossAxisCount: crossCount,
          mainAxisExtent: mainAxisExtent,
        ),
        delegate: SliverChildBuilderDelegate(
          (BuildContext context, int index) {
            if (showSkeleton) {
              return const _GridCardSkeleton();
            }
            return BangumiCardV(
              bangumiItem: _feed.items[10 + index],
              coverWidth: cardWidth,
              coverHeight: coverHeight,
            );
          },
          childCount: childCount,
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context, CategoryTagFeed feed) {
    final theme = Theme.of(context);
    if (feed.isLoading && feed.items.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              Text(
                '正在加载更多...',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (feed.hasError && feed.items.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: TextButton.icon(
            onPressed: () => widget.controller.retryTag(widget.tag),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('加载更多失败 · 点击重试'),
          ),
        ),
      );
    }
    if (feed.isExhausted && feed.items.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            '已加载全部 ${feed.items.length} 部番剧',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return const SizedBox(height: 24);
  }
}

class _GridCardSkeleton extends StatelessWidget {
  const _GridCardSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.45,
          );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}
