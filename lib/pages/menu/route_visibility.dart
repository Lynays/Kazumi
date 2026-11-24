import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Whether the surrounding route subtree is covered by another page.
///
/// Published by the page that owns the route, so long-lived children can stop
/// background work while hidden instead of inspecting the navigation stack.
class RouteVisibility extends InheritedWidget {
  const RouteVisibility({
    super.key,
    required this.isCovered,
    required super.child,
  });

  final bool isCovered;

  /// Subscribes; dependents are notified only when the state flips.
  static bool isCoveredOf(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<RouteVisibility>()
            ?.isCovered ??
        false;
  }

  @override
  bool updateShouldNotify(RouteVisibility oldWidget) =>
      isCovered != oldWidget.isCovered;
}

/// Freezes incoming [MediaQuery] updates and layout constraints while a route
/// is covered by another opaque page so offstage routes do not re-layout or
/// re-decode images on every desktop window resize frame.
class FreezeLayoutWhenCovered extends StatefulWidget {
  const FreezeLayoutWhenCovered({
    super.key,
    required this.isCovered,
    required this.child,
  });

  final bool isCovered;
  final Widget child;

  @override
  State<FreezeLayoutWhenCovered> createState() =>
      _FreezeLayoutWhenCoveredState();
}

class _FreezeLayoutWhenCoveredState extends State<FreezeLayoutWhenCovered> {
  MediaQueryData? _frozenMediaQuery;

  @override
  Widget build(BuildContext context) {
    final effectiveCovered =
        widget.isCovered || !TickerMode.valuesOf(context).enabled;
    final liveMediaQuery = MediaQuery.maybeOf(context);
    if (!effectiveCovered || _frozenMediaQuery == null) {
      _frozenMediaQuery = liveMediaQuery;
    }

    Widget content = _FreezeLayoutBox(
      frozen: effectiveCovered,
      child: widget.child,
    );
    final data = _frozenMediaQuery;
    if (data != null) {
      content = MediaQuery(data: data, child: content);
    }
    return content;
  }
}

class _FreezeLayoutBox extends SingleChildRenderObjectWidget {
  const _FreezeLayoutBox({required this.frozen, required super.child});

  final bool frozen;

  @override
  _RenderFreezeLayout createRenderObject(BuildContext context) =>
      _RenderFreezeLayout(frozen: frozen);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderFreezeLayout renderObject,
  ) {
    renderObject.frozen = frozen;
  }
}

class _RenderFreezeLayout extends RenderProxyBox {
  _RenderFreezeLayout({required bool frozen}) : _frozen = frozen;

  bool _frozen;
  BoxConstraints? _frozenConstraints;

  bool get frozen => _frozen;
  set frozen(bool value) {
    if (_frozen == value) return;
    _frozen = value;
    if (!_frozen) {
      markNeedsLayout();
    }
  }

  @override
  void performLayout() {
    final childBox = child;
    if (childBox == null) {
      size = constraints.smallest;
      return;
    }

    final BoxConstraints childConstraints;
    if (_frozen && _frozenConstraints != null) {
      childConstraints = _frozenConstraints!;
    } else {
      _frozenConstraints = constraints;
      childConstraints = constraints;
    }

    // Passing identical cached constraints while frozen lets RenderObject.layout
    // return immediately in O(1) unless a descendant explicitly dirtied layout.
    childBox.layout(childConstraints, parentUsesSize: true);
    size = constraints.constrain(childBox.size);
  }
}
