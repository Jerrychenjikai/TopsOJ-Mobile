import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:TopsOJ/cached_problem_func.dart';
import 'package:TopsOJ/problem_page.dart';
import 'package:TopsOJ/cached_problem_page.dart';
import 'package:TopsOJ/basic_func.dart';
import 'package:TopsOJ/ranking_page.dart';
import 'package:TopsOJ/login_page.dart';
import 'package:TopsOJ/2025_annual_wrap.dart' as wrap2025;
import 'package:TopsOJ/bluetooth_compete.dart';
import 'package:TopsOJ/problems_page.dart';
import 'package:TopsOJ/home_page.dart';
import 'package:TopsOJ/index_providers.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PackageInfo packageInfo = await PackageInfo.fromPlatform();
  runApp(const ProviderScope(child: TopsOJ()));
}

class TopsOJ extends StatelessWidget {
  const TopsOJ({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Tops Online Judge",
      routes: {
        '/home': (context) => MainPage(),
        '/ranking': (context) => RankingPage(),
        '/2025wrap': (context) => wrap2025.AnnualReportPage(),
        '/battle': (context) => BattlePage(),
      },
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromRGBO(107, 38, 37, 1.0),
        ),
      ),
      home: const RootPage(),
    );
  }
}

// 初始页：根据登录状态跳转
class RootPage extends StatelessWidget {
  const RootPage({super.key});
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: checkLogin().then((value) {
        if (value == null) return false;
        return value['apikey'] != null;
      }),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data!) {
          return const MainPage();
        } else {
          return const LoginPage(gotopage: '/home');
        }
      },
    );
  }
}

// 主页面
class MainPage extends ConsumerStatefulWidget {
  const MainPage({super.key});

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends ConsumerState<MainPage> {
  String _response = '';
  Map<String, dynamic> _userinfo = {};
  List<Widget> _weeklylb_render = [];
  List<Widget> _precommend_render = [];

  @override
  void initState() {
    super.initState();
    _makeRequest();
  }

  Future<void> _makeRequest() async {
    // this renders the content in the drawer
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
    List<dynamic> weeklylb = await fetchWeeklylb();
    List<dynamic> precommend = await fetchRecommendedProblems();
    setState(() {
      _weeklylb_render = [];
      for (dynamic lb in weeklylb) {
        _weeklylb_render.add(
          ListTile(
            title: Text(lb['username']),
            subtitle: Text("${lb['total_points']} Points"),
            leading: Text("${lb['rank']}"),
          ),
        );
      }
      if (precommend.length != 0) {
        _precommend_render = [];
        for (dynamic pr in precommend) {
          if (_precommend_render.length > 4) {
            break;
          }
          _precommend_render.add(
            ListTile(
              title: Text(pr['name']),
              subtitle: Text(pr['pid']),
              leading: Icon(Icons.book),
              onTap: () {
                _gotoProblem(pr['pid']);
              },
            ),
          );
        }
      }
      if (statusCode == 200) {
        _response = 'Welcome, $username';
        _userinfo = result['userdata'];
      } else if (statusCode == 429) {
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
      MaterialPageRoute(builder: (_) => const LoginPage(gotopage: '/home')),
      (route) => false,
    );
  }

  void _gotoProblem([String? id]) {
    final String problemId = (id ?? "");
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

  @override
  Widget build(BuildContext context) {
    final List<String> _tabTitles = const [
      'TopsOJ',       // index 0
      'Problems',   // index 1
    ];
    final currentIndex = ref.watch(mainPageIndexProvider);

    return Scaffold(
      drawer: Drawer(
        width: max(min(MediaQuery.of(context).size.width * 0.75, 500), 350),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  _response,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      Text("Join date: ${_userinfo['join_date']}"),
                      const SizedBox(height: 5),
                      Text("Total Points: ${_userinfo['total_points']}"),
                      const SizedBox(height: 5),
                      Text("Streak: ${_userinfo['streak']}"),
                      const SizedBox(height: 15),
                      Text(
                        "Weekly Leaderboard",
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      ..._weeklylb_render,
                      const SizedBox(height: 15),
                      Text(
                        "Problems you might find challenging",
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      ..._precommend_render,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      onDrawerChanged: (isOpened) {
        if (isOpened) {
          _makeRequest();
        }
      },
      appBar: AppBar(
        title: Text(_tabTitles[currentIndex]),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      floatingActionButton: SpeedDial(
        child: const Icon(Icons.add),
        // 展开时的图标（常用来放 ×）
        closeManually: false,
        activeChild: const Icon(Icons.close),
        // 方向：最常用的是 up
        direction: SpeedDialDirection.up,
        // 动画曲线
        animationCurve: Curves.easeInOutCubic,
        // 背景遮罩（可选）
        overlayColor: Theme.of(context).colorScheme.secondary,
        overlayOpacity: 0.4,
        // 子按钮间距
        spacing: 8,
        // 与主按钮的距离
        spaceBetweenChildren: 12,
        children: [
          SpeedDialChild(
            child: const Icon(Icons.bar_chart),
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
            foregroundColor: Colors.black,
            label: '2025 Wrap',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => wrap2025.AnnualReportPage()),
              );
            },
          ),
          SpeedDialChild(
            child: const Icon(Icons.sports_mma),
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
            foregroundColor: Colors.black,
            label: 'Battle (under development)',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => BattlePage()),
              );
            },
          ),
          SpeedDialChild(
            child: const Icon(Icons.workspace_premium),
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
            foregroundColor: Colors.black,
            label: 'Rankings',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => RankingPage()),
              );
            },
          ),
          SpeedDialChild(
            child: const Icon(Icons.save),
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
            foregroundColor: Colors.black,
            label: 'Cached Problems',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => CachedPage()),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: currentIndex,
        children: const [
          HomePage(),//这里用来占位未来的homepage
          Problems(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          ref.read(mainPageIndexProvider.notifier).state = index;
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.filter),
            label: 'Problems',
          ),
        ],
      ),
    );
  }
}