import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kazumi/pages/popular/popular_carousel_region.dart';
import 'package:kazumi/pages/popular/popular_sections.dart';
import 'package:kazumi/pages/popular/popular_showcase.dart';

/// Displays the popular sections in the available content viewport.
class PopularDashboard extends StatelessWidget {
  const PopularDashboard({
    super.key,
    required this.sections,
    required this.viewportHeight,
  });

  static const double _sectionGap = 12;
  static const double _minShowcaseHeight = 200;
  static const double _minCarouselHeight = 204;

  final PopularSections sections;

  /// Available height after the host deducts navigation and outer padding.
  final double viewportHeight;

  @override
  Widget build(BuildContext context) {
    final contentHeight = viewportHeight.isFinite
        ? viewportHeight - _sectionGap
        : 0.0;
    final showcaseHeight = math.max(_minShowcaseHeight, contentHeight / 3);
    final carouselHeight = math.max(
      _minCarouselHeight,
      contentHeight - showcaseHeight,
    );

    return SingleChildScrollView(
      primary: false,
      child: PopularShowcaseWithCarousels(
        featured: sections.featured,
        mosaic: sections.mosaic,
        showcaseHeight: showcaseHeight,
        gap: _sectionGap,
        carousels: SizedBox(
          height: carouselHeight,
          child: PopularCarouselRegion(rows: sections.rows),
        ),
      ),
    );
  }
}
