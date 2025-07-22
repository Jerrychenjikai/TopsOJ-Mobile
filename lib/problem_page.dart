import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:TopsOJ/cached_problem_func.dart';
import 'package:TopsOJ/basic_func.dart';
import 'dart:io';


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
  bool _isCached = false;
  bool _successfully_loaded = false;

  List<Widget> _rendered=[];

  Future<void> _loadProblemData() async {
    _isCached = await is_cached(widget.problemId);
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('apiKey') ?? "";
    var markdownUrl;
    var markdownResponse;
    var markdownJson;

    // fetch markdown
    try{
      markdownUrl = Uri.parse('https://topsoj.com/api/publicproblem?id=${widget.problemId}');
      markdownResponse = await http.get(markdownUrl);
      markdownJson = jsonDecode(markdownResponse.body);
    } catch(e){
      if(await is_cached(widget.problemId)){
        var cachedinfo = (await cached_info(widget.problemId));
        _markdownData = await readMarkdown(widget.problemId+'.md') ?? "Error: problem markdown not found. Delete this cached problem";
        _problemName = cachedinfo['name'] ?? "Error: Problem not cached";
        _nxt = cachedinfo['nxt'] ?? "";
        _prev = cachedinfo['prev'] ?? "";
        _canNxt = ((!_nxt.isEmpty) & (await is_cached(_nxt))) ? true : false;
        _canPrev = ((!_prev.isEmpty) & (await is_cached(_prev))) ? true : false;
        _isSolved = cachedinfo['correct']=='true' ? true : false;
        _successfully_loaded = true;

        _parseContent("[From local storage]\n"+_markdownData);

        return;
      }
      else{
        _markdownData="Network error";
        return;
      }
    }

    if (markdownResponse.statusCode != 200) {
      _markdownData="Markdown load failed: ${markdownResponse.statusCode} ${markdownJson['message']}";
      return;
    }

    // set state in batch
    _markdownData = markdownJson['data']['description_md'] ?? '';
    _problemName = markdownJson['data']['problem_name'] ?? '';
    _canNxt = markdownJson['data']['can_next'];
    _canPrev = markdownJson['data']['can_prev'];
    _nxt = _canNxt ? markdownJson['data']['nxt'].replaceFirst('/problem/', '') : "";
    _prev = _canPrev ? markdownJson['data']['prev'].replaceFirst('/problem/', '') : "";
    _isSolved = await checkSolved(widget.problemId);
    _successfully_loaded = true;

    _parseContent(_markdownData);
  }

  void _submit() async {
    final answer = _controller.text.trim();
    _controller.clear();
    var response = await submitProblem(widget.problemId, answer);
    if (response['statusCode'] == 200) {
      final passed = response['data']['check'] as bool;
      if(passed){
        await record(widget.problemId, 'correct', '${true}');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(passed ? 'Your answer is correct' : 'Your answer is incorrect')),
      );
    } else {
      if(response['statusCode'] == -1){
        if(await is_cached(widget.problemId)){
          await record(widget.problemId, 'answer', answer);
          response = {'statusCode': -2, 'data': 'You are offline. Answer recorded in cache'};
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response['statusCode'] == -2
          ? '${response['data']}'
          : 'Submission failed: ${response['statusCode']} ${response['data']}')),
      );
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
    );//same as the one in cached_problem_func.dart

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

      if(src[0]=='/') final_src="https://topsoj.com"+src;
      else final_src=src;

      print(cnt);
      final filename = urlToFilename(widget.problemId,cnt);
      cnt+=1;
      final file = File("${path}/${filename}");
      
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Image.file(
            file,
            width: width,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace){
              //print("file not found: ${path}/${filename}");
              return Image.network(
                final_src,
                width: width,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Text("--Failed to load image--",
                    style: TextStyle(color: Colors.red));//change this text to red
                }
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
    _rendered=widgets;
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

    final spans = <InlineSpan>[];
    int lastEnd = 0;
    for (final match in regexInline.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
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
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: const TextStyle(color: Colors.black87, fontSize: 20),
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
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(title: const Text("Loading...")),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        // Use _parseContent to build the content
        final content = ListView(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          children: _rendered,
        );

        return WillPopScope(onWillPop: ()async{
            Navigator.pop(context, true); // 手动传回是否需要刷新
            return false; // 阻止默认返回行为（因为我们手动pop了）
          },
          child: Scaffold(
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
                      child: Icon(Icons.check, color: Colors.green, size: 24),
                    ),
                ],
              ),
            ),
            body: Column(
              children: [
                Expanded(child: content),
                if(!_isCached & _successfully_loaded) 
                  ElevatedButton(
                    onPressed: () async {
                      setState(() async {
                        await cache(widget.problemId, _problemName, _markdownData, _nxt, _prev);
                        _isCached=true;
                      });
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
                          onSubmitted: (value){
                            _submit();
                          },
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
          ),
        );
      },
    );
  }
}