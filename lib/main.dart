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
    return await checkApiKeyValid(apiKey) == 200;
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

  @override
  void initState() {
    super.initState();
    _fetchMarkdown();
  }

  Future<void> _fetchMarkdown() async {
    try {
      final url = Uri.parse('https://topsoj.com/api/publicproblem?id=${widget.problemId}');
      final response = await http.get(url);
      final Map<String, dynamic> jsonData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        setState(() {
          _markdownData = jsonData['data']['description_md'] ?? '';
          _problemName = jsonData['data']['problem_name'] ?? "";
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

  Future<Map<String, dynamic>> submit_problem(answer) async {
    var url = Uri.parse('https://topsoj.com/api/submitproblem');

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('apiKey');

    if (apiKey == null || apiKey.isEmpty) {
      return {
        'statusCode': -1,
        'data': "API Key Not Found. Log In Again"
      };
    }

    // 表单数据
    Map<String, String> formData = {
      'problem_id': widget.problemId,
      'answer': answer,
    };

    // 构造请求头
    var headers = {'Authorization': 'Bearer $apiKey'};

    // 发送 POST 请求
    var response = await http.post(
      url,
      headers: headers,
      body: formData, // http 库会自动进行 url 编码
      encoding: Encoding.getByName('utf-8'),
    );

    // 处理响应
    final jsonData = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return {
        "statusCode": 200,
        'data': jsonData['data']
      };
    } else {
      return {
        'statusCode': response.statusCode,
        'data': jsonData['message']
      };
    }
  }

  void _submit() async {
    final response = await submit_problem(_answer);
    setState(() {
      _answer = _controller.text;
      _controller.clear();

      if(response['statusCode']==200){
        if(response['data']['check']){
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Your answer is correct')),
          );
        }
        else{
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Your answer is incorrect')),
          );
        }
      }
      else{
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission failed: ${response['statusCode']} ${response['data']}')),
        );
      }
    });
  }

  List<Widget> _parseMarkdownWithLatex(String raw) {
    final widgets = <Widget>[];
    final regexInline = RegExp(r'\$(.+?)\$');
    final regexBlock = RegExp(r'\$\$(.+?)\$\$', dotAll: true);

    String processed = raw.replaceAllMapped(regexBlock, (match) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Math.tex(match.group(1)!, textStyle: const TextStyle(fontSize: 18)),
          ),
        ),
      );
      return '';
    });

    for (var line in processed.split('\n')) {
      final spans = <InlineSpan>[];
      int lastMatchEnd = 0;

      for (final match in regexInline.allMatches(line)) {
        if (match.start > lastMatchEnd) {
          spans.add(TextSpan(text: line.substring(lastMatchEnd, match.start)));
        }
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Math.tex(match.group(1)!, textStyle: const TextStyle(fontSize: 16)),
        ));
        lastMatchEnd = match.end;
      }

      if (lastMatchEnd < line.length) {
        spans.add(TextSpan(text: line.substring(lastMatchEnd)));
      }

      if (spans.isNotEmpty) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: RichText(
              text: TextSpan(style: const TextStyle(color: Colors.black), children: spans),
            ),
          ),
        );
      } else {
        widgets.add(MarkdownBody(data: line));
      }
    }

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final content = _markdownData.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : ListView(children: _parseMarkdownWithLatex(_markdownData));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        title: Text('Problem: ${_problemName}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(child: content),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Answer',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
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
