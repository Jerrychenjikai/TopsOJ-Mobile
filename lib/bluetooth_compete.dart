//basic modules
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;
import 'dart:math';
import 'dart:async';
import "dart:convert";
import 'dart:typed_data';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:uuid/uuid.dart';

//frontend modules
import 'package:flutter/material.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

//backend modules
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ble_peripheral/ble_peripheral.dart' as ble_peri;

import 'package:TopsOJ/basic_func.dart';
import 'package:TopsOJ/login_page.dart';
import 'package:TopsOJ/problem_page.dart';

sealed class BattleState {
  const BattleState();
}

class Idle extends BattleState {}

class Scanning extends BattleState {}

class Connecting extends BattleState {}

class Ready extends BattleState {}

class Playing extends BattleState {
  final int currentQuestionId;//index from a list
  const Playing(this.currentQuestionId);
}

class Result extends BattleState {
  final int myScore;
  final int peerScore;
  const Result(this.myScore, this.peerScore);
}

class BattleController extends StateNotifier<BattleState> {
  BattleController() : super(Idle());

  String? peerDeviceId; // 可选保留，如果后续需要
  bool isHost = false;
  BluetoothDevice? peerDevice;
  BluetoothCharacteristic? deviceIdChar; // 可选保留，如果后续GATT需要
  final Uuid _uuid = const Uuid();

  bool _alreadyStopped = false;

  final Guid serviceUuid = Guid('05216c6d-7508-44c5-ae43-55cc4d06cbef');
  final Guid charUuid = Guid('12345678-1234-5678-1234-567812345678'); // 自定义char UUID

  // ==================== 新增：协议层 ====================
  String? peerCentralId;                    // Host 专用：记录 Client 的 deviceId
  StreamSubscription<List<int>>? _notifSub; // Client 专用：监听通知
  StreamSubscription? _scanSub; // 新增这个

  // ==================== function to call snackbar ====================
  void Function(String message)? showSnackBar;

  // ==================== match data ====================
  List<String> problem_ids = [];
  int numProblems = 0;//IMPORTANT: could not be greater than 10
  int current_problem_index = 0;
  List<bool> self_finish = [];
  List<bool> self_correct = [];
  List<bool> opp_finish = [];
  List<bool> opp_correct = [];
  List<int> self_time_taken = [];
  List<int> opp_time_taken = [];
  int question_start_time = 0;

  // 统一发送（Host 用 notify，Client 用 writeWithResponse）
  Future<void> _sendMessage(Map<String, dynamic> payload) async {
    await Future.delayed(Duration(milliseconds: 100));
    final jsonStr = jsonEncode(payload);
    final data = Uint8List.fromList(utf8.encode(jsonStr));

    try {
      if (isHost) {
        await ble_peri.BlePeripheral.updateCharacteristic(
          characteristicId: charUuid.toString(),
          value: data,
          // deviceId: peerCentralId,   // 只发给特定设备（可选，单人匹配可省略）
        );
        print('🟢 Host 发送: ${payload['type']}');
      } else if (deviceIdChar != null) {
        await deviceIdChar!.write(data, withoutResponse: false);
        print('🟢 Client 发送: ${payload['type']}');
      }
    } catch (e) {
      print('❌ 发送失败: $e');
      showSnackBar?.call('Failed to send message. Please quit this page and restart');
    }
  }

