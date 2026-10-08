import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 1. 引入 services 包
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math';

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
import 'basic/ui_basic.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();  

  // 2. 开启 Edge-to-Edge，并将系统状态栏与底部导航栏设为全透明
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent, // 关键：系统底部导航栏透明
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  // 提前加载好 Shader[cite: 1]
  await preloadLiquidGlassShader(); //[cite: 1]
  PackageInfo packageInfo = await PackageInfo.fromPlatform(); //[cite: 1]
  runApp(const ProviderScope(child: TopsOJ())); //[cite: 1]
}

class TopsOJ extends StatelessWidget {
  const TopsOJ({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Tops Online Judge",
      routes: {
        '/home': (context) => const MainPage(),
      },
      theme: ThemeData(
        useMaterial3: true, 
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromRGBO(107, 38, 37, 1.0),
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,                      
          scrolledUnderElevation: 0,         
          surfaceTintColor: Colors.transparent, 
          shadowColor: Colors.transparent,
        ),
        textTheme: Theme.of(context).textTheme.apply(
          bodyColor: Colors.black,
          displayColor: Colors.black,
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,          
          shape: RoundedRectangleBorder(                
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

  // 用于捕获主界面背景内容的 Key
  final GlobalKey _backgroundKey = GlobalKey();

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
      if (precommend.isNotEmpty) {
        _precommend_render = [];
        for (dynamic pr in precommend) {
          if (_precommend_render.length > 4) {
            break;
          }
          _precommend_render.add(
            ListTile(
              title: Text(pr['name']),
              subtitle: Text(pr['pid']),
              leading: const Icon(Icons.book),
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
      'Problems',     // index 1
      'Rankings',
    ];
    final currentIndex = ref.watch(
      mainPageProvider.select((state) => state.index),
    );

    return LiquidGlassScope(
      repaintBoundaryKey: _backgroundKey,
      child: Scaffold(
        extendBody: true, // 核心：让 body 延伸到底部导航栏下方
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
                              const Text(
                                "Weekly Leaderboard",
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
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
                              const Text(
                                "Problems you might find challenging",
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
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
        floatingActionButton: _buildLiquidSpeedDial(context),
        body: RepaintBoundary(
          key: _backgroundKey,
          child: IndexedStack(
            index: currentIndex,
            children: const [
              HomePage(),
              Problems(),
              RankingPage(),
            ],
          ),
        ),
        bottomNavigationBar: _buildLiquidBottomNavigationBar(context, currentIndex),
      ),
    );
  }

  /// 完全透明的 Liquid Glass 底部导航条
  Widget _buildLiquidBottomNavigationBar(BuildContext context, int currentIndex) {
    const double navBarHeight = 64.0;
    const double borderRadius = navBarHeight / 2; // 圆角半径等于高度的一半 (32.0)

    final theme = Theme.of(context);
    final selectedColor = theme.colorScheme.primary;
    final unselectedColor = theme.colorScheme.onSurfaceVariant.withOpacity(0.6);

    final items = [
      (icon: Icons.home, label: 'Home'),
      (icon: Icons.filter_alt_outlined, label: 'Problems'),
      (icon: Icons.leaderboard_outlined, label: 'Rankings'),
    ];

    return Container(
      color: Colors.transparent, // 确保无任何实体背景层
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: max(MediaQuery.of(context).padding.bottom, 12),
        top: 4,
      ),
      child: LiquidGlassContainer(
        height: navBarHeight,
        borderRadius: borderRadius,
        refractionIntensity: 3.5,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(items.length, (index) {
            final isSelected = index == currentIndex;
            final color = isSelected ? selectedColor : unselectedColor;

            return Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(borderRadius),
                onTap: () {
                  ref.read(mainPageProvider.notifier).update((state) => (
                    index: index,
                    search: null,
                    ranking_category: null,
                  ));
                  // 待新页面在 IndexedStack 中绘制完成后更新液态玻璃折射纹理
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (context.mounted) {
                      LiquidGlassScope.notifyUpdate(context);
                    }
                  });
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      items[index].icon,
                      color: color,
                      size: isSelected ? 26 : 22,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      items[index].label,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  /// Liquid Glass 样式的 SpeedDial (Floating Action Button)
  Widget _buildLiquidSpeedDial(BuildContext context) {
    const double fabSize = 56.0;
    const double fabRadius = fabSize / 2; // 圆形 (28.0)

    const double childSize = 48.0;
    const double childRadius = childSize / 2; // 圆形 (24.0)

    return SpeedDial(
      elevation: 0,
      backgroundColor: Colors.transparent,
      overlayColor: Theme.of(context).colorScheme.secondary,
      overlayOpacity: 0.25,
      direction: SpeedDialDirection.up,
      animationCurve: Curves.easeInOutCubic,
      spacing: 8,
      spaceBetweenChildren: 12,
      closeManually: false,

      // 主 FAB 图标 (未展开状态)
      child: LiquidGlassContainer(
        width: fabSize,
        height: fabSize,
        borderRadius: fabRadius,
        refractionIntensity: 3,
        child: const Center(
          child: Icon(Icons.keyboard_arrow_up, color: Colors.black),
        ),
      ),

      // 主 FAB 图标 (已展开状态)
      activeChild: LiquidGlassContainer(
        width: fabSize,
        height: fabSize,
        borderRadius: fabRadius,
        refractionIntensity: 3,
        child: const Center(
          child: Icon(Icons.close, color: Colors.black),
        ),
      ),

      // 弹出子按钮列表
      children: [
        SpeedDialChild(
          elevation: 0,
          backgroundColor: Colors.transparent,
          label: '2025 Wrap',
          labelBackgroundColor: Colors.white.withOpacity(0.75),
          labelStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
          child: LiquidGlassContainer(
            width: childSize,
            height: childSize,
            borderRadius: childRadius,
            refractionIntensity: 3,
            child: const Center(
              child: Icon(Icons.bar_chart, color: Colors.black),
            ),
          ),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => wrap2025.AnnualReportPage()),
            );
          },
        ),
        SpeedDialChild(
          elevation: 0,
          backgroundColor: Colors.transparent,
          label: 'Math PvP',
          labelBackgroundColor: Colors.white.withOpacity(0.75),
          labelStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
          child: LiquidGlassContainer(
            width: childSize,
            height: childSize,
            borderRadius: childRadius,
            refractionIntensity: 3,
            child: const Center(
              child: Icon(Icons.sports_mma, color: Colors.black),
            ),
          ),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => BattlePage()),
            );
          },
        ),
        SpeedDialChild(
          elevation: 0,
          backgroundColor: Colors.transparent,
          label: 'Cached Problems',
          labelBackgroundColor: Colors.white.withOpacity(0.75),
          labelStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
          child: LiquidGlassContainer(
            width: childSize,
            height: childSize,
            borderRadius: childRadius,
            refractionIntensity: 3,
            child: const Center(
              child: Icon(Icons.save, color: Colors.black),
            ),
          ),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => CachedPage()),
            );
          },
        ),
      ],
    );
  }
}