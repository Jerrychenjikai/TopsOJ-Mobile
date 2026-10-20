import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'basic/ui_basic.dart';

/// 外部开关可拉伸面板（计算器关闭、再次展开）时用。
/// 面板不在树上时调用 [open] / [close] 会被忽略。
class StretchableLiquidGlassController {
  _StretchableLiquidGlassState? _state;

  void _attach(_StretchableLiquidGlassState state) {
    _state = state;
  }

  void _detach(_StretchableLiquidGlassState state) {
    if (_state == state) _state = null;
  }

  void open() => _state?.open();

  void close() => _state?.close();
}

/// 可拖高度的液态玻璃容器。
///
/// 上方是拖拽把手：上拉增高、下拉降低，范围是屏幕高度的 0 ~ [maxSplit]。
/// 拖到不足 1px 视为收起；若提供了 [onCollapsed]，此时回调（计算器用来关掉自己）。
/// 点击把手会动画到 [defaultSplit]。
///
/// 内容高度是 [defaultSplit] / [maxSplit] 乘以屏幕高度，把手高度另算，不占这个比例。
class StretchableLiquidGlass extends StatefulWidget {
  const StretchableLiquidGlass({
    super.key,
    required this.child,
    this.controller,
    this.defaultSplit = 0.4,
    this.maxSplit = 0.5,
    this.borderRadius = 32,
    this.initiallyOpen = true,
    this.minLayoutExtent,
    this.duration = const Duration(milliseconds: 300),
    this.onCollapsed,
  });

  final Widget child;
  final StretchableLiquidGlassController? controller;

  /// 点击把手、以及初次出现时展开到的屏幕高度比例。
  final double defaultSplit;

  /// 拖拽上限，占屏幕高度的比例。
  final double maxSplit;

  final double borderRadius;

  /// 第一次挂到树上时从 0 动画展开。计算器是打开时才插入这棵树。
  final bool initiallyOpen;

  /// 子组件布局高度的下限（不会超过 maxSplit 对应的高度）。
  /// 计算器在展开动画里太矮会把按键挤出溢出，所以给一个下限再裁切。
  /// 为空时按可见高度布局，适合内部自己滚动的内容。
  final double? minLayoutExtent;

  final Duration duration;

  /// 拖到 0，或 [close] 动画结束落到 0 时调用。
  final VoidCallback? onCollapsed;

  @override
  State<StretchableLiquidGlass> createState() => _StretchableLiquidGlassState();
}

class _StretchableLiquidGlassState extends State<StretchableLiquidGlass>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// 收到 0 的动画结束时才回调 [StretchableLiquidGlass.onCollapsed]，
  /// 避免打开动画从 0 起步时被立刻关掉。
  bool _closeAtZero = false;

  double get _openSplit => widget.defaultSplit.clamp(0.0, widget.maxSplit);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: 0.0,
    )..addStatusListener(_handleStatus);
    widget.controller?._attach(this);

    if (widget.initiallyOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        open();
      });
    }
  }

  @override
  void didUpdateWidget(StretchableLiquidGlass oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _controller
      ..removeStatusListener(_handleStatus)
      ..dispose();
    super.dispose();
  }

  void open() {
    _closeAtZero = false;
    _controller.animateTo(
      _openSplit,
      duration: widget.duration,
      curve: Curves.easeOut,
    );
  }

  void close() {
    _closeAtZero = true;
    if (_controller.value <= 0.001) {
      _controller.value = 0.0;
      _handleStatus(AnimationStatus.dismissed);
      return;
    }
    _controller.animateTo(
      0.0,
      duration: widget.duration,
      curve: Curves.easeOut,
    );
  }

  void _handleStatus(AnimationStatus status) {
    if (!mounted) return;
    final bool settled = status == AnimationStatus.completed ||
        status == AnimationStatus.dismissed;
    if (!settled) return;

    if (_closeAtZero && _controller.value <= 0.001) {
      _closeAtZero = false;
      widget.onCollapsed?.call();
    }
    if (!mounted) return;
    _notifyGlass();
  }

  void _notifyGlass() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      LiquidGlassScope.notifyUpdate(context);
    });
  }

  /// 拖动跟手。高度落到 0（不足 1px 视为 0）时收起。
  void _setSplit(double split, double screenHeight) {
    final double next = split.clamp(0.0, widget.maxSplit);
    final bool collapsed =
        next <= 0.0 || (screenHeight > 0 && next * screenHeight < 1);
    if (collapsed) {
      _closeAtZero = false;
      _controller.value = 0.0;
      widget.onCollapsed?.call();
      if (mounted) _notifyGlass();
      return;
    }
    _controller.value = next;
  }

  Widget _buildHandle(double screenHeight) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (_) {
        _closeAtZero = false;
        _controller.stop();
      },
      onVerticalDragUpdate: (details) {
        if (screenHeight <= 0) return;
        final double next =
            _controller.value - (details.delta.dy / screenHeight);
        _setSplit(next, screenHeight);
      },
      onVerticalDragEnd: (_) => _notifyGlass(),
      onVerticalDragCancel: () => _notifyGlass(),
      onTap: open,
      child: const SizedBox(
        width: double.infinity,
        height: 32,
        child: Center(
          child: Icon(Icons.drag_handle, color: Colors.black),
        ),
      ),
    );
  }

  Widget _buildBody(double screenHeight) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final double visibleHeight = screenHeight * _controller.value;
        if (visibleHeight <= 0) return const SizedBox.shrink();

        double layoutHeight = visibleHeight;
        if (widget.minLayoutExtent != null && screenHeight > 0) {
          final double floor = math.min(
            widget.minLayoutExtent!,
            screenHeight * widget.maxSplit,
          );
          layoutHeight = math.max(visibleHeight, floor);
        }

        return SizedBox(
          width: double.infinity,
          height: visibleHeight,
          child: ClipRect(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double width = constraints.maxWidth.isFinite
                    ? constraints.maxWidth
                    : MediaQuery.sizeOf(context).width;
                return OverflowBox(
                  alignment: Alignment.topCenter,
                  minWidth: width,
                  maxWidth: width,
                  minHeight: layoutHeight,
                  maxHeight: layoutHeight,
                  child: widget.child,
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.sizeOf(context).height;

    return SizedBox(
      width: double.infinity,
      child: LiquidGlassContainer(
        borderRadius: widget.borderRadius,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHandle(screenHeight),
              _buildBody(screenHeight),
            ],
          ),
        ),
      ),
    );
  }
}