  // 统一接收处理
  void _handleIncomingMessage(Uint8List rawData, {String? fromDeviceId}) {
    try {
      final jsonStr = utf8.decode(rawData);
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final type = map['type'] as String;

      print('📥 收到消息: $type ${fromDeviceId != null ? "from $fromDeviceId" : ""}');

      if (fromDeviceId != null) peerCentralId = fromDeviceId; // Host 记录对端

      switch (type) {
        case 'MATCH_INIT':
          if (!isHost) handleMatchInit(map);
          break;
        case 'ACK_MATCH_INIT':
          if (isHost) handleAckMathInit();
          break;
        case 'PROBLEM_IDS':
          if (!isHost) handleProblemIds(map);
          break;
        case 'ACK_PROBLEM_IDS':
          if (isHost) handleAckProblemIds();
          break;
        case 'START':
          //todo: add another back and forth to ensure problem is loaded before displaying
          if (!isHost) handleStart(map);
          break;
        case 'ANSWER':
          handleAnswer(map);
          break;
        case 'ACK_ANSWER':
          handleAnswerAck();
          break;
        case 'NEXT':
          if (!isHost) handleNext(map);
          break;
        case 'END':
          handleEnd(map);
          break;
        default:
          print('未知消息类型: $type');
      }
    } catch (e) {
      print('消息解析失败: $e');
      showSnackBar?.call('Failed to analyze received message. Please quit this page and restart');
    }
  }

  // =================== 双方都需要用到的函数 ================
  // 双方给对方提交答案示例（在 PlayingView 的提交按钮里调用）
  Future<void> sendAnswer(int qIndex, bool result) async {
    if(self_finish[qIndex]) return;

    int timeTakenMs = DateTime.now().millisecondsSinceEpoch - question_start_time;

    self_finish[qIndex] = true;
    self_correct[qIndex] = result;
    self_time_taken[qIndex] = timeTakenMs;
    await _sendMessage({
      'type': 'ANSWER',
      'qIndex': qIndex,//int
      'result': result,//bool: 做没做对
      'timeTakenMs': timeTakenMs,//int
    });

    if (isHost && self_finish[current_problem_index] && opp_finish[current_problem_index]){
      print("received all answers for problem ${current_problem_index}");
      print("host correct: ${self_correct[current_problem_index]}");
      print("client correct: ${opp_correct[current_problem_index]}");
      if(current_problem_index<numProblems-1) await sendNext(current_problem_index+1);
      else await sendEnd();
    }
  }

  Future<void> handleAnswer(Map<String, dynamic> data) async {
    print('收到对方提交: ${data['result']}');

    final qIndex = data['qIndex'];
    final result = data['result'];
    final timeTaken = data['timeTakenMs'];

    if(opp_finish[qIndex]){
      print("重复提交");
      return;
    }

    showSnackBar?.call('对手已提交：第 $qIndex 题 — $result （${timeTaken ?? 0} ms）');

    opp_finish[qIndex] = true;
    opp_correct[qIndex] = result;
    opp_time_taken[qIndex] = timeTaken;

    await _sendMessage({
      'type': "ACK_ANSWER",
    });

    if (isHost && self_finish[current_problem_index] && opp_finish[current_problem_index]){
      print("received all answers for problem ${current_problem_index}");
      print("host correct: ${self_correct[current_problem_index]}");
      print("client correct: ${opp_correct[current_problem_index]}");
      if(current_problem_index<numProblems-1) await sendNext(current_problem_index+1);
      else await sendEnd();
    }
  }

  Future<void> handleAnswerAck() async {
    print("opponent received my answer");
  }

  // ==================== Client的收/发消息的函数 ====================
  Future<void> handleMatchInit(Map<String, dynamic> data) async {
    // TODO: 这里可以弹出对话框让用户确认，暂时自动接受
    print('收到 MATCH_INIT: ${data['numQuestions']}题');
    await _sendMessage({'type': 'ACK_MATCH_INIT'});
    // 后续流程由 Host 推动
  }

  Future<void> handleProblemIds(Map<String, dynamic> data) async {
    print('收到题目ID列表: ${data['ids']}');
    // 保存到本地变量，后面 fetch 题目用
    problem_ids = (data['ids'] as List<dynamic>).cast<String>();
    numProblems = problem_ids.length;
    for(int i=0; i<numProblems; i++){
      self_finish.add(false);
      self_correct.add(false);
      opp_finish.add(false);
      opp_correct.add(false);
      self_time_taken.add(0);
      opp_time_taken.add(0);
    }
    await _sendMessage({'type': 'ACK_PROBLEM_IDS'});
  }

