import 'package:flutter/material.dart';

import 'package:TopsOJ/cached_problem_func.dart';
import 'package:TopsOJ/basic_func.dart';
import 'package:TopsOJ/ranking_animation.dart';

/// 提交结果提示弹窗（带有出现动画）
class SubmissionResultDialog extends StatefulWidget {
  final Map<String, dynamic> response;

  const SubmissionResultDialog({super.key, required this.response});

  @override
  State<SubmissionResultDialog> createState() => _SubmissionResultDialogState();
}

class _SubmissionResultDialogState extends State<SubmissionResultDialog> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    // 图标弹簧放大效果
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );

    // 文字延迟渐变显示
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusCode = widget.response['statusCode'];
    final data = widget.response['data'];

    Widget mainIcon;
    Widget detailText = const SizedBox.shrink();

    if (statusCode == 200) {
      final bool check = data is Map ? (data['check'] ?? false) : false;
      if (check) {
        mainIcon = const Icon(Icons.check_circle, color: Colors.green, size: 90);
        detailText = Column(
          children: [
            if (data['points_awarded'] != null)
              Text(
                '+${data['points_awarded']} Points',
                style: const TextStyle(color: Colors.green, fontSize: 16, fontWeight: FontWeight.w600),
              ),
            const SizedBox(height: 4),
            if (data['new_streak'] != null)
              Text(
                'Streak: ${data['new_streak']}',
                style: const TextStyle(color: Colors.green, fontSize: 14),
              ),
          ],
        );
      } else {
        mainIcon = const Icon(Icons.cancel, color: Colors.red, size: 90);
      }
    } else {
      mainIcon = Text(
        '$statusCode',
        style: const TextStyle(color: Colors.red, fontSize: 50, fontWeight: FontWeight.bold),
      );
      detailText = Text(
        '${data ?? "Unknown Error"}',
        style: const TextStyle(color: Colors.red, fontSize: 14),
        textAlign: TextAlign.center,
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 10,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _scaleAnimation,
              child: mainIcon,
            ),
            if (statusCode != 200 || (statusCode == 200 && data is Map && data['check'] == true))
              const SizedBox(height: 20),
            FadeTransition(
              opacity: _fadeAnimation,
              child: detailText,
            ),
          ],
        ),
      ),
    );
  }
}

/// 提交栏。接受 problemId 和 onSubmitResult，返回一个 Row：剩余宽度是输入框，右边是提交按钮。
Widget problemSubmit(String problemId, {Function(bool passed)? onSubmitResult}) {
  return _ProblemSubmit(
    problemId: problemId,
    onSubmitResult: onSubmitResult,
  );
}

class _ProblemSubmit extends StatefulWidget {
  final String problemId;
  final Function(bool passed)? onSubmitResult;

  const _ProblemSubmit({
    required this.problemId,
    this.onSubmitResult,
  });

  @override
  State<_ProblemSubmit> createState() => _ProblemSubmitState();
}

class _ProblemSubmitState extends State<_ProblemSubmit> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() async {
    final answer = _controller.text.trim();
    if (answer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Answer could not be empty")),
      );
      return;
    }

    bool isCached = await is_cached(widget.problemId);

    var response = await submitAndRankingAnimation(
      context,
      'total points',
      !isCached, // 如果已经缓存，则不一定需要登陆
      (apiKey) async {
        var res = await submitProblem(widget.problemId, answer);

        if (res['statusCode'] == -1) {
          if (await is_cached(widget.problemId)) {
            await record(widget.problemId, 'answer', answer);
            res = {'statusCode': -2, 'data': 'You are offline. Answer recorded in cache'};
          }
        }
        if (res['statusCode'] == 401) {
          res['data'] = "Login expired. Please log in again";
        }

        // 直接在 submitAndRankingAnimation 回调内弹出提交状态对话框
        // 以保证其挂载顺序先于 Ranking Change 对话框
        if (mounted) {
          await showDialog(
            context: context,
            barrierDismissible: true,
            builder: (context) => SubmissionResultDialog(response: res),
          );
        }

        return res;
      },
    );

    if (response['statusCode'] == 200) {
      _controller.clear();
      final passed = response['data']['check'] as bool;
      if (passed) {
        await record(widget.problemId, 'correct', '${true}');
      }

      // 调用外部传入的回调函数（如果存在）
      if (widget.onSubmitResult != null) {
        widget.onSubmitResult!(passed);
      }
    } else {
      // 在提交失败或离线记录时，调用回调并传递false
      if (widget.onSubmitResult != null) {
        widget.onSubmitResult!(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            decoration: const InputDecoration(
              hintText: 'Answer',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onSubmitted: (value) {
              _submit();
            },
          ),
        ),
        const SizedBox(width: 10),
        FloatingActionButton(
          onPressed: _submit,
          tooltip: 'Submit',
          mini: true,
          child: const Icon(Icons.send),
        ),
      ],
    );
  }
}
