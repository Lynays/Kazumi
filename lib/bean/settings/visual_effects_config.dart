import 'package:flutter/widgets.dart';
import 'package:kazumi/services/storage/storage.dart';

/// User-configurable visual effect intensities.
///
/// Each level lives in `[minLevel, maxLevel]` (`0%` to `150%`) where
/// [defaultLevel] (`0.70`, i.e. 70%) maps to `1.0x` of the original baseline
/// strength, `0.0` disables the effect completely, and `1.50` boosts it to
/// `~2.14x`.
@immutable
class VisualEffectsConfig {
  const VisualEffectsConfig({
    this.reflection = defaultLevel,
    this.floorLight = defaultLevel,
    this.cardEffects = defaultLevel,
    this.headerBlur = defaultLevel,
  });

  static const double minLevel = 0.0;
  static const double defaultLevel = 0.70;
  static const double maxLevel = 1.50;
  static const VisualEffectsConfig defaults = VisualEffectsConfig();

  factory VisualEffectsConfig.uniform(double level) {
    final clamped = clampLevel(level);
    return VisualEffectsConfig(
      reflection: clamped,
      floorLight: clamped,
      cardEffects: clamped,
      headerBlur: clamped,
    );
  }

  factory VisualEffectsConfig.fromStorage() {
    return VisualEffectsConfig(
      reflection: clampLevel(GStorage.getSetting(SettingsKeys.effectReflection)),
      floorLight: clampLevel(GStorage.getSetting(SettingsKeys.effectFloorLight)),
      cardEffects: clampLevel(
        GStorage.getSetting(SettingsKeys.effectCardEffects),
      ),
      headerBlur: clampLevel(GStorage.getSetting(SettingsKeys.effectHeaderBlur)),
    );
  }

  final double reflection;
  final double floorLight;
  final double cardEffects;
  final double headerBlur;

  static double clampLevel(double value) =>
      value.isFinite ? value.clamp(minLevel, maxLevel) : defaultLevel;

  static double scaleFor(double level) => clampLevel(level) / defaultLevel;

  static int percentFor(double level) => (clampLevel(level) * 100).round();

  double get reflectionScale => scaleFor(reflection);
  double get floorLightScale => scaleFor(floorLight);
  double get cardEffectsScale => scaleFor(cardEffects);
  double get headerBlurScale => scaleFor(headerBlur);

  int get reflectionPercent => percentFor(reflection);
  int get floorLightPercent => percentFor(floorLight);
  int get cardEffectsPercent => percentFor(cardEffects);
  int get headerBlurPercent => percentFor(headerBlur);

  bool get isUniform =>
      reflectionPercent == floorLightPercent &&
      reflectionPercent == cardEffectsPercent &&
      reflectionPercent == headerBlurPercent;

  bool get isDefault =>
      isUniform && reflectionPercent == percentFor(defaultLevel);

  double get overallLevel {
    if (isUniform) return reflection;
    return clampLevel(
      (reflection + floorLight + cardEffects + headerBlur) / 4.0,
    );
  }

  int get overallPercent => percentFor(overallLevel);

  VisualEffectsConfig copyWith({
    double? reflection,
    double? floorLight,
    double? cardEffects,
    double? headerBlur,
  }) {
    return VisualEffectsConfig(
      reflection: reflection != null ? clampLevel(reflection) : this.reflection,
      floorLight: floorLight != null ? clampLevel(floorLight) : this.floorLight,
      cardEffects:
          cardEffects != null ? clampLevel(cardEffects) : this.cardEffects,
      headerBlur: headerBlur != null ? clampLevel(headerBlur) : this.headerBlur,
    );
  }

  Future<void> saveToStorage() async {
    await GStorage.putSettings({
      SettingsKeys.effectReflection: reflection,
      SettingsKeys.effectFloorLight: floorLight,
      SettingsKeys.effectCardEffects: cardEffects,
      SettingsKeys.effectHeaderBlur: headerBlur,
    });
  }

  static VisualEffectsConfig of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<VisualEffectsScope>()
            ?.config ??
        defaults;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is VisualEffectsConfig &&
            reflection == other.reflection &&
            floorLight == other.floorLight &&
            cardEffects == other.cardEffects &&
            headerBlur == other.headerBlur;
  }

  @override
  int get hashCode => Object.hash(
        reflection,
        floorLight,
        cardEffects,
        headerBlur,
      );
}

/// Provides [VisualEffectsConfig] to effect widgets without rebuilding the
/// root [ThemeData] or triggering [AnimatedTheme].
class VisualEffectsScope extends InheritedWidget {
  const VisualEffectsScope({
    super.key,
    required this.config,
    required super.child,
  });

  final VisualEffectsConfig config;

  @override
  bool updateShouldNotify(VisualEffectsScope oldWidget) =>
      config != oldWidget.config;
}
