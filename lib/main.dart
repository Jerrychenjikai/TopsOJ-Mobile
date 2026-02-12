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
      },
      theme: ThemeData(
        useMaterial3: true, 
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromRGBO(107, 38, 37, 1.0),
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,                      // 平时无阴影（可选，但常一起设）
          scrolledUnderElevation: 0,         // ← 核心！全局让滚动时也不抬升/不变色
          surfaceTintColor: Colors.transparent, // 额外保险，防止 tint 染色（强烈推荐）
          shadowColor: Colors.transparent,
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,          // 預設改成 floating
          shape: RoundedRectangleBorder(                // 可選：更好看
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 6,
          showCloseIcon: true,
          closeIconColor: Theme.of(context).colorScheme.onPrimary,
          dismissDirection: DismissDirection.down,
        ),
      ),
      home: const MainPage(),
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
  }

  Future<void> _makeRequest() async {
    if((await checkLogin()) == null){
      final success = await popLogin(context);
      if (success != true) {
        setState(() {_response = "Not Logged In";});
        _precommend_render = [];
        _userinfo = {};
        _weeklylb_render = [];
        return;
      }
    }

    // this renders the content in the drawer
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String apiKey = prefs.getString('apiKey') ?? "";
    final result = await checkApiKeyValid(apiKey);
    final statusCode = result['statusCode'];

    final String? username = result['username'];
    List<dynamic> weeklylb = await fetchWeeklylb();
    List<dynamic> precommend = await fetchRecommendedProblems();
    setState(() {
      _weeklylb_render = [];
      for (dynamic lb in weeklylb) {
        _weeklylb_render.add(
          ListTile(
            title: Text(lb['username']),
            trailing: Text(
              "${lb['total_points']} Points",
              style: const TextStyle(fontSize: 15),
            ),
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
    if((await checkLogin()) != null){
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('apiKey');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Successfully logged out')),
      );
    }
    else popLogin(context);
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
      'Rankings',
    ];
    final currentIndex = ref.watch(
      mainPageProvider.select((state) => state.index),
    );

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

                      Card(
                        color: Theme.of(context).colorScheme.surfaceContainerLowest,
                        child: Column(
                          children: [
                            const SizedBox(height: 8),
                            Text(
                              "Weekly Leaderboard",
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                            ..._weeklylb_render,
                          ],
                        ),
                      ),
                      const SizedBox(height: 15),
                      Card(
                        color: Theme.of(context).colorScheme.surfaceContainerLowest,
                        child: Column(
                          children: [
                            const SizedBox(height: 8),
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
            icon: const Icon(Icons.person_2_outlined),
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
          HomePage(),
          Problems(),
          RankingPage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          ref.read(mainPageProvider.notifier).update((state) => (
            index: index,
            search: null,
            ranking_category: null,
          ));
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
          BottomNavigationBarItem(
            icon: Icon(Icons.leaderboard),
            label: 'Rankings',
          ),
        ],
      ),
    );
  }
}