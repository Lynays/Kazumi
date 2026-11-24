import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Publishes whether the top-level window is actively being resized so heavy
/// offscreen effects (e.g. transparent floor reflections) can temporarily step
/// aside during drags and restore seamlessly once dragging stops.
class WindowResizeScope extends StatefulWidget {
  const WindowResizeScope({
    super.key,
    this.debounceDuration = const Duration(milliseconds: 150),
    required this.child,
  });

  final Duration debounceDuration;
  final Widget child;

  static bool isResizingOf(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<_WindowResizeInherited>()
            ?.isResizing ??
        false;
  }

  @override
  State<WindowResizeScope> createState() => _WindowResizeScopeState();
}

class _WindowResizeScopeState extends State<WindowResizeScope>
    with WidgetsBindingObserver {
  ui.FlutterView? _view;
  Size? _lastPhysicalSize;
  Timer? _resumeTimer;
  bool _isResizing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _view = View.maybeOf(context);
    _lastPhysicalSize ??= _view?.physicalSize;
  }

  @override
  void didChangeMetrics() {
    final currentSize = _view?.physicalSize;
    if (currentSize == null || currentSize == _lastPhysicalSize) {
      return;
    }
    _lastPhysicalSize = currentSize;
    if (!_isResizing) {
      setState(() => _isResizing = true);
    }
    _resumeTimer?.cancel();
    _resumeTimer = Timer(widget.debounceDuration, () {
      _resumeTimer = null;
      if (!mounted || !_isResizing) return;
      setState(() => _isResizing = false);
    });
  }

  @override
  void dispose() {
    _resumeTimer?.cancel();
    _resumeTimer = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _WindowResizeInherited(
      isResizing: _isResizing,
      child: widget.child,
    );
  }
}

class _WindowResizeInherited extends InheritedWidget {
  const _WindowResizeInherited({
    required this.isResizing,
    required super.child,
  });

  final bool isResizing;

  @override
  bool updateShouldNotify(_WindowResizeInherited oldWidget) =>
      isResizing != oldWidget.isResizing;
}
