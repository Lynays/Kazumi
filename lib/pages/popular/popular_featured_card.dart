import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:kazumi/bean/settings/visual_effects_config.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';

/// Netflix-style hero showcase card for the current popular TOP 1 anime.
class PopularFeaturedCard extends StatelessWidget {
  const PopularFeaturedCard({super.key, required this.item});

  static final RegExp _whitespacePattern = RegExp(r'\s+');

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
    final isDark = theme.brightness == Brightness.dark;
    final cardEffectsScale = VisualEffectsConfig.of(context).cardEffectsScale;
    final edgeFadeColor = theme.scaffoldBackgroundColor;
    final accent = isDark ? const Color(0xFFE4152A) : colors.primary;
    final onAccent = isDark ? Colors.white : colors.onPrimary;
    final title = _title;
    final cover = _cover;
    final summary = item.summary.replaceAll(_whitespacePattern, ' ').trim();
    final rawTitle = item.name.trim();
    final genres = item.tags.take(3).map((tag) => tag.name).join('  ·  ');
    const cardRadius = BorderRadius.all(Radius.circular(14));

    return Semantics(
      container: true,
      button: true,
      label: '当前热门 TOP 1，$title',
      child: Material(
        type: MaterialType.transparency,
        borderRadius: cardRadius,
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (_, c) {
            final w = c.maxWidth.isFinite && c.maxWidth > 0
                ? c.maxWidth
                : 480.0;
            final h = c.maxHeight.isFinite && c.maxHeight > 0
                ? c.maxHeight
                : 240.0;
            final scaledTitleSize = MediaQuery.textScalerOf(context).scale(16);
            final textHeight = scaledTitleSize > 16
                ? h * 16 / scaledTitleSize
                : h;
            final compact = textHeight < 240;
            final tight = textHeight < 144;
            final titleStyle =
                (compact
                        ? theme.textTheme.titleMedium
                        : theme.textTheme.headlineMedium)
                    ?.copyWith(
                      color: Colors.white,
                      fontSize: compact
                          ? null
                          : (w >= 560 && textHeight >= 260 ? 36 : 30),
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                    );
            final titleText = Text(
              title,
              maxLines: compact ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: titleStyle,
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
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Color(0xF008080C),
                        Color(0xAE08080C),
                        Color(0x0608080C),
                        Color(0x34090B10),
                      ],
                      stops: [0.0, 0.30, 0.59, 1.0],
                    ),
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Color(0x96090B10),
                        Color(0x40090B10),
                        Color(0x00090B10),
                      ],
                      stops: [0.0, 0.14, 0.34],
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        edgeFadeColor,
                        edgeFadeColor.withValues(alpha: 0.0),
                        edgeFadeColor.withValues(alpha: 0.0),
                        edgeFadeColor,
                      ],
                      stops: const [0.0, 0.03, 0.96, 1.0],
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        edgeFadeColor,
                        edgeFadeColor.withValues(alpha: 0.0),
                        edgeFadeColor.withValues(alpha: 0.0),
                        edgeFadeColor,
                      ],
                      stops: const [0.0, 0.05, 0.89, 1.0],
                    ),
                  ),
                ),
                if (textHeight < 96)
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: titleText,
                    ),
                  )
                else
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 12 : 30,
                      tight ? 8 : 12,
                      16,
                      tight ? 8 : (compact ? 12 : 22),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _pill(
                                accent,
                                onAccent,
                                'TOP 1',
                                icon: Icons.emoji_events_rounded,
                                r: 12,
                              ),
                              SizedBox(height: tight ? 4 : (compact ? 6 : 10)),
                              titleText,
                              if (rawTitle.isNotEmpty &&
                                  rawTitle != title &&
                                  textHeight >= 190) ...[
                                const SizedBox(height: 2),
                                Text(
                                  rawTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.88),
                                    height: 1.12,
                                  ),
                                ),
                              ],
                              SizedBox(height: compact ? 3 : 6),
                              Row(
                                children: [
                                  if (item.ratingScore > 0) ...[
                                    _pill(
                                      Colors.transparent,
                                      Colors.white,
                                      item.ratingScore.toStringAsFixed(1),
                                      icon: Icons.star_rounded,
                                      iconColor: const Color(0xFFF5B742),
                                      px: 0,
                                      py: 0,
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Flexible(
                                    child: Text(
                                      !compact && genres.isNotEmpty
                                          ? genres
                                          : '当前热门',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: const Color(0xD9F6EDF1),
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              if (summary.isNotEmpty && textHeight >= 180) ...[
                                const SizedBox(height: 6),
                                Flexible(
                                  child: Text(
                                    summary,
                                    maxLines: textHeight >= 220 ? 3 : 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.86,
                                      ),
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                              if (textHeight >= 128) ...[
                                SizedBox(
                                  height: tight ? 6 : (compact ? 8 : 12),
                                ),
                                _pill(
                                  accent,
                                  onAccent,
                                  '查看详情',
                                  icon: Icons.info_outline_rounded,
                                  glowColor: cardEffectsScale > 0
                                      ? accent
                                      : null,
                                  glowScale: cardEffectsScale,
                                  r: 10,
                                  px: compact ? 16 : 20,
                                  py: tight ? 5 : (compact ? 7 : 10),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (!compact && w >= 420) SizedBox(width: w * 0.48),
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
    Color? iconColor,
    Color? glowColor,
    double glowScale = 1.0,
    double r = 6,
    double px = 8,
    double py = 3,
  }) {
    final label = Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
    );
    return Container(
      padding: EdgeInsets.symmetric(horizontal: px, vertical: py),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(r),
        boxShadow: glowColor == null || glowScale <= 0
            ? null
            : [
                BoxShadow(
                  color: glowColor.withValues(
                    alpha: (0.48 * glowScale).clamp(0.0, 1.0),
                  ),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: icon == null
          ? label
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: iconColor ?? fg),
                const SizedBox(width: 3),
                Flexible(child: label),
              ],
            ),
    );
  }
}
