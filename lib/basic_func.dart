import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

Future<Map<String, dynamic>> checkApiKeyValid(String apiKey) async {
  final uri = Uri.parse('https://topsoj.com/api/confirmlogin');

  try {
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $apiKey'},
    );

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      //print(jsonData);
      return {
        'statusCode': 200,
        'username': jsonData['data']['username'][0]['username'],
        'userdata': jsonData['data']['username'][0],
      };
    } else {
      return {
        'statusCode': response.statusCode,
        'username': null,
        'userdata': null
      };
    }
  } catch (e) {
    return {
      'statusCode': -1,
      'username': null,
      'userdata': null
    };
  }
}

Future<dynamic> checkLogin() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String apiKey = prefs.getString('apiKey') ?? '';
  if (apiKey.isEmpty) return null;
  final response = await checkApiKeyValid(apiKey);
  if (response['statusCode'] == 200){
    response['apikey']=apiKey;
    return response;
  }
  return null;
}

Future<Map<String, dynamic>> login(String username, String password) async {
  final uri = Uri.parse('https://topsoj.com/api/login');

  try {
    final response = await http.post(
      uri,
      headers: {},
      body: {
        'username': username,
        'password': password,
        'platform': "Mobile"
      }
    );

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      print(jsonData);
      return {
        'statusCode': 200,
        'username': jsonData['data']['username'],
        'apikey': jsonData['data']['key']
      };
    } else {
      return {
        'statusCode': response.statusCode,
        'username': null,
        'apikey': null
      };
    }
  } catch (e) {
    return {
      'statusCode': -1,
      'username': null,
      'apikey': null
    };
  }
}

Future<Map<String, dynamic>> submitProblem(String problemId, String answer) async {
    var url = Uri.parse('https://topsoj.com/api/submitproblem');
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('apiKey');

    if (apiKey == null || apiKey.isEmpty) {
        return {'statusCode': -1, 'data': 'API Key Not Found. Log In Again'};
    }

    var headers;
    var response;
    var jsonData;

    try{
        headers = {'Authorization': 'Bearer $apiKey'};
        response = await http.post(url, headers: headers, body: {
            'problem_id': problemId,
            'answer': answer,
    });
        jsonData = jsonDecode(response.body);
    } catch(e){
        return {'statusCode': -1, 'data': 'You are offline'};
    }

    if (response.statusCode == 200) {
        return {'statusCode': 200, 'data': jsonData['data']};
    } else {
        return {'statusCode': response.statusCode, 'data': jsonData['message']};
    }
}

Future<bool> checkSolved(String problemId) async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('apiKey') ?? "";

    // fetch isSolved
    bool solved = false;
    if (apiKey.isNotEmpty) {
      final solvedUrl = Uri.parse('https://topsoj.com/api/problemsolved?id=${problemId}');
      final solvedResponse = await http.get(solvedUrl, headers: {
        'Authorization': 'Bearer $apiKey',
      });
      if (solvedResponse.statusCode == 200) {
        final solvedJson = jsonDecode(solvedResponse.body);
        solved = solvedJson['data']['solved'] == true;
      }
    }

    return solved;
}

Future<List<dynamic>> fetchRecommendedProblems() async {
  final prefs = await SharedPreferences.getInstance();
  final apiKey = prefs.getString('apiKey') ?? "";

  List<dynamic> recommended_problems=[];

  if (apiKey.isNotEmpty) {
    final solvedUrl = Uri.parse('https://topsoj.com/api/problemrecommend');
    final solvedResponse = await http.get(solvedUrl, headers: {
      'Authorization': 'Bearer $apiKey',
    });
    if (solvedResponse.statusCode == 200) {
      final solvedJson = jsonDecode(solvedResponse.body);
      recommended_problems = solvedJson['data'];
    }
  }

  return recommended_problems;
}

Future<List<dynamic>> fetchWeeklylb() async {
  final prefs = await SharedPreferences.getInstance();
  final apiKey = prefs.getString('apiKey') ?? "";

  List<dynamic> weeklylb=[];

  if (apiKey.isNotEmpty) {
    final solvedUrl = Uri.parse('https://topsoj.com/api/weeklylb');
    final solvedResponse = await http.get(solvedUrl, headers: {
      'Authorization': 'Bearer $apiKey',
    });
    if (solvedResponse.statusCode == 200) {
      final solvedJson = jsonDecode(solvedResponse.body);
      weeklylb = solvedJson['data']['leaderboard'];
    }
  }

  return weeklylb;
}

double min(double a, double b){
  if(a<b) return a;
  return b;
}

double max(double a,double b){
  if(a<b) return b;
  return a;
}

Future<void> launchURL(BuildContext context, String url) async {
  final uri = Uri.parse(url);
  if (!await launchUrl(uri)) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Cannot open URL: $url')),
    );
  }
}