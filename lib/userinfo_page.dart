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


class UserinfoPage extends StatefulWidget {
    const UserinfoPage({super.key});

    @override
    _UserinfoPageState createState() => _UserinfoPageState();
}

class _UserinfoPageState extends State<UserinfoPage> {
    Map<String, dynamic> _userinfo={};

    Future<void> _fetch_data() async {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        String apiKey = prefs.getString('apiKey') ?? '';

        Map<String, dynamic> data= await checkApiKeyValid(apiKey);
        if(data['statusCode']!=200){
            Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => LoginPage(gotopage: '/userinfo')),
            );
        }
        _userinfo = data['userdata'];
        print(_userinfo);
        return;
    }

    Widget build(BuildContext context){ 
        return FutureBuilder(
            future: _fetch_data(),
            builder: (context, snapshot){
                if (snapshot.connectionState != ConnectionState.done){
                    return Scaffold(
                        appBar: AppBar(title: const Text("User: ")),
                        body: const Center(child: CircularProgressIndicator()),
                    );
                }
                return Scaffold(
                    appBar: AppBar(title: Text("User: "+_userinfo['username'])),
                    body: Column(
                        children: [
                            Expanded(child: Text("Join date: "+_userinfo['join_date'])),
                        ],
                    ),
                );
            },
        );
    }
}