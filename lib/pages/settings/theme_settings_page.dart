import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/card/palette_card.dart';
import 'package:kazumi/pages/menu/cinema_tokens.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/settings/theme_provider.dart';
import 'package:kazumi/bean/settings/visual_effects_config.dart';
import 'package:kazumi/bean/settings/color_type.dart';
import 'package:kazumi/bean/settings/settings_detail_scaffold.dart';
import 'package:kazumi/bean/settings/settings_dropdown_tile.dart';
import 'package:kazumi/bean/settings/settings_list.dart';
import 'package:window_manager/window_manager.dart';
import 'package:kazumi/utils/device.dart';
import 'package:kazumi/utils/theme.dart';

class ThemeSettingsPage extends StatefulWidget {
  const ThemeSettingsPage({super.key});

  @override
  State<ThemeSettingsPage> createState() => _ThemeSettingsPageState();
}

class _ThemeSettingsPageState extends State<ThemeSettingsPage> {
  late dynamic defaultThemeMode;
  late dynamic defaultThemeColor;
  late bool oledEnhance;
  late bool useDynamicColor;
  late bool showWindowButton;
  late bool useSystemFont;
  late VisualEffectsConfig _effects;
  late bool _showDetailedEffects;
  late final ThemeProvider themeProvider;

  @override
  void initState() {
    super.initState();
    defaultThemeMode = GStorage.getSetting(SettingsKeys.themeMode);
    defaultThemeColor = GStorage.getSetting(SettingsKeys.themeColor);
    oledEnhance = GStorage.getSetting(SettingsKeys.oledEnhance);
    useDynamicColor = GStorage.getSetting(SettingsKeys.useDynamicColor);
    showWindowButton = GStorage.getSetting(SettingsKeys.showWindowButton);
    useSystemFont = GStorage.getSetting(SettingsKeys.useSystemFont);
    _effects = VisualEffectsConfig.fromStorage();
    _showDetailedEffects = !_effects.isUniform;
    themeProvider = context.read<ThemeProvider>();
    themeProvider.setVisualEffects(_effects);
  }

  double _snapEffectLevel(double value) => (value * 20).round() / 20.0;

  String _formatEffectPercent(int percent) => percent <= 0 ? '关闭' : '$percent%';

  void _applyVisualEffects(VisualEffectsConfig next) {
    if (next == _effects) return;
    themeProvider.setVisualEffects(next);
    setState(() {
      _effects = next;
    });
    unawaited(next.saveToStorage());
  }

  void _applyCurrentTheme() {
    final customColor = resolveCustomThemeColor(defaultThemeColor?.toString());
    themeProvider.setTheme(
      buildAppTheme(
        brightness: Brightness.light,
        customColor: customColor,
        fontFamily: themeProvider.currentFontFamily,
      ),
      buildAppTheme(
        brightness: Brightness.dark,
        customColor: customColor,
        fontFamily: themeProvider.currentFontFamily,
        oledEnhance: oledEnhance,
      ),
    );
  }

  void setTheme(Color? color) {
    defaultThemeColor = color?.toARGB32().toRadixString(16) ?? 'default';
    _applyCurrentTheme();
    GStorage.putSetting(SettingsKeys.themeColor, defaultThemeColor);
  }

  void resetTheme() {
    defaultThemeColor = 'default';
    _applyCurrentTheme();
    GStorage.putSetting(SettingsKeys.themeColor, 'default');
  }

  void updateTheme(String theme) async {
    if (theme == 'dark') {
      themeProvider.setThemeMode(ThemeMode.dark);
    }
    if (theme == 'light') {
      themeProvider.setThemeMode(ThemeMode.light);
    }
    if (theme == 'system') {
      themeProvider.setThemeMode(ThemeMode.system);
    }
    await GStorage.putSetting(SettingsKeys.themeMode, theme);
    setState(() {
      defaultThemeMode = theme;
    });

    // Update Windows title bar theme
    if (Platform.isWindows) {
      await windowManager.setBrightness(
          themeProvider.isEffectiveDark() ? Brightness.dark : Brightness.light);
    }
  }