  void handleStart(Map<String, dynamic> data) {
    print('比赛开始！startAt=${data['startAt']}');
    current_problem_index = 0;
    state = const Playing(0);
    question_start_time = DateTime.now().millisecondsSinceEpoch;
  }

  void handleNext(Map<String, dynamic> data) {
    final idx = data['qIndex'] as int;
    print('下一题: $idx');
    current_problem_index = idx;
    state = Playing(idx);
    question_start_time = DateTime.now().millisecondsSinceEpoch;
  }

  void handleEnd(Map<String, dynamic> data) {
    print('比赛结束，胜者: ${data['winner']}');
    finish(data['clientScore'] ?? 0, data['hostScore'] ?? 0);
  }

  // ==================== Host的收/发消息的函数 ====================
  Future<void> initiateMatch({
    required int numQuestions,
    required int pointInterval,
  }) async {
    if (!isHost) return;
    final matchToken = _uuid.v4();
    numProblems = numQuestions;
    await _sendMessage({
      'type': 'MATCH_INIT',
      'hostUid': '你的hostUid', // 从登录拿
      'numQuestions': numQuestions,
      'pointInterval': pointInterval,
      'matchToken': matchToken,
    });
  }

  Future<void> handleAckMathInit() async {
    print('Client 已接受，开始准备题目...');

    //接受题目
    final jsonData = await fetchFilterProblems(
      "",
      "false",
      '0',
    );

    if (jsonData['statusCode'] == 200) {
      if(jsonData['data']['problems'].length < numProblems){
        showSnackBar?.call(
          'problem filter error: only ${jsonData['data']['problems'].length} questions satisfy your filter'
        );
        return;
      }
      for(int i=0; i<numProblems; i++){
        problem_ids.add(jsonData['data']['problems'][i]['id']);
      }
    } else {
      showSnackBar?.call(
        'Search Error: ${jsonData['statusCode']} ${jsonData['message']}'
      );
      reset();
      return;
    }
    
    for(int i=0; i<numProblems; i++){
      self_finish.add(false);
      self_correct.add(false);
      opp_finish.add(false);
      opp_correct.add(false);
      self_time_taken.add(0);
      opp_time_taken.add(0);
    }
    sendProblemIds(problem_ids);
  }

  Future<void> sendProblemIds(List<String> ids) async {
    if (!isHost) return;
    await _sendMessage({'type': 'PROBLEM_IDS', 'ids': ids});
  }

  Future<void> handleAckProblemIds() async {
    if (!isHost) return;
    sendStart();
  }

  Future<void> sendStart() async {
    if (!isHost) return;
    await _sendMessage({'type': 'START'});
    current_problem_index = 0;
    state = const Playing(0);
    question_start_time = DateTime.now().millisecondsSinceEpoch;
  }

  Future<void> sendNext(int qIndex) async {
    if (!isHost) return;
    current_problem_index = qIndex;
    state = Playing(qIndex);
    await _sendMessage({'type': 'NEXT', 'qIndex': qIndex});
    question_start_time = DateTime.now().millisecondsSinceEpoch;
  }

  Future<void> sendEnd() async {
    if (!isHost) return;

    //TODO: calculate scores here based on correct and timetaken
    int hostScore = 0;
    int clientScore = 0;

    for(int i=0;i<numProblems;i++){
      hostScore += (self_correct[i] ? 1 : 0) * (10 + max(0, 5-(self_time_taken[i]/1000)).toInt());
      clientScore += (opp_correct[i] ? 1 : 0) * (10 + max(0, 5-(opp_time_taken[i]/1000)).toInt());
    }

    finish(hostScore, clientScore);

    await _sendMessage({
      'type': 'END', 
      'hostScore': hostScore, 
      'clientScore': clientScore
    });
  }

