/*
This is a bluetooth compete function
bluetooth module: flutter_blue_plus

Constraints:
1. two users have to stay close to each other
2. bluetooth on
3. app stays in foreground

Procedure: 
(for now just ignore step 8 and assume that both host and client do not cheat.)
(no interactions with server required except fetching problems)
(for now assume login credit will not expire during match)

1. 发现与连接:
   由用户指定host和client
   host广播，client扫描

2. 握手与鉴权
   Host asks user numQuestions and pointInterval
   Host -> Client: MATCH_INIT {hostUid, numQuestions, pointInterval, matchToken} (writeWithResponse)
   Client -> Host: ACK 或 REJECT

3. 题目准备
   Host 从服务器请求题目Id
   Host -> Client: PROBLEM_IDS (writeWithResponse)

3. 时间同步
   Host 与 Client 进行 5 次 SYNC_REQUEST/ACK_SYNC_REQUEST client 计算 offset
   starting now all time stamps are in terms of Host. Client has to convert its own time stamp

4. 开始比赛
   Host -> Client: START {startAt: host_time_ms}（writeWithResponse）
   Both start when local_time >= convert(host_time_ms)

5. 每题流程（循环）
   Host -> Client: NEXT {qIndex}
   both fetch problem content
   when Client is ready: Client -> Host: READY
   when Host is ready and Host received Client READY: Host -> Client {displayAt: host_time_ms, endAt: displayAt + max_duration (e.g. 3mins)} (writeWithResponse)
   At displayAt both display simultaneously
   On submit or on local_time > endAt: ANSWER {qIndex, result:AC/WA, timeTakenMs, localSubmitTime} (writeWithResponse)
   When both submit: Host -> Client: ROUND_RESULT {qIndex, whoFirst, scores...} (writeWithResponse)

6. 结束
   Host -> Client: END {summary, winner}
7. (for now ignore) Host send result to server (two uids, several pids, who wins). Server performs some type of check to verify (prolly through submission history) and give some type of reward
*/

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
import 'package:flutter_riverpod/flutter_riverpod.dart';

//backend modules
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ble_peripheral/ble_peripheral.dart' as ble_peri;

import 'package:TopsOJ/basic_func.dart';
import 'package:TopsOJ/login_page.dart';

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
  int numProblems = 0;
  int current_problem_index = 0;
  List<bool> self_finish = [];
  List<bool> self_correct = [];
  List<bool> opp_finish = [];
  List<bool> opp_correct = [];
  List<int> self_time_taken = [];
  List<int> opp_time_taken = [];

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
    }
  }

  // =================== 双方都需要用到的函数 ================
  // 双方给对方提交答案示例（在 PlayingView 的提交按钮里调用）
  Future<void> sendAnswer(int qIndex, bool result, int timeTakenMs) async {
    self_finish[qIndex] = true;
    self_correct[qIndex] = result;
    self_time_taken[qIndex] = timeTakenMs;
    await _sendMessage({
      'type': 'ANSWER',
      'qIndex': qIndex,//int
      'result': result,//bool: 做没做对
      'timeTakenMs': timeTakenMs,//int
      'localSubmitTime': DateTime.now().millisecondsSinceEpoch,//host time
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
  }

  void handleNext(Map<String, dynamic> data) {
    final idx = data['qIndex'] as int;
    print('下一题: $idx');
    current_problem_index = idx;
    state = Playing(idx);
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
    numProblems = 2;
    problem_ids = ['2011_amc12A_p01','2012_amc12A_p01'];
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
  }

  Future<void> sendNext(int qIndex) async {
    if (!isHost) return;
    current_problem_index = qIndex;
    state = Playing(qIndex);
    await _sendMessage({'type': 'NEXT', 'qIndex': qIndex});
  }

  Future<void> sendEnd() async {
    if (!isHost) return;

    //calculate scores here
    final hostScore = 40;
    final clientScore = 50;

    finish(hostScore, clientScore);

    await _sendMessage({
      'type': 'END', 
      'hostScore': hostScore, 
      'clientScore': clientScore
    });
  }

  Future<void> startHost() async {

    // Request permissions (原有)
    if (await Permission.bluetooth.request().isDenied ||
        await Permission.bluetoothScan.request().isDenied ||
        await Permission.bluetoothAdvertise.request().isDenied ||
        await Permission.bluetoothConnect.request().isDenied) {
      print('Bluetooth permissions denied');
      return;
    }

    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt <= 30) {
        if (await Permission.location.request().isDenied) {
          print('Location permissions denied');
          return;
        }
      }
    }

    final isOn = await FlutterBluePlus.isOn;
    if (!isOn) {
      print('Bluetooth is off');
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
      return;
    }

    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt <= 30) {
        if (await Permission.location.request().isDenied) {
          print('Location permissions denied');
          return;
        }
      }
    }

    final isOn = await FlutterBluePlus.isOn;
    if (!isOn) {
      print('Bluetooth is off');
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
          print(1);
          try {
            print(2);
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
              reset();
              return;
            }

            // 直接调用onDeviceFound
            await onDeviceFound(peerDevice!);
          } catch (e) {
            print('Connection failed: $e');
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
        reset();
      }

      // Still set up listener for *future* changes (e.g., disconnects)
      device.connectionState.listen((BluetoothConnectionState bluetoothState) {
        print('Connection state changed: $bluetoothState');
        if (bluetoothState == BluetoothConnectionState.connected) {
          // Handle reconnects if needed
        } else if (bluetoothState == BluetoothConnectionState.disconnected) {
          print('Disconnected');
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

  Future<void> reset() async {
    _notifSub?.cancel();
    _notifSub = null;
    _scanSub?.cancel();
    _scanSub = null;

    peerCentralId = null;

    FlutterBluePlus.stopScan().catchError((e) => print('Stop scan error: $e'));
    ble_peri.BlePeripheral.stopAdvertising().catchError((e) => print('Stop adv error: $e'));
    peerDevice?.disconnect().catchError((e) => print('Disconnect error: $e'));

    // 新增：清空服务和回调
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

    showSnackBar = null; // 新增：清空 SnackBar 回调

    // 新增：延迟以确保蓝牙栈稳定
    await Future.delayed(Duration(seconds: 1));
    print('Reset fully completed');
  }
}

final battleProvider =
    StateNotifierProvider<BattleController, BattleState>(
        (ref) => BattleController());

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
  @override
  void initState() {
    super.initState();
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
    // 安全停止（即使没在运行也不会报错）
    FlutterBluePlus.stopScan();
    ble_peri.BlePeripheral.stopAdvertising();
    print("page exited, bluetooth scanning stopped");
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(battleProvider);

    ref.read(battleProvider.notifier).showSnackBar = (String message) {
      // 这里确保在主线程并且 UI 存在时才弹出
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      });
    };

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
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
    );
  }
}

