import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/widget/window_resize_scope.dart';
import 'package:kazumi/pages/menu/route_visibility.dart';
import 'package:kazumi/pages/popular/category_controller.dart';
import 'package:kazumi/pages/popular/popular_carousel_floor.dart';
import 'package:kazumi/pages/popular/popular_carousel_strip.dart';

/// Level-1 Cinema Category Overview page: 15 virtualized horizontal carousel
/// rows over a viewport-fixed [PopularCarouselFloor], coordinated by a single
/// [Ticker] that gently cruises only mounted visible rows.
class CategoryOverviewView extends StatefulWidget {
  const CategoryOverviewView({
    super.key,
    required this.controller,
    required this.viewportHeight,
  });

  final CategoryController controller;
  final double viewportHeight;

  @override
  State<CategoryOverviewView> createState() => _CategoryOverviewViewState();
}

class _CategoryOverviewViewState extends State<CategoryOverviewView>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const double _rowGap = 14.0;
  static const Duration _resizePauseDuration = Duration(milliseconds: 150);
  static const List<double> _speeds = [24.0, 15.5, 31.0];
  static const List<double> _initialOffsets = [0.0, 56.0, 118.0];

  late final ScrollController _verticalController;
  late final Ticker _ticker;

  final Map<String, _MountedOverviewRow> _mountedRows =
      <String, _MountedOverviewRow>{};
  final Set<String> _visibleTags = <String>{};
  final Set<String> _interactingTags = <String>{};
  final Set<String> _resettingTags = <String>{};
  final Set<String> _seededTags = <String>{};
  final Map<String, Timer> _resetTimers = <String, Timer>{};
  final Map<String, ValueNotifier<double>> _rowOpacities =
      <String, ValueNotifier<double>>{};

  Duration? _lastTick;
  ui.FlutterView? _view;
  Size? _lastPhysicalSize;
  Timer? _resizeResumeTimer;
  bool _viewportUpdatePending = false;
  bool _appResumed = true;
  bool _tickerEnabled = true;
  bool _reduceMotion = false;
  bool _isCovered = false;
  bool _scopeResizing = false;
  bool _metricsResizing = false;
  bool _verticalScrolling = false;
  bool _disposed = false;

  bool get _isResizing => _scopeResizing || _metricsResizing;

  bool get _canAutoScroll =>
      _appResumed &&
      _tickerEnabled &&
      !_reduceMotion &&
      !_isCovered &&
      !_isResizing &&
      !_verticalScrolling;

  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _appResumed = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    _verticalController = ScrollController(
      initialScrollOffset: widget.controller.overviewScrollOffset,
    );
    _verticalController.addListener(_onVerticalScroll);
    _ticker = createTicker(_onTick);
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(CategoryOverviewView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
    _scheduleViewportUpdate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _isCovered = RouteVisibility.isCoveredOf(context);
    _scopeResizing = WindowResizeScope.isResizingOf(context);
    _view = View.maybeOf(context);
    _lastPhysicalSize = _view?.physicalSize;
    if (_isCovered || !_tickerEnabled) {
      _resizeResumeTimer?.cancel();
      _resizeResumeTimer = null;
      _metricsResizing = false;
    } else if (!_isResizing) {
      _scheduleViewportUpdate();
    }
    _syncTicker();
  }

  @override
  void didChangeMetrics() {
    if (_disposed || !_tickerEnabled || _isCovered) return;
    final currentPhysicalSize = _view?.physicalSize;
    final sizeChanged =
        currentPhysicalSize == null || currentPhysicalSize != _lastPhysicalSize;
    if (sizeChanged) {
      _lastPhysicalSize = currentPhysicalSize;
      final wasResizing = _metricsResizing;
      _metricsResizing = true;
      if (!wasResizing) {
        _syncTicker();
      }
      _resizeResumeTimer?.cancel();
      _resizeResumeTimer = Timer(_resizePauseDuration, () {
        _resizeResumeTimer = null;
        if (!mounted || _disposed) return;
        _metricsResizing = false;
        if (!_tickerEnabled || _isCovered) return;
        _scheduleViewportUpdate();
      });
      return;
    }
    _scheduleViewportUpdate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appResumed = state == AppLifecycleState.resumed;
    _syncTicker();
  }

  @override
  void dispose() {
    _disposed = true;
    if (_verticalController.hasClients) {
      widget.controller.overviewScrollOffset = _verticalController.offset;
    }
    widget.controller.removeListener(_onControllerChanged);
    _resizeResumeTimer?.cancel();
    _resizeResumeTimer = null;
    WidgetsBinding.instance.removeObserver(this);
    _verticalController.removeListener(_onVerticalScroll);
    _verticalController.dispose();
    _ticker.dispose();
    for (final timer in _resetTimers.values) {
      timer.cancel();
    }
    _resetTimers.clear();
    for (final opacity in _rowOpacities.values) {
      opacity.dispose();
    }
    _rowOpacities.clear();
    _mountedRows.clear();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted || _disposed) return;
    _scheduleViewportUpdate();
  }

  void _onVerticalScroll() {
    if (_verticalController.hasClients) {
      widget.controller.overviewScrollOffset = _verticalController.offset;
    }
    if (!_verticalScrolling) {
      _scheduleViewportUpdate();
    }
  }

  ValueNotifier<double> _opacityFor(String tag) {
    return _rowOpacities.putIfAbsent(tag, () => ValueNotifier<double>(1.0));
  }

  void _registerRow(_MountedOverviewRow row) {
    final opacity = _rowOpacities[row.tag];
    if (opacity != null && opacity.value != 1.0) {
      opacity.value = 1.0;
    }
    _mountedRows[row.tag] = row;
    _scheduleViewportUpdate();
  }

  void _unregisterRow(String tag, ScrollController controller) {
    final current = _mountedRows[tag];
    if (current != null && identical(current.controller, controller)) {
      _mountedRows.remove(tag);
      _visibleTags.remove(tag);
      _interactingTags.remove(tag);
      // Only cancel timers during dispose/finalizeTree; avoid mutating
      // ValueNotifier while its child ValueListenableBuilder is still
      // unmounting in the same locked tree pass.
      _resetTimers.remove(tag)?.cancel();
      _resettingTags.remove(tag);
      _syncTicker();
    }
  }

  void _onRowInteractionStart(String tag) {
    _interactingTags.add(tag);
    _cancelRowReset(tag);
  }

  void _onRowInteractionEnd(String tag) {
    _interactingTags.remove(tag);
  }

  void _seedOffsets() {
    if (!mounted || _disposed || _reduceMotion) return;
    for (final row in _mountedRows.values) {
      final tag = row.tag;
      if (_seededTags.contains(tag) || !_visibleTags.contains(tag)) continue;
      if (widget.controller.rowScrollOffsets.containsKey(tag)) {
        _seededTags.add(tag);
        continue;
      }
      final c = row.controller;
      if (!c.hasClients || !c.position.hasContentDimensions) continue;
      final max = c.position.maxScrollExtent;
      if (!max.isFinite || max <= 10) continue;
      _seededTags.add(tag);
      final initial = _initialOffsets[row.index % _initialOffsets.length]
          .clamp(0.0, max * 0.4);
      if (initial > 0 && c.offset == 0) {
        c.jumpTo(initial);
      }
    }
  }

  void _scheduleViewportUpdate() {
    if (_viewportUpdatePending ||
        _disposed ||
        !_tickerEnabled ||
        _isCovered ||
        _isResizing ||
        _verticalScrolling) {
      return;
    }
    _viewportUpdatePending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewportUpdatePending = false;
      if (!mounted ||
          _disposed ||
          !_tickerEnabled ||
          _isCovered ||
          _isResizing) {
        return;
      }
      for (final row in _mountedRows.values) {
        final renderObj = row.key.currentContext?.findRenderObject();
        final visible =
            renderObj is RenderBox && renderObj.hasSize && _isVisible(renderObj);
        if (visible) {
          _visibleTags.add(row.tag);
        } else {
          if (_visibleTags.remove(row.tag)) {
            _cancelRowReset(row.tag);
          }
        }
      }
      _seedOffsets();
      _syncTicker();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  bool _isVisible(RenderBox row) {
    final viewport = RenderAbstractViewport.maybeOf(row);
    if (viewport == null) return !row.size.isEmpty;
    final bounds = MatrixUtils.transformRect(
      row.getTransformTo(viewport),
      row.paintBounds,
    );
    return !bounds.isEmpty && viewport.paintBounds.overlaps(bounds);
  }

  bool _canScrollRow(_MountedOverviewRow row) {
    if (!_visibleTags.contains(row.tag)) return false;
    final c = row.controller;
    if (!c.hasClients || !c.position.hasContentDimensions) return false;
    final max = c.position.maxScrollExtent;
    return max.isFinite && max > 0.5;
  }

  void _syncTicker() {
    if (_disposed) return;
    final shouldRun =
        _canAutoScroll && _mountedRows.values.any(_canScrollRow);
    if (shouldRun && !_ticker.isActive) {
      _lastTick = null;
      _ticker.start();
    } else if (!shouldRun) {
      if (_ticker.isActive) {
        _ticker.stop();
        _lastTick = null;
      }
      _cancelAllPendingResets();
    }
  }

  void _cancelRowReset(String tag) {
    _resetTimers.remove(tag)?.cancel();
    _resettingTags.remove(tag);
    final opacity = _rowOpacities[tag];
    if (opacity != null && opacity.value != 1.0) {
      opacity.value = 1.0;
    }
  }

  void _cancelAllPendingResets() {
    for (final timer in _resetTimers.values) {
      timer.cancel();
    }
    _resetTimers.clear();
    _resettingTags.clear();
    for (final opacity in _rowOpacities.values) {
      if (opacity.value != 1.0) {
        opacity.value = 1.0;
      }
    }
  }

  void _onTick(Duration elapsed) {
    final prev = _lastTick;
    _lastTick = elapsed;
    if (prev == null || _disposed) return;
    final dt = ((elapsed - prev).inMicroseconds / 1e6).clamp(0.0, 0.05);
    if (dt <= 0) return;

    for (final row in _mountedRows.values) {
      final tag = row.tag;
      if (!_canScrollRow(row) ||
          _interactingTags.contains(tag) ||
          _resettingTags.contains(tag)) {
        continue;
      }
      final c = row.controller;
      final max = c.position.maxScrollExtent;
      final speed = _speeds[row.index % _speeds.length];
      final next = c.offset + speed * dt;
      if (next >= max - 0.5) {
        _startRowReset(tag, c);
      } else {
        c.jumpTo(next);
      }
    }
  }

  void _startRowReset(String tag, ScrollController c) {
    if (!_canAutoScroll ||
        !_visibleTags.contains(tag) ||
        _interactingTags.contains(tag)) {
      return;
    }
    _resetTimers.remove(tag)?.cancel();
    _resettingTags.add(tag);
    _opacityFor(tag).value = 0.0;
    _resetTimers[tag] = Timer(const Duration(milliseconds: 180), () {
      if (!mounted || _disposed) return;
      if (!_canAutoScroll ||
          !_visibleTags.contains(tag) ||
          _interactingTags.contains(tag)) {
        _cancelRowReset(tag);
        return;
      }
      if (c.hasClients) c.jumpTo(0.0);
      _opacityFor(tag).value = 1.0;
      _resetTimers[tag] = Timer(const Duration(milliseconds: 180), () {
        _resetTimers.remove(tag);
        if (!_disposed) _resettingTags.remove(tag);
      });
    });
  }

  bool _handleVerticalScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (notification is ScrollStartNotification) {
      if (!_verticalScrolling) {
        _verticalScrolling = true;
        _syncTicker();
      }
    } else if (notification is ScrollEndNotification) {
      if (_verticalScrolling) {
        _verticalScrolling = false;
        _scheduleViewportUpdate();
      }
    }
    return false;
  }

  bool get _allMountedRowsFailed {
    if (_mountedRows.isEmpty) return false;
    for (final tag in _mountedRows.keys) {
      final feed = widget.controller.feedFor(tag);
      if (feed.isLoading || !feed.hasError || feed.items.isNotEmpty) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final safeHeight = widget.viewportHeight.isFinite && widget.viewportHeight > 0
        ? widget.viewportHeight
        : 640.0;
    // Floor-quantize to 2px steps so ~3 full rows + 4th header edge fit on desktop.
    final rawExtent = ((safeHeight - 24.0) / 3.0).clamp(188.0, 244.0);
    final rowExtent = (rawExtent / 2.0).floor() * 2.0;
    final itemExtent = rowExtent + _rowGap;
    final tags = widget.controller.tags;

    return PopularCarouselFloor(
      child: NotificationListener<ScrollNotification>(
        onNotification: _handleVerticalScrollNotification,
        child: NotificationListener<ScrollMetricsNotification>(
          onNotification: (_) {
            _scheduleViewportUpdate();
            return false;
          },
          child: CustomScrollView(
            key: const ValueKey('category-overview-scroll'),
            controller: _verticalController,
            scrollCacheExtent: const ScrollCacheExtent.pixels(160.0),
            slivers: [
              SliverToBoxAdapter(
                child: ListenableBuilder(
                  listenable: widget.controller,
                  builder: (context, _) {
                    if (!_allMountedRowsFailed) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: Material(
                        color: Theme.of(
                          context,
                        ).colorScheme.errorContainer.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.cloud_off_rounded, size: 18),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  '当前可见分类加载失败，可一键重试或调整加速设置',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              TextButton(
                                onPressed: () => widget.controller
                                    .retryFailedTags(_mountedRows.keys.toList()),
                                child: const Text('重试全部'),
                              ),
                              TextButton(
                                onPressed: () async {
                                  await context.pushNamed('/settings/proxy/');
                                  if (!mounted) return;
                                  widget.controller.retryFailedTags(
                                    _mountedRows.keys.toList(),
                                  );
                                },
                                child: const Text('加速设置'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.only(top: 10, bottom: 16),
                sliver: SliverFixedExtentList.builder(
                  itemExtent: itemExtent,
                  itemCount: tags.length,
                  itemBuilder: (context, index) {
                    final tag = tags[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: _rowGap),
                      child: _CategoryOverviewRow(
                        key: ValueKey('category-overview-row-$tag'),
                        index: index,
                        tag: tag,
                        height: rowExtent,
                        controller: widget.controller,
                        opacityListenable: _opacityFor(tag),
                        reduceMotion: _reduceMotion,
                        onRegister: _registerRow,
                        onUnregister: _unregisterRow,
                        onInteractionStart: () => _onRowInteractionStart(tag),
                        onInteractionEnd: () => _onRowInteractionEnd(tag),
                        onOpenDetail: () =>
                            widget.controller.openCategoryDetail(tag),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MountedOverviewRow {
  const _MountedOverviewRow({
    required this.index,
    required this.tag,
    required this.controller,
    required this.key,
  });

  final int index;
  final String tag;
  final ScrollController controller;
  final GlobalKey key;
}

class _CategoryOverviewRow extends StatefulWidget {
  const _CategoryOverviewRow({
    super.key,
    required this.index,
    required this.tag,
    required this.height,
    required this.controller,
    required this.opacityListenable,
    required this.reduceMotion,
    required this.onRegister,
    required this.onUnregister,
    required this.onInteractionStart,
    required this.onInteractionEnd,
    required this.onOpenDetail,
  });

  final int index;
  final String tag;
  final double height;
  final CategoryController controller;
  final ValueNotifier<double> opacityListenable;
  final bool reduceMotion;
  final ValueChanged<_MountedOverviewRow> onRegister;
  final void Function(String tag, ScrollController controller) onUnregister;
  final VoidCallback onInteractionStart;
  final VoidCallback onInteractionEnd;
  final VoidCallback onOpenDetail;

  @override
  State<_CategoryOverviewRow> createState() => _CategoryOverviewRowState();
}

class _CategoryOverviewRowState extends State<_CategoryOverviewRow> {
  final GlobalKey _rowKey = GlobalKey();
  late final ScrollController _rowController;
  late CategoryTagFeed _feed;

  @override
  void initState() {
    super.initState();
    _feed = widget.controller.feedFor(widget.tag);
    _rowController = ScrollController(
      initialScrollOffset: widget.controller.rowScrollOffsets[widget.tag] ?? 0.0,
    );
    _rowController.addListener(_saveHorizontalOffset);
    widget.controller.addListener(_onFeedChanged);
    widget.onRegister(
      _MountedOverviewRow(
        index: widget.index,
        tag: widget.tag,
        controller: _rowController,
        key: _rowKey,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(widget.controller.ensureRowLoaded(widget.tag));
    });
  }

  @override
  void didUpdateWidget(_CategoryOverviewRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onFeedChanged);
      widget.controller.addListener(_onFeedChanged);
      _feed = widget.controller.feedFor(widget.tag);
    }
  }

  void _onFeedChanged() {
    if (!mounted) return;
    final next = widget.controller.feedFor(widget.tag);
    if (next != _feed) {
      setState(() => _feed = next);
    }
  }

  void _saveHorizontalOffset() {
    if (_rowController.hasClients) {
      widget.controller.rowScrollOffsets[widget.tag] = _rowController.offset;
    }
  }

  @override
  void dispose() {
    if (_rowController.hasClients) {
      widget.controller.rowScrollOffsets[widget.tag] = _rowController.offset;
    }
    widget.controller.cancelPendingRowLoad(widget.tag);
    widget.controller.removeListener(_onFeedChanged);
    widget.onUnregister(widget.tag, _rowController);
    _rowController.removeListener(_saveHorizontalOffset);
    _rowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strip = PopularCarouselStrip(
      items: _feed.items,
      controller: _rowController,
      height: widget.height,
      label: widget.tag,
      onLabelTap: widget.onOpenDetail,
      isLoading: _feed.isLoading && _feed.items.isEmpty,
      hasError: _feed.hasError && _feed.items.isEmpty,
      onRetry: () => widget.controller.retryTag(widget.tag),
      onUserInteractionStart: widget.onInteractionStart,
      onUserInteractionEnd: widget.onInteractionEnd,
    );

    return ValueListenableBuilder<double>(
      valueListenable: widget.opacityListenable,
      child: strip,
      builder: (context, opacity, child) => AnimatedOpacity(
        key: _rowKey,
        opacity: opacity,
        duration: widget.reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 180),
        child: child,
      ),
    );
  }
}
