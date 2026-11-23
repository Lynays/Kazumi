import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:kazumi/bean/card/bangumi_card.dart';
import 'package:kazumi/bean/widget/bangumi_mirror_error_widget.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/pages/popular/popular_controller.dart';
import 'package:kazumi/pages/popular/popular_dashboard.dart';
import 'package:kazumi/pages/popular/popular_sections.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:mobx/mobx.dart';

class PopularPage extends StatefulWidget {
  const PopularPage({super.key, required this.controller});

  final PopularController controller;

  @override
  State<PopularPage> createState() => _PopularPageState();
}

class _PopularPageState extends State<PopularPage> {
  static const double _progressHeight = 4;

  late final ScrollController scrollController;
  late final ReactionDisposer _tagReactionDisposer;

  PopularController get popularController => widget.controller;

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
    popularController.attachTrendView();
    if (popularController.currentTag.isEmpty) {
      _loadTrend();
    }
  }

  @override
  void dispose() {
    _tagReactionDisposer();
    popularController.detachTrendView();
    scrollController.removeListener(scrollListener);
    scrollController.dispose();
    super.dispose();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? Colors.transparent : null,
      body: LayoutBuilder(
        builder: (context, constraints) {
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
                sliver: Observer(builder: (_) => _buildResults(viewportHeight)),
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

  Widget _buildResults(double viewportHeight) {
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
      return contentGrid(popularController.bangumiList);
    }
    return SliverToBoxAdapter(
      child: PopularDashboard(
        sections: splitPopularItems(popularController.trendList),
        viewportHeight: viewportHeight,
      ),
    );
  }

  Widget contentGrid(List<BangumiItem> bangumiList) {
    int crossCount = 3;
    if (MediaQuery.sizeOf(context).width > LayoutBreakpoint.compact['width']!) {
      crossCount = 5;
    }
    if (MediaQuery.sizeOf(context).width > LayoutBreakpoint.medium['width']!) {
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
              MediaQuery.of(context).size.width / crossCount / 0.65 +
              MediaQuery.textScalerOf(context).scale(32.0),
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
