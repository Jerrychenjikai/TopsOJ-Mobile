import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:flutter_simple_calculator/flutter_simple_calculator.dart';

import 'package:TopsOJ/cached_problem_func.dart';
import 'package:TopsOJ/basic_func.dart';
import 'dart:io';
import "package:TopsOJ/login_page.dart";
import 'package:TopsOJ/ranking_animation.dart';
import 'package:TopsOJ/template.dart';

/// 题目详情数据模型 (Data Class)
class ProblemDetail {
  final String problemId;
  final String name;
  final String markdownData;
  final bool canNxt;
  final bool canPrev;
  final String nxt;
  final String prev;
  final bool isSolved;
  final bool isCached;

  ProblemDetail({
    required this.problemId,
    required this.name,
    required this.markdownData,
    required this.canNxt,
    required this.canPrev,
    required this.nxt,
    required this.prev,
    required this.isSolved,
    required this.isCached,
  });

  ProblemDetail copyWith({
    String? problemId,
    String? name,
    String? markdownData,
    bool? canNxt,
    bool? canPrev,
    String? nxt,
    String? prev,
    bool? isSolved,
    bool? isCached,
  }) {
    return ProblemDetail(
      problemId: problemId ?? this.problemId,
      name: name ?? this.name,
      markdownData: markdownData ?? this.markdownData,
      canNxt: canNxt ?? this.canNxt,
      canPrev: canPrev ?? this.canPrev,
      nxt: nxt ?? this.nxt,
      prev: prev ?? this.prev,
      isSolved: isSolved ?? this.isSolved,
      isCached: isCached ?? this.isCached,
    );
  }
}

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

// 题目页面
class ProblemPage extends StatefulWidget {
  final String problemId;
  final bool isEmbedded; // 是否作为嵌入组件（默认为false，表示独立页面）
  final Function(bool passed)? onSubmitResult; // 提交结果回调函数（passed表示是否正确）

  const ProblemPage({
    super.key,
    required this.problemId,
    this.isEmbedded = false,
    this.onSubmitResult,
  });

  @override
  State<ProblemPage> createState() => _ProblemPageState();
}

class _ProblemPageState extends State<ProblemPage> {
  final TextEditingController _controller = TextEditingController();

  // 封装后的题目详情模型
  ProblemDetail? _problemDetail;

  String _activated_tool = "none";
  double? _current_calculator_value = 0;

  List<Widget> _rendered = [];

  Widget? _buildTool() {
    if (_activated_tool == "calculator") {
      return Column(
        children: [
          Expanded(
            child: SimpleCalculator(
              value: _current_calculator_value ?? 0,
              hideExpression: false,
              hideSurroundingBorder: true,
              autofocus: true,
              onChanged: (key, value, expression) {
                setState(() {
                  _current_calculator_value = value; // 实时获取计算结果
                });
              },
            ),
          ),
        ],
      );
    } else {
      return null;
    }
  }

  Future<void> _loadProblemData() async {
    if (_problemDetail?.problemId == widget.problemId) return;

    bool isCached = await is_cached(widget.problemId);
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('apiKey') ?? "";
    var markdownUrl;
    var markdownResponse;
    var markdownJson;

    // fetch markdown
    try {
      markdownUrl = Uri.parse('https://topsoj.com/api/publicproblem?id=${widget.problemId}');
      markdownResponse = await http.get(markdownUrl);
      markdownJson = jsonDecode(markdownResponse.body);
    } catch (e) {
      if (await is_cached(widget.problemId)) {
        var cachedinfo = (await cached_info(widget.problemId));
        String markdownData = await readMarkdown(widget.problemId + '.md') ?? "Error: problem markdown not found. Delete this cached problem";
        String problemName = cachedinfo['name'] ?? "Error: Problem not cached";
        String nxt = cachedinfo['nxt'] ?? "";
        String prev = cachedinfo['prev'] ?? "";
        bool canNxt = ((!nxt.isEmpty) & (await is_cached(nxt))) ? true : false;
        bool canPrev = ((!prev.isEmpty) & (await is_cached(prev))) ? true : false;
        bool isSolved = cachedinfo['correct'] == 'true' ? true : false;

        _problemDetail = ProblemDetail(
          problemId: widget.problemId,
          name: problemName,
          markdownData: markdownData,
          canNxt: canNxt,
          canPrev: canPrev,
          nxt: nxt,
          prev: prev,
          isSolved: isSolved,
          isCached: true,
        );

        await _parseContent("[From local storage]\n" + markdownData);

        return;
      } else {
        _problemDetail = ProblemDetail(
          problemId: widget.problemId,
          name: "Network error",
          markdownData: "Network error",
          canNxt: false,
          canPrev: false,
          nxt: "",
          prev: "",
          isSolved: false,
          isCached: false,
        );
        return;
      }
    }

    if (markdownResponse.statusCode != 200) {
      _problemDetail = ProblemDetail(
        problemId: widget.problemId,
        name: "Error",
        markdownData: "Markdown load failed: ${markdownResponse.statusCode} ${markdownJson['message']}",
        canNxt: false,
        canPrev: false,
        nxt: "",
        prev: "",
        isSolved: false,
        isCached: isCached,
      );
      return;
    }

    // 设置组合好的 ProblemDetail 实例
    String markdownData = markdownJson['data']['description_md'] ?? '';
    String problemName = markdownJson['data']['problem_name'] ?? '';
    bool canNxt = markdownJson['data']['can_next'];
    bool canPrev = markdownJson['data']['can_prev'];
    String nxt = canNxt ? markdownJson['data']['nxt'].replaceFirst('/problem/', '') : "";
    String prev = canPrev ? markdownJson['data']['prev'].replaceFirst('/problem/', '') : "";
    bool isSolved = await checkSolved(widget.problemId);

    _problemDetail = ProblemDetail(
      problemId: widget.problemId,
      name: problemName,
      markdownData: markdownData,
      canNxt: canNxt,
      canPrev: canPrev,
      nxt: nxt,
      prev: prev,
      isSolved: isSolved,
      isCached: isCached,
    );

    await _parseContent(markdownData);
  }