class IdleView extends ConsumerWidget {
  const IdleView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Row(
        children:[
          ElevatedButton(
            onPressed: () {
              ref.read(battleProvider.notifier).startScan();
            },
            child: const Text("Idle- Start Scan"),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(battleProvider.notifier).startHost();
            },
            child: const Text("Idle- Start as host"),
          ),
        ],
      ),
    );
  }
}

class ScanningView extends ConsumerWidget {
  const ScanningView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: const Text("Scanning"),
    );
  }
}

class ConnectingView extends ConsumerWidget {
  const ConnectingView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: const Text("Device found. Connecting"),
    );
  }
}

class ReadyView extends ConsumerWidget {
  const ReadyView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(battleProvider.notifier);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(notifier.isHost ? "你是 Host（出题方）" : "你是 Client（挑战方）"),
          const SizedBox(height: 20),
          if (notifier.isHost)
            ElevatedButton(
              onPressed: () => notifier.initiateMatch(numQuestions: 2, pointInterval: 10),//point interval used to filter problems, but now it is useless
              child: const Text("开始比赛（发送 MATCH_INIT）"),
            )
          else
            const Text("等待 Host 开始..."),
        ],
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
    // 显示题目内容的简单模拟：若有 problem_ids 则显示对应 id，否则显示占位文本
    final problemText = (problemIds.isNotEmpty && questionIndex < problemIds.length)
        ? '题目: ${problemIds[questionIndex]}' // 你可以把 id 替换为实际题目文本
        : '题目 #${questionIndex}（占位）';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 当前题号
            Text(
              'Current Problem Index: $questionIndex',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),

            // 显示题目内容（模拟）
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  problemText,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 两个模拟按钮：做对 / 做错
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    // 模拟答题耗时（1~10 秒）
                    final timeTakenMs = Random().nextInt(9000) + 1000;
                    await notifier.sendAnswer(questionIndex, true, timeTakenMs);
                    // 可选：在本端做本地提示
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('已发送 ANSWER (correct) for #$questionIndex, time=${timeTakenMs}ms')),
                    );
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Simulate Correct'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(150, 44),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () async {
                    final timeTakenMs = Random().nextInt(9000) + 1000;
                    await notifier.sendAnswer(questionIndex, false, timeTakenMs);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('已发送 ANSWER (wrong) for #$questionIndex, time=${timeTakenMs}ms')),
                    );
                  },
                  icon: const Icon(Icons.close),
                  label: const Text('Simulate Wrong'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(150, 44),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 额外显示：本地状态（可选，用于调试）
            Builder(builder: (_) {
              // 试着读取 controller 内部的状态数组（如果尚未初始化，使用 fallback）
              final selfFinish = (notifier.self_finish.length > questionIndex)
                  ? notifier.self_finish[questionIndex]
                  : false;
              final oppFinish = (notifier.opp_finish.length > questionIndex)
                  ? notifier.opp_finish[questionIndex]
                  : false;
              return Text('本端已提交: ${selfFinish ? "是" : "否"}    对方已提交: ${oppFinish ? "是" : "否"}');
            }),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("My Score: $myScore, Peer Score: $peerScore"),
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