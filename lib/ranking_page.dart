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
    String _ranking_category = "total points";
    final List<String> categories = ['total points','rating','triangulate','mental math'];
    
    List<Widget> _leaderboard_render = [];

    Future<void> _fetch_ranking_data() async {
      _leaderboard_render = [];

      final leaderboard = [1,2,3,4];
      for (dynamic lb in leaderboard) {
        _leaderboard_render.add(
          ListTile(
            title: Text("name"),
            trailing: Text(
              "${_ranking_category} point",
              style: const TextStyle(fontSize: 15),
            ),
            leading: Text(lb.toString()),
          ),
        );
      }
      return;
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
                    return Scaffold(
                        appBar: AppBar(title: const Text("Ranking Page (To be redesigned)")),
                        body: const Center(child: CircularProgressIndicator()),
                    );
                }
                return SafeArea(
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                            children: [
                                DropdownButton<String>(
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