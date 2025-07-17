import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:TopsOJ/basic_func.dart';

final imgRegex = RegExp(
    r'<img[^>]*src="([^"]+)"[^>]*?width="(\d+)(?:px)?"[^>]*?>',
    caseSensitive: false,
);//same as the one in problem_page.dart

Future<List<String>> imageCount(String problemId) async {
    String markdown = await readMarkdown(problemId+'.md') ?? "";
    
    String cache="";
    List<String> ans=[];
    for (final match in imgRegex.allMatches(markdown)){
        final src = match.group(1)!;
        final final_src;

        final width = match.group(2) != null ? double.tryParse(match.group(2)!) : null;

        if(src[0]=='/') final_src="https://topsoj.com"+src;
        else final_src=src;

        cache=final_src;
        ans.add(cache);
    }
    return ans;
}

String urlToFilename(String problemId, int cnt){
    return problemId+"${cnt}.jpg";
    //currently there is no problemid with illegal characters, but that has to be enforced
}

//Some file operations for storing markdown content
// 获取本地存储路径
Future<String> get localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path; // 应用私有目录
}

Future<File?> saveImage(String url, String problemId, int cnt) async{
    try{
        final response = await http.get(Uri.parse(url));

        if(response.statusCode != 200){
            throw Exception("Failed to download image");
        }

        final path = await localPath;

        final filename = urlToFilename(problemId, cnt);

        final File image = File("${path}/${filename}");
        return await image.writeAsBytes(response.bodyBytes);
    } catch(e) {
        print("Error saving image: $e");
        return null;
    }
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
        print("file deleted: ${filename}");
    }
}


Future<Map<String, Map<String, String>>> get_cached() async {
    final prefs = await SharedPreferences.getInstance();

    final mapContent = prefs.getString('cached map problems') ?? "{}";
    final Map<String, dynamic> decodedMap = jsonDecode(mapContent);
    final Map<String, Map<String, String>> existingMap =
        decodedMap.map((key, value) =>
            MapEntry(key, Map<String, String>.from(value)));

    return existingMap;
}

Future<void> save_cached(Map<String, Map<String, String>> cached) async{//save map to disk
    final prefs = await SharedPreferences.getInstance();
    final content = jsonEncode(cached);

    await prefs.setString('cached map problems', content);
}





//below are the actual function you are going to be using to cache problems

Future<void> delcache(String problemId) async {
    final String filename = problemId + '.md';
    int cnt = (await imageCount(problemId)).length;
    for(int i=0;i<cnt;i++){
        deleteMarkdown(urlToFilename(problemId,i));
    }
    await deleteMarkdown(filename);

    Map<String, Map<String, String>> cached = await get_cached();

    // 从 map 里删除指定 problemId 对应的数据
    cached.remove(problemId);

    // 保存更新后的缓存
    await save_cached(cached);
}

Future<void> cache(String problemId, String problemName, String markdownData, String nxt, String prev) async{ //cache a problem
    Map<String, String> newproblem = {
        'name':problemName, 
        'answer':'', 
        'correct':'${await checkSolved(problemId)}',
        'nxt':nxt,
        'prev':prev
    }; 
    final String filename = problemId+'.md';
    await delcache(problemId); //delete to make sure no duplicates
    await writeMarkdown(filename, markdownData);
    
    List<String> images = await imageCount(problemId);
    for(int i=0;i<images.length;i++){
        print("image saved: ${await saveImage(images[i],problemId,i)}");
    }

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