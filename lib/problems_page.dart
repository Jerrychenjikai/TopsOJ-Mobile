import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:TopsOJ/index_providers.dart';
import 'package:TopsOJ/basic_func.dart';
import 'package:TopsOJ/problem_page/problem_page.dart';
import 'package:TopsOJ/login_page.dart';
import 'package:TopsOJ/basic/ui_basic.dart';
import 'package:TopsOJ/template.dart';

class Problems extends ConsumerStatefulWidget {
  const Problems({super.key});

  @override
  _ProblemsState createState() => _ProblemsState();
}

class _ProblemsState extends ConsumerState<Problems> {
  RangeValues _pointRange = const RangeValues(1, 10);
  final TextEditingController _problemIdController = TextEditingController();
  int _page = 1;
  int _problems_cnt = 3;
  int _solved = 1; //0 - only fetch unsolved problems, 1 - no restrictions, 2 - only solved problems

  List<dynamic> _problem_ids = [
    {'id': "02_amc10A_p01", 'name': '2002 AMC 10A problem 1'},
    {'id': "03_amc12A_p01", 'name': '2003 AMC 12A problem 1'},
    {'id': "04_amc12A_p02", 'name': '2004 AMC 12A problem 2'},
  ]; //changed by the _getProblems function

  // 题目列表背景，给筛选面板和翻页胶囊做液态玻璃折射。
  final GlobalKey _problemsListKey = GlobalKey();
  

  Future<void> _getProblems() async {
    List<String> solvelist = ['false', 'none', 'true'];
    if(solvelist[_solved] != "none" && (await checkLogin())==null){
      final success = await popLogin(context);
      if (success != true) {
        setState((){_solved = 1;});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You need to log in to filter by solved')),
        );
        return;
      }
    }

    final jsonData = await fetchFilterProblems(
      _problemIdController.text.trim(),
      solvelist[_solved],
      '${_page}',
      '${_pointRange.end.round()}',
      '${_pointRange.start.round()}',
    );

    if (jsonData['statusCode'] == 200) {
      setState(() {
        _problem_ids = jsonData['data']['problems'];
        _problems_cnt = jsonData['data']['length'][0]['cnt'];
      });
      return;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Search Error: ${jsonData['statusCode']} ${jsonData['message']}'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
  }

