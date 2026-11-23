import 'package:flutter/material.dart';

/// Shared geometry and color tokens for the cinema shell and redesigned pages.
abstract final class CinemaTokens {
  static const double railWidth = 60.0;
  static const double topBarHeight = 58.0;
  static const double panelRadius = 16.0;
  static const double searchRadius = 22.0;

  static const Color darkCanvas = Color(0xFF09090D);
  static const Color darkRailSurface = Color(0xFF08080C);
  static const Color darkPanelSurface = Color(0xF014141B);
  static const Color darkInputFill = Color(0xCC16161F);
  static const Color darkAccent = Color(0xFFE4152A);
  static const Color darkOnAccent = Colors.white;
  static const Color darkTextPrimary = Color(0xFFF3F4F8);
  static const Color darkTextSecondary = Color(0xFFA4A8B6);
  static const Color darkIconMuted = Color(0xFF8C90A0);
  static const Color darkBorder = Color(0x14FFFFFF);
}

/// 影院视觉配色解析：深色模式启用黑红影院色板，浅色模式回退至 App ColorScheme。
class CinemaPalette {
  const CinemaPalette({
    required this.isCinemaDark,
    required this.canvas,
    required this.railSurface,
    required this.railBorder,
    required this.panelSurface,
    required this.panelBorder,
    required this.inputFill,
    required this.accent,
    required this.onAccent,
    required this.textPrimary,
    required this.textSecondary,
    required this.iconMuted,
  });

  final bool isCinemaDark;
  final Color canvas;
  final Color railSurface;
  final Color railBorder;
  final Color panelSurface;
  final Color panelBorder;
  final Color inputFill;
  final Color accent;
  final Color onAccent;
  final Color textPrimary;
  final Color textSecondary;
  final Color iconMuted;

  factory CinemaPalette.of(BuildContext context) {
    final theme = Theme.of(context);
    if (theme.brightness == Brightness.dark) {
      return CinemaPalette(
        isCinemaDark: true,
        canvas: CinemaTokens.darkCanvas,
        railSurface: CinemaTokens.darkRailSurface,
        railBorder: Colors.white.withValues(alpha: 0.08),
        panelSurface: CinemaTokens.darkPanelSurface,
        panelBorder: Colors.white.withValues(alpha: 0.08),
        inputFill: CinemaTokens.darkInputFill,
        accent: CinemaTokens.darkAccent,
        onAccent: CinemaTokens.darkOnAccent,
        textPrimary: CinemaTokens.darkTextPrimary,
        textSecondary: CinemaTokens.darkTextSecondary,
        iconMuted: CinemaTokens.darkIconMuted,
      );
    }

    final colors = theme.colorScheme;
    return CinemaPalette(
      isCinemaDark: false,
      canvas: colors.surface,
      railSurface: colors.surfaceContainer,
      railBorder: colors.outlineVariant,
      panelSurface: colors.surfaceContainerHigh,
      panelBorder: colors.outlineVariant,
      inputFill: colors.surfaceContainerHigh,
      accent: colors.primary,
      onAccent: colors.onPrimary,
      textPrimary: colors.onSurface,
      textSecondary: colors.onSurfaceVariant,
      iconMuted: colors.onSurfaceVariant,
    );
  }
}
