import 'package:flutter/material.dart';
import 'dart:convert';

import 'package:TopsOJ/basic_func.dart';
import 'package:TopsOJ/login_page.dart';

Future<void> submitAndRankingAnimation(BuildContext context, String leaderboard_type, Future<void> Function(String) callback) async {
  // 尝试拿到当前登录信息（与示例一致）
  var s = await checkLogin();
  if (s == null) {
    // 如果未登录，弹出登录（popLogin 返回 true 表示登录成功）
    final success = await popLogin(context);
    if (success != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not logged in, score not submitted')),
      );
      return;
    }
    // 再次获取登录信息
    s = await checkLogin();
  }

  var response = await fetchRanking(0, leaderboard_type, username: s['userdata']['username']);
  List<dynamic> _leaderboard_init = json.decode(response.body)['data']['users'];
  int _initial_rank = -1;
  int _initial_offset = _leaderboard_init[0]['ranking'] - 1;

  for(int i=0; i<_leaderboard_init.length; i++){
    if(_leaderboard_init[i]['username'] == s['userdata']['username']) 
      _initial_rank = _leaderboard_init[i]['ranking'];
    _leaderboard_init[i] = _leaderboard_init[i]['username'];
  }

  await callback(s['apikey']);

  response = await fetchRanking(0, leaderboard_type, username: s['userdata']['username']);
  List<dynamic> _leaderboard_after = json.decode(response.body)['data']['users'];
  int _after_rank = -1;
  int _after_offset = _leaderboard_after[0]['ranking'] - 1;

  for(int i=0; i<_leaderboard_after.length; i++){
    if(_leaderboard_after[i]['username'] == s['userdata']['username']) 
      _after_rank = _leaderboard_after[i]['ranking'];
    _leaderboard_after[i] = _leaderboard_after[i]['username'];
  }

  if((_initial_rank != _after_rank && _after_rank != -1 && _initial_rank != -1)){
    showRankingChangeDialog(
      context,
      oldRank: _leaderboard_init.cast<String>(),
      newRank: _leaderboard_after.cast<String>(),
      offsetA: _initial_offset,
      offsetB: _after_offset,
      focus: s['userdata']['username'],
    );
  }
}

/// 显示排行榜变化动画的 Dialog（支持旧榜/新榜各自独立的 offset + 排名数字动效）
/// - 两个 offset 独立，显示区域始终顶部对齐
/// - 已有元素（两榜都有）：位置平滑移动 + 排名数字**连续变化**（从 offsetA+indexA → offsetB+indexB）
/// - 仅旧榜元素：位置按 offset 差异滑出 + 排名数字保持旧值（淡出）
/// - 仅新榜元素：位置按 offset 差异滑入 + 排名数字保持新值（淡入）
/// - 排名数字颜色会随当前数值实时变化（1金、2银、3铜）
void showRankingChangeDialog(
  BuildContext context, {
  required List<String> oldRank, // 旧榜 a
  required List<String> newRank, // 新榜 b
  required int offsetA, // 旧榜 offset
  required int offsetB, // 新榜 offset
  String? focus, // 要高亮的成员
}) {
  showDialog(
    context: context,
    builder: (context) => RankingChangeDialog(
      oldRank: oldRank,
      newRank: newRank,
      offsetA: offsetA,
      offsetB: offsetB,
      focus: focus ?? '',
    ),
  );
}

class RankingChangeDialog extends StatefulWidget {
  final List<String> oldRank;
  final List<String> newRank;
  final int offsetA;
  final int offsetB;
  final String focus;

  const RankingChangeDialog({
    super.key,
    required this.oldRank,
    required this.newRank,
    required this.offsetA,
    required this.offsetB,
    required this.focus,
  });

  @override
  State<RankingChangeDialog> createState() => _RankingChangeDialogState();
}

