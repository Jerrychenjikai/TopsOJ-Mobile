import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:TopsOJ/basic_func.dart';
import 'package:TopsOJ/login_page.dart';


class RankingPage extends StatefulWidget {
    const RankingPage({super.key});

    @override
    _RankingState createState() => _RankingState();
}

class _RankingState extends State<RankingPage> {
    Future<void> _fetch_data() async {
        return;
    }

    Widget build(BuildContext context){ 
        return FutureBuilder(
            future: _fetch_data(),
            builder: (context, snapshot){
                if (snapshot.connectionState != ConnectionState.done){
                    return Scaffold(
                        appBar: AppBar(title: const Text("Ranking Page (To be redesigned)")),
                        body: const Center(child: CircularProgressIndicator()),
                    );
                }
                return Scaffold(
                    appBar: AppBar(title: Text("Ranking Page (To be redesigned)")),
                    body: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                            children: [
                                Expanded(
                                    child: ListView(
                                        children: [
                                            Text("User 1"),
                                            Text("User 2"),
                                            Text("User 3"),
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