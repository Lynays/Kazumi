import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';

// 视频卡片 - 垂直布局
class BangumiCardV extends StatelessWidget {
  const BangumiCardV({
    super.key,
    required this.bangumiItem,
    this.canTap = true,
    this.enableHero = true,
    this.coverWidth,
    this.coverHeight,
  });

  final BangumiItem bangumiItem;
  final bool canTap;
  final bool enableHero;
  final double? coverWidth;
  final double? coverHeight;

  String get _coverUrl {
    for (final key in const ['large', 'common', 'medium', 'small', 'grid']) {
      final url = bangumiItem.images[key]?.trim() ?? '';
      if (url.isNotEmpty) return url;
    }
    return '';
  }

  Widget _buildCoverImage(double width, double height) {
    final image = NetworkImgLayer(
      src: _coverUrl,
      width: width,
      height: height,
      fadeOutDuration: Duration.zero,
      fadeInDuration: const Duration(milliseconds: 80),
    );
    if (!enableHero) return image;
    return Hero(
      transitionOnUserGestures: true,
      flightShuttleBuilder: NetworkImgLayer.heroFlightShuttleBuilder,
      tag: bangumiItem.id,
      child: image,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasKnownCoverSize =
        coverWidth != null &&
        coverHeight != null &&
        coverWidth!.isFinite &&
        coverHeight!.isFinite &&
        coverWidth! > 0 &&
        coverHeight! > 0;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () {
          if (!canTap) {
            KazumiDialog.showToast(
              message: '编辑模式',
            );
            return;
          }
          context.pushNamed('/info/', arguments: bangumiItem);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 0.65,
              child: hasKnownCoverSize
                  ? _buildCoverImage(coverWidth!, coverHeight!)
                  : LayoutBuilder(
                      builder: (context, boxConstraints) => _buildCoverImage(
                        boxConstraints.maxWidth,
                        boxConstraints.maxHeight,
                      ),
                    ),
            ),
            BangumiContent(bangumiItem: bangumiItem),
          ],
        ),
      ),
    );
  }
}

class BangumiContent extends StatelessWidget {
  const BangumiContent({super.key, required this.bangumiItem});

  final BangumiItem bangumiItem;

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context).clamp(
      maxScaleFactor: 1.1,
    );
    final style = DefaultTextStyle.of(context).style.copyWith(
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
        );

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(5, 3, 5, 1),
        child: Text(
          bangumiItem.nameCn,
          textAlign: TextAlign.start,
          style: style,
          textScaler: textScaler,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
