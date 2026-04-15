import 'package:flutter/material.dart';

/// 显示排行榜变化动画的 Dialog
/// - 先显示旧榜（a）
/// - 点击“开始动画”后：
///   - 已有元素**平滑移动**到新位置
///   - 新增元素**淡入**
///   - 移除元素**淡出**
void showRankingChangeDialog(
  BuildContext context, {
  required List<String> oldRank, // 旧榜 a
  required List<String> newRank, // 新榜 b
  required int offset, //number of members above the two leaderboards and not included
  String? focus, //this is the member that is going to be highlighted
}) {
  showDialog(
    context: context,
    builder: (context) => RankingChangeDialog(
      oldRank: oldRank,
      newRank: newRank,
      offset: offset,
      focus: focus ?? '',
    ),
  );
}

class RankingChangeDialog extends StatefulWidget {
  final List<String> oldRank;
  final List<String> newRank;
  final int offset;
  final String focus;

  const RankingChangeDialog({
    super.key,
    required this.oldRank,
    required this.newRank,
    required this.offset,
    required this.focus,
  });

  @override
  State<RankingChangeDialog> createState() => _RankingChangeDialogState();
}

class _RankingChangeDialogState extends State<RankingChangeDialog>
    with TickerProviderStateMixin {
  late final AnimationController _controller;

  // 每个元素的动画（只在 initState 创建一次，避免 build 时重复创建）
  late final Map<String, Animation<double>> _yAnimations;
  late final Map<String, Animation<double>> _opacityAnimations;

  // 所有唯一元素（用于同时处理新增/移除/移动）
  late final List<String> _uniqueItems;

  // 旧榜 / 新榜 的索引位置（用于计算起始和结束位置）
  late final Map<String, int> _oldPositions;
  late final Map<String, int> _newPositions;

  // 每一行的高度（固定值，保证 Positioned 动画精确）
  static const double _itemHeight = 50.0;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // 计算旧榜位置
    _oldPositions = {};
    for (int i = 0; i < widget.oldRank.length; i++) {
      _oldPositions[widget.oldRank[i]] = i;
    }

    // 计算新榜位置
    _newPositions = {};
    for (int i = 0; i < widget.newRank.length; i++) {
      _newPositions[widget.newRank[i]] = i;
    }

    // 所有唯一元素（保留出现顺序：旧榜 → 新增）
    final allItems = <String>{...widget.oldRank, ...widget.newRank};
    _uniqueItems = allItems.toList();

    // 为每个元素创建动画 Tween（只创建一次）
    _yAnimations = {};
    _opacityAnimations = {};

    for (final item in _uniqueItems) {
      final oldIdx = _oldPositions[item];
      final newIdx = _newPositions[item];

      final inOld = oldIdx != null;
      final inNew = newIdx != null;

      // 起始 Y（旧位置或新位置）
      final startY = inOld
          ? oldIdx! * _itemHeight
          : newIdx! * _itemHeight;

      // 结束 Y（新位置或旧位置）
      final endY = inNew
          ? newIdx! * _itemHeight
          : oldIdx! * _itemHeight;

      // 起始透明度
      final startOpacity = inOld ? 1.0 : 0.0;
      // 结束透明度
      final endOpacity = inNew ? 1.0 : 0.0;

      _yAnimations[item] = Tween<double>(begin: startY, end: endY).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Curves.easeInOutCubic,
        ),
      );

      _opacityAnimations[item] = Tween<double>(
        begin: startOpacity,
        end: endOpacity,
      ).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Curves.easeInOutCubic,
        ),
      );
    }

    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 构建每一行排行项（固定高度，带排名和升降箭头）
  Widget _buildRankItem(String item) {
    final oldIdx = _oldPositions[item];
    final newIdx = _newPositions[item];

    // 显示的目标排名（优先新榜）
    final displayRank = (newIdx ?? oldIdx ?? 0) + 1 + widget.offset;

    // 升降箭头（仅当位置发生变化时显示）
    Widget? changeIcon;
    if (oldIdx != null && newIdx != null && oldIdx != newIdx) {
      changeIcon = newIdx < oldIdx
          ? const Icon(Icons.arrow_upward, color: Colors.green, size: 22)
          : const Icon(Icons.arrow_downward, color: Colors.red, size: 22);
    }

    // 使用 Container 完全模仿 ListTile 的形状和风格（无边框、无填充色）
    // - leading：排名圆圈
    // - title：username（a 和 b 中的值，即 item）
    // - trailing：升降箭头（保持原有功能）
    return Container(
      height: _itemHeight,
      decoration: BoxDecoration(
        color: widget.focus == item
          ? Theme.of(context).colorScheme.surfaceContainerLow
          : Colors.transparent,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          children: [
            // leading（排名圆圈）
            Text(
              '$displayRank',
              style: TextStyle(
                color: displayRank == 1
                    ? Colors.amber
                    : displayRank == 2
                        ? Colors.grey
                        : displayRank == 3
                            ? Colors.brown
                            : Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(width: 16),
            // title
            Expanded(
              child: Text(
                item,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            // trailing（保持原有升降箭头功能）
            if (changeIcon != null)
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: changeIcon,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 计算所需的最大高度（取新旧榜中较长的那一个）
    final maxLen = widget.oldRank.length > widget.newRank.length
        ? widget.oldRank.length
        : widget.newRank.length;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题
            Text(
              'Your rank changed!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Maintain the effort to climb the ranks!',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 24),

            // 动画区域（支持滚动，防止过长溢出）
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.65, // 最多占屏幕 65% 高度，可自行调整
              ),
              child: SingleChildScrollView(
                child: Container(
                  // 保持原始高度（动画需要精确的绝对定位）
                  height: maxLen * _itemHeight + 1,
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: _uniqueItems.map((item) {
                      return AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          return Positioned(
                            left: 0,
                            right: 0,
                            top: _yAnimations[item]!.value,
                            child: Opacity(
                              opacity: _opacityAnimations[item]!.value,
                              child: _buildRankItem(item),
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}