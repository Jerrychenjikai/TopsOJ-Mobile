import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
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
      } else {
        _response = 'API Key Invalid: $statusCode';
      }
    });
  }

  void _gotoProblem() {
    final String problemId = _problemIdController.text.trim();
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
                labelText: 'Enter Problem ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _gotoProblem,
              child: const Text('Go to Problem'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _makeRequest,
              child: const Text('Request Login Status'),
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
  String _answer = "";
  String _markdownData = "";
  String _problemName = "";
  bool _canNxt = false;
  bool _canPrev = false;
  String _nxt = "";
  String _prev = "";
  var _isSolved;

  @override
  void initState() {
    super.initState();
    _fetchMarkdown();
    _checkIfSolved();
  }

  Future<void> _checkIfSolved() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('apiKey');

    if (apiKey == null || apiKey.isEmpty) return;

    final url = Uri.parse('https://topsoj.com/api/problemsolved?id=${widget.problemId}');
    final response = await http.get(url, headers: {
      'Authorization': 'Bearer $apiKey',
    });

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      setState(() {
        _isSolved = jsonData['data']['solved'] == true;
      });
    }
  }

  Future<void> _fetchMarkdown() async {
    try {
      final url = Uri.parse('https://topsoj.com/api/publicproblem?id=${widget.problemId}');
      final response = await http.get(url);
      final Map<String, dynamic> jsonData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        setState(() {
          _markdownData = jsonData['data']['description_md'] ?? '';
          _problemName = jsonData['data']['problem_name'] ?? '';
          _canNxt = jsonData['data']['can_next'];
          _canPrev = jsonData['data']['can_prev'];
          _nxt = jsonData['data']['nxt'].replaceFirst('/problem/', '');
          _prev = jsonData['data']['prev'].replaceFirst('/problem/', '');
        });
      } else {
        setState(() {
          _markdownData = 'Loading failed: ${response.statusCode} ${jsonData['message']}';
        });
      }
    } catch (e) {
      setState(() {
        _markdownData = 'Loading Error: $e';
      });
    }
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
    _answer = _controller.text.trim();
    _controller.clear();
    final response = await submitProblem(_answer);
    if (response['statusCode'] == 200) {
      final passed = response['data']['check'] as bool;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(passed ? 'Your answer is correct' : 'Your answer is incorrect'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Submission failed: ${response['statusCode']} ${response['data']}'),
        ),
      );
    }
  }

  // 解析 markdown 中的 latex
  List<Widget> _parseMarkdownWithLatex(String raw) {
    final widgets = <Widget>[];
    final regexBlock = RegExp(r'\$\$(.+?)\$\$', dotAll: true);
    int lastEnd = 0;
    raw = raw.replaceAll('<br>', '\n');

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
    final regexInline = RegExp(r'\$(.+?)\$');

    for (var line in text.split('\n')) {
      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 12));
        continue;
      }

      final spans = <InlineSpan>[];
      int lastEnd = 0;

      for (final match in regexInline.allMatches(line)) {
        if (match.start > lastEnd) {
          spans.add(TextSpan(
            text: line.substring(lastEnd, match.start),
            style: const TextStyle(color: Colors.black87, fontSize: 20),
          ));
        }

        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Math.tex(
              match.group(1)!,
              textStyle: const TextStyle(color: Colors.black87, fontSize: 20),
            ),
          ),
        ));

        lastEnd = match.end;
      }

      if (lastEnd < line.length) {
        spans.add(TextSpan(
          text: line.substring(lastEnd),
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
    final content = _markdownData.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            children: _parseMarkdownWithLatex(_markdownData),
          );

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: Text(
                '$_problemName',
                style: const TextStyle(fontSize: 22),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_isSolved)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Image.network(
                  'https://topsoj.com/assets/images/checkmark.png',
                  width: 24,
                  height: 24,
                ),
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
  }
}
