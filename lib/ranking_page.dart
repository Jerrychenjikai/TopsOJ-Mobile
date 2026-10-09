import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:TopsOJ/basic_func.dart';
import 'package:TopsOJ/index_providers.dart';
import 'basic/ui_basic.dart';

class PvpLeaderboardWidget extends StatelessWidget {
  const PvpLeaderboardWidget({super.key});

  Future<List<List<Map<String, dynamic>>>> _fetchLeaderboard() async {
    final response = await fetchPvpLeaderboard();
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List<dynamic> usersList = data['data']['users'];
      return usersList.map((e) =>
        (e as List<dynamic>).map((obj) => Map<String, dynamic>.from(obj)).toList()
      ).toList();
    } else {
      throw Exception(
        'Failed to load leaderboard: ${response.statusCode} ${response.reasonPhrase ?? ""}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<List<Map<String, dynamic>>>>(
      future: _fetchLeaderboard(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

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

        if (tiers.isEmpty) {
          return const Center(child: Text('Play math pvp with someone else to join the leaderboard'));
        }

        final List<Widget> tierWidgets = [];
        int currentRank = 1;

        for (int i = 0; i < tiers.length; i++) {
          final tier = tiers[i];
          if (tier.isEmpty) continue;

          final List<Widget> children = [];
          for (final userMap in tier) {
            children.add(_buildUserTile(userMap, currentRank));
            currentRank++;
          }

          tierWidgets.add(
            ExpansionTile(
              title: Text(
                'Tier ${i + 1}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              collapsedShape: const Border(),
              shape: const Border(),
              children: children,
            ),
          );
        }

        final double topSafeArea = MediaQuery.of(context).padding.top;
        final double bottomSafeArea = MediaQuery.of(context).padding.bottom;

        return ListView(
          // 避让 App Bar + 胶囊栏的高度 (topSafeArea + 68)
          padding: EdgeInsets.only(top: topSafeArea + 68, bottom: 90 + bottomSafeArea),
          children: tierWidgets,
        );
      },
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user, int rank) {
    final int userId = user['id'] as int;
    final String username = user['username'] as String? ?? 'User $userId';

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

    return ListTile(
      leading: leading,
      title: Text(
        username,
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
  final List<String> categories = ['total points', 'rating', 'triangulate', 'mental math', 'math pvp'];

  // 排行榜专用的背景捕获 Key
  final GlobalKey _rankingListKey = GlobalKey();

  List<Widget> _leaderboard_render_list = [];
  Widget _leaderboard_render = const Center(child: CircularProgressIndicator());

  Future<void> _fetch_ranking_data() async {
    if (_ranking_category == "math pvp") {
      _leaderboard_render = const PvpLeaderboardWidget();
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
          _total_page = (data['length'] / 30).ceil();

          for (var user in users) {
            final String username = user['username'];
            final String points = user['points'].toString();

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

            String trailingText = points;
            if (_ranking_category == "total points") {
              trailingText += " pts";
            } else if (_ranking_category == "rating") {
              trailingText += " rating";
            } else if (_ranking_category == "triangulate") {
              trailingText += " pixels";
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
            // 避让顶部 App Bar + 悬浮胶囊栏 (topSafeArea + 68)
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 68,
              bottom: 90 + MediaQuery.of(context).padding.bottom,
            ),
            children: [
              ..._leaderboard_render_list,
            ],
          );
        } else {
          final errorMsg = jsonResponse['error'] ?? jsonResponse['message'] ?? '未知错误';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("failed to fetch ranking: ${response.statusCode} $errorMsg"),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("failed to fetch ranking: ${response.statusCode} ${response.reasonPhrase ?? response.body}"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("failed to fetch ranking: error ${e.toString()}"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final double topSafeArea = MediaQuery.of(context).padding.top;

    ref.listen<String?>(
      mainPageProvider.select((state) => state.ranking_category),
      (prev, next) {
        if (next == null) return;

        if (_ranking_category != next) {
          _ranking_category = next;

          setState(() {
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
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        return LiquidGlassScope(
          repaintBoundaryKey: _rankingListKey,
          child: Stack(
            children: [
              // 1. 底层：纯列表，避让上方遮挡
              NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollUpdateNotification) {
                    LiquidGlassScope.notifyUpdate(context);
                  }
                  return false;
                },
                child: RepaintBoundary(
                  key: _rankingListKey,
                  child: _leaderboard_render,
                ),
              ),

              // 2. 顶层：悬浮在 App Bar 下方的分类选择胶囊
              Positioned(
                top: topSafeArea, // 避开状态栏 height + App Bar 60px
                left: 16,
                right: 16,
                child: LiquidGlassContainer(
                  height: 52,
                  borderRadius: 26,
                  refractionIntensity: 3.5,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        if (_page > 1 && _ranking_category != 'math pvp')
                          IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: () {
                              setState(() {
                                _page--;
                                _fetch_ranking_data();
                              });
                            },
                          )
                        else
                          const SizedBox(width: 48),

                        const Spacer(),

                        SizedBox(
                          width: 140,
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: _ranking_category,
                              hint: const Text('Please choose ranking category'),
                              items: categories.map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value, overflow: TextOverflow.ellipsis),
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
                        ),

                        const Spacer(),

                        if (_page < _total_page && _ranking_category != 'math pvp')
                          IconButton(
                            icon: const Icon(Icons.arrow_forward),
                            onPressed: () {
                              setState(() {
                                _page++;
                                _fetch_ranking_data();
                              });
                            },
                          )
                        else
                          const SizedBox(width: 48),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}