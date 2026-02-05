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
import 'package:TopsOJ/problem_page.dart';

class Problems extends ConsumerStatefulWidget {
  const Problems({super.key});

  @override
  _ProblemsState createState() => _ProblemsState();
}

class _ProblemsState extends ConsumerState<Problems> {
  double _splitRatio = 0.3;
  final TextEditingController _problemIdController = TextEditingController();
  int _page = 1;
  int _problems_cnt = 3;
  double _solved = 1; //0 - only fetch unsolved problems, 1 - no restrictions, 2 - only solved problems

  List<dynamic> _problem_ids = [
    {'id': "02_amc10A_p01", 'name': '2002 AMC 10A problem 1'},
    {'id': "03_amc12A_p01", 'name': '2003 AMC 12A problem 1'},
    {'id': "04_amc12A_p02", 'name': '2004 AMC 12A problem 2'},
  ]; //changed by the _getProblems function

  Future<void> _getProblems() async {
    var url = Uri.parse('https://topsoj.com/api/problems');
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('apiKey');
    List<String> solvelist = ['false', 'none', 'true'];
    if (apiKey == null || apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("API Key Not Found. Log In Again")),
      );
      return;
    }
    var headers = {'Authorization': 'Bearer $apiKey'};
    var response = await http.post(url, headers: headers, body: {
      'page': '${_page}',
      'title': _problemIdController.text.trim(),
      'solved': solvelist[_solved.toInt()],
    });
    final jsonData = jsonDecode(response.body);
    if (response.statusCode == 200) {
      setState(() {
        //jsonData['data']['solved']=['nt1'];
        _problem_ids = jsonData['data']['problems'];
        _problems_cnt = jsonData['data']['length'][0]['cnt'];
      });
      return;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Search Error: ${response.statusCode} ${jsonData['message']}')),
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

  @override
  Widget build(BuildContext context) {
    final search = ref.watch(
      mainPageProvider.select((state) => state.search),
    );

    if (_problemIdController.text != (search ?? '') && search != null) {
      _problemIdController.text = search ?? '';
      _problemIdController.selection = TextSelection.fromPosition(
        TextPosition(offset: _problemIdController.text.length),
      );
      setState((){
        _getProblems();
      });
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
            Widget buildFilter() {
              return Card(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          const Text("Filter by solved: "),
                          Expanded(
                            child: DropdownButton<int>(
                              value: _solved.toInt(), // 当前选中值 (0,1,2)
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
                                    _solved = newValue.toDouble(); // 保持 _solved 是 double 类型
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
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
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
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              _page = 1;
                              _getProblems();
                            },
                            child: const Icon(Icons.search),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }

            Widget buildList() {
              return Card(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (_page > 1)
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _page = _page - 1;
                                  _getProblems();
                                });
                              },
                              child: const Icon(Icons.arrow_back),
                            )
                          else
                            const SizedBox(width: 60),
                          Text(
                            'Page $_page/${(_problems_cnt / 10).ceil()}',
                            style: const TextStyle(fontSize: 16),
                          ),
                          if (_page * 10 < _problems_cnt)
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _page = _page + 1;
                                  _getProblems();
                                });
                              },
                              child: const Icon(Icons.arrow_forward),
                            )
                          else
                            const SizedBox(width: 60),
                        ],
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: _render(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (isLandscape) {
              // 横向布局：左侧题目列表，右侧过滤器
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 左侧：题目列表（占剩余空间）
                  Expanded(
                    child: buildList(),
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
                          quarterTurns: 1, // 旋转把手图标，使其适合横向拖拽
                          child: Icon(Icons.drag_handle),
                        ),
                      ),
                    ),
                  ),
                  // 右侧：过滤器（宽度根据比例）
                  if (_splitRatio > 0)
                    SizedBox(
                      width: maxWidth * _splitRatio,
                      child: buildFilter(),
                    ),
                ],
              );
            } else {
              // 纵向布局：上部过滤器，下部题目列表
              return Column(
                children: [
                  // 上部：过滤器
                  SizedBox(
                    height: maxHeight * _splitRatio,
                    child: buildFilter(),
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
                  // 下部：题目列表（占剩余空间）
                  Expanded(
                    child: buildList(),
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