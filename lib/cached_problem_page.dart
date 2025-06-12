import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:TopsOJ/problem_page.dart';
import 'package:TopsOJ/cached_problem_func.dart';

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

  Future<List<Widget>> _render() async {
    List<Widget> widgets = [];
    List<Map<String, String>> _cached = await get_cached();

    void _gotoProblem([String? id]) {
      final String problemId = (id ?? "");
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

    for (Map<String, String> problem in _cached) {
      widgets.add(
        ListTile(
          title: Text(problem['name'] ?? 'No Name'),
          subtitle: Text("Your answer: ${problem['answer']?.isNotEmpty == true ? problem['answer'] : 'No Answer'}"),
          leading: const Icon(Icons.book),
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
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: snapshot.data!,
                ),
              );
            }
          },
        ),
      ),
    );
  }
}

