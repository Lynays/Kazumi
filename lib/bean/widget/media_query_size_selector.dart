import 'package:flutter/widgets.dart';

/// Isolates [MediaQuery.sizeOf] subscriptions so [builder] only runs when the
/// selected value [T] changes or the parent widget updates.
class MediaQuerySizeSelector<T> extends StatefulWidget {
  const MediaQuerySizeSelector({
    super.key,
    required this.select,
    required this.builder,
    this.child,
  });

  final T Function(Size size) select;
  final Widget Function(BuildContext context, T value, Widget? child) builder;
  final Widget? child;

  @override
  State<MediaQuerySizeSelector<T>> createState() =>
      _MediaQuerySizeSelectorState<T>();
}

class _MediaQuerySizeSelectorState<T> extends State<MediaQuerySizeSelector<T>> {
  T? _lastValue;
  bool _hasValue = false;
  Widget? _cachedChild;

  @override
  void didUpdateWidget(covariant MediaQuerySizeSelector<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _cachedChild = null;
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.select(MediaQuery.sizeOf(context));
    if (_cachedChild == null || !_hasValue || value != _lastValue) {
      _lastValue = value;
      _hasValue = true;
      // Wrap in Builder so inherited dependencies read inside widget.builder
      // attach to the inner Element rather than this selector State.
      _cachedChild = Builder(
        builder: (innerContext) =>
            widget.builder(innerContext, value, widget.child),
      );
    }
    return _cachedChild!;
  }
}
