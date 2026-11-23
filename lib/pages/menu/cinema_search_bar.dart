import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/modules/search/search_history_module.dart';
import 'package:kazumi/pages/menu/cinema_tokens.dart';
import 'package:kazumi/pages/menu/route_visibility.dart';
import 'package:kazumi/pages/search/search_filter_panel.dart';
import 'package:kazumi/repositories/search_history_repository.dart';
import 'package:kazumi/utils/search_parser.dart';

class CinemaSearchSubmit {
  const CinemaSearchSubmit({
    required this.query,
    this.hideWatched = false,
    this.hideAbandoned = false,
    this.autoSubmit = false,
  });

  final String query;
  final bool hideWatched;
  final bool hideAbandoned;
  final bool autoSubmit;
}

@visibleForTesting
enum CinemaSecondaryPlacement { right, left, below }

@visibleForTesting
class CinemaSearchOverlayLayout {
  const CinemaSearchOverlayLayout({
    required this.primaryRect,
    required this.secondaryPlacement,
    required this.secondaryRect,
    required this.stackedWidth,
    required this.stackedLeft,
    required this.availableBelow,
  });

  final Rect primaryRect;
  final CinemaSecondaryPlacement secondaryPlacement;
  final Rect secondaryRect;
  final double stackedWidth;
  final double stackedLeft;
  final double availableBelow;
}

@visibleForTesting
CinemaSearchOverlayLayout computeCinemaSearchOverlayLayout({
  required Rect anchorRect,
  required Size viewport,
  double bottomInset = 0,
}) {
  const edgeMargin = 12.0;
  const verticalGap = 8.0;
  const sideGap = 10.0;
  const minPrimaryWidth = 320.0;
  const minSideWidth = 360.0;
  const preferredSideWidth = 380.0;
  const sideBreakpoint = 720.0;

  final availableWidth = math.max(0.0, viewport.width - edgeMargin * 2);
  final primaryWidth = math.min(
    availableWidth,
    math.max(anchorRect.width, minPrimaryWidth),
  );
  final maxPrimaryLeft = math.max(
    edgeMargin,
    viewport.width - edgeMargin - primaryWidth,
  );
  final primaryLeft = anchorRect.left
      .clamp(edgeMargin, maxPrimaryLeft)
      .toDouble();
  final maxTop = math.max(edgeMargin, viewport.height - edgeMargin - 120.0);
  final primaryTop = (anchorRect.bottom + verticalGap)
      .clamp(edgeMargin, maxTop)
      .toDouble();
  final availableBelow = math.max(
    0.0,
    viewport.height - primaryTop - edgeMargin - bottomInset,
  );
  final primaryMaxHeight = math.min(availableBelow, 440.0);

  final primaryRect = Rect.fromLTWH(
    primaryLeft,
    primaryTop,
    primaryWidth,
    primaryMaxHeight,
  );

  final spaceRight =
      viewport.width - (primaryLeft + primaryWidth + sideGap) - edgeMargin;
  final spaceLeft = primaryLeft - sideGap - edgeMargin;
  final secondaryMaxHeight = math.min(availableBelow, 560.0);

  CinemaSecondaryPlacement placement;
  Rect secondaryRect;

  if (viewport.width >= sideBreakpoint && spaceRight >= minSideWidth) {
    placement = CinemaSecondaryPlacement.right;
    final width = math.min(spaceRight, preferredSideWidth);
    secondaryRect = Rect.fromLTWH(
      primaryLeft + primaryWidth + sideGap,
      primaryTop,
      width,
      secondaryMaxHeight,
    );
  } else if (viewport.width >= sideBreakpoint && spaceLeft >= minSideWidth) {
    placement = CinemaSecondaryPlacement.left;
    final width = math.min(spaceLeft, preferredSideWidth);
    secondaryRect = Rect.fromLTWH(
      primaryLeft - sideGap - width,
      primaryTop,
      width,
      secondaryMaxHeight,
    );
  } else {
    placement = CinemaSecondaryPlacement.below;
    final stackedWidth = math.min(
      availableWidth,
      math.max(primaryWidth, minSideWidth),
    );
    final maxStackedLeft = math.max(
      edgeMargin,
      viewport.width - edgeMargin - stackedWidth,
    );
    final stackedLeft = anchorRect.left
        .clamp(edgeMargin, maxStackedLeft)
        .toDouble();
    secondaryRect = Rect.fromLTWH(
      stackedLeft,
      primaryTop,
      stackedWidth,
      availableBelow,
    );
    return CinemaSearchOverlayLayout(
      primaryRect: primaryRect,
      secondaryPlacement: placement,
      secondaryRect: secondaryRect,
      stackedWidth: stackedWidth,
      stackedLeft: stackedLeft,
      availableBelow: availableBelow,
    );
  }

  return CinemaSearchOverlayLayout(
    primaryRect: primaryRect,
    secondaryPlacement: placement,
    secondaryRect: secondaryRect,
    stackedWidth: primaryWidth,
    stackedLeft: primaryLeft,
    availableBelow: availableBelow,
  );
}

