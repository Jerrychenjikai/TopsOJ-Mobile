import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:TopsOJ/cached_problem_func.dart';


// 题目页面
class ProblemPage extends StatefulWidget {
  final String problemId;

  const ProblemPage({super.key, required this.problemId});

  @override
  State<ProblemPage> createState() => _ProblemPageState();
}

class _ProblemPageState extends State<ProblemPage> {
  final TextEditingController _controller = TextEditingController();

  String _markdownData = "";
  String _problemName = "";
  bool _canNxt = false;
  bool _canPrev = false;
  String _nxt = "";
  String _prev = "";
  bool _isSolved = false;

  Future<void> _loadProblemData() async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('apiKey') ?? "";

    // fetch markdown
    final markdownUrl = Uri.parse('https://topsoj.com/api/publicproblem?id=${widget.problemId}');
    final markdownResponse = await http.get(markdownUrl);
    final markdownJson = jsonDecode(markdownResponse.body);

    if (markdownResponse.statusCode != 200) {
      if(is_cached(widget.problemId)){
        _markdownData = await readMarkdown(widget.problemId+'.md') ?? "Error: problem markdown not found. Delete this cached problem";
        _problemName = await cached_info(widget.problemId)['name'];
        _canNxt = false;
        _canPrev = false;
        _isSolved = false;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to load question from server. This content is from local storage")),
        );
        return;
      }
      else{
        _markdownData="Markdown load failed: ${markdownResponse.statusCode} ${markdownJson['message']}";
        return;
      }
    }

    // fetch isSolved
    bool solved = false;
    if (apiKey.isNotEmpty) {
      final solvedUrl = Uri.parse('https://topsoj.com/api/problemsolved?id=${widget.problemId}');
      final solvedResponse = await http.get(solvedUrl, headers: {
        'Authorization': 'Bearer $apiKey',
      });
      if (solvedResponse.statusCode == 200) {
        final solvedJson = jsonDecode(solvedResponse.body);
        solved = solvedJson['data']['solved'] == true;
      }
    }

    // set state in batch
    _markdownData = markdownJson['data']['description_md'] ?? '';
    _problemName = markdownJson['data']['problem_name'] ?? '';
    _canNxt = markdownJson['data']['can_next'];
    _canPrev = markdownJson['data']['can_prev'];
    _nxt = markdownJson['data']['nxt'].replaceFirst('/problem/', '');
    _prev = markdownJson['data']['prev'].replaceFirst('/problem/', '');
    _isSolved = solved;
  }

  Future<Map<String, dynamic>> submitProblem(String answer) async {
    var url = Uri.parse('https://topsoj.com/api/submitproblem');
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('apiKey');

    if (apiKey == null || apiKey.isEmpty) {
      return {'statusCode': -1, 'data': 'API Key Not Found. Log In Again'};
    }

    var headers = {'Authorization': 'Bearer $apiKey'};
    var response = await http.post(url, headers: headers, body: {
      'problem_id': widget.problemId,
      'answer': answer,
    });
    final jsonData = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return {'statusCode': 200, 'data': jsonData['data']};
    } else {
      return {'statusCode': response.statusCode, 'data': jsonData['message']};
    }
  }

  void _submit() async {
    final answer = _controller.text.trim();
    _controller.clear();
    final response = await submitProblem(answer);
    if (response['statusCode'] == 200) {
      final passed = response['data']['check'] as bool;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(passed ? 'Your answer is correct' : 'Your answer is incorrect')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Submission failed: ${response['statusCode']} ${response['data']}')),
      );
    }
  }

  List<Widget> _parseContent(String raw) {
    // First, replace <br> with newline
    raw = raw.replaceAll('<br>', '\n');
    raw = raw.replaceAll('<center>', '');
    raw = raw.replaceAll('</center>', '\n');

    final widgets = <Widget>[];
    final imgRegex = RegExp(
      r'<img[^>]*src="([^"]+)"[^>]*?width="(\d+)(?:px)?"[^>]*?>',
      caseSensitive: false,
    );

    int lastEnd = 0;
    for (final match in imgRegex.allMatches(raw)) {
      // Process text before image
      if (match.start > lastEnd) {
        widgets.addAll(_parseMarkdownWithLatex(raw.substring(lastEnd, match.start)));
      }
      // Add image widget
      final src = match.group(1)!;
      final final_src;

      final width = match.group(2) != null ? double.tryParse(match.group(2)!) : null;

      if(src[0]=='/'){
        final_src="https://topsoj.com"+src;
      }
      else{
        final_src=src;
      }
      
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Image.network(
            final_src,
            width: width,
            fit: BoxFit.contain,
          ),
        ),
      );
      lastEnd = match.end;
    }
    // Remaining content after last image
    if (lastEnd < raw.length) {
      widgets.addAll(_parseMarkdownWithLatex(raw.substring(lastEnd)));
    }
    return widgets;
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
              textStyle: const TextStyle(color: Colors.black87, fontSize: 24),
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
    final widgets = <Widget>[];
    // Support inline math with newlines via dotAll
    final regexInline = RegExp(r'\$(.+?)\$', dotAll: true);

    for (var segment in text.split('\n')) {
      if (segment.trim().isEmpty) {
        widgets.add(const SizedBox(height: 12));
        continue;
      }
      final spans = <InlineSpan>[];
      int lastEnd = 0;
      for (final match in regexInline.allMatches(segment)) {
        if (match.start > lastEnd) {
          spans.add(TextSpan(
            text: segment.substring(lastEnd, match.start),
            style: const TextStyle(color: Colors.black87, fontSize: 20),
          ));
        }
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Math.tex(
              match.group(1)!.trim(),
              textStyle: const TextStyle(color: Colors.black87, fontSize: 20),
            ),
          ),
        ));
        lastEnd = match.end;
      }
      if (lastEnd < segment.length) {
        spans.add(TextSpan(
          text: segment.substring(lastEnd),
          style: const TextStyle(color: Colors.black87, fontSize: 20),
        ));
      }
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: RichText(text: TextSpan(children: spans)),
        ),
      );
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _loadProblemData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(title: const Text("Loading...")),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        // Use _parseContent to build the content
        final content = ListView(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          children: _parseContent(_markdownData),
        );

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    _problemName,
                    style: const TextStyle(fontSize: 22),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_isSolved)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(Icons.check_circle, color: Colors.green, size: 24),
                  ),
              ],
            ),
          ),
          body: Column(
            children: [
              Expanded(child: content),
              ElevatedButton(
                onPressed: () async {
                  await cache(widget.problemId, _problemName, _markdownData);
                  print(await get_cached());
                  print(await readMarkdown(widget.problemId+'.md'));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Problem Cached')),
                  );
                },
                child: const Text('Cache this problem'),
              ),
              if (_canPrev || _canNxt)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (_canPrev)
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => ProblemPage(problemId: _prev),
                              ),
                            );
                          },
                          icon: const Icon(Icons.arrow_back),
                          label: const Text("Previous"),
                        ),
                      if (_canNxt)
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => ProblemPage(problemId: _nxt),
                              ),
                            );
                          },
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text("Next"),
                        ),
                    ],
                  ),
                ),
              Container(
                color: Colors.white,
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
                      ),
                    ),
                    const SizedBox(width: 10),
                    FloatingActionButton(
                      onPressed: _submit,
                      tooltip: 'Submit',
                      child: const Icon(Icons.send),
                      mini: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}