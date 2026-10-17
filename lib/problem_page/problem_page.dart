
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:flutter_simple_calculator/flutter_simple_calculator.dart';

import 'package:TopsOJ/cached_problem_func.dart';
import 'package:TopsOJ/basic_func.dart';
import 'package:TopsOJ/template.dart';
import 'package:TopsOJ/problem_page/problem_render.dart';
import 'package:TopsOJ/problem_page/problem_submit.dart';

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

// 题目页面。只接受 problemId。内容渲染和提交栏分别来自 problem_render / problem_submit。
class ProblemPage extends StatefulWidget {
  final String problemId;

  const ProblemPage({
    super.key,
    required this.problemId,
  });

  @override
  State<ProblemPage> createState() => _ProblemPageState();
}

class _ProblemPageState extends State<ProblemPage> {
  // 封装后的题目详情模型
  ProblemDetail? _problemDetail;

  String _activated_tool = "none";
  double? _current_calculator_value = 0;

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
        bool canNxt = ((!nxt.isEmpty) && (await is_cached(nxt))) ? true : false;
        bool canPrev = ((!prev.isEmpty) && (await is_cached(prev))) ? true : false;
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
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _loadProblemData(),
      builder: (context, snapshot) {
        final ready = _problemDetail?.problemId == widget.problemId;
        final problemName = ready ? _problemDetail!.name : "Loading...";
        final isSolved = _problemDetail?.isSolved ?? false;
        final canPrev = ready && (_problemDetail?.canPrev ?? false);
        final canNxt = ready && (_problemDetail?.canNxt ?? false);
        final prev = _problemDetail?.prev ?? "";
        final nxt = _problemDetail?.nxt ?? "";

        // 题目正文由 problem_render 负责；这里只保留原来 ListView 的外边距
        final bodyContent = Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                child: problemRender(widget.problemId),
              ),
            ),
            if (canPrev || canNxt)
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
          ],
        );

        var splitBodyContent = ScreenSplitter(childA: bodyContent, childB: _buildTool());

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
            bottomNavigationBar: Container(
              padding: const EdgeInsets.all(16),
              child: problemSubmit(
                widget.problemId,
                onSubmitResult: (passed) {
                  if (passed) {
                    setState(() {
                      _problemDetail = _problemDetail?.copyWith(isSolved: true);
                    });
                  }
                },
              ),
            ),
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
      },
    );
  }
}