  Future<void> startHost() async {
    if (await Permission.bluetooth.request().isDenied ||
        await Permission.bluetoothScan.request().isDenied ||
        await Permission.bluetoothAdvertise.request().isDenied ||
        await Permission.bluetoothConnect.request().isDenied) {
      print('Bluetooth permissions denied');
      showSnackBar?.call('Please grant bluetooth permission');
      reset();
      return;
    }

    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt <= 30) {
        if (await Permission.location.request().isDenied) {
          print('Location permissions denied');
          showSnackBar?.call('Please turn on location');
        reset();
          return;
        }
      }
    }

    final isOn = await FlutterBluePlus.isOn;
    if (!isOn) {
      print('Bluetooth is off');
      showSnackBar?.call('Please turn on bluetooth');
      reset();
      return;
    }

    // 初始化peripheral
    await ble_peri.BlePeripheral.initialize();

    // 添加服务和特性（保留原GATT结构，但移除交换逻辑）
    await ble_peri.BlePeripheral.addService(
      ble_peri.BleService(
        uuid: serviceUuid.toString(),
        primary: true,
        characteristics: [
          ble_peri.BleCharacteristic(
            uuid: charUuid.toString(),
            properties: [
              ble_peri.CharacteristicProperties.read.index,
              ble_peri.CharacteristicProperties.write.index,
              ble_peri.CharacteristicProperties.notify.index,
            ],
            permissions: [
              ble_peri.AttributePermissions.writeable.index,
              ble_peri.AttributePermissions.readable.index,
            ],
            // 注意：**不要** 在这里传入 value（initial cached value），
            // 否则 iOS CoreBluetooth 会报：Characteristics with cached values must be read-only
          ),
        ],
      ),
    );

    // 设置连接状态监听（Android only）
    if (Platform.isAndroid) {
      ble_peri.BlePeripheral.setConnectionStateChangeCallback((remoteDeviceId, connected) {
        print("connection detected - Android");
        if (connected) {
          print('Connected as peripheral by $remoteDeviceId (Android)');
          onDeviceFound(null);
        } else {
          print('Disconnected');
          showSnackBar?.call('Disconnected');
          reset();
        }
      });
    } else {
      // iOS: 使用订阅变化作为连接代理
      ble_peri.BlePeripheral.setCharacteristicSubscriptionChangeCallback((remoteDeviceId, characteristicId, subscribed, centralId, [name]) {
        print("connection detected - iOS");
        if (subscribed && characteristicId == charUuid.toString()) {
          print('Central subscribed to char from $remoteDeviceId (iOS)');
          onDeviceFound(null);
        } else if (!subscribed) {
          print('Central unsubscribed (disconnected?)');
          showSnackBar?.call('Client is disconnected');
          reset();
        }
      });
    }

    // this is the function to cope with write requests
    ble_peri.BlePeripheral.setWriteRequestCallback((String remoteDeviceId, String characteristicUuid, int offset, Uint8List? value) {
      if (value != null && characteristicUuid == charUuid.toString()) {
        _handleIncomingMessage(value, fromDeviceId: remoteDeviceId);
      }
      return ble_peri.WriteRequestResult(status: 0);
    });

    ble_peri.BlePeripheral.setReadRequestCallback(
      (String remoteDeviceId, String characteristicUuid, int offset, Uint8List? value) {
        print('Read request received:');
        print('  from: $remoteDeviceId');
        print('  char: $characteristicUuid');
        print('  offset: $offset');
        print('  value (should be null for read): $value');

        // 返回成功响应（即使是空值也行，让 iOS 的自动 read 通过）
        return ble_peri.ReadRequestResult(
          value: Uint8List(0),   // 空字节数组
          offset: offset,        // 通常保持原 offset
          status: 0,             // 0 = GATT_SUCCESS
        );
      },
    );

    // Start advertising
    try {
      await ble_peri.BlePeripheral.startAdvertising(
        services: [serviceUuid.toString()],
        localName: "TopsOJBG",
      );
      print('Advertising started');
    } catch (e) {
      print('Advertising failed: $e');
      showSnackBar?.call('Failed to start bluetooth advertising');
      reset();
    }

    isHost = true;
    state = Scanning(); // 或自定义为 Advertising()，但复用原state
  }

  Future<void> startScan() async {
    // Request permissions (原有)
    if (await Permission.bluetooth.request().isDenied ||
        await Permission.bluetoothScan.request().isDenied ||
        await Permission.bluetoothAdvertise.request().isDenied ||
        await Permission.bluetoothConnect.request().isDenied) {
      print('Bluetooth permissions denied');
      showSnackBar?.call('Please grant bluetooth permission');
      reset();
      return;
    }

    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt <= 30) {
        if (await Permission.location.request().isDenied) {
          print('Location permissions denied');
          showSnackBar?.call('Please turn on location');
          reset();
          return;
        }
      }
    }

    final isOn = await FlutterBluePlus.isOn;
    if (!isOn) {
      print('Bluetooth is off');
      showSnackBar?.call('Please turn on bluetooth');
      reset();
      return;
    }

    isHost = false;
    state = Scanning();

    // Start scanning
    await FlutterBluePlus.startScan(
      timeout: Duration(seconds: 30),
      androidScanMode: AndroidScanMode.lowLatency,
      androidUsesFineLocation: true,
    );

    // Listen to scan results
    _scanSub = FlutterBluePlus.scanResults.listen((results) async {
      for (ScanResult r in results) {
        final adv = r.advertisementData;
        print('''
          === Device Found ===
          Name: ${r.device.platformName}
          LocalName: ${adv.localName}
          Services: ${adv.serviceUuids}
          Manufacturer Data: ${adv.manufacturerData}
          TxPower: ${adv.txPowerLevel}
          ''');
        
        if (adv.serviceUuids.contains(serviceUuid) ||
            (adv.localName?.contains("TopsOJBG") ?? false)){
          
          await FlutterBluePlus.stopScan();
          print("found someone: $r");

          // 直接连接（移除交换逻辑）
          peerDevice = r.device;
          try {
            await peerDevice!.connect(
              license: License.free,
              timeout: const Duration(seconds: 10),
              ).timeout(
                const Duration(seconds: 12),
                onTimeout: () => throw TimeoutException('Connect timeout after 12s'),
              );
            print('Connected as central');

            // Discover services and char（保留，如果后续需要）
            List<BluetoothService> services = await peerDevice!.discoverServices();
            BluetoothService service = services.firstWhere((s) => s.uuid == serviceUuid);
            deviceIdChar = service.characteristics.firstWhere((c) => c.uuid == charUuid);

            try {
              await deviceIdChar!.setNotifyValue(true);
              print('Subscribed to characteristic');

              // ★★★ 新增：监听通知
              _notifSub = deviceIdChar!.onValueChangedStream.listen((value) {
                _handleIncomingMessage(Uint8List.fromList(value));
              });
            } catch (e) {
              print('Subscription failed: $e');
              showSnackBar?.call('Connection failed');
              reset();
              return;
            }

            // 直接调用onDeviceFound
            await onDeviceFound(peerDevice!);
          } catch (e) {
            print('Connection failed: $e');
            showSnackBar?.call('Connection failed');
            reset();
          }
        }
      }
    });
  }

  Future<void> onDeviceFound(BluetoothDevice? device) async {
    print("Found Device, connecting");
    // Stop scanning and advertising to save battery and avoid conflicts
    if (!isHost) {
      await FlutterBluePlus.stopScan();
    }
    if (isHost) {
      await ble_peri.BlePeripheral.stopAdvertising();
    }

    if (device == null) {
      // peripheral模式下处理（host）
      state = Connecting();
      onReady();
      return;
    }

    if (!isHost) {
      // Central mode (client) - we've already awaited connect() in startScan,
      // so check current state instead of listening for changes
      try {
        final currentState = await device.connectionState.first;  // Get current state (waits if needed)
        print('Current connection state: $currentState');
        if (currentState == BluetoothConnectionState.connected) {
          print('Central mode: already connected, proceeding to onReady');
          onReady();
        } else {
          print('Unexpected state: $currentState - retrying connect');
          await device.connect(license: License.free);  // Retry if needed
          onReady();
        }
      } catch (e) {
        print('Connection state check failed: $e');
        showSnackBar?.call('Connection failed');
        reset();
      }

      // Still set up listener for *future* changes (e.g., disconnects)
      device.connectionState.listen((BluetoothConnectionState bluetoothState) {
        print('Connection state changed: $bluetoothState');
        if (bluetoothState == BluetoothConnectionState.connected) {
          // Handle reconnects if needed
        } else if (bluetoothState == BluetoothConnectionState.disconnected) {
          print('Disconnected');
          showSnackBar?.call('disconnected');
          reset();
        }
      });
    }
  }

  void onReady() {
    state = Ready();
  }

  void finish(int my, int peer) {
    state = Result(my, peer);
  }

  // 立即同步的清理（供 dispose 调用）
  void stopSync() {
    if (_alreadyStopped) return;
    _alreadyStopped = true;
    _notifSub?.cancel();
    _notifSub = null;
    _scanSub?.cancel();
    _scanSub = null;
    // 调用 stopScan() 不 await（或使用 catchError）
    FlutterBluePlus.stopScan().catchError((e) => print('stopScan err $e'));
    // 不依赖 ref/context
  }

  Future<void> reset() async {
    stopSync();

    peerCentralId = null;

    ble_peri.BlePeripheral.stopAdvertising().catchError((e) => print('Stop adv error: $e'));
    peerDevice?.disconnect().catchError((e) => print('Disconnect error: $e'));

    // 清空服务和回调
    await ble_peri.BlePeripheral.clearServices().catchError((e) => print('Clear services error: $e'));

    peerDevice = null;
    deviceIdChar = null;
    isHost = false;
    state = Idle();

    // 清空数据...
    problem_ids = [];
    numProblems = 0;
    current_problem_index = 0;
    self_finish = [];
    self_correct = [];
    opp_finish = [];
    opp_correct = [];
    self_time_taken = [];
    opp_time_taken = [];
    question_start_time = 0;
    showSnackBar = null; // 清空 SnackBar 回调

    // 延迟以确保蓝牙栈稳定
    await Future.delayed(Duration(seconds: 1));
    print('Reset fully completed');
  }
}

