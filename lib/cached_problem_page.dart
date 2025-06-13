import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:TopsOJ/problem_page.dart';
import 'package:TopsOJ/cached_problem_func.dart';
import 'package:TopsOJ/basic_func.dart';

//This is the page for list of cached problems
class CachedPage extends StatefulWidget {
  const CachedPage({Key? key}) : super(key: key);

  @override
  _CachedPageState createState() => _CachedPageState();
}

class _CachedPageState extends State<CachedPage> {
  late Future<List<Widget>> _cachedProblemsFuture;

  @override
  void initState() {
    super.initState();
    _cachedProblemsFuture = _render(); // 初始化异步任务
  }

  Future<void> _submitAll() async { //submit the first 5 wrong problems since there is a rate limit
    List<Map<String, String>> problems = await get_cached();
    Map<String, dynamic> response;
    int cnt=0;

    for(var problem in problems){
      if((problem['id'] ?? "").isEmpty || (problem['answer'] ?? "").isEmpty || problem['correct']=="true") 
        continue;
      if(cnt==5) break;
      cnt++;

      response = await submitProblem(problem['id'] ?? "",problem['answer'] ?? "");

      if (response['statusCode'] == 200) {
        final passed = response['data']['check'] as bool;
        if(passed){
          await record(problem['id'] ?? "", 'correct', '${true}');
        }
        else{
          await record(problem['id'] ?? "", 'correct', '${false}');
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('When Submitting ${problem['name']} \nSubmission failed: ${response['statusCode']} ${response['data']}')),
        );
        break;
      }
    }

    setState(() async {
      _cachedProblemsFuture = _render();
    });
  }

  Future<void> _gotoProblem([String? id]) async {
    final String problemId = (id ?? "");
    if (problemId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a problem ID')),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProblemPage(problemId: problemId),
      ),
    );

    if(result){
      setState((){
        _cachedProblemsFuture = _render();
      });
    }
  }

  Future<List<Widget>> _render() async {
    List<Widget> widgets = [];
    List<Map<String, String>> _cached = await get_cached();

    for (Map<String, String> problem in _cached) {
      widgets.add(
        ListTile(
          title: Text(problem['name'] ?? 'No Name'),
          subtitle: Text("Your answer: ${problem['answer']?.isNotEmpty == true ? problem['answer'] : 'No Answer'}\n"
                          "Correct:    ${problem['correct']}"),
          leading: const Icon(Icons.book),
          trailing: IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              await delcache(problem['id'] ?? "");
              setState(() async {
                _cachedProblemsFuture = _render();
              });
            },
          ),
          onTap: () => _gotoProblem(problem['id']),
        ),
      );
    }

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Cached Problems"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<List<Widget>>(
          future: _cachedProblemsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text("Error: ${snapshot.error}"));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text("No cached problems."));
            } else {
              return Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                      children: snapshot.data!,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          _submitAll();
                        },
                        child: const Text("Submit five wrong problems"),
                      ),
                    ),
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

