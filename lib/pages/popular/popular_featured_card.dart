import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/utils/constants.dart';

/// Netflix-style hero showcase card for the current popular TOP 1 anime.
class PopularFeaturedCard extends StatelessWidget {
  const PopularFeaturedCard({super.key, required this.item});

  final BangumiItem item;

  String get _title {
    final cn = item.nameCn.trim();
    if (cn.isNotEmpty) return cn;
    final raw = item.name.trim();
    return raw.isNotEmpty ? raw : '未知番剧';
  }

  String get _cover {
    for (final k in const ['large', 'common', 'medium', 'small', 'grid']) {
      final url = item.images[k]?.trim() ?? '';
      if (url.isNotEmpty) return url;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final title = _title;
    final cover = _cover;
    final summary = item.summary.replaceAll(RegExp(r'\s+'), ' ').trim();

    return Semantics(
      container: true,
      button: true,
      label: '当前热门 TOP 1，$title',
      child: Material(
        color: colors.surfaceContainerHighest,
        borderRadius: StyleString.mdRadius,
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (_, c) {
            final w = c.maxWidth.isFinite && c.maxWidth > 0
                ? c.maxWidth
                : 480.0;
            final h = c.maxHeight.isFinite && c.maxHeight > 0
                ? c.maxHeight
                : 240.0;
            final compact = h < 180;
            final posterH = (h - 32).clamp(96.0, 220.0);
            final posterW = posterH * 0.68;
            final titleStyle =
                (compact
                        ? theme.textTheme.titleMedium
                        : theme.textTheme.headlineSmall)
                    ?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    );

            return Stack(
              fit: StackFit.expand,
              children: [
                NetworkImgLayer(
                  src: cover,
                  width: w,
                  height: h,
                  borderRadius: BorderRadius.zero,
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomLeft,
                      end: Alignment.topRight,
                      colors: [
                        Color(0xE6000000),
                        Color(0x9E000000),
                        Color(0x33000000),
                      ],
                      stops: [0.0, 0.56, 1.0],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(compact ? 12 : 18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                _pill(
                                  colors.primary,
                                  colors.onPrimary,
                                  'TOP 1',
                                ),
                                _pill(
                                  const Color(0x3DFFFFFF),
                                  Colors.white,
                                  '当前热门',
                                ),
                                if (item.ratingScore > 0)
                                  _pill(
                                    const Color(0x4D000000),
                                    Colors.white,
                                    item.ratingScore.toStringAsFixed(1),
                                    icon: Icons.star_rounded,
                                  ),
                              ],
                            ),
                            SizedBox(height: compact ? 6 : 10),
                            Text(
                              title,
                              maxLines: compact ? 1 : 2,
                              overflow: TextOverflow.ellipsis,
                              style: titleStyle,
                            ),
                            if (summary.isNotEmpty && h >= 150) ...[
                              const SizedBox(height: 6),
                              Flexible(
                                child: Text(
                                  summary,
                                  maxLines: h >= 220 ? 3 : 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.86),
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                            if (h >= 120) ...[
                              SizedBox(height: compact ? 8 : 12),
                              _pill(
                                Colors.white.withValues(alpha: 0.92),
                                Colors.black87,
                                '查看详情',
                                icon: Icons.play_arrow_rounded,
                                r: 20,
                                px: 12,
                                py: 6,
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (w >= 440 && h >= 160 && cover.isNotEmpty) ...[
                        const SizedBox(width: 16),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: StyleString.mdRadius,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.24),
                            ),
                          ),
                          child: NetworkImgLayer(
                            src: cover,
                            width: posterW,
                            height: posterH,
                            borderRadius: StyleString.mdRadius,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Positioned.fill(
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      onTap: () => context.pushNamed('/info/', arguments: item),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static Widget _pill(
    Color bg,
    Color fg,
    String text, {
    IconData? icon,
    double r = 6,
    double px = 8,
    double py = 3,
  }) {
    final label = Text(
      text,
      style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700),
    );
    return Container(
      padding: EdgeInsets.symmetric(horizontal: px, vertical: py),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(r),
      ),
      child: icon == null
          ? label
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: fg),
                const SizedBox(width: 3),
                label,
              ],
            ),
    );
  }
}
