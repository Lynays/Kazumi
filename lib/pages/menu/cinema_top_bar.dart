import 'package:flutter/material.dart';
import 'package:kazumi/bean/appbar/drag_to_move_bar.dart';
import 'package:kazumi/bean/widget/embedded_native_control_area.dart';
import 'package:kazumi/bean/widget/kazumi_menu.dart';
import 'package:kazumi/pages/menu/cinema_nav_logic.dart';
import 'package:kazumi/pages/menu/cinema_tokens.dart';

/// Persistent top navigation bar across all shell tabs.
class CinemaTopBar extends StatelessWidget {
  const CinemaTopBar({
    super.key,
    required this.isHomeRoute,
    required this.selectedCategoryTag,
    required this.tags,
    required this.onSelectHome,
    required this.onSelectCategoryTag,
    required this.searchBar,
    required this.compactPortrait,
    this.onHistoryTap,
    this.showCloseButton = false,
    this.onCloseWindow,
  });

  final bool isHomeRoute;
  final String selectedCategoryTag;
  final List<String> tags;
  final VoidCallback onSelectHome;
  final ValueChanged<String> onSelectCategoryTag;
  final Widget searchBar;
  final bool compactPortrait;
  final VoidCallback? onHistoryTap;
  final bool showCloseButton;
  final VoidCallback? onCloseWindow;

  bool get _homeActive => isHomeRoute && selectedCategoryTag.isEmpty;
  bool get _categoryActive => isHomeRoute && selectedCategoryTag.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: EmbeddedNativeControlArea(
        child: DragToMoveArea(
          child: compactPortrait
              ? _buildPortrait(context)
              : _buildLandscape(context),
        ),
      ),
    );
  }

  Widget _buildLandscape(BuildContext context) {
    final palette = CinemaPalette.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: CinemaTokens.topBarHeight),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildHomeButton(context),
          const SizedBox(width: 8),
          _buildCategoryButton(context),
          const SizedBox(width: 16),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: searchBar,
              ),
            ),
          ),
          const SizedBox(width: 16),
          const CinemaClockText(),
          if (showCloseButton) ...[
            const SizedBox(width: 8),
            IconButton(
              tooltip: '退出',
              onPressed: onCloseWindow,
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.close_rounded, color: palette.iconMuted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPortrait(BuildContext context) {
    final palette = CinemaPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final showClock = constraints.maxWidth >= 420;
              return Row(
                children: [
                  if (onHistoryTap != null) ...[
                    IconButton(
                      tooltip: '历史记录',
                      onPressed: onHistoryTap,
                      icon: Icon(
                        Icons.history_rounded,
                        color: palette.iconMuted,
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Expanded(child: searchBar),
                  if (showClock) ...[
                    const SizedBox(width: 10),
                    const CinemaClockText(),
                  ],
                  if (showCloseButton) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: '退出',
                      onPressed: onCloseWindow,
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.close_rounded, color: palette.iconMuted),
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                _buildHomeButton(context),
                const SizedBox(width: 8),
                Flexible(child: _buildCategoryButton(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeButton(BuildContext context) {
    return _TopNavTabButton(
      label: '首页',
      active: _homeActive,
      onTap: onSelectHome,
    );
  }

  static final Expando<ThemeData> _darkMenuThemeCache = Expando<ThemeData>();

  Widget _buildCategoryButton(BuildContext context) {
    final palette = CinemaPalette.of(context);
    final theme = Theme.of(context);
    final label = _categoryActive ? '分类 · $selectedCategoryTag' : '分类';
    final menuTheme = palette.isCinemaDark
        ? (_darkMenuThemeCache[theme] ??= theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: palette.accent,
              surfaceContainer: palette.panelSurface,
              onSurface: palette.textPrimary,
            ),
          ))
        : theme;

    return Theme(
      data: menuTheme,
      child: KazumiMenuButton(
        animated: true,
        style: MenuStyle(
          maximumSize: const WidgetStatePropertyAll(Size(220, 360)),
          backgroundColor: palette.isCinemaDark
              ? WidgetStatePropertyAll(palette.panelSurface)
              : null,
        ),
        menuChildren: [
          for (final tag in tags)
            KazumiMenuItem(
              label: tag,
              selected: _categoryActive && tag == selectedCategoryTag,
              onPressed: () => onSelectCategoryTag(tag),
            ),
        ],
        builder: (context, toggle) => _TopNavTabButton(
          label: label,
          active: _categoryActive,
          trailingIcon: Icons.keyboard_arrow_down_rounded,
          onTap: toggle,
        ),
      ),
    );
  }
}

class _TopNavTabButton extends StatelessWidget {
  const _TopNavTabButton({
    required this.label,
    required this.active,
    required this.onTap,
    this.trailingIcon,
  });

  final String label;
  final bool active;
  final VoidCallback? onTap;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final palette = CinemaPalette.of(context);
    final textStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
      color: active ? palette.textPrimary : palette.textSecondary,
      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
    );

    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textStyle,
                      ),
                    ),
                    if (trailingIcon != null) ...[
                      const SizedBox(width: 2),
                      Icon(
                        trailingIcon,
                        size: 18,
                        color: active
                            ? palette.textPrimary
                            : palette.textSecondary,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                AnimatedContainer(
                  key: ValueKey('top-nav-indicator-$label-$active'),
                  duration: const Duration(milliseconds: 160),
                  width: active ? 22 : 0,
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: active ? palette.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
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