  void _gotoProblem([String? id]) {
    final String problemId = (id ?? "");
    print("problem id:" + problemId);
    if (problemId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a problem ID')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProblemPage(problemId: problemId),
      ),
    );
  }

  List<Widget> _render() {
    List<Widget> widgets = [];
    for (Map<String, dynamic> problem in _problem_ids) {
      widgets.add(
        ListTile(
          title: Text(problem['name']),
          subtitle: Text(problem['id']),
          leading: problem['solved'] == 1
              ? Icon(Icons.check, color: Colors.green, size: 24)
              : (problem['solved'] == 0
                  ? Icon(Icons.clear, color: Colors.red, size: 24)
                  : Icon(Icons.book)),
          onTap: () {
            _gotoProblem(problem['id']);
          },
        ),
      );
    }
    return widgets;
  }

  Widget _buildFilter() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            children: [
              const Text("Filter by solved: "),
              Expanded(
                child: DropdownButton<int>(
                  value: _solved, // 当前选中值 (0,1,2)
                  isExpanded: true, // 让下拉菜单占满宽度
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  underline: Container(
                    height: 2,
                    color: Theme.of(context).primaryColor,
                  ),
                  items: const [
                    DropdownMenuItem<int>(
                      value: 0,
                      child: Text('Incorrect'),
                    ),
                    DropdownMenuItem<int>(
                      value: 1,
                      child: Text('All'),
                    ),
                    DropdownMenuItem<int>(
                      value: 2,
                      child: Text('Correct'),
                    ),
                  ],
                  onChanged: (int? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _solved = newValue;
                        _page = 1;
                        _getProblems();
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(children: [
            const Text("Filter by points: "),
            Expanded(child: 
              RangeSlider(
                min: 1,
                max: 10,
                divisions: 9,               // 可选：分成多少段（整数步长）
                labels: RangeLabels(
                  _pointRange.start.round().toString(),
                  _pointRange.end.round().toString(),
                ),
                values: _pointRange,
                onChanged: (RangeValues values) {
                  setState(() {
                    _pointRange = values;
                    _page = 1;
                    _getProblems();
                  });
                },
              ),
            ),
          ],),
          const SizedBox(height: 10),
          TextField(
            controller: _problemIdController,
            decoration: const InputDecoration(
              labelText: 'Enter Problem Name/ID',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (value) {
              _page = 1;
              _getProblems();
            },
          ),
        ],
      ),
    );
  }

  /// 翻页按钮跟 ranking page 的胶囊一致：左右 IconButton，中间页码。
  Widget _buildPageSwitcher() {
    final int totalPages = (_problems_cnt / 10).ceil();
    return LiquidGlassContainer(
      height: 52,
      borderRadius: 26,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            if (_page > 1)
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _page = _page - 1;
                    _getProblems();
                  });
                },
              )
            else
              const SizedBox(width: 48),
            const Spacer(),
            Text(
              'Page $_page/$totalPages',
              style: const TextStyle(fontSize: 16),
            ),
            const Spacer(),
            if (_page * 10 < _problems_cnt)
              IconButton(
                icon: const Icon(Icons.arrow_forward),
                onPressed: () {
                  setState(() {
                    _page = _page + 1;
                    _getProblems();
                  });
                },
              )
            else
              const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(
      mainPageProvider.select((state) => state.search),
      (prev, next) {
        if (next == null) return;

        if (_problemIdController.text != next) {
          _problemIdController.text = next;
          _problemIdController.selection = TextSelection.fromPosition(
            TextPosition(offset: next.length),
          );

          _getProblems();
        }

        ref.read(mainPageProvider.notifier).update(
          (state) => state.copyWith(search: null),
        );
      },
    );

    final double topSafe = MediaQuery.paddingOf(context).top;
    final double safeBottom = MediaQuery.paddingOf(context).bottom;
    final double bottomInset = safeBottom < 12 ? 12 : safeBottom;
    // MainPage 底部导航：top 4 + 高度 64 + 底部安全区，再留一点缝。
    final double aboveNav = 4 + bottomInset + 8;
    // 悬浮顶栏占 status bar 以下 60（见 main.dart 的 liquid app bar）。
    const double capsuleHeight = 52;
    final double capsuleTop = topSafe + 8;
    final double screenHeight = MediaQuery.sizeOf(context).height;

    return LiquidGlassScope(
      repaintBoundaryKey: _problemsListKey,
      child: Builder(
        builder: (glassContext) {
          return Stack(
            children: [
              NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollUpdateNotification) {
                    // 内层 scope 管筛选/翻页玻璃，外层 scope 管主界面顶栏和底栏。
                    LiquidGlassScope.notifyUpdate(glassContext);
                    LiquidGlassScope.notifyUpdate(context);
                  }
                  return false;
                },
                child: RepaintBoundary(
                  key: _problemsListKey,
                  child: ListView(
                    // 列表本身铺满屏幕；padding 只是让首尾能滚出顶栏、翻页胶囊和底部筛选。
                    padding: EdgeInsets.only(
                      top: capsuleTop + capsuleHeight + 12,
                      bottom: aboveNav + screenHeight * 0.3 + 48,
                    ),
                    children: _render(),
                  ),
                ),
              ),
              Positioned(
                top: capsuleTop,
                left: 16,
                right: 16,
                child: _buildPageSwitcher(),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: aboveNav,
                child: StretchableLiquidGlass(
                  defaultSplit: 0.3,
                  maxSplit: 0.5,
                  child: _buildFilter(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}