  void updateOledEnhance() {
    oledEnhance = GStorage.getSetting(SettingsKeys.oledEnhance);
    _applyCurrentTheme();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsDetailScaffold(
      title: const Text('外观设置'),
      body: SettingsList(
        sections: [
          SettingsSection(
            title: Text('外观'),
            tiles: [
              SettingsDropdownTile<String>(
                leading: Icons.dark_mode_rounded,
                title: const Text('深色模式'),
                value: defaultThemeMode,
                fallbackLabel: '跟随系统',
                options: const {'system': '跟随系统', 'light': '浅色', 'dark': '深色'},
                onChanged: updateTheme,
              ),
              SettingsTile(
                leading: Icons.palette_rounded,
                enabled: !useDynamicColor,
                onPressed: (_) async {
                  KazumiDialog.show(builder: (context) {
                    return AlertDialog(
                      title: Text('配色方案'),
                      content: StatefulBuilder(builder:
                          (BuildContext context, StateSetter setState) {
                        final List<Map<String, dynamic>> colorThemes =
                            colorThemeTypes;
                        final isDark =
                            Theme.of(context).brightness == Brightness.dark;
                        final storedColor = defaultThemeColor?.toString();
                        return Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: isDesktop() ? 8 : 0,
                          children: [
                            ...colorThemes.map(
                              (e) {
                                final index = colorThemes.indexOf(e);
                                final Color themeColor = e['color'] as Color;
                                final Color swatchColor = index == 0 && isDark
                                    ? CinemaTokens.darkAccent
                                    : themeColor;
                                final bool isSelected = index == 0
                                    ? isDefaultThemeColor(storedColor)
                                    : themeColor.toARGB32().toRadixString(16) ==
                                          storedColor;
                                return GestureDetector(
                                  onTap: () {
                                    index == 0
                                        ? resetTheme()
                                        : setTheme(themeColor);
                                    KazumiDialog.dismiss();
                                  },
                                  child: Column(
                                    children: [
                                      PaletteCard(
                                        color: swatchColor,
                                        selected: isSelected,
                                      ),
                                      Text(e['label']),
                                    ],
                                  ),
                                );
                              },
                            )
                          ],
                        );
                      }),
                    );
                  });
                },
                title: Text('配色方案'),
              ),
              SettingsTile.switchTile(
                leading: Icons.colorize_rounded,
                enabled: !Platform.isIOS,
                onToggle: (value) async {
                  useDynamicColor = value ?? !useDynamicColor;
                  await GStorage.putSetting(
                      SettingsKeys.useDynamicColor, useDynamicColor);
                  themeProvider.setDynamic(useDynamicColor);
                  setState(() {});
                },
                title: Text('动态配色'),
                initialValue: useDynamicColor,
              ),
              SettingsTile.switchTile(
                leading: Icons.font_download_rounded,
                onToggle: (value) async {
                  useSystemFont = value ?? !useSystemFont;
                  await GStorage.putSetting(
                      SettingsKeys.useSystemFont, useSystemFont);
                  themeProvider.setFontFamily(useSystemFont);
                  _applyCurrentTheme();
                  setState(() {});
                },
                title: Text('使用系统字体'),
                description: Text('关闭后使用 MI Sans 字体'),
                initialValue: useSystemFont,
              ),
            ],
            bottomInfo: Text('动态配色仅支持安卓12及以上和桌面平台'),
          ),
          SettingsSection(
            title: const Text('视觉特效'),
            tiles: [
              SettingsSliderTile(
                leading: Icons.auto_awesome_rounded,
                title: const Text('视觉特效强度'),
                description: const Text('以默认 70% 为基准，统一调节全局特效强度'),
                value: _effects.overallLevel,
                min: VisualEffectsConfig.minLevel,
                max: VisualEffectsConfig.maxLevel,
                divisions: 30,
                valueLabel: _effects.isUniform
                    ? _formatEffectPercent(_effects.overallPercent)
                    : '自定义 · ${_effects.overallPercent}%',
                onChanged: (value) => _applyVisualEffects(
                  VisualEffectsConfig.uniform(_snapEffectLevel(value)),
                ),
              ),
              SettingsTile(
                leading: Icons.tune_rounded,
                title: const Text('单项特效调节'),
                description: const Text('分别调整倒影、光晕、反光、阴影与背景虚化'),
                value: Text(
                  _effects.isUniform
                      ? (_effects.overallPercent == 0
                          ? '全部关闭'
                          : '统一 ${_effects.overallPercent}%')
                      : '已自定义',
                ),
                trailing: Icon(
                  _showDetailedEffects
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                ),
                onPressed: (_) {
                  setState(() {
                    _showDetailedEffects = !_showDetailedEffects;
                  });
                },
              ),
              if (_showDetailedEffects) ...[
                SettingsSliderTile(
                  leading: Icons.flip_rounded,
                  title: const Text('海报底部倒影'),
                  description: const Text('首页轮播与榜单拼贴卡片下方的镜像倒影'),
                  value: _effects.reflection,
                  min: VisualEffectsConfig.minLevel,
                  max: VisualEffectsConfig.maxLevel,
                  divisions: 30,
                  valueLabel: _formatEffectPercent(_effects.reflectionPercent),
                  onChanged: (value) => _applyVisualEffects(
                    _effects.copyWith(reflection: _snapEffectLevel(value)),
                  ),
                ),
                SettingsSliderTile(
                  leading: Icons.blur_circular_rounded,
                  title: const Text('影院背景光晕'),
                  description: const Text('深色影院底板的氛围光晕'),
                  value: _effects.backdropGlow,
                  min: VisualEffectsConfig.minLevel,
                  max: VisualEffectsConfig.maxLevel,
                  divisions: 30,
                  valueLabel:
                      _formatEffectPercent(_effects.backdropGlowPercent),
                  onChanged: (value) => _applyVisualEffects(
                    _effects.copyWith(backdropGlow: _snapEffectLevel(value)),
                  ),
                ),
                SettingsSliderTile(
                  leading: Icons.flare_rounded,
                  title: const Text('舞台地面反光'),
                  description: const Text('首页展示区与轮播区地面的环境反光'),
                  value: _effects.floorLight,
                  min: VisualEffectsConfig.minLevel,
                  max: VisualEffectsConfig.maxLevel,
                  divisions: 30,
                  valueLabel: _formatEffectPercent(_effects.floorLightPercent),
                  onChanged: (value) => _applyVisualEffects(
                    _effects.copyWith(floorLight: _snapEffectLevel(value)),
                  ),
                ),
                SettingsSliderTile(
                  leading: Icons.layers_rounded,
                  title: const Text('卡片阴影与光泽'),
                  description: const Text('首页海报卡片的立体阴影、高光描边与按钮辉光'),
                  value: _effects.cardEffects,
                  min: VisualEffectsConfig.minLevel,
                  max: VisualEffectsConfig.maxLevel,
                  divisions: 30,
                  valueLabel: _formatEffectPercent(_effects.cardEffectsPercent),
                  onChanged: (value) => _applyVisualEffects(
                    _effects.copyWith(cardEffects: _snapEffectLevel(value)),
                  ),
                ),
                SettingsSliderTile(
                  leading: Icons.blur_on_rounded,
                  title: const Text('详情页背景虚化'),
                  description: const Text('番剧详情页顶部的封面模糊氛围背景'),
                  value: _effects.headerBlur,
                  min: VisualEffectsConfig.minLevel,
                  max: VisualEffectsConfig.maxLevel,
                  divisions: 30,
                  valueLabel: _formatEffectPercent(_effects.headerBlurPercent),
                  onChanged: (value) => _applyVisualEffects(
                    _effects.copyWith(headerBlur: _snapEffectLevel(value)),
                  ),
                ),
                SettingsTile(
                  leading: Icons.settings_backup_restore_rounded,
                  enabled: !_effects.isDefault,
                  title: const Text('恢复默认特效强度'),
                  description: const Text('将所有视觉特效恢复为 70% 基准强度'),
                  onPressed: (_) =>
                      _applyVisualEffects(VisualEffectsConfig.defaults),
                ),
              ],
            ],
            bottomInfo: const Text(
              '调至 0% 将关闭对应特效以降低绘制开销，70% 为默认基准强度，最高可调至 150%',
            ),
          ),
          SettingsSection(
            title: Text('显示'),
            tiles: [
              SettingsTile.switchTile(
                leading: Icons.contrast_rounded,
                onToggle: (value) async {
                  oledEnhance = value ?? !oledEnhance;
                  await GStorage.putSetting(
                      SettingsKeys.oledEnhance, oledEnhance);
                  updateOledEnhance();
                  setState(() {});
                },
                title: Text('OLED优化'),
                description: Text('深色模式下使用纯黑背景'),
                initialValue: oledEnhance,
              ),
            ],
          ),
          if (isDesktop())
            SettingsSection(
              title: Text('窗口'),
              tiles: [
                SettingsTile.switchTile(
                  leading: Icons.web_asset_rounded,
                  onToggle: (value) async {
                    showWindowButton = value ?? !showWindowButton;
                    await GStorage.putSetting(
                        SettingsKeys.showWindowButton, showWindowButton);
                    setState(() {});
                  },
                  title: Text('使用系统标题栏'),
                  description: Text('重启应用生效'),
                  initialValue: showWindowButton,
                ),
              ],
            ),
          if (Platform.isAndroid)
            SettingsSection(
              title: Text('屏幕'),
              tiles: [
                SettingsTile(
                  leading: Icons.sixty_fps_rounded,
                  onPressed: (_) async {
                    context.pushNamed('/settings/theme/display');
                  },
                  title: Text('屏幕帧率'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
