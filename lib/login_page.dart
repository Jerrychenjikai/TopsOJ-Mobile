import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:TopsOJ/basic_func.dart';
import 'package:TopsOJ/cached_problem_page.dart';

Future<bool?> popLogin(BuildContext context) async {
  return await showDialog<bool>(
    context: context,
    barrierDismissible: true,        // 允许点击外部关闭
    builder: (context) => LoginPage(),
  );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});   // 去掉 gotopage 参数

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();

  Future<void> _login() async {
    String username = _username.text.trim();
    String password = _password.text.trim();
    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter username and password')),
      );
      return;
    }

    final result = await login(username, password);
    final int isValid = result['statusCode'];
    final String? apiKey = result['apikey'];

    if (isValid != 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login Invalid: ${isValid.toString()}')),
      );
      return;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('apiKey', apiKey ?? "");

    // 登录成功 → 关闭弹窗并返回 true
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(        // 防止键盘弹出时溢出
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LogIn',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _username,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Username',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _password,
                obscureText: true,                     // 建议加上密码隐藏
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Password',
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _login,
                      child: const Text('LogIn'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        launchURL(context, "https://topsoj.com/register");
                      },
                      child: const Text('Register'),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context, false),  // 取消
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}