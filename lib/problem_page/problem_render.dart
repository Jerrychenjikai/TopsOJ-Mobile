import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_math_fork/flutter_math.dart';

import 'package:TopsOJ/cached_problem_func.dart';
import 'dart:io';

/// 获取题目内容并渲染 markdown。只接受 problemId，返回一个 ListView（无外层 Container / Padding）。
Widget problemRender(String problemId) {
  return _ProblemRender(problemId: problemId);
}

class _ProblemRender extends StatefulWidget {
  final String problemId;

  const _ProblemRender({required this.problemId});

  @override
  State<_ProblemRender> createState() => _ProblemRenderState();
}

class _ProblemRenderState extends State<_ProblemRender> {
  String? _loadedProblemId;
  List<Widget> _rendered = [];

  Future<void> _loadProblemData() async {
    if (_loadedProblemId == widget.problemId) return;

    var markdownUrl;
    var markdownResponse;
    var markdownJson;

    // fetch markdown
    try {
      markdownUrl = Uri.parse('https://topsoj.com/api/publicproblem?id=${widget.problemId}');
      markdownResponse = await http.get(markdownUrl);
      markdownJson = jsonDecode(markdownResponse.body);
    } catch (e) {
      if (await is_cached(widget.problemId)) {
        String markdownData = await readMarkdown(widget.problemId + '.md') ?? "Error: problem markdown not found. Delete this cached problem";
        _loadedProblemId = widget.problemId;
        await _parseContent("[From local storage]\n" + markdownData);
        return;
      } else {
        _loadedProblemId = widget.problemId;
        await _parseContent("Network error");
        return;
      }
    }

    if (markdownResponse.statusCode != 200) {
      _loadedProblemId = widget.problemId;
      await _parseContent("Markdown load failed: ${markdownResponse.statusCode} ${markdownJson['message']}");
      return;
    }

    String markdownData = markdownJson['data']['description_md'] ?? '';
    _loadedProblemId = widget.problemId;
    await _parseContent(markdownData);
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
    ); // same as the one in cached_problem_func.dart

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

      if (src[0] == '/')
        final_src = "https://topsoj.com" + src;
      else
        final_src = src;

      print(cnt);
      final filename = urlToFilename(widget.problemId, cnt);
      cnt += 1;
      final file = File("${path}/${filename}");

      widgets.add(
        Image.file(
          file,
          width: width,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Image.network(
              final_src,
              width: width,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Text(
                  "--Failed to load image--",
                  style: TextStyle(color: Colors.red),
                );
              },
            );
          },
        ),
      );
      lastEnd = match.end;
    }
    // Remaining content after last image
    if (lastEnd < raw.length) {
      widgets.addAll(_parseMarkdownWithLatex(raw.substring(lastEnd)));
    }
    _rendered = widgets;
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
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Math.tex(
            match.group(1)!,
            textStyle: const TextStyle(color: Colors.black87, fontSize: 24),
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
      RichText(text: TextSpan(children: spans)),
    );
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _loadProblemData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done && _loadedProblemId != widget.problemId) {
          return ListView(
            children: [
              Center(child: CircularProgressIndicator()),
            ],
          );
        }

        return ListView(
          children: _rendered,
        );
      },
    );
  }
}
