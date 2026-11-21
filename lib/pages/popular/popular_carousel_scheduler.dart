import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Round-robin auto-scroll scheduler for horizontally scrollable carousel strips.
///
/// Selects at most one attached and scrollable [ScrollController] per cycle,
/// leaving ownership and disposal of all controllers to the caller.
class PopularCarouselScheduler {
  PopularCarouselScheduler({
    required List<ScrollController> controllers,
    required double Function(int rowIndex) stepExtent,
    Duration idleInterval = const Duration(seconds: 4),
    Duration animationDuration = const Duration(milliseconds: 750),
    Future<void> Function(int rowIndex, ScrollController controller)?
    onReachEnd,
    Curve curve = Curves.easeInOutCubic,
  }) : _controllers = List<ScrollController>.unmodifiable(controllers),
       _stepExtent = stepExtent,
       _idleInterval = idleInterval.isNegative ? Duration.zero : idleInterval,
       _animationDuration = animationDuration <= Duration.zero
           ? const Duration(milliseconds: 1)
           : animationDuration,
       _onReachEnd = onReachEnd,
       _curve = curve;

  final List<ScrollController> _controllers;
  final double Function(int rowIndex) _stepExtent;
  final Duration _idleInterval;
  final Duration _animationDuration;
  final Future<void> Function(int rowIndex, ScrollController controller)?
  _onReachEnd;
  final Curve _curve;

  Timer? _timer;
  int _nextRow = 0;
  int? _activeRow;
  int _epoch = 0;
  bool _running = false;
  bool _paused = false;
  bool _disposed = false;

  /// Starts or unpauses scheduled carousel stepping.
  void start() {
    if (_disposed) return;
    if (_running && !_paused) return;
    _running = true;
    _paused = false;
    _schedule();
  }

  /// Pauses scheduling and halts any active programmatic scroll in place.
  void pause() {
    if (_disposed || !_running || _paused) return;
    _paused = true;
    _haltActive();
  }

  /// Resumes scheduling after [pause]; has no effect if stopped or disposed.
  void resume() {
    if (_disposed || !_running || !_paused) return;
    _paused = false;
    _schedule();
  }

  /// Stops scheduling, halts any active scroll, and resets round-robin order.
  void stop() {
    if (_disposed) return;
    _running = false;
    _paused = false;
    _nextRow = 0;
    _haltActive();
  }

  /// Permanently stops the scheduler without disposing external controllers.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _running = false;
    _paused = false;
    _nextRow = 0;
    _haltActive();
  }

  void _schedule() {
    if (_disposed || !_running || _paused || _activeRow != null) return;
    _timer?.cancel();
    final epoch = _epoch;
    _timer = Timer(_idleInterval, () {
      _timer = null;
      if (epoch != _epoch || _disposed || !_running || _paused) return;
      unawaited(_advance(epoch));
    });
  }

  ({int row, double step})? _pickNextRow() {
    final count = _controllers.length;
    if (count == 0) return null;
    final start = _nextRow % count;
    for (var offset = 0; offset < count; offset++) {
      final idx = (start + offset) % count;
      final pos = _attachedPosition(_controllers[idx]);
      if (pos == null ||
          !pos.hasContentDimensions ||
          !pos.hasPixels ||
          !pos.maxScrollExtent.isFinite ||
          pos.maxScrollExtent <= 0.5) {
        continue;
      }
      final step = _stepExtent(idx);
      if (!step.isFinite || step <= 0) continue;
      return (row: idx, step: step);
    }
    return null;
  }

  ScrollPosition? _attachedPosition(ScrollController controller) {
    if (!controller.hasClients) return null;
    final positions = controller.positions;
    return positions.length == 1 ? positions.first : null;
  }

  Future<void> _advance(int myEpoch) async {
    if (myEpoch != _epoch || _disposed || !_running || _paused) return;
    final picked = _pickNextRow();
    if (picked == null) {
      _schedule();
      return;
    }

    final idx = picked.row;
    final controller = _controllers[idx];
    final pos = _attachedPosition(controller);
    if (pos == null || !pos.hasContentDimensions || !pos.hasPixels) {
      _schedule();
      return;
    }

    _activeRow = idx;
    _nextRow = (idx + 1) % _controllers.length;

    try {
      if (pos.pixels >= pos.maxScrollExtent - 0.5) {
        final onReachEnd = _onReachEnd;
        if (onReachEnd != null) {
          await onReachEnd(idx, controller);
        } else {
          await controller.animateTo(
            0.0,
            duration: _animationDuration,
            curve: _curve,
          );
        }
      } else {
        final target = (pos.pixels + picked.step)
            .clamp(0.0, pos.maxScrollExtent)
            .toDouble();
        await controller.animateTo(
          target,
          duration: _animationDuration,
          curve: _curve,
        );
      }
    } catch (_) {
      // Controllers may detach mid-animation during teardown; ignore safely.
    } finally {
      if (myEpoch == _epoch) {
        _activeRow = null;
        if (!_disposed && _running && !_paused) {
          _schedule();
        }
      }
    }
  }

  void _haltActive() {
    _epoch++;
    _timer?.cancel();
    _timer = null;
    final row = _activeRow;
    _activeRow = null;
    if (row == null || row >= _controllers.length) return;
    final pos = _attachedPosition(_controllers[row]);
    if (pos != null &&
        pos.hasPixels &&
        pos.isScrollingNotifier.value &&
        pos.userScrollDirection == ScrollDirection.idle) {
      pos.jumpTo(pos.pixels);
    }
  }
}
