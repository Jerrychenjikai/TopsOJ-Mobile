import 'package:flutter/widgets.dart';

import 'package:TopsOJ/basic/ui_basic.dart';

/// 主界面整栏被盖住时（窄屏正在看从主界面打开的题目）为 false。
/// 玻璃钩子在重新露出来之后再采样，避免把 Offstage 的空白采进去。
class ShellPaneActive extends InheritedWidget {
  final bool active;

  const ShellPaneActive({
    super.key,
    required this.active,
    required super.child,
  });

  static bool of(BuildContext context) {
    final inherited =
        context.dependOnInheritedWidgetOfExactType<ShellPaneActive>();
    return inherited?.active ?? true;
  }

  @override
  bool updateShouldNotify(ShellPaneActive oldWidget) => active != oldWidget.active;
}

/// 窗口或这一栏的尺寸变了之后，通知最近的 [LiquidGlassScope] 重新采样。
/// 必须放在对应的 scope 里面。iPad 拖动窗口大小时靠这个更新折射。
class LiquidGlassMetricsHook extends StatefulWidget {
  final Widget child;

  const LiquidGlassMetricsHook({super.key, required this.child});

  @override
  State<LiquidGlassMetricsHook> createState() => _LiquidGlassMetricsHookState();
}

class _LiquidGlassMetricsHookState extends State<LiquidGlassMetricsHook> {
  Size? _size;
  EdgeInsets? _padding;
  bool? _active;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final mq = MediaQuery.of(context);
    final size = mq.size;
    final padding = mq.padding;
    final active = ShellPaneActive.of(context);
    final first = _size == null;
    final sizeChanged = _size != size || _padding != padding;
    final becameActive = _active == false && active;
    _size = size;
    _padding = padding;
    _active = active;
    if (first || !active || !(sizeChanged || becameActive)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      LiquidGlassScope.notifyUpdate(context);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
