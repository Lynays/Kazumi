import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/media_query_size_selector.dart';
import 'package:kazumi/navigation.dart';
import 'package:kazumi/pages/menu/cinema_backdrop.dart';
import 'package:kazumi/pages/menu/cinema_nav_logic.dart';
import 'package:kazumi/pages/menu/cinema_navigation_bars.dart';
import 'package:kazumi/pages/menu/cinema_search_bar.dart';
import 'package:kazumi/pages/menu/cinema_top_bar.dart';
import 'package:kazumi/pages/menu/route_visibility.dart';
import 'package:kazumi/pages/popular/popular_controller.dart';
import 'package:kazumi/pages/router.dart';
import 'package:kazumi/repositories/search_history_repository.dart';
import 'package:kazumi/services/platform/desktop_window_config.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/utils/device.dart';
import 'package:window_manager/window_manager.dart';

class ScaffoldMenu extends StatefulWidget {
  const ScaffoldMenu({
    super.key,
    required this.location,
    this.popularController,
    this.historyRepository,
  });

  final String location;
  final PopularController? popularController;
  final ISearchHistoryRepository? historyRepository;

  @override
  State<ScaffoldMenu> createState() => _ScaffoldMenu();
}

class _ScaffoldMenu extends State<ScaffoldMenu> with RouteAware {
  final _outletKey = GlobalKey<RouterOutletState>();
  final _searchBarKey = GlobalKey();
  late final PopularController _popularController =
      widget.popularController ?? inject<PopularController>();
  late final ISearchHistoryRepository _historyRepository =
      widget.historyRepository ?? inject<ISearchHistoryRepository>();
  late int _selectedIndex = menu.indexForPath(widget.location);
  DateTime? _lastExitPromptAt;

  /// The shell sits at the bottom of the root stack and stays mounted while
  /// other pages cover it, so it publishes that state for its subtree.
  PageRoute<void>? _route;
  bool _isCovered = false;

