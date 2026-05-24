import "package:flutter/material.dart";

class ScreenSplitter extends StatefulWidget {
  final Widget childA;
  final Widget? childB; // 改为可选参数

  const ScreenSplitter({
    super.key,
    required this.childA,
    this.childB,
  });

  @override
  State<ScreenSplitter> createState() => _ScreenSplitterState();
}

class _ScreenSplitterState extends State<ScreenSplitter> {
  // 将 _splitRatio 提取为类成员变量，确保它的状态在重建时得以保留
  double _splitRatio = 0.3;

  @override
  Widget build(BuildContext context) {
    // 如果 childB 为 null，直接返回带 Padding 和 SafeArea 的 childA，不包含拖拽逻辑
    if (widget.childB == null) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: widget.childA,
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxHeight = constraints.maxHeight;
            final maxWidth = constraints.maxWidth;
            final isLandscape = maxWidth > maxHeight;
            const maxSplit = 0.5;

            if (isLandscape) {
              // 横向布局
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 左侧：占剩余空间
                  Expanded(
                    child: widget.childA,
                  ),
                  // 拖拽把手（垂直条）
                  GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        _splitRatio -= details.delta.dx / maxWidth;
                        _splitRatio = _splitRatio.clamp(0.0, maxSplit);
                      });
                    },
                    onTap: () {
                      setState(() {
                        _splitRatio = _splitRatio < 0.15 ? 0.3 : 0.0;
                      });
                    },
                    child: Container(
                      width: 20,
                      color: Theme.of(context).colorScheme.surface,
                      child: const Center(
                        child: RotatedBox(
                          quarterTurns: 1,
                          child: Icon(Icons.drag_handle),
                        ),
                      ),
                    ),
                  ),
                  // 右侧：宽度根据比例
                  if (_splitRatio > 0)
                    SizedBox(
                      width: maxWidth * _splitRatio,
                      child: widget.childB!, // 使用 ! 强制解包，因为上面已经判空
                    ),
                ],
              );
            } else {
              // 纵向布局
              return Column(
                children: [
                  // 上部：高度根据比例
                  SizedBox(
                    height: maxHeight * _splitRatio,
                    child: widget.childB!,
                  ),
                  // 拖拽把手（水平条）
                  GestureDetector(
                    onVerticalDragUpdate: (details) {
                      setState(() {
                        _splitRatio += details.delta.dy / maxHeight;
                        _splitRatio = _splitRatio.clamp(0.0, maxSplit);
                      });
                    },
                    onTap: () {
                      setState(() {
                        _splitRatio = _splitRatio < 0.15 ? 0.3 : 0.0;
                      });
                    },
                    child: Container(
                      height: 20,
                      color: Theme.of(context).colorScheme.surface,
                      child: const Center(
                        child: Icon(Icons.drag_handle),
                      ),
                    ),
                  ),
                  // 下部：占剩余空间
                  Expanded(
                    child: widget.childA, // 使用 ! 强制解包
                  ),
                ],
              );
            }
          },
        ),
      ),
    );
  }
}