class CinemaSearchBar extends StatefulWidget {
  const CinemaSearchBar({
    super.key,
    required this.historyRepository,
    required this.onSubmit,
    required this.onImageSearch,
    this.hintText = '搜索番剧名称',
  });

  final ISearchHistoryRepository historyRepository;
  final ValueChanged<CinemaSearchSubmit> onSubmit;
  final Future<String?> Function() onImageSearch;
  final String hintText;

  @override
  State<CinemaSearchBar> createState() => _CinemaSearchBarState();
}

class _CinemaSearchBarState extends State<CinemaSearchBar> {
  final _anchorKey = GlobalKey();
  final _overlayController = OverlayPortalController();
  final _textController = TextEditingController();
  final _focusNode = FocusNode();

  List<SearchHistory> _histories = const [];
  bool _primaryOpen = false;
  bool _secondaryOpen = false;
  bool _managingHistory = false;
  bool _keyboardRegistered = false;
  bool _wasCovered = false;
  Size? _lastViewportSize;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
    _histories = _loadHistories();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isCovered = RouteVisibility.isCoveredOf(context);
    if (isCovered && !_wasCovered && _primaryOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _closeAll(unfocus: true);
        }
      });
    }
    _wasCovered = isCovered;
  }

  @override
  void dispose() {
    _unregisterKeyboardHandler();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  List<SearchHistory> _loadHistories() {
    try {
      return widget.historyRepository.getAllHistories();
    } catch (_) {
      return const [];
    }
  }

  void _registerKeyboardHandler() {
    if (_keyboardRegistered) return;
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    _keyboardRegistered = true;
  }

  void _unregisterKeyboardHandler() {
    if (!_keyboardRegistered) return;
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _keyboardRegistered = false;
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (!mounted || !_primaryOpen) return false;
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape) {
      return false;
    }
    // Let modal routes (e.g. dropdown menus or date range picker) handle Esc first.
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) {
      return false;
    }
    if (_secondaryOpen) {
      setState(() => _secondaryOpen = false);
      return true;
    }
    _closeAll(unfocus: true);
    return true;
  }

  void _onFocusChanged() {
    if (!mounted) return;
    if (_focusNode.hasFocus) {
      _openPrimaryDropdown();
    } else {
      setState(() {});
    }
  }

  void _openPrimaryDropdown() {
    final histories = _loadHistories();
    _registerKeyboardHandler();
    if (!_overlayController.isShowing) {
      _overlayController.show();
    }
    setState(() {
      _histories = histories;
      _primaryOpen = true;
      if (histories.isEmpty) {
        _managingHistory = false;
      }
    });
  }

  void _closeAll({required bool unfocus}) {
    _unregisterKeyboardHandler();
    if (_overlayController.isShowing) {
      _overlayController.hide();
    }
    if (unfocus) {
      _focusNode.unfocus();
    }
    if (!mounted) return;
    if (_primaryOpen || _secondaryOpen || _managingHistory) {
      setState(() {
        _primaryOpen = false;
        _secondaryOpen = false;
        _managingHistory = false;
      });
    }
  }

  void _toggleSecondaryPanel() {
    if (!_primaryOpen) {
      _openPrimaryDropdown();
    }
    final nextOpen = !_secondaryOpen;
    if (nextOpen) {
      // Dismiss soft keyboard on narrow viewports so the filter panel has room.
      _focusNode.unfocus();
    }
    setState(() => _secondaryOpen = nextOpen);
  }

  void _clearInput() {
    _textController.clear();
    if (!_focusNode.hasFocus) {
      _focusNode.requestFocus();
    }
  }

  void _submitText(String raw) {
    final trimmed = raw.trim();
    final query = trimmed.isEmpty
        ? ''
        : SearchParser.fromFilterState(SearchParser(trimmed).toFilterState());
    _closeAll(unfocus: true);
    widget.onSubmit(CinemaSearchSubmit(query: query));
  }

  void _submitFromHistory(SearchHistory history) {
    _textController.value = TextEditingValue(
      text: history.keyword,
      selection: TextSelection.collapsed(offset: history.keyword.length),
    );
    _closeAll(unfocus: true);
    widget.onSubmit(CinemaSearchSubmit(query: history.keyword));
  }

  void _applySecondaryFilters(SearchFilterResult result) {
    var state = result.filterState;
    final liveInput = SearchParser(_textController.text);
    final liveId = liveInput.parseId() ?? '';
    if (state.isIdSearch && liveId != state.id) {
      state = state.copyWith(id: liveId, keyword: liveInput.parseKeywords());
    } else if (!state.isIdSearch) {
      state = state.copyWith(keyword: liveInput.parseKeywords());
    }
    final query = SearchParser.fromFilterState(state);
    _textController.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    _closeAll(unfocus: true);
    widget.onSubmit(
      CinemaSearchSubmit(
        query: query,
        hideWatched: result.notShowWatched,
        hideAbandoned: result.notShowAbandoned,
        autoSubmit: true,
      ),
    );
  }

  Future<void> _handleImageSearch() async {
    _closeAll(unfocus: true);
    final result = await widget.onImageSearch();
    if (!mounted || result == null || result.trim().isEmpty) return;
    _submitText(result);
  }

  Future<void> _deleteHistory(SearchHistory history) async {
    await widget.historyRepository.deleteHistory(history);
    if (!mounted) return;
    final next = _loadHistories();
    setState(() {
      _histories = next;
      if (next.isEmpty) {
        _managingHistory = false;
      }
    });
  }

  Future<void> _clearAllHistory() async {
    await widget.historyRepository.clearAllHistories();
    if (!mounted) return;
    setState(() {
      _histories = const [];
      _managingHistory = false;
    });
  }

  Rect _resolveAnchorRect(BuildContext context, Size viewport) {
    final anchorObject = _anchorKey.currentContext?.findRenderObject();
    final overlayObject = Overlay.maybeOf(context)?.context.findRenderObject();
    if (anchorObject is RenderBox &&
        anchorObject.attached &&
        anchorObject.hasSize) {
      final ancestor = overlayObject is RenderBox && overlayObject.attached
          ? overlayObject
          : null;
      final offset = anchorObject.localToGlobal(
        Offset.zero,
        ancestor: ancestor,
      );
      return offset & anchorObject.size;
    }
    return Rect.fromLTWH(16, 12, math.min(420, viewport.width - 32), 40);
  }

  Widget _buildOverlay(BuildContext context) {
    final overlayBox = Overlay.maybeOf(context)?.context.findRenderObject();
    final viewport = overlayBox is RenderBox && overlayBox.hasSize
        ? overlayBox.size
        : MediaQuery.sizeOf(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    if (_lastViewportSize != null && _lastViewportSize != viewport) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _primaryOpen) {
          setState(() {});
        }
      });
    }
    _lastViewportSize = viewport;

    final anchorRect = _resolveAnchorRect(context, viewport);
    final layout = computeCinemaSearchOverlayLayout(
      anchorRect: anchorRect,
      viewport: viewport,
      bottomInset: bottomInset,
    );

    final primaryPanel = _buildPrimaryPanel(context);
    final secondaryPanel = _secondaryOpen
        ? _buildSecondaryPanel(context)
        : null;

    return Stack(
      children: [
        ..._buildCutoutBarrier(anchorRect, viewport),
        if (_secondaryOpen &&
            layout.secondaryPlacement == CinemaSecondaryPlacement.below)
          Positioned(
            left: layout.stackedLeft,
            top: layout.primaryRect.top,
            width: layout.stackedWidth,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: layout.availableBelow),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: math
                          .min(
                            184.0,
                            math.max(68.0, layout.availableBelow * 0.34),
                          )
                          .clamp(0.0, math.max(0.0, layout.availableBelow - 8))
                          .toDouble(),
                    ),
                    child: primaryPanel,
                  ),
                  const SizedBox(height: 8),
                  Flexible(child: secondaryPanel!),
                ],
              ),
            ),
          )
        else ...[
          Positioned(
            left: layout.primaryRect.left,
            top: layout.primaryRect.top,
            width: layout.primaryRect.width,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: layout.primaryRect.height),
              child: primaryPanel,
            ),
          ),
          if (secondaryPanel != null)
            Positioned(
              left: layout.secondaryRect.left,
              top: layout.secondaryRect.top,
              width: layout.secondaryRect.width,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: layout.secondaryRect.height,
                ),
                child: secondaryPanel,
              ),
            ),
        ],
      ],
    );
  }

  /// Covers everything except [anchorRect] so outside taps dismiss the overlay
  /// while taps inside the search capsule pass straight through to the input.
  List<Widget> _buildCutoutBarrier(Rect anchorRect, Size viewport) {
    final top = anchorRect.top.clamp(0.0, viewport.height);
    final bottom = anchorRect.bottom.clamp(top, viewport.height);
    final left = anchorRect.left.clamp(0.0, viewport.width);
    final right = anchorRect.right.clamp(left, viewport.width);

    Widget strip() => GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => _closeAll(unfocus: true),
    );

    return [
      if (top > 0)
        Positioned(left: 0, right: 0, top: 0, height: top, child: strip()),
      if (bottom < viewport.height)
        Positioned(left: 0, right: 0, top: bottom, bottom: 0, child: strip()),
      if (left > 0 && bottom > top)
        Positioned(
          left: 0,
          top: top,
          width: left,
          height: bottom - top,
          child: strip(),
        ),
      if (right < viewport.width && bottom > top)
        Positioned(
          left: right,
          right: 0,
          top: top,
          height: bottom - top,
          child: strip(),
        ),
    ];
  }

  Widget _buildPanelSurface(
    BuildContext context, {
    required Key key,
    required Widget child,
  }) {
    final palette = CinemaPalette.of(context);
    return Material(
      key: key,
      color: palette.panelSurface,
      elevation: palette.isCinemaDark ? 12 : 6,
      shadowColor: Colors.black.withValues(
        alpha: palette.isCinemaDark ? 0.55 : 0.2,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CinemaTokens.panelRadius),
        side: BorderSide(color: palette.panelBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _buildPrimaryPanel(BuildContext context) {
    final palette = CinemaPalette.of(context);
    final theme = Theme.of(context);
    final activeTint = palette.accent.withValues(
      alpha: palette.isCinemaDark ? 0.14 : 0.10,
    );

    return _buildPanelSurface(
      context,
      key: const ValueKey('cinema-search-primary-panel'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Material(
                color: _secondaryOpen ? activeTint : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 2,
                  ),
                  leading: Icon(
                    Icons.tune_rounded,
                    color: _secondaryOpen ? palette.accent : palette.iconMuted,
                  ),
                  title: Text(
                    '按条件查找',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: _secondaryOpen
                          ? palette.accent
                          : palette.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '题材、放送时间与评分',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: _secondaryOpen ? palette.accent : palette.iconMuted,
                  ),
                  onTap: _toggleSecondaryPanel,
                ),
              ),
            ),
            if (_histories.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                child: Divider(height: 1, color: palette.panelBorder),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '最近搜索',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                    ),
                    if (_managingHistory)
                      TextButton(
                        onPressed: _clearAllHistory,
                        style: TextButton.styleFrom(
                          foregroundColor: palette.accent,
                        ),
                        child: const Text('清空'),
                      ),
                    TextButton(
                      onPressed: () =>
                          setState(() => _managingHistory = !_managingHistory),
                      style: TextButton.styleFrom(
                        foregroundColor: palette.textSecondary,
                      ),
                      child: Text(_managingHistory ? '完成' : '管理'),
                    ),
                  ],
                ),
              ),
              for (final history in _histories.take(10))
                _buildHistoryItem(context, history),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(BuildContext context, SearchHistory history) {
    final palette = CinemaPalette.of(context);
    final readable = formatReadableSearchQuery(history.keyword);
    final label = readable.isNotEmpty ? readable : history.keyword;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 2,
          ),
          leading: Icon(
            Icons.history_rounded,
            size: 19,
            color: palette.iconMuted,
          ),
          title: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: palette.textPrimary),
          ),
          trailing: _managingHistory
              ? IconButton(
                  tooltip: '删除这条搜索记录',
                  onPressed: () => _deleteHistory(history),
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: palette.iconMuted,
                  ),
                )
              : Icon(
                  Icons.north_west_rounded,
                  size: 17,
                  color: palette.iconMuted,
                ),
          onTap: () => _submitFromHistory(history),
        ),
      ),
    );
  }

  Widget _buildSecondaryPanel(BuildContext context) {
    final palette = CinemaPalette.of(context);
    final theme = Theme.of(context);
    final panelTheme = palette.isCinemaDark
        ? theme.copyWith(
            canvasColor: const Color(0xFF1A1A24),
            colorScheme: theme.colorScheme.copyWith(
              primary: palette.accent,
              onPrimary: palette.onAccent,
              surface: palette.panelSurface,
              surfaceContainerLow: const Color(0xFF1C1C26),
              onSurface: palette.textPrimary,
              onSurfaceVariant: palette.textSecondary,
              outlineVariant: palette.panelBorder,
            ),
          )
        : theme;

    return Theme(
      data: panelTheme,
      child: _buildPanelSurface(
        context,
        key: const ValueKey('cinema-search-secondary-panel'),
        child: SearchFilterPanel(
          showDragHandle: false,
          initialState: SearchParser(_textController.text).toFilterState(),
          initialNotShowWatched: false,
          initialNotShowAbandoned: false,
          onApply: _applySecondaryFilters,
          onClose: () => setState(() => _secondaryOpen = false),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = CinemaPalette.of(context);
    final theme = Theme.of(context);
    final active = _focusNode.hasFocus || _primaryOpen;

    return OverlayPortal(
      controller: _overlayController,
      overlayChildBuilder: _buildOverlay,
      child: Container(
        key: _anchorKey,
        constraints: const BoxConstraints(minHeight: 40),
        decoration: BoxDecoration(
          color: palette.inputFill,
          borderRadius: BorderRadius.circular(CinemaTokens.searchRadius),
          border: Border.all(
            color: active
                ? palette.accent.withValues(alpha: 0.65)
                : palette.panelBorder,
          ),
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: '搜索',
              onPressed: () => _submitText(_textController.text),
              visualDensity: VisualDensity.compact,
              icon: Icon(
                Icons.search_rounded,
                size: 20,
                color: active ? palette.textPrimary : palette.iconMuted,
              ),
            ),
            Expanded(
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                textInputAction: TextInputAction.search,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: palette.textPrimary,
                ),
                cursorColor: palette.accent,
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: palette.textSecondary,
                  ),
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onTap: _openPrimaryDropdown,
                onSubmitted: _submitText,
              ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _textController,
              builder: (context, value, _) {
                if (value.text.isEmpty) return const SizedBox.shrink();
                return IconButton(
                  tooltip: '清空输入',
                  onPressed: _clearInput,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: palette.iconMuted,
                  ),
                );
              },
            ),
            IconButton(
              tooltip: '以图搜番',
              onPressed: _handleImageSearch,
              visualDensity: VisualDensity.compact,
              icon: Icon(
                Icons.image_search_rounded,
                size: 20,
                color: palette.iconMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