class _RankingChangeDialogState extends State<RankingChangeDialog>
    with TickerProviderStateMixin {
  late final AnimationController _controller;

  // 每个元素的动画（只在 initState 创建一次）
  late final Map<String, Animation<double>> _yAnimations;
  late final Map<String, Animation<double>> _opacityAnimations;
  late final Map<String, Animation<double>> _rankAnimations; // 排名数字动效

  // 所有唯一元素
  late final List<String> _uniqueItems;

  // 旧榜 / 新榜 的可见索引位置（0-based）
  late final Map<String, int> _oldPositions;
  late final Map<String, int> _newPositions;

  // 最大可见行数（用于 off-screen 动画）
  late final int _maxVisibleItems;

  static const double _itemHeight = 50.0;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // 计算位置映射
    _oldPositions = {};
    for (int i = 0; i < widget.oldRank.length; i++) {
      _oldPositions[widget.oldRank[i]] = i;
    }

    _newPositions = {};
    for (int i = 0; i < widget.newRank.length; i++) {
      _newPositions[widget.newRank[i]] = i;
    }

    final allItems = <String>{...widget.oldRank, ...widget.newRank};
    _uniqueItems = allItems.toList();

    _maxVisibleItems = widget.oldRank.length > widget.newRank.length
        ? widget.oldRank.length
        : widget.newRank.length;

    // 创建三种动画
    _yAnimations = {};
    _opacityAnimations = {};
    _rankAnimations = {};

    for (final item in _uniqueItems) {
      final oldIdx = _oldPositions[item];
      final newIdx = _newPositions[item];
      final inOld = oldIdx != null;
      final inNew = newIdx != null;

      // 1. Y 位置动画（保持原有逻辑）
      double startY;
      double endY;
      if (inOld && inNew) {
        startY = oldIdx * _itemHeight;
        endY = newIdx * _itemHeight;
      } else if (inOld) {
        startY = oldIdx * _itemHeight;
        if (widget.offsetA < widget.offsetB) {
          endY = -_itemHeight;
        } else if (widget.offsetA > widget.offsetB) {
          endY = _maxVisibleItems * _itemHeight;
        } else {
          endY = startY;
        }
      } else if (inNew) {
        endY = newIdx * _itemHeight;
        if (widget.offsetA < widget.offsetB) {
          startY = _maxVisibleItems * _itemHeight;
        } else if (widget.offsetA > widget.offsetB) {
          startY = -_itemHeight;
        } else {
          startY = endY;
        }
      } else {
        continue;
      }

      _yAnimations[item] = Tween<double>(begin: startY, end: endY).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
      );

      // 2. 透明度动画（保持原有）
      _opacityAnimations[item] = Tween<double>(
        begin: inOld ? 1.0 : 0.0,
        end: inNew ? 1.0 : 0.0,
      ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
      );

      // 3. 排名数字连续变化动画
      final oldRankNum = inOld ? widget.offsetA + oldIdx + 1 : null;
      final newRankNum = inNew ? widget.offsetB + newIdx + 1 : null;

      final startRank = (oldRankNum ?? newRankNum ?? 1).toDouble();
      final endRank = (newRankNum ?? oldRankNum ?? 1).toDouble();

      _rankAnimations[item] = Tween<double>(begin: startRank, end: endRank).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
      );
    }

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 构建每一行（排名数字现在由外部传入当前动画值）
  Widget _buildRankItem(String item, int displayRank) {
    final oldIdx = _oldPositions[item];
    final newIdx = _newPositions[item];

    // 升降箭头（仅当位置真的变化时显示）
    Widget? changeIcon;
    if (oldIdx != null && newIdx != null && oldIdx + widget.offsetA != newIdx + widget.offsetB) {
      changeIcon = newIdx + widget.offsetB  < oldIdx + widget.offsetA
          ? const Icon(Icons.arrow_upward, color: Colors.green, size: 22)
          : const Icon(Icons.arrow_downward, color: Colors.red, size: 22);
    }

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
            // leading：带动效的排名数字
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
            // trailing
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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

            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.65,
              ),
              child: SingleChildScrollView(
                child: Container(
                  height: _maxVisibleItems * _itemHeight + 1,
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
                          final currentRank = _rankAnimations[item]!.value.round();

                          return Positioned(
                            left: 0,
                            right: 0,
                            top: _yAnimations[item]!.value,
                            child: Opacity(
                              opacity: _opacityAnimations[item]!.value,
                              child: _buildRankItem(item, currentRank),
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