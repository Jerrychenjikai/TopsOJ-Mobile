import 'package:flutter/material.dart';

import 'package:TopsOJ/problem_page/problem_page.dart';

/// 主壳层交给「从主界面点开题目」用的入口。
///
/// 主界面和题目列表在 [MainSplitScope] 下面，[openProblem] 会进壳层：
/// 宽屏放右栏，窄屏盖住主界面。
/// 其它页面（缓存题、年度报告、对战等）不在这个 scope 里，
/// 找不到时退回普通的全屏 [Navigator.push]。
class MainSplitScope extends InheritedWidget {
  final void Function(String problemId) onOpenProblem;

  const MainSplitScope({
    super.key,
    required this.onOpenProblem,
    required super.child,
  });

  static void openProblem(BuildContext context, String problemId) {
    final scope = _maybeOf(context);
    if (scope != null) {
      scope.onOpenProblem(problemId);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProblemPage(problemId: problemId),
      ),
    );
  }

  static MainSplitScope? _maybeOf(BuildContext context) {
    final element =
        context.getElementForInheritedWidgetOfExactType<MainSplitScope>();
    final widget = element?.widget;
    return widget is MainSplitScope ? widget : null;
  }

  @override
  bool updateShouldNotify(MainSplitScope oldWidget) => false;
}
