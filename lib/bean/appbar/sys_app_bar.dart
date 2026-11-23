import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/widget/embedded_native_control_area.dart';
import 'package:kazumi/services/platform/desktop_window_config.dart';
import 'package:window_manager/window_manager.dart';
import 'package:kazumi/utils/device.dart';

/// 标记外层外壳已提供窗口关闭按钮，避免内嵌页面的 SysAppBar 重复渲染关闭图标。
class ShellWindowCloseScope extends InheritedWidget {
  const ShellWindowCloseScope({
    super.key,
    required this.handledByShell,
    required super.child,
  });

  final bool handledByShell;

  static bool isHandledByShell(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<ShellWindowCloseScope>()
            ?.handledByShell ??
        false;
  }

  @override
  bool updateShouldNotify(ShellWindowCloseScope oldWidget) =>
      handledByShell != oldWidget.handledByShell;
}

class SysAppBar extends StatelessWidget implements PreferredSizeWidget {
  final double? toolbarHeight;
  final Widget? title;
  final Color? backgroundColor;
  final List<Widget>? actions;
  final Widget? leading;
  final bool needTopOffset;

  const SysAppBar({
    super.key,
    this.toolbarHeight,
    this.title,
    this.backgroundColor,
    this.actions,
    this.leading,
    this.needTopOffset = true,
  });

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop();
    final appBarActions = <Widget>[...?actions];
    if (desktop) {
      if (!DesktopWindowConfig.showWindowButton &&
          !ShellWindowCloseScope.isHandledByShell(context)) {
        appBarActions.add(CloseButton(onPressed: () => windowManager.close()));
      }
      appBarActions.add(const SizedBox(width: 8));
    }
    final appBarLeading =
        leading ??
        ((ModalRoute.of(context)?.impliesAppBarDismissal ?? false)
            ? IconButton(
                onPressed: () => context.maybePop(),
                icon: const Icon(Icons.arrow_back),
              )
            : null);

    return GestureDetector(
      onPanStart: desktop ? (_) => windowManager.startDragging() : null,
      child: AppBar(
        toolbarHeight: preferredSize.height,
        scrolledUnderElevation: 0.0,
        title: title != null
            ? EmbeddedNativeControlArea(
                requireOffset: needTopOffset,
                child: title!,
              )
            : null,
        centerTitle: Platform.isIOS,
        actions: appBarActions.map((action) {
          return EmbeddedNativeControlArea(
            requireOffset: needTopOffset,
            child: action,
          );
        }).toList(),
        leading: appBarLeading != null
            ? EmbeddedNativeControlArea(
                requireOffset: needTopOffset,
                child: appBarLeading,
              )
            : null,
        backgroundColor: backgroundColor,
        automaticallyImplyLeading: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              Theme.of(context).brightness == Brightness.light
              ? Brightness.dark
              : Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
        ),
      ),
    );
  }

  @override
  Size get preferredSize {
    // Reserve space for native macOS window controls.
    final topOffset =
        Platform.isMacOS &&
            needTopOffset &&
            DesktopWindowConfig.showWindowButton
        ? 22.0
        : 0.0;
    return Size.fromHeight((toolbarHeight ?? kToolbarHeight) + topOffset);
  }
}
