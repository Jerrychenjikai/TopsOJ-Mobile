import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:TopsOJ/basic_func.dart';
import 'package:TopsOJ/index_providers.dart';

class RankingPage extends ConsumerStatefulWidget {
    const RankingPage({super.key});

    @override
    _RankingState createState() => _RankingState();
}

class _RankingState extends ConsumerState<RankingPage> {
    int _page = 1;
    int _total_page = 1;
    String _ranking_category = "total points";
    final List<String> categories = ['total points','rating','triangulate','mental math'];
    
    List<Widget> _leaderboard_render = [];

    Future<void> _fetch_ranking_data() async {
      _leaderboard_render = [];

      try {
        final url = Uri.parse('https://topsoj.com/api/rankings');
        SharedPreferences prefs = await SharedPreferences.getInstance();
        String? apiKey = prefs.getString('apiKey');
        var headers = {'Authorization': 'Bearer $apiKey'};

        final response = await http.post(
          url,
          headers: headers,
          body: {
            'page': _page.toString(),
            'leaderboard_type': _ranking_category,
          },
        );

        if (response.statusCode == 200) {
          final Map<String, dynamic> jsonResponse = json.decode(response.body);

          if (jsonResponse['status'] == 'success') {
            final data = jsonResponse['data'];
            final List<dynamic> users = data['users'];

            _leaderboard_render = [];
            int currentRank = (_page - 1) * 30 + 1;
            _total_page = (data['length']/30).ceil();

            for (var user in users) {
              final String username = user['username'];
              final String points = user['points'].toString();

              // 前三名用奖牌图标
              Widget leading;
              if (currentRank <= 3) {
                Color medalColor;
                switch (currentRank) {
                  case 1:
                    medalColor = Colors.amber;
                    break;
                  case 2:
                    medalColor = Colors.grey.shade400;
                    break;
                  case 3:
                    medalColor = Colors.brown.shade400;
                    break;
                  default:
                    medalColor = Colors.grey;
                }
                leading = Icon(
                  Icons.emoji_events_rounded,
                  color: medalColor,
                  size: 35,
                );
              } else {
                leading = Container(
                  width: 35,
                  alignment: Alignment.center,
                  child: Text(
                    currentRank.toString(),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                );
              }

              // 不同榜单的 trailing 显示文字
              String trailingText = points;
              if (_ranking_category == "total points") {
                trailingText += " pts";
              } else if (_ranking_category == "rating") {
                trailingText += " rating";
              } else if (_ranking_category == "triangulate") {
                trailingText += " pixels"; // triangulate / mental math 都是 score
              } else {
                trailingText += " s";
              }

              _leaderboard_render.add(
                ListTile(
                  leading: leading,
                  title: Text(
                    username,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  trailing: Text(
                    trailingText,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  dense: true,
                ),
              );

              currentRank++;
            }
          } else {
            // 后端返回了错误状态
            final errorMsg = jsonResponse['error'] ?? jsonResponse['message'] ?? '未知错误';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("failed to fetch ranking: ${response.statusCode} $errorMsg"),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        } else {
          // HTTP 错误
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("failed to fetch ranking: ${response.statusCode} ${response.reasonPhrase ?? response.body}"),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      } catch (e) {
        // 网络异常、解析异常等
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("failed to fetch ranking: error ${e.toString()}"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }

    Widget build(BuildContext context){ 
        ref.listen<String?>(
          mainPageProvider.select((state) => state.ranking_category),
          (prev, next) {
            if (next == null) return;

            if (_ranking_category != next) {
              _ranking_category = next;
              print(next);

              setState((){
                _fetch_ranking_data();
              });
            }

            ref.read(mainPageProvider.notifier).update(
              (state) => state.copyWith(ranking_category: null),
            );
          },
        );
        return FutureBuilder(
            future: _fetch_ranking_data(),
            builder: (context, snapshot){
                if (snapshot.connectionState != ConnectionState.done){
                    return Center(
                        child: const Center(child: CircularProgressIndicator()),
                    );
                }
                return SafeArea(
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                            children: [
                                Row(
                                  children: [
                                    if (_page > 1)
                                      ElevatedButton(
                                        onPressed: () {
                                          setState(() {
                                            _page--;
                                            _fetch_ranking_data();
                                          });
                                        },
                                        child: const Icon(Icons.arrow_back),
                                      ),

                                    const Spacer(),   // 关键：让下拉菜单始终居中

                                    // 原 DropdownButton（完全不变）
                                    SizedBox(
                                      width: 150, // 想要的宽度
                                      child: DropdownButton<String>(
                                        isExpanded: true,
                                        value: _ranking_category,
                                        hint: Text('Please choose ranking category'),
                                        underline: Container(
                                          height: 2,
                                          color: Theme.of(context).primaryColor,
                                        ),
                                        items: categories.map((String value) {
                                          return DropdownMenuItem<String>(
                                            value: value,
                                            child: Text(value),
                                          );
                                        }).toList(),
                                        onChanged: (String? newValue) {
                                          setState(() {
                                            _ranking_category = newValue ?? "total points";
                                            _fetch_ranking_data();
                                          });
                                        },
                                      ),
                                    ),

                                    const Spacer(),   // 关键：让下拉菜单始终居中

                                    if (_page < _total_page)
                                      ElevatedButton(
                                        onPressed: () {
                                          setState(() {
                                            _page++;
                                            _fetch_ranking_data();
                                          });
                                        },
                                        child: const Icon(Icons.arrow_forward),
                                      ),
                                  ],
                                ),
                                Expanded(
                                  child: ListView(
                                    children: [
                                      ..._leaderboard_render,
                                    ],
                                  ),
                                ),
                            ],
                        ),
                    ),
                );
            },
        );
    }
}