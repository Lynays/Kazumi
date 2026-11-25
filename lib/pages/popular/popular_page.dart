import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:kazumi/bean/card/bangumi_card.dart';
import 'package:kazumi/bean/widget/bangumi_mirror_error_widget.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/pages/popular/category_controller.dart';
import 'package:kazumi/pages/popular/category_detail_view.dart';
import 'package:kazumi/pages/popular/category_overview_view.dart';
import 'package:kazumi/pages/popular/popular_controller.dart';
import 'package:kazumi/pages/popular/popular_dashboard.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:mobx/mobx.dart';

class PopularPage extends StatefulWidget {
  const PopularPage({
    super.key,
    required this.controller,
    this.categoryController,
  });

  final PopularController controller;
  final CategoryController? categoryController;

  @override
  State<PopularPage> createState() => _PopularPageState();
}

class _PopularPageState extends State<PopularPage> {
  static const double _progressHeight = 4;

  late final ScrollController scrollController;
  late final ReactionDisposer _tagReactionDisposer;
  PopularBrowseMode? _lastBrowseMode;

  PopularController get popularController => widget.controller;
  CategoryController? get categoryController => widget.categoryController;

  @override
  void initState() {
    super.initState();
    scrollController = ScrollController(
      initialScrollOffset: popularController.scrollOffset,
    );
    scrollController.addListener(scrollListener);
    _tagReactionDisposer = reaction<String>(
      (_) => popularController.currentTag,
      (_) {
        popularController.scrollOffset = 0.0;
        if (scrollController.hasClients) {
          scrollController.jumpTo(0);
        }
      },
    );
    _lastBrowseMode = categoryController?.mode;
    categoryController?.addListener(_onCategoryChanged);
    popularController.attachTrendView();
    if (popularController.currentTag.isEmpty &&
        (categoryController == null ||
            categoryController!.mode == PopularBrowseMode.home)) {
      _loadTrend();
    }
  }

  @override
  void didUpdateWidget(PopularPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categoryController != widget.categoryController) {
      oldWidget.categoryController?.removeListener(_onCategoryChanged);
      _lastBrowseMode = widget.categoryController?.mode;
      widget.categoryController?.addListener(_onCategoryChanged);
    }
  }

  @override
  void dispose() {
    categoryController?.removeListener(_onCategoryChanged);
    _tagReactionDisposer();
    popularController.detachTrendView();
    scrollController.removeListener(scrollListener);
    scrollController.dispose();
    super.dispose();
  }

  void _onCategoryChanged() {
    final nextMode = categoryController?.mode;
    final enteredHome =
        nextMode == PopularBrowseMode.home &&
        _lastBrowseMode != PopularBrowseMode.home;
    _lastBrowseMode = nextMode;
    if (enteredHome &&
        popularController.currentTag.isEmpty &&
        popularController.trendList.isEmpty &&
        !popularController.isLoadingMore &&
        !popularController.isTimeOut) {
      unawaited(_loadTrend());
    }
  }

  void scrollListener() {
    popularController.scrollOffset = scrollController.offset;
    if (popularController.currentTag.isNotEmpty &&
        scrollController.position.pixels >=
            scrollController.position.maxScrollExtent - 200 &&
        !popularController.isLoadingMore) {
      KazumiLogger().i(
        'PopularPageController: Fetching next recommendation batch',
      );
      popularController.queryBangumiByTag();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cat = categoryController;
    if (cat == null) {
      return _buildHomeScaffold(context);
    }

    return ListenableBuilder(
      listenable: cat,
      builder: (context, _) {
        switch (cat.mode) {
          case PopularBrowseMode.categoryOverview:
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Scaffold(
              backgroundColor: isDark ? Colors.transparent : null,
              body: LayoutBuilder(
                builder: (_, constraints) => CategoryOverviewView(
                  controller: cat,
                  viewportHeight: constraints.maxHeight,
                ),
              ),
            );
          case PopularBrowseMode.categoryDetail:
            return LayoutBuilder(
              builder: (_, constraints) => CategoryDetailView(
                controller: cat,
                tag: cat.activeTag,
                viewportWidth: constraints.maxWidth,
                viewportHeight: constraints.maxHeight,
              ),
            );
          case PopularBrowseMode.home:
            return _buildHomeScaffold(context);
        }
      },
    );
  }

  Widget _buildHomeScaffold(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? Colors.transparent : null,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final viewportWidth = constraints.maxWidth;
          final viewportHeight = constraints.maxHeight - _progressHeight;
          return CustomScrollView(
            controller: scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Observer(
                  builder: (_) => AnimatedOpacity(
                    opacity: popularController.isLoadingMore ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: popularController.isLoadingMore
                        ? const LinearProgressIndicator(
                            minHeight: _progressHeight,
                          )
                        : const SizedBox(height: _progressHeight),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  StyleString.cardSpace,
                  0,
                  StyleString.cardSpace,
                  0,
                ),
                sliver: Observer(
                  builder: (observerContext) => _buildResults(
                    observerContext,
                    viewportWidth,
                    viewportHeight,
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Observer(
        builder: (_) {
          if (popularController.currentTag.isEmpty) {
            return const SizedBox.shrink();
          }
          return FloatingActionButton(
            onPressed: () => scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOut,
            ),
            child: const Icon(Icons.arrow_upward),
          );
        },
      ),
    );
  }

  Widget _buildResults(
    BuildContext observerContext,
    double viewportWidth,
    double viewportHeight,
  ) {
    if (popularController.isTimeOut) {
      return SliverToBoxAdapter(
        child: SizedBox(
          height: 400,
          child: BangumiMirrorErrorWidget(
            onRetry: () {
              if (popularController.currentTag.isEmpty) {
                popularController.queryBangumiByTrend(type: 'init');
              } else {
                popularController.queryBangumiByTag();
              }
            },
            onSettingsReturned: () {
              if (mounted) {
                setState(() {});
              }
            },
          ),
        ),
      );
    }
    if (popularController.currentTag.isNotEmpty) {
      return contentGrid(
        observerContext,
        popularController.bangumiList,
        viewportWidth,
      );
    }
    return SliverToBoxAdapter(
      child: PopularDashboard(
        sections: popularController.popularSections,
        viewportHeight: viewportHeight,
      ),
    );
  }

  Widget contentGrid(
    BuildContext gridContext,
    List<BangumiItem> bangumiList,
    double viewportWidth,
  ) {
    final availableWidth = viewportWidth.isFinite && viewportWidth > 0
        ? viewportWidth
        : 0.0;
    int crossCount = 3;
    if (availableWidth > LayoutBreakpoint.compact['width']!) {
      crossCount = 5;
    }
    if (availableWidth > LayoutBreakpoint.medium['width']!) {
      crossCount = 6;
    }
    return SliverPadding(
      padding: const EdgeInsets.all(8),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          // 行间距
          mainAxisSpacing: StyleString.cardSpace - 2,
          // 列间距
          crossAxisSpacing: StyleString.cardSpace,
          // 列数
          crossAxisCount: crossCount,
          mainAxisExtent:
              availableWidth / crossCount / 0.65 +
              MediaQuery.textScalerOf(gridContext).scale(32.0),
        ),
        delegate: SliverChildBuilderDelegate((BuildContext context, int index) {
          return bangumiList.isNotEmpty
              ? BangumiCardV(bangumiItem: bangumiList[index])
              : null;
        }, childCount: bangumiList.isNotEmpty ? bangumiList.length : 10),
      ),
    );
  }

  Future<void> _loadTrend() => popularController.queryBangumiByTrend(
    type: popularController.trendList.isEmpty ? 'init' : 'add',
  );
}
