import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kazumi/pages/menu/cinema_tokens.dart';

/// 3 个侧栏/底栏按钮对应的目标路由索引（对应 menu.dart 里的 1/2/3，首页为 0）。
enum CinemaNavTab {
  timeline(1, '时间表'),
  collect(2, '喜欢'),
  settings(3, '设置');

  const CinemaNavTab(this.routeIndex, this.label);

  final int routeIndex;
  final String label;
}

/// 根据当前路由索引与被点击的按钮，计算目标路由索引：
/// - 若当前已在该按钮对应页面，则返回 0（首页）；
/// - 否则切换到该按钮对应的 routeIndex。
int resolveCinemaNavTap({
  required int currentRouteIndex,
  required CinemaNavTab tapped,
}) => currentRouteIndex == tapped.routeIndex ? 0 : tapped.routeIndex;

/// 根据当前路由索引反查高亮的按钮；在首页（0）时返回 null。
CinemaNavTab? activeCinemaNavTab(int currentRouteIndex) {
  for (final tab in CinemaNavTab.values) {
    if (tab.routeIndex == currentRouteIndex) {
      return tab;
    }
  }
  return null;
}

/// Leaf widget displaying local time (`HH:mm`), refreshing only on minute turns.
class CinemaClockText extends StatefulWidget {
  const CinemaClockText({super.key, this.style, this.nowProvider});

  final TextStyle? style;
  final DateTime Function()? nowProvider;

  @override
  State<CinemaClockText> createState() => _CinemaClockTextState();
}

class _CinemaClockTextState extends State<CinemaClockText> {
  Timer? _timer;
  late String _formatted = _format(_now());

  DateTime _now() => widget.nowProvider?.call() ?? DateTime.now();

  static String _format(DateTime time) {
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  void initState() {
    super.initState();
    _scheduleNextMinute();
  }

  @override
  void didUpdateWidget(covariant CinemaClockText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nowProvider != widget.nowProvider) {
      _formatted = _format(_now());
      _scheduleNextMinute();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  void _scheduleNextMinute() {
    _timer?.cancel();
    final now = _now();
    final remainingMs = 60000 - (now.second * 1000 + now.millisecond);
    final delay = Duration(
      milliseconds: remainingMs <= 0 ? 60000 : remainingMs,
    );
    _timer = Timer(delay, _onMinuteTick);
  }

  void _onMinuteTick() {
    if (!mounted) return;
    final next = _format(_now());
    if (next != _formatted) {
      setState(() => _formatted = next);
    }
    _scheduleNextMinute();
  }

  @override
  Widget build(BuildContext context) {
    final palette = CinemaPalette.of(context);
    final baseStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
      color: palette.textSecondary,
      fontWeight: FontWeight.w500,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final effectiveStyle = widget.style == null
        ? baseStyle
        : baseStyle?.merge(widget.style) ?? widget.style;
    return Semantics(
      label: '当前时间 $_formatted',
      child: Text(_formatted, maxLines: 1, style: effectiveStyle),
    );
  }
}
