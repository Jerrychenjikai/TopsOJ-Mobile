import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:TopsOJ/cached_problem_func.dart';
import 'package:TopsOJ/problem_page.dart';
import 'package:TopsOJ/cached_problem_page.dart';
import 'package:TopsOJ/basic_func.dart';
import 'package:TopsOJ/ranking_page.dart';
import 'package:TopsOJ/login_page.dart';

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
      routes: {
        '/home': (context) => MainPage(),
        '/ranking': (context) => RankingPage(),
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
          return const LoginPage(gotopage: '/home');
        }
      },
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
  Map<String, dynamic> _userinfo={};
  final TextEditingController _problemIdController = TextEditingController();
  int _page=1;
  int _problems_cnt=3;
  List<Widget> _weeklylb_render=[];
  List<Widget> _precommend_render = [];
  double _solved = 1;//0 - only fetch unsolved problems, 1 - no restrictions, 2 - only solved problems

  @override
  void initState(){
    super.initState();
    _makeRequest();
  }

  List<dynamic> _problem_ids = [
    {'id': "02_amc10A_p01", 'name': '2002 AMC 10A problem 1'},
    {'id': "03_amc12A_p01", 'name': '2003 AMC 12A problem 1'},
    {'id': "04_amc12A_p02", 'name': '2004 AMC 12A problem 2'},
  ];//changed by the _getProblems function

  Future<void> _getProblems() async {
    var url = Uri.parse('https://topsoj.com/api/problems');
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('apiKey');
    List<String> solvelist = ['false','none','true'];

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
      'solved': solvelist[_solved.toInt()],
    });

    final jsonData = jsonDecode(response.body);
    if (response.statusCode == 200) {
      setState((){
        //jsonData['data']['solved']=['nt1'];
        _problem_ids = jsonData['data']['problems'];
        _problems_cnt = jsonData['data']['length'][0]['cnt'];
      });
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
          leading: problem['solved']==1 ? Icon(Icons.check, color: Colors.green, size: 24) : (problem['solved']==0 ? Icon(Icons.clear, color: Colors.red, size: 24) : Icon(Icons.book)),
          onTap: () {
            _gotoProblem(problem['id']);
          },
        ),
      );
    }

    return widgets;
  }
  
  Future<void> _makeRequest() async {//this renders the content in the drawer
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
      _weeklylb_render=[];

      for (dynamic lb in weeklylb) {
        _weeklylb_render.add(
          ListTile(
            title: Text(lb['username']),
            subtitle: Text("${lb['total_points']} Points"),
            leading: Text("${lb['rank']}"),
          ),
        );
      }

      if(precommend.length!=0){
        _precommend_render=[];
        for (dynamic pr in precommend){
          if(_precommend_render.length>4){
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
            )
          );
        }
      }

      if (statusCode == 200) {
        _response = 'Welcome, $username';
        _userinfo = result['userdata'];
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
      MaterialPageRoute(builder: (_) => const LoginPage(gotopage: '/home')),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        width: max(min(MediaQuery.of(context).size.width * 0.75, 500),350),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:Column(
            children: [
              const SizedBox(height:30),
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
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => RankingPage()),
                      );
                    },
                    child: const Text("Rankings"),
                  ),
                  ElevatedButton(
                    onPressed: (){
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CachedPage(),
                        ),
                      );
                    },
                    child: const Text('Cached problems'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      onDrawerChanged: (isOpened){
        if (isOpened){
          _makeRequest();
        }
      },
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
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text("Filter by solved: "),
                        Expanded(
                          child: Slider(
                            value: _solved,
                            min: 0,
                            max: 2,
                            divisions: 2,
                            label: ['Incorrect', 'All', 'Correct'][_solved.toInt()],
                            onChanged: (double value) {
                              setState(() {
                                _solved = value;
                                _getProblems();
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _problemIdController,
                            decoration: const InputDecoration(
                              labelText: 'Enter Problem Name/ID',
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (value){
                              _getProblems();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            _page=1;
                            _getProblems();
                          },
                          child: const Icon(Icons.search),
                        ),
                      ],
                    ),
                  
                    const SizedBox(height: 25),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (_page > 1)
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _page = _page - 1;
                                _getProblems();
                              });
                            },
                            child: const Icon(Icons.arrow_back),
                          )
                        else
                          const SizedBox(width: 60), // 占位对齐

                        // 中间页数文字
                        Text('Page $_page/${(_problems_cnt/10).ceil()}', style: const TextStyle(fontSize: 16)),

                        if (_page * 10 < _problems_cnt)
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _page = _page + 1;
                                _getProblems();
                              });
                            },
                            child: const Icon(Icons.arrow_forward),
                          )
                        else
                          const SizedBox(width: 60), // 占位对齐
                      ],
                    ),
                    ..._render(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

