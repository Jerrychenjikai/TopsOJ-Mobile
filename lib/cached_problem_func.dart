import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:TopsOJ/basic_func.dart';

//Some file operations for storing markdown content
// 获取本地存储路径
Future<String> get localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path; // 应用私有目录
}

// 获取文件对象
Future<File> localFile(String filename) async {
    final path = await localPath;
    return File('$path/$filename');
}

// 写入 markdown 内容
Future<File> writeMarkdown(String filename, String content) async {
    final file = await localFile(filename);
    return file.writeAsString(content);
}

// 读取 markdown 内容
Future<String?> readMarkdown(String filename) async {
    try {
        final file = await localFile(filename);
        return await file.readAsString();
    } catch (e) {
        return null; // 文件不存在或读取失败
    }
}

// 删除文件
Future<void> deleteMarkdown(String filename) async {
    final file = await localFile(filename);
    if (await file.exists()) {
        await file.delete();
    }
}


Future<Map<String, Map<String, String>>> get_cached() async {
    final prefs = await SharedPreferences.getInstance();

    // Step 1: 读取旧的列表结构
    final content = prefs.getString('cached problems') ?? "[]";
    final List<dynamic> decodedList = jsonDecode(content);
    final List<Map<String, String>> oldList = decodedList
        .map<Map<String, String>>((item) => Map<String, String>.from(item))
        .toList();

  // Step 2: 转换旧列表为 Map
    Map<String, Map<String, String>> listAsMap = {
        for (var item in oldList)
            if (item.containsKey('id')) item['id']!: item
    };

  // Step 3: 读取原本已存在的 map 缓存
    final mapContent = prefs.getString('cached map problems') ?? "{}";
    final Map<String, dynamic> decodedMap = jsonDecode(mapContent);
    final Map<String, Map<String, String>> existingMap =
        decodedMap.map((key, value) =>
            MapEntry(key, Map<String, String>.from(value)));

  // Step 4: 合并两个 Map（listAsMap 优先）
    final mergedMap = {...existingMap, ...listAsMap};

  // Step 5: 清空旧结构
    await prefs.remove('cached problems');

    return mergedMap;
}

Future<void> save_cached(Map<String, Map<String, String>> cached) async{//save map to disk
    final prefs = await SharedPreferences.getInstance();
    final content = jsonEncode(cached);

    await prefs.setString('cached map problems', content);
}





//below are the actual function you are going to be using to cache problems

Future<void> delcache(String problemId) async {
    final String filename = problemId + '.md';
    await deleteMarkdown(filename);

    Map<String, Map<String, String>> cached = await get_cached();

    // 从 map 里删除指定 problemId 对应的数据
    cached.remove(problemId);

    // 保存更新后的缓存
    await save_cached(cached);
}

Future<void> cache(String problemId, String problemName, String markdownData) async{ //cache a problem
    Map<String, String> newproblem = {'name':problemName, 'answer':'', 'correct':'${await checkSolved(problemId)}'}; 
    final String filename = problemId+'.md';
    await delcache(problemId); //delete to make sure no duplicates
    await writeMarkdown(filename, markdownData);

    Map<String, Map<String, String>> cached = await get_cached();
    cached[problemId]=newproblem;
    await save_cached(cached);
}

Future<bool> is_cached(String problemId) async { //check if a problem is cached
    Map<String, Map<String, String>> problem = await get_cached();
    return problem.containsKey(problemId);
}

Future<Map<String, String>> cached_info(String problemId) async { //obtain the information of a cached problem
    Map<String, Map<String, String>> problem = await get_cached();
    return problem[problemId] ?? {};
}

Future<void> record(String problemId, String key, String value) async {
    if(await is_cached(problemId)){
        Map<String, Map<String, String>> problem = await get_cached();
        
        (problem[problemId] ?? {})[key]=value;

        await save_cached(problem);
        return;
    }
    return;
}