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

// 公共函数：验证API KEY
Future<int> checkApiKeyValid(String apiKey) async {
  final uri = Uri.parse('https://topsoj.com/api/confirmlogin');

  try {
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $apiKey'},
    );
    return response.statusCode;
  } catch (e) {
    return -1;
  }
}

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

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  String _response = '';

  Future<void> _makeRequest() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('apiKey');

    if (apiKey == null || apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API Key Not Found')),
      );
      return;
    }

    int isValid = await checkApiKeyValid(apiKey);

    setState(() {
      _response = isValid == 200
          ? 'API Key Valid'
          : 'API Key Invalid: ${isValid.toString()}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home Page')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _makeRequest,
              child: const Text('Request'),
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

    int isValid = await checkApiKeyValid(apiKey);

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

class ProblemPage extends StatefulWidget {
  const ProblemPage({super.key});

  @override
  State<ProblemPage> createState() => _ProblemPageState();
}

class _ProblemPageState extends State<ProblemPage> {
  final TextEditingController _controller = TextEditingController();
  String _answer = "";
  String _markdownData = "";

  @override
  void initState() {
    super.initState();
    _fetchMarkdown();
  }

  Future<void> _fetchMarkdown() async {
    try {
      final url = Uri.parse('https://topsoj.com/api/publicproblem?id=20_aime_II_p01');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = jsonDecode(response.body);
        setState(() {
          _markdownData = jsonData['data']['description_md'] ?? '';
        });
      } else {
        setState(() {
          _markdownData = 'Loading failed: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _markdownData = 'Loading Error: $e';
      });
    }
  }

  void _submit() {
    setState(() {
      _answer = _controller.text;
      _controller.clear();
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
        title: const Text('TopsOJ Problem Page'),
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