final battleProvider = StateNotifierProvider<BattleController, BattleState>((ref) {
  final controller = BattleController();
  ref.onDispose(() {
    // provider 被销毁时清理（可以调用同步或异步安全方法）
    controller.stopSync();
    unawaited(controller.reset());
  });
  return controller;
});

class BattlePage extends StatelessWidget {
  const BattlePage ({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: const BattleEntry(),
    );
  }
}

class BattleEntry extends ConsumerStatefulWidget {  // 改成 Stateful
  const BattleEntry({super.key});

  @override
  ConsumerState<BattleEntry> createState() => _BattleEntryState();
}

class _BattleEntryState extends ConsumerState<BattleEntry> {
  late final BattleController _battleCtrl;

  @override
  void initState() {
    super.initState();
    _battleCtrl = ref.read(battleProvider.notifier);
    ref.listen<BattleState>(battleProvider, (previous, next) {});
    _jumpIfNoLogin();
  }

  Future<void> _jumpIfNoLogin() async {
    if ((await checkLogin()) == null) {
      final success = await popLogin(context);
      if (success != true) {
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    // 调用 BattleController 的 reset() 方法
    _battleCtrl.reset();
    unawaited(_battleCtrl.reset());

    print("page exited, bluetooth scanning stopped");
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(battleProvider);

    ref.read(battleProvider.notifier).showSnackBar = (String message) {
      // 确保在主线程并且 UI 存在时才弹出
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      });
    };

    // 定义主题颜色，作为全局主题应用于整个BattleEntry及其子View
    // 这允许所有页面（通过AnimatedSwitcher切换）继承相同的风格
    final battleTheme = Theme.of(context).copyWith(
      scaffoldBackgroundColor: Colors.blue,

      // 重点修改 colorScheme，让输入文本默认黑色
      colorScheme: ColorScheme.dark(  // 推荐用 ColorScheme.dark() 作为基础
        primary: Colors.orangeAccent,
        onPrimary: Colors.white,
        secondary: Colors.orangeAccent,
        onSecondary: Colors.white,
        surface: Colors.blue.shade800,           // 卡片/表面可能的背景
        onSurface: Colors.white,                 // ← 这里！输入文本默认颜色设为黑色
        onSurfaceVariant: Colors.black87,        // hint / 次要文字也黑色
        brightness: Brightness.dark,
      ).copyWith(
        // 如果需要覆盖某些地方的白色，可以再细调
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.orangeAccent.withOpacity(0.6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.orangeAccent, width: 2.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.orangeAccent, width: 2.5),
        ),
        // hint 文字颜色（黑色）
        hintStyle: const TextStyle(
          color: Colors.white,   // 稍淡的黑色，更像典型 hint
          fontSize: 16,
        ),
        // label 颜色（如果有 floating label）
        labelStyle: const TextStyle(
          color: Colors.black87,
        ),
        // 前/后缀图标颜色
        prefixIconColor: Colors.orangeAccent,
        suffixIconColor: Colors.orangeAccent,
        //cursorColor: Colors.orangeAccent,
      ),

      // 其他部分不变
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: Colors.orangeAccent,
        foregroundColor: Colors.white,
        elevation: 6,
        highlightElevation: 12,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orangeAccent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 5,
        ),
      ),

      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.white, fontSize: 18),
        bodyMedium: TextStyle(color: Colors.white, fontSize: 16),
        headlineSmall: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
      ),

      cardTheme: CardThemeData(
        color: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: Colors.orangeAccent,
            width: 2,
          ),
        ),
      ),
    );

    return Theme(
      data: battleTheme,
      child: Scaffold(
        // 加上 AppBar，并应用主题
        appBar: AppBar(
          title: const Text("Math PvP"),
          centerTitle: true,
          elevation: 2,
          backgroundColor: Colors.blue, // 与背景一致或调整为撞色
          titleTextStyle: battleTheme.textTheme.headlineSmall?.copyWith(color: Colors.white),
        ),
        
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300), // 页面切换过渡动画
            transitionBuilder: (Widget child, Animation<double> animation) {
              // 添加淡入淡出过渡动画以增强切换效果
              return FadeTransition(opacity: animation, child: child);
            },
            child: switch (state) {
              Idle() => const IdleView(),
              Scanning() => const ScanningView(),
              Connecting() => const ConnectingView(),
              Ready() => const ReadyView(),
              Playing(:final currentQuestionId) =>
                  PlayingView(questionIndex: currentQuestionId),
              Result(:final myScore, :final peerScore) =>
                  ResultView(myScore: myScore, peerScore: peerScore),
            },
          ),
        ),
      ),
    );
  }
}

