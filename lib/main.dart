import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';

void main() {
  runApp(const TopsOJ());
}

class TopsOJ extends StatelessWidget {
  const TopsOJ({super.key});

  @override
  Widget build(BuildContext context){
    return MaterialApp(
      title: "Tops Online Judge",
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Color.fromRGBO(107, 38, 37, 1.0),
        ),
      ),
      home: const HomePage(title: 'TopsOJ Home Page'),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});

  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _controller = TextEditingController();
  String _answer="";
  String _markdownData="";

  @override
  void initState(){
    super.initState();
    _fetchMarkdown();
  }

  Future<void> _fetchMarkdown() async {
    final url = Uri.parse('https://topsoj.com/api/publicproblem?id=20_aime_II_p01');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonData = jsonDecode(response.body);
      print(response.body);
      setState(() {
        _markdownData = jsonData['data']['description_md'];
      });
    } else {
      setState(() {
        _markdownData = 'Loading Failed: ${response.statusCode}';
      });
    }
  }

  void _submit(){
    setState(() {
      _answer = _controller.text;
      _controller.clear();
    });
  }

  List<Widget> _parseMarkdownWithLatex(String raw) {
    final widgets = <Widget>[];
    final regexInline = RegExp(r'\$(.+?)\$'); // in-line formulae
    final regexBlock = RegExp(r'\$\$(.+?)\$\$', dotAll: true); // block formulae

    // block formulae
    String processed = raw.replaceAllMapped(regexBlock, (match) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Math.tex(match.group(1)!, textStyle: TextStyle(fontSize: 18)),
          ),
        ),
      );
      return ''; // delete from string
    });

    // in-line formulae
    for (var line in processed.split('\n')) {
      final spans = <InlineSpan>[];
      int lastMatchEnd = 0;

      for (final match in regexInline.allMatches(line)) {
        if (match.start > lastMatchEnd) {
          spans.add(TextSpan(text: line.substring(lastMatchEnd, match.start)));
        }
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Math.tex(match.group(1)!, textStyle: TextStyle(fontSize: 16)),
        ));
        lastMatchEnd = match.end;
      }

      if (lastMatchEnd < line.length) {
        spans.add(TextSpan(text: line.substring(lastMatchEnd)));
      }

      if (spans.isNotEmpty) {
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: RichText(text: TextSpan(style: TextStyle(color: Colors.black), children: spans)),
        ));
      } else {
        widgets.add(MarkdownBody(data: line, size: 25));
      }
    }

    return widgets;
  }

  @override
  Widget build(BuildContext context){
    final content = _markdownData.isEmpty
        ? Center(child: CircularProgressIndicator())
        : ListView(children: _parseMarkdownWithLatex(_markdownData));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          Expanded(child:content,),
          Padding( // fixed textbox
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Answer',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                FloatingActionButton(
                  onPressed: _submit,
                  tooltip: 'Submit',
                  child: Icon(Icons.send),
                  mini: true,
                ),
              ],
            ),
          ),
        ]
      ),
    );
  }
}