  @override
  void didUpdateWidget(covariant ScaffoldMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location != widget.location) {
      _selectedIndex = menu.indexForPath(widget.location);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<void> && !identical(route, _route)) {
      rootRouteObserver.unsubscribe(this);
      _route = route;
      _isCovered = !route.isCurrent;
      rootRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    rootRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPushNext() => _setCovered(true);

  @override
  void didPopNext() => _setCovered(false);

  void _setCovered(bool value) {
    if (!mounted || _isCovered == value) {
      return;
    }
    setState(() => _isCovered = value);
  }

  void _selectDestination(int index) {
    _lastExitPromptAt = null;
    if (index == _selectedIndex) {
      return;
    }
    final outlet = _outletKey.currentState;
    if (outlet == null) return;
    outlet.navigate('/tab${menu.getPath(index)}/');
    setState(() => _selectedIndex = index);
  }

  void _handleCinemaNavTap(CinemaNavTab tab) {
    final targetIndex = resolveCinemaNavTap(
      currentRouteIndex: _selectedIndex,
      tapped: tab,
    );
    _selectDestination(targetIndex);
  }

  void _handleHistoryTap() {
    context.pushNamed('/settings/history/');
  }

  void _selectHome() {
    if (_selectedIndex != 0) {
      _selectDestination(0);
    }
    if (_popularController.currentTag.isNotEmpty) {
      _popularController.scrollOffset = 0.0;
      _popularController.setCurrentTag('');
      _popularController.clearBangumiList();
      unawaited(
        _popularController.queryBangumiByTrend(
          type: _popularController.trendList.isEmpty ? 'init' : 'add',
        ),
      );
    }
  }

  void _selectCategoryTag(String tag) {
    if (tag.isEmpty) {
      _selectHome();
      return;
    }
    if (tag != _popularController.currentTag) {
      _popularController.scrollOffset = 0.0;
      _popularController.setCurrentTag(tag);
      unawaited(_popularController.queryBangumiByTag(type: 'init'));
    } else if (_popularController.bangumiList.isEmpty &&
        !_popularController.isLoadingMore) {
      unawaited(_popularController.queryBangumiByTag(type: 'init'));
    }
    if (_selectedIndex != 0) {
      _selectDestination(0);
    }
  }

  void _handleSearchSubmit(CinemaSearchSubmit submit) {
    final params = <String, String>{};
    if (submit.query.isNotEmpty) {
      params['query'] = submit.query;
    }
    if (submit.hideWatched) {
      params['hideWatched'] = '1';
    }
    if (submit.hideAbandoned) {
      params['hideAbandoned'] = '1';
    }
    if (submit.autoSubmit) {
      params['submit'] = '1';
    }
    final uri = Uri(
      path: '/search/',
      queryParameters: params.isEmpty ? null : params,
    );
    context.pushNamed(uri.toString());
  }

  Future<String?> _handleImageSearch() async {
    final result = await context.pushNamed('/search/image');
    if (result is String && result.isNotEmpty) {
      return result;
    }
    return null;
  }

  void _handleSystemBack(BuildContext context) {
    if (_outletKey.currentState?.maybePop() ?? false) {
      _lastExitPromptAt = null;
      return;
    }

    if (_selectedIndex != 0) {
      _selectDestination(0);
      return;
    }

    final now = DateTime.now();
    final lastPromptAt = _lastExitPromptAt;
    if (lastPromptAt == null ||
        now.difference(lastPromptAt) > const Duration(seconds: 2)) {
      _lastExitPromptAt = now;
      KazumiDialog.showToast(message: '再按一次退出应用', context: context);
      return;
    }

    _lastExitPromptAt = null;
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final showShellCloseButton =
        isDesktop() && !DesktopWindowConfig.showWindowButton;
    return RouteVisibility(
      isCovered: _isCovered,
      child: FreezeLayoutWhenCovered(
        isCovered: _isCovered,
        child: ShellWindowCloseScope(
          handledByShell: showShellCloseButton,
          child: PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) {
                _handleSystemBack(context);
              }
            },
            child: MediaQuerySizeSelector<bool>(
              select: (size) => size.height > size.width,
              builder: (context, isPortrait, _) => _buildShell(
                context,
                isPortrait: isPortrait,
                showCloseButton: showShellCloseButton,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return CinemaSearchBar(
      key: _searchBarKey,
      historyRepository: _historyRepository,
      onSubmit: _handleSearchSubmit,
      onImageSearch: _handleImageSearch,
    );
  }

  Widget _buildTopBar({
    required bool compactPortrait,
    required bool showCloseButton,
  }) {
    return Observer(
      builder: (_) => CinemaTopBar(
        isHomeRoute: _selectedIndex == 0,
        selectedCategoryTag: _popularController.currentTag,
        tags: defaultAnimeTags,
        onSelectHome: _selectHome,
        onSelectCategoryTag: _selectCategoryTag,
        searchBar: _buildSearchBar(),
        compactPortrait: compactPortrait,
        onHistoryTap: compactPortrait ? _handleHistoryTap : null,
        showCloseButton: showCloseButton,
        onCloseWindow: showCloseButton ? () => windowManager.close() : null,
      ),
    );
  }

  Widget _outlet() {
    return _RemoveTopPadding(
      child: NotificationListener<NavigationNotification>(
        // A non-poppable outlet must not override the shell's PopScope state.
        onNotification: (notification) => !notification.canHandlePop,
        child: RouterOutlet(key: _outletKey),
      ),
    );
  }

  Widget _buildShell(
    BuildContext context, {
    required bool isPortrait,
    required bool showCloseButton,
  }) {
    final activeTab = activeCinemaNavTab(_selectedIndex);
    final content = Column(
      children: [
        _buildTopBar(
          compactPortrait: isPortrait,
          showCloseButton: showCloseButton,
        ),
        Expanded(child: _outlet()),
      ],
    );

    if (isPortrait) {
      return CinemaBackdrop(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: content,
          bottomNavigationBar: CinemaBottomBar(
            activeTab: activeTab,
            onTabTap: _handleCinemaNavTap,
          ),
        ),
      );
    }

    return CinemaBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Row(
          children: [
            CinemaSideRail(
              activeTab: activeTab,
              onTabTap: _handleCinemaNavTap,
              onHistoryTap: _handleHistoryTap,
            ),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}

/// Removes top padding only when non-zero, subscribing solely to
/// [MediaQuery.paddingOf] on desktop instead of the full [MediaQueryData].
class _RemoveTopPadding extends StatelessWidget {
  const _RemoveTopPadding({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.paddingOf(context).top == 0) {
      return child;
    }
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: child,
    );
  }
}
