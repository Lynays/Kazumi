import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/pages/popular/popular_carousel_floor.dart';
import 'package:kazumi/pages/popular/popular_carousel_strip.dart';

/// Vertically stacks three Popular carousel strips with staggered continuous
/// slow cruise and independent per-row hover/interaction pause.
class PopularCarouselRegion extends StatefulWidget {
  const PopularCarouselRegion({super.key, required this.rows});

  final List<List<BangumiItem>> rows;

  @override
  State<PopularCarouselRegion> createState() => _PopularCarouselRegionState();
}

class _PopularCarouselRegionState extends State<PopularCarouselRegion>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const int _rowCount = 3;
  static const double _gap = 12.0;
  static const List<double> _weights = [0.352, 0.308, 0.340];
  static const List<double> _speeds = [24.0, 15.5, 31.0];
  static const List<double> _initialOffsets = [0.0, 56.0, 118.0];

  late final List<ScrollController> _controllers;
  late final Ticker _ticker;
  final List<double> _opacities = [1.0, 1.0, 1.0];
  final List<bool> _seeded = [false, false, false];
  final List<Timer?> _resetTimers = List<Timer?>.filled(_rowCount, null);
  final Set<int> _interactingRows = <int>{};
  final Set<int> _resettingRows = <int>{};

  Duration? _lastTick;
  bool _appResumed = true;
  bool _tickerEnabled = true;
  bool _reduceMotion = false;
  bool _disposed = false;

  bool get _canAutoScroll => _appResumed && _tickerEnabled && !_reduceMotion;

  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _appResumed = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    _controllers = List.generate(_rowCount, (_) => ScrollController());
    _ticker = createTicker(_onTick);
    WidgetsBinding.instance.addPostFrameCallback((_) => _seedOffsets());
  }

  @override
  void didUpdateWidget(PopularCarouselRegion oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _seedOffsets());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _syncTicker(notify: false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appResumed = state == AppLifecycleState.resumed;
    _syncTicker();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    for (final t in _resetTimers) {
      t?.cancel();
    }
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _seedOffsets() {
    if (!mounted || _disposed || _reduceMotion) return;
    for (var i = 0; i < _rowCount; i++) {
      if (_seeded[i]) continue;
      final c = _controllers[i];
      if (!c.hasClients) continue;
      final max = c.position.maxScrollExtent;
      if (!max.isFinite || max <= 10) continue;
      _seeded[i] = true;
      final initial = _initialOffsets[i].clamp(0.0, max * 0.4);
      if (initial > 0 && c.offset == 0) {
        c.jumpTo(initial);
      }
    }
  }

  void _syncTicker({bool notify = true}) {
    if (_disposed) return;
    final shouldRun = _canAutoScroll;
    if (shouldRun && !_ticker.isActive) {
      _lastTick = null;
      _ticker.start();
    } else if (!shouldRun) {
      if (_ticker.isActive) {
        _ticker.stop();
        _lastTick = null;
      }
      _cancelAllPendingResets(notify: notify);
    }
  }

  void _onRowInteractionStart(int row) {
    _interactingRows.add(row);
    _cancelRowReset(row);
  }

  void _onRowInteractionEnd(int row) {
    _interactingRows.remove(row);
  }

  void _cancelRowReset(int row, {bool notify = true}) {
    _resetTimers[row]?.cancel();
    _resetTimers[row] = null;
    _resettingRows.remove(row);
    if (_opacities[row] != 1.0) {
      if (notify && mounted && !_disposed) {
        setState(() => _opacities[row] = 1.0);
      } else {
        _opacities[row] = 1.0;
      }
    }
  }

  void _cancelAllPendingResets({bool notify = true}) {
    var opacityChanged = false;
    for (var i = 0; i < _rowCount; i++) {
      _resetTimers[i]?.cancel();
      _resetTimers[i] = null;
      _resettingRows.remove(i);
      if (_opacities[i] != 1.0) {
        _opacities[i] = 1.0;
        opacityChanged = true;
      }
    }
    if (opacityChanged && notify && mounted && !_disposed) {
      setState(() {});
    }
  }

  void _onTick(Duration elapsed) {
    final prev = _lastTick;
    _lastTick = elapsed;
    if (prev == null || _disposed) return;
    final dt = ((elapsed - prev).inMicroseconds / 1e6).clamp(0.0, 0.05);
    if (dt <= 0) return;

    for (var i = 0; i < _rowCount; i++) {
      if (_interactingRows.contains(i) || _resettingRows.contains(i)) continue;
      final c = _controllers[i];
      if (!c.hasClients) continue;
      final max = c.position.maxScrollExtent;
      if (!max.isFinite || max <= 0.5) continue;
      final next = c.offset + _speeds[i] * dt;
      if (next >= max - 0.5) {
        _startRowReset(i, c);
      } else {
        c.jumpTo(next);
      }
    }
  }

  void _startRowReset(int row, ScrollController c) {
    if (!_canAutoScroll || _interactingRows.contains(row)) return;
    _resetTimers[row]?.cancel();
    _resettingRows.add(row);
    if (mounted && !_disposed) setState(() => _opacities[row] = 0.0);
    _resetTimers[row] = Timer(const Duration(milliseconds: 180), () {
      if (!mounted || _disposed) return;
      if (!_canAutoScroll || _interactingRows.contains(row)) {
        _cancelRowReset(row);
        return;
      }
      if (c.hasClients) c.jumpTo(0.0);
      setState(() => _opacities[row] = 1.0);
      _resetTimers[row] = Timer(const Duration(milliseconds: 180), () {
        _resetTimers[row] = null;
        if (!_disposed) _resettingRows.remove(row);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) {
        final totalH =
            c.hasBoundedHeight && c.maxHeight.isFinite && c.maxHeight > 0
            ? c.maxHeight
            : 600.0;
        final netH = (totalH - _gap * 2).clamp(180.0, double.infinity);

        return PopularCarouselFloor(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < _rowCount; i++) ...[
                if (i > 0) const SizedBox(height: _gap),
                AnimatedOpacity(
                  opacity: _opacities[i],
                  duration: _reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  child: PopularCarouselStrip(
                    items: i < widget.rows.length
                        ? widget.rows[i]
                        : const <BangumiItem>[],
                    controller: _controllers[i],
                    height: netH * _weights[i],
                    onUserInteractionStart: () => _onRowInteractionStart(i),
                    onUserInteractionEnd: () => _onRowInteractionEnd(i),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
