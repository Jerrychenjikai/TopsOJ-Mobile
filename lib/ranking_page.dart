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

class PvpLeaderboardWidget extends StatelessWidget {
  const PvpLeaderboardWidget({super.key});

  /// 异步拉取并解析排行榜数据
  Future<List<List<int>>> _fetchLeaderboard() async {
    final response = await fetchPvpLeaderboard();
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List<dynamic> usersList = data['data']['users'];
      return usersList.map((e) => List<int>.from(e)).toList();
    } else {
      throw Exception(
        'Failed to load leaderboard: ${response.statusCode} ${response.reasonPhrase ?? ""}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<List<int>>>(
      future: _fetchLeaderboard(),
      builder: (context, snapshot) {
        // 加载中
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // 错误处理：显示错误文字 + 弹出 SnackBar
        if (snapshot.hasError) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to fetch ranking: ${snapshot.error}'),
                backgroundColor: Colors.redAccent,
              ),
            );
          });
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'Failed to load leaderboard.\n${snapshot.error}',
                style: const TextStyle(color: Colors.red, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final tiers = snapshot.data!;

        // 空数据
        if (tiers.isEmpty) {
          return const Center(child: Text('Play math pvp with someone else to join the leaderboard'));
        }

        // 构建分层卡片列表
        final List<Widget> tierWidgets = [];
        int currentRank = 1; // 全局序号，跨层递增

        for (int i = 0; i < tiers.length; i++) {
          final tier = tiers[i];
          if (tier.isEmpty) continue;

          final List<Widget> children = [];
          for (final userId in tier) {
            children.add(_buildUserTile(userId, currentRank));
            currentRank++;
          }

          tierWidgets.add(
            ExpansionTile(
              title: Text(
                'Tier ${i + 1}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              collapsedShape: const Border(), // 收起时无边框
              shape: const Border(),          // 展开时无边框
              children: children,
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.only(bottom: 16),
          children: tierWidgets,
        );
      },
    );
  }

  /// 构建单个用户条目，样式与原有排行榜保持一致
  Widget _buildUserTile(int userId, int rank) {
    // 奖牌图标或数字序号
    Widget leading;
    if (rank <= 3) {
      Color medalColor;
      switch (rank) {
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
          rank.toString(),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
      );
    }

    // 标题目前使用用户 ID，未来可替换为真实用户名
    return ListTile(
      leading: leading,
      title: Text(
        'User $userId',
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
      dense: true,
    );
  }
}

class RankingPage extends ConsumerStatefulWidget {
    const RankingPage({super.key});

    @override
    _RankingState createState() => _RankingState();
}

class _RankingState extends ConsumerState<RankingPage> {
    int _page = 1;
    int _total_page = 1;
    String _ranking_category = "total points";
    final List<String> categories = ['total points','rating','triangulate','mental math', 'math pvp'];
    
    List<Widget> _leaderboard_render_list = [];
    Widget _leaderboard_render = const Center(child: CircularProgressIndicator());

    Future<void> _fetch_ranking_data() async {
      if(_ranking_category == "math pvp"){
        _leaderboard_render = PvpLeaderboardWidget();
        return;
      }

      _leaderboard_render_list = [];

      try {
        final response = await fetchRanking(_page, _ranking_category);

        if (response.statusCode == 200) {
          final Map<String, dynamic> jsonResponse = json.decode(response.body);

          if (jsonResponse['status'] == 'success') {
            final data = jsonResponse['data'];
            final List<dynamic> users = data['users'];

            _leaderboard_render_list = [];
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

              _leaderboard_render_list.add(
                ListTile(
                  leading: leading,
                  title: Text(
                    username,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
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
            _leaderboard_render = ListView(
              children: [
                ..._leaderboard_render_list,
              ],
            );
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
                                    if (_page > 1 && _ranking_category != 'math pvp')
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

                                    if (_page < _total_page && _ranking_category != 'math pvp')
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
                                  child: _leaderboard_render,
                                ),
                            ],
                        ),
                    ),
                );
            },
        );
    }
}