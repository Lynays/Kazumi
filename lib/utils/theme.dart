import 'package:flutter/material.dart';
import 'package:kazumi/pages/menu/cinema_tokens.dart';
import 'package:kazumi/utils/constants.dart';

/// Default seed color for light mode when no custom theme color is selected.
const Color defaultLightThemeSeed = Colors.green;

/// High-contrast cinema red for text-only buttons and active tab labels on dark
/// surfaces (same hue as [CinemaTokens.darkAccent], WCAG AA >= 5.4:1).
const Color cinemaDarkTextAccent = Color(0xFFFF5C6C);

/// Deep crimson container paired with [cinemaDarkOnPrimaryContainer].
const Color cinemaDarkPrimaryContainer = Color(0xFF7A1022);
const Color cinemaDarkOnPrimaryContainer = Color(0xFFFFECEE);

/// Subtle dark crimson tonal container for tonal buttons, selected chips,
/// active settings rail items, and selected split rows.
const Color cinemaDarkSecondaryContainer = Color(0xFF4A1721);
const Color cinemaDarkOnSecondaryContainer = Color(0xFFFFE3E6);

const Color _cinemaDarkSecondary = Color(0xFFFF8A94);
const Color _cinemaDarkOnSecondary = Color(0xFF440912);

/// Legacy hex stored when toggling OLED/system font previously persisted
/// [Colors.green] instead of `'default'`.
final String _legacyDefaultGreenHex =
    defaultLightThemeSeed.toARGB32().toRadixString(16);

/// Returns true when [storedColor] represents the app's default color theme.
bool isDefaultThemeColor(String? storedColor) {
  if (storedColor == null || storedColor.isEmpty || storedColor == 'default') {
    return true;
  }
  return storedColor.toLowerCase() == _legacyDefaultGreenHex;
}

/// Parses a stored custom [SettingsKeys.themeColor] value, or returns null
/// when the default theme color is active.
Color? resolveCustomThemeColor(String? storedColor) {
  if (isDefaultThemeColor(storedColor)) {
    return null;
  }
  final parsed = int.tryParse(storedColor!, radix: 16);
  return parsed == null ? null : Color(parsed);
}

/// Unified dark cinema [ColorScheme] anchored on the Home TOP 1 red accent
/// ([CinemaTokens.darkAccent]).
ColorScheme buildCinemaDarkColorScheme() {
  final base = ColorScheme.fromSeed(
    seedColor: CinemaTokens.darkAccent,
    brightness: Brightness.dark,
  );
  return base.copyWith(
    primary: CinemaTokens.darkAccent,
    onPrimary: CinemaTokens.darkOnAccent,
    primaryContainer: cinemaDarkPrimaryContainer,
    onPrimaryContainer: cinemaDarkOnPrimaryContainer,
    secondary: _cinemaDarkSecondary,
    onSecondary: _cinemaDarkOnSecondary,
    secondaryContainer: cinemaDarkSecondaryContainer,
    onSecondaryContainer: cinemaDarkOnSecondaryContainer,
    surfaceTint: CinemaTokens.darkAccent,
  );
}

/// Builds Kazumi's Material 3 [ThemeData] for light or dark mode.
///
/// When [colorScheme] is omitted and [customColor] is null (default palette):
/// - Light mode keeps [defaultLightThemeSeed] (`Colors.green`).
/// - Dark mode uses the unified cinema red palette matching the Home TOP 1
///   hero button and cinema shell ([CinemaTokens.darkAccent]).
ThemeData buildAppTheme({
  required Brightness brightness,
  required String? fontFamily,
  Color? customColor,
  ColorScheme? colorScheme,
  bool oledEnhance = false,
}) {
  final useCinemaDarkRed =
      brightness == Brightness.dark &&
      colorScheme == null &&
      customColor == null;

  final effectiveColorScheme =
      colorScheme ?? (useCinemaDarkRed ? buildCinemaDarkColorScheme() : null);
  final effectiveSeed = effectiveColorScheme == null
      ? (customColor ?? defaultLightThemeSeed)
      : null;

  var theme = ThemeData(
    useMaterial3: true,
    fontFamily: fontFamily,
    brightness: brightness,
    colorSchemeSeed: effectiveSeed,
    colorScheme: effectiveColorScheme,
    floatingActionButtonTheme: useCinemaDarkRed
        ? const FloatingActionButtonThemeData(
            backgroundColor: CinemaTokens.darkAccent,
            foregroundColor: CinemaTokens.darkOnAccent,
          )
        : null,
    textButtonTheme: useCinemaDarkRed
        ? TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: cinemaDarkTextAccent),
          )
        : null,
    outlinedButtonTheme: useCinemaDarkRed
        ? OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: cinemaDarkTextAccent,
            ),
          )
        : null,
    elevatedButtonTheme: useCinemaDarkRed
        ? ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              foregroundColor: cinemaDarkTextAccent,
            ),
          )
        : null,
    tabBarTheme: useCinemaDarkRed
        ? const TabBarThemeData(
            indicatorColor: CinemaTokens.darkAccent,
            labelColor: cinemaDarkTextAccent,
          )
        : null,
    switchTheme: useCinemaDarkRed
        ? SwitchThemeData(
            thumbColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return null;
              }
              if (states.contains(WidgetState.selected)) {
                return states.contains(WidgetState.hovered) ||
                        states.contains(WidgetState.focused) ||
                        states.contains(WidgetState.pressed)
                    ? cinemaDarkOnPrimaryContainer
                    : CinemaTokens.darkOnAccent;
              }
              return null;
            }),
          )
        : null,
    progressIndicatorTheme: progressIndicatorTheme2024,
    sliderTheme: sliderTheme2024,
    pageTransitionsTheme: pageTransitionsTheme2024,
  );

  if (brightness == Brightness.dark && oledEnhance) {
    theme = oledDarkTheme(theme);
  }
  return theme;
}

ThemeData oledDarkTheme(ThemeData defaultDarkTheme) {
  final colorScheme = defaultDarkTheme.colorScheme;
  final onPrimary =
      ThemeData.estimateBrightnessForColor(colorScheme.primary) ==
              Brightness.dark
          ? colorScheme.onPrimary
          : Colors.black;
  final onSecondary =
      ThemeData.estimateBrightnessForColor(colorScheme.secondary) ==
              Brightness.dark
          ? colorScheme.onSecondary
          : Colors.black;
  return defaultDarkTheme.copyWith(
    scaffoldBackgroundColor: Colors.black,
    colorScheme: colorScheme.copyWith(
      onPrimary: onPrimary,
      onSecondary: onSecondary,
      surface: Colors.black,
      onSurface: Colors.white,
    ),
  );
}
