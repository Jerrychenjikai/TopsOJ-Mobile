import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PackageInfo packageInfo = await PackageInfo.fromPlatform();
  runApp(const TopsOJ());
}

class TopsOJ extends StatelessWidget {
  const TopsOJ({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Tops Online Judge",
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromRGBO(107, 38, 37, 1.0),
        ),
      ),
      home: const RootPage(),
    );
  }
}

Future<Map<String, dynamic>> checkApiKeyValid(String apiKey) async {
  final uri = Uri.parse('https://topsoj.com/api/confirmlogin');

  try {
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $apiKey'},
    );

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      print(jsonData);
      return {
        'statusCode': 200,
        'username': jsonData['data']['username'],
      };
    } else {
      return {
        'statusCode': response.statusCode,
        'username': null,
      };
    }
  } catch (e) {
    return {
      'statusCode': -1,
      'username': null,
    };
  }
}


// 初始页：根据登录状态跳转
class RootPage extends StatelessWidget {
  const RootPage({super.key});

  Future<bool> _checkLogin() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String apiKey = prefs.getString('apiKey') ?? '';
    if (apiKey.isEmpty) return false;
    final response = await checkApiKeyValid(apiKey);
    return response['statusCode'] == 200;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkLogin(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data!) {
          return const MainPage();
        } else {
          return const LoginPage();
        }
      },
    );
  }
}

// 登录页
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _controller = TextEditingController();

  Future<void> _login() async {
    String apiKey = _controller.text.trim();
    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter API key')),
      );
      return;
    }

    final result = await checkApiKeyValid(apiKey);
    final int isValid = result['statusCode'];
    final String? username = result['username'];

    if (isValid != 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('API Key Invalid: ${isValid.toString()}')),
      );
      return;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('apiKey', apiKey);

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainPage()),
      (route) => false,
    );
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot open URL: $url')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('LogIn')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Click to generate API Key:', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _launchURL("https://topsoj.com/settings"),
              child: const Text(
                'https://topsoj.com/settings',
                style: TextStyle(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'API Key',
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: _login,
                child: const Text('LogIn'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 主页面
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  String _response = '';
  final TextEditingController _problemIdController = TextEditingController();
  int _page=1;
  int _problems_cnt=0;

  List<Map<String, dynamic>> _problem_ids = [
    {'id': "02_amc10A_p01", 'name': '2002 AMC 10A problem 1'},
    {'id': "03_amc12A_p01", 'name': '2003 AMC 12A problem 1'},
    {'id': "04_amc12A_p02", 'name': '2004 AMC 12A problem 2'},
  ];//replace this with function that requests for problem list

  Future<void> _getProblems() async {
    var url = Uri.parse('https://topsoj.com/api/problems');
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('apiKey');

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
    });

    final jsonData = jsonDecode(response.body);
    if (response.statusCode == 200) {
      _problem_ids = jsonData['data']['problems'];
      _problems_cnt = jsonData['data']['length'];
      return;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Search Error: ${response.statusCode} ${jsonData['message']}')),
      );
      return;
    }
  }

  void _gotoProblem([String? id]) {
    final String problemId = (id ?? _problemIdController.text.trim());
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
          leading: Icon(Icons.book),
          onTap: () {
            _gotoProblem(problem['id']);
          },
        ),
      );
    }

    return widgets;
  }
  
  Future<void> _makeRequest() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('apiKey');

    if (apiKey == null || apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API Key Not Found, Log In Again')),
      );
      return;
    }

    final result = await checkApiKeyValid(apiKey);
    final int statusCode = result['statusCode'];
    final String? username = result['username'];

    setState(() {
      if (statusCode == 200) {
        _response = 'API Key Valid\nUsername: $username';
      } else if (statusCode == 429){
        _response = "Too many requests. Wait 1 minute";
      } else {
        _response = 'API Key Invalid: $statusCode';
      }
    });
  }

  Future<void> _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('apiKey');

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Page'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _problemIdController,
              decoration: const InputDecoration(
                labelText: 'Enter Problem Name/ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _getProblems,
              child: const Text('Search'),
            ),

            ..._render(),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _makeRequest,
              child: const Text('Login Status'),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Text(_response, style: const TextStyle(fontSize: 16)),
              ),
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
      _markdownData="Markdown load failed: ${markdownResponse.statusCode} ${markdownJson['message']}";
      return;
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
    print(raw);
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

      print(final_src);
      
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