class IdleView extends ConsumerWidget {
  const IdleView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 活动说明Card，居中且醒目
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  "Math PvP Activity",
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  "Challenge your friend in a face-to-face math battle! Compete to see who solves problems faster and more accurately. Have fun and sharpen your math skills!",
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
            ],
          ),
        ),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly, // 按钮居中且均匀分布
          children:[
            ElevatedButton(
              onPressed: () {
                ref.read(battleProvider.notifier).startScan();
              },
              child: const Text("Start Scan"),
            ),
            ElevatedButton(
              onPressed: () {
                ref.read(battleProvider.notifier).startHost();
              },
              child: const Text("Start as Host"),
            ),
          ],
        ),
      ],
    );
  }
}

class ScanningView extends ConsumerWidget {
  const ScanningView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ScanningView 继承 battleTheme
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator( // 添加加载指示器以匹配主题
            color: Colors.orangeAccent,
          ),
          const SizedBox(height: 16),
          Text(
            "Scanning for opponents...",
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

class ConnectingView extends ConsumerWidget {
  const ConnectingView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ConnectingView 继承 battleTheme
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: Colors.orangeAccent,
          ),
          const SizedBox(height: 16),
          Text(
            "Device found. Connecting...",
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

class ReadyView extends ConsumerStatefulWidget {
  const ReadyView({super.key});

  @override
  ConsumerState<ReadyView> createState() => _ReadyViewState();
}

class _ReadyViewState extends ConsumerState<ReadyView> {
  int _selectedQuestions = 5; // 默认5题

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(battleProvider.notifier);
    final isHost = notifier.isHost;

    // ReadyView 继承 battleTheme，无需本地Theme
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              isHost ? "You are Host" : "You are Client",
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 32),

            if (isHost) ...[
              Text(
                "Please select number of problems:",
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 10),
              // NumberPicker 应用白色字体和撞色风格
              NumberPicker(
                minValue: 1,
                maxValue: 10,//IMPORTANT: could not be greater than 10
                value: _selectedQuestions,
                step: 1,
                itemHeight: 50,
                selectedTextStyle: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.orangeAccent, // 选中项橙色突出
                ),
                textStyle: const TextStyle(
                  fontSize: 20,
                  color: Colors.white, // 白色字体
                ),
                decoration: BoxDecoration(
                  border: Border.symmetric(
                    horizontal: BorderSide(color: Colors.orangeAccent, width: 2),
                  ),
                ),
                onChanged: (value) => setState(() => _selectedQuestions = value),
              ),
              const SizedBox(height: 24),
            ] else ...[
              Text(
                "Waiting for Host to set number of problems...",
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 40),
            ],

            if (isHost)
              ElevatedButton(
                onPressed: () {
                  notifier.initiateMatch(
                    numQuestions: _selectedQuestions,
                    pointInterval: 10, // used to filter problems but useless right now
                  );
                },
                child: const Text("Start Match"),
              ),

            // 如果是客户端，可以添加一个可选的取消按钮，但原代码无按钮，故不添加额外按钮
          ],
        ),
      ),
    );
  }
}

class PlayingView extends ConsumerWidget {
  final int questionIndex;
  const PlayingView({super.key, required this.questionIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(battleProvider.notifier);
    final problemIds = notifier.problem_ids;

    // PlayingView 继承 battleTheme
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            //TODO: display problem answer progress of opponent

            // 显示题目
            Expanded(
              child: Card( // 应用主题卡片风格
                clipBehavior: Clip.antiAlias, // 让内容跟随圆角裁剪
                child: Builder( // 使用 Builder 来创建一个新的 context，确保 ProblemPage 继承外部的 battleTheme
                  builder: (BuildContext innerContext) {
                    return ProblemPage(
                      problemId: problemIds[questionIndex],
                      isEmbedded: true,
                      onSubmitResult: (passed) async {
                        await notifier.sendAnswer(questionIndex, passed);
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ResultView extends ConsumerWidget {
  final int myScore;
  final int peerScore;
  const ResultView({super.key, required this.myScore, required this.peerScore});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ResultView 继承 battleTheme
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "My Score: $myScore, Peer Score: $peerScore",
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              ref.read(battleProvider.notifier).reset();
            },
            child: const Text("Reset"),
          ),
        ],
      ),
    );
  }
}