  void _submit() async {
    final answer = _controller.text.trim();
    if (answer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Answer could not be empty")),
      );
      return;
    }

    bool isCached = _problemDetail?.isCached ?? await is_cached(widget.problemId);

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

      if (passed) {
        setState(() {
          _problemDetail = _problemDetail?.copyWith(isSolved: true);
        });
      }
    } else {
      // 在提交失败或离线记录时，调用回调并传递false
      if (widget.onSubmitResult != null) {
        widget.onSubmitResult!(false);
      }
    }
  }

  Future<void> _parseContent(String raw) async {
    final path = await localPath;
    // First, replace <br> with newline
    raw = raw.replaceAll('<br>', '\n');
    raw = raw.replaceAll('<center>', '');
    raw = raw.replaceAll('</center>', '\n');

    final widgets = <Widget>[];
    final imgRegex = RegExp(
      r'<img[^>]*src="([^"]+)"[^>]*?width="(\d+)(?:px)?"[^>]*?>',
      caseSensitive: false,
    ); // same as the one in cached_problem_func.dart

    int lastEnd = 0;
    int cnt = 0;
    for (final match in imgRegex.allMatches(raw)) {
      // Process text before image
      if (match.start > lastEnd) {
        widgets.addAll(_parseMarkdownWithLatex(raw.substring(lastEnd, match.start)));
      }
      // Add image widget
      final src = match.group(1)!;
      final final_src;

      final width = match.group(2) != null ? double.tryParse(match.group(2)!) : null;

      if (src[0] == '/')
        final_src = "https://topsoj.com" + src;
      else
        final_src = src;

      print(cnt);
      final filename = urlToFilename(widget.problemId, cnt);
      cnt += 1;
      final file = File("${path}/${filename}");

      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Image.file(
            file,
            width: width,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Image.network(
                final_src,
                width: width,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Text(
                    "--Failed to load image--",
                    style: TextStyle(color: Colors.red),
                  );
                },
              );
            },
          ),
        ),
      );
      lastEnd = match.end;
    }
    // Remaining content after last image
    if (lastEnd < raw.length) {
      widgets.addAll(_parseMarkdownWithLatex(raw.substring(lastEnd)));
    }
    _rendered = widgets;
    return;
  }

  List<Widget> _parseMarkdownWithLatex(String raw) {
    final widgets = <Widget>[];
    // Regex for block-level $$...$$ including newlines
    final regexBlock = RegExp(r'\$\$(.+?)\$\$', dotAll: true);
    int lastEnd = 0;

    for (final match in regexBlock.allMatches(raw)) {
      if (match.start > lastEnd) {
        final normalText = raw.substring(lastEnd, match.start);
        widgets.addAll(_processInlineMath(normalText));
      }

      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Math.tex(
              match.group(1)!,
              textStyle: TextStyle(color: widget.isEmbedded ? Colors.white : Colors.black87, fontSize: 24),
            ),
          ),
        ),
      );
      lastEnd = match.end;
    }
    if (lastEnd < raw.length) {
      widgets.addAll(_processInlineMath(raw.substring(lastEnd)));
    }
    return widgets;
  }

  List<Widget> _processInlineMath(String text) {
    var embedded = widget.isEmbedded;
    final widgets = <Widget>[];
    // Support inline math with newlines via dotAll
    final regexInline = RegExp(r'\$(.+?)\$', dotAll: true);

    final spans = <InlineSpan>[];
    int lastEnd = 0;
    for (final match in regexInline.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: TextStyle(color: embedded ? Colors.white : Colors.black87, fontSize: 20),
        ));
      }
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Math.tex(
            match.group(1)!.trim(),
            textStyle: TextStyle(color: embedded ? Colors.white : Colors.black87, fontSize: 20),
          ),
        ),
      ));
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: TextStyle(color: widget.isEmbedded ? Colors.white : Colors.black87, fontSize: 20),
      ));
    }
    widgets.add(
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: RichText(text: TextSpan(children: spans)),
      ),
    );
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _loadProblemData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done && _problemDetail?.problemId != widget.problemId) {
          return widget.isEmbedded
              ? const Center(child: CircularProgressIndicator()) // 嵌入时只显示加载指示器
              : Scaffold(
                  appBar: AppBar(title: const Text("Loading...")),
                  body: const Center(child: CircularProgressIndicator()),
                );
        }

        final problemName = _problemDetail?.name ?? "";
        final isSolved = _problemDetail?.isSolved ?? false;
        final canPrev = _problemDetail?.canPrev ?? false;
        final canNxt = _problemDetail?.canNxt ?? false;
        final prev = _problemDetail?.prev ?? "";
        final nxt = _problemDetail?.nxt ?? "";

        // Use _parseContent to build the content
        final content = ListView(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          children: _rendered,
        );

        final submitSection = Container(
          padding: const EdgeInsets.all(16),
          child: Row(
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
          ),
        );

        // 构建主体内容（不包含Scaffold/AppBar的部分）
        final bodyContent = Column(
          children: [
            Expanded(child: content),
            if ((canPrev || canNxt) && !widget.isEmbedded)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (canPrev)
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => ProblemPage(problemId: prev),
                            ),
                          );
                        },
                        icon: const Icon(Icons.arrow_back),
                        label: const Text("Previous"),
                      ),
                    if (canNxt)
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => ProblemPage(problemId: nxt),
                            ),
                          );
                        },
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text("Next"),
                      ),
                  ],
                ),
              ),
            if (widget.isEmbedded) submitSection,
          ],
        );

        var splitBodyContent = ScreenSplitter(childA: bodyContent, childB: _buildTool());

        // 根据isEmbedded决定是否包裹Scaffold和AppBar
        if (widget.isEmbedded) {
          return bodyContent; // 嵌入时直接返回主体内容
        } else {
          return WillPopScope(
            onWillPop: () async {
              Navigator.pop(context, true); // 手动传回是否需要刷新
              return false; // 阻止默认返回行为（因为我们手动pop了）
            },
            child: Scaffold(
              appBar: AppBar(
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        problemName,
                        style: const TextStyle(fontSize: 22),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSolved)
                      const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(Icons.check, color: Colors.green, size: 24),
                      ),
                  ],
                ),
              ),
              body: splitBodyContent,
              bottomNavigationBar: submitSection,
              floatingActionButton: SpeedDial(
                child: const Icon(Icons.keyboard_arrow_up),
                closeManually: false,
                activeChild: const Icon(Icons.close),
                direction: SpeedDialDirection.up,
                animationCurve: Curves.easeInOutCubic,
                overlayColor: Theme.of(context).colorScheme.secondary,
                overlayOpacity: 0.4,
                spacing: 8,
                spaceBetweenChildren: 12,
                children: [
                  SpeedDialChild(
                    child: const Icon(Icons.save),
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
                    foregroundColor: Colors.black,
                    label: 'Cache this problem',
                    onTap: () async {
                      if (_problemDetail != null) {
                        await cache(
                          widget.problemId,
                          _problemDetail!.name,
                          _problemDetail!.markdownData,
                          _problemDetail!.nxt,
                          _problemDetail!.prev,
                        );
                        setState(() {
                          _problemDetail = _problemDetail!.copyWith(isCached: true);
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Problem Cached')),
                        );
                      }
                    },
                  ),
                  SpeedDialChild(
                    child: const Icon(Icons.calculate),
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
                    foregroundColor: Colors.black,
                    label: 'Calculator',
                    onTap: () {
                      setState(() {
                        _activated_tool = "calculator";
                      });
                    },
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
  }
}