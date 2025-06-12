import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

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


Future<List<Map<String, String>>> get_cached() async{
    final prefs = await SharedPreferences.getInstance();
    final content = prefs.getString('cached problems') ?? "[]";

    List<dynamic> decoded = jsonDecode(content);
    List<Map<String, String>> cached = decoded.map<Map<String, String>>(
        (item) => Map<String, String>.from(item)
    ).toList();
    //map should include: id, problem name, user answer (initially blank)

    return cached;
}

Future<void> save_cached(List<Map<String, String>> cached) async{//save map to disk
    final prefs = await SharedPreferences.getInstance();
    final content = jsonEncode(cached);

    await prefs.setString('cached problems', content);
}

Future<void> delcache(String problemId) async {//delete 
    final String filename = problemId+'.md';
    await deleteMarkdown(filename);

    List<Map<String, String>> cached = await get_cached();
    cached.removeWhere((f) => f['id']==problemId);
    await save_cached(cached);
}

Future<void> cache(String problemId, String problemName, String markdownData) async{
    Map<String, String> newproblem = {'id':problemId, 'name':problemName, 'answer':''}; 
    final String filename = problemId+'.md';
    await delcache(problemId); //delete to make sure no duplicates
    await writeMarkdown(filename, markdownData);

    List<Map<String, String>> cached = await get_cached();
    cached.add(newproblem);
    await save_cached(cached);
}