import 'package:flutter/material.dart';
import 'package:kazumi/bean/widget/embedded_native_control_area.dart';
import 'package:kazumi/pages/menu/cinema_nav_logic.dart';
import 'package:kazumi/pages/menu/cinema_tokens.dart';

IconData _iconForTab(CinemaNavTab tab, {required bool selected}) =>
    switch (tab) {
      CinemaNavTab.timeline =>
        selected ? Icons.calendar_today_rounded : Icons.calendar_today_outlined,
      CinemaNavTab.collect =>
        selected ? Icons.favorite_rounded : Icons.favorite_border_rounded,
      CinemaNavTab.settings =>
        selected ? Icons.settings_rounded : Icons.settings_outlined,
    };

/// Landscape / desktop ultra-dark slim side rail with top history trigger and
/// bottom 3-tab navigation (none selected on Home).
class CinemaSideRail extends StatelessWidget {
  const CinemaSideRail({
    super.key,
    required this.activeTab,
    required this.onTabTap,
    required this.onHistoryTap,
  });

  final CinemaNavTab? activeTab;
  final ValueChanged<CinemaNavTab> onTabTap;
  final VoidCallback onHistoryTap;

  @override
  Widget build(BuildContext context) {
    final palette = CinemaPalette.of(context);
    return Material(
      color: palette.railSurface,
      child: Container(
        width: CinemaTokens.railWidth,
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: palette.railBorder)),
        ),
        child: SafeArea(
          right: false,
          child: EmbeddedNativeControlArea(
            child: Column(
              children: [
                const SizedBox(height: 8),
                _RailIconButton(
                  tooltip: '历史记录',
                  icon: Icons.history_rounded,
                  selected: false,
                  onTap: onHistoryTap,
                ),
                const Spacer(),
                for (final tab in CinemaNavTab.values) ...[
                  _RailIconButton(
                    tooltip: tab.label,
                    icon: _iconForTab(tab, selected: activeTab == tab),
                    selected: activeTab == tab,
                    onTap: () => onTabTap(tab),
                  ),
                  const SizedBox(height: 6),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RailIconButton extends StatelessWidget {
  const _RailIconButton({
    required this.tooltip,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = CinemaPalette.of(context);
    final activeBg = palette.accent.withValues(
      alpha: palette.isCinemaDark ? 0.16 : 0.12,
    );
    return Semantics(
      button: true,
      selected: selected,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: SizedBox(
          width: CinemaTokens.railWidth,
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (selected)
                Positioned(
                  left: 0,
                  child: Container(
                    width: 3,
                    height: 20,
                    decoration: BoxDecoration(
                      color: palette.accent,
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(3),
                      ),
                    ),
                  ),
                ),
              Material(
                color: selected ? activeBg : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onTap,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Icon(
                      icon,
                      size: 22,
                      color: selected ? palette.accent : palette.iconMuted,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Portrait bottom 3-tab bar supporting `activeTab == null` when on Home.
class CinemaBottomBar extends StatelessWidget {
  const CinemaBottomBar({
    super.key,
    required this.activeTab,
    required this.onTabTap,
  });

  final CinemaNavTab? activeTab;
  final ValueChanged<CinemaNavTab> onTabTap;

  @override
  Widget build(BuildContext context) {
    final palette = CinemaPalette.of(context);
    final labelBase = Theme.of(context).textTheme.labelSmall;

    return Material(
      color: palette.railSurface,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: palette.railBorder)),
        ),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 58),
            child: Row(
              children: [
                for (final tab in CinemaNavTab.values)
                  Expanded(
                    child: _BottomNavButton(
                      tab: tab,
                      selected: activeTab == tab,
                      labelBase: labelBase,
                      onTap: () => onTabTap(tab),
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

class _BottomNavButton extends StatelessWidget {
  const _BottomNavButton({
    required this.tab,
    required this.selected,
    required this.labelBase,
    required this.onTap,
  });

  final CinemaNavTab tab;
  final bool selected;
  final TextStyle? labelBase;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = CinemaPalette.of(context);
    final activeBg = palette.accent.withValues(
      alpha: palette.isCinemaDark ? 0.16 : 0.12,
    );
    final fg = selected ? palette.accent : palette.iconMuted;

    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      child: Tooltip(
        message: tab.label,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 54),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? activeBg : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _iconForTab(tab, selected: selected),
                      size: 20,
                      color: fg,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tab.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: labelBase?.copyWith(
                      color: selected ? palette.accent : palette.textSecondary,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
