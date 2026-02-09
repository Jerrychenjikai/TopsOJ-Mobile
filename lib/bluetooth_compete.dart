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
   Host 与 Client 进行 5 次 SYNC_REQUEST/SYNC_RESPONSE 往返，Host 计算 offset 并发送最终 TIME_SYNC {offset, rtt} 给 Client（writeWithResponse）
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
      print('📤 Write request: value: $value');
      // 处理写入逻辑...
      return ble_peri.WriteRequestResult(
        status: 0,   // 0 = 成功
      );
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
    FlutterBluePlus.scanResults.listen((results) async {
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
              await deviceIdChar!.setNotifyValue(true);  // Subscribe to notifications
              print('Subscribed to characteristic');
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

  void startBattle() {
    state = const Playing(0);
  }

  void nextQuestion() {
    if (state is Playing) {
      final current = (state as Playing).currentQuestionId;
      if (current < 4) { // Simulate 5 questions (0-4)
        state = Playing(current + 1);
      } else {
        finish(50, 40); // Arbitrary scores
      }
    }
  }

  void finish(int my, int peer) {
    state = Result(my, peer);
  }

  void reset() {
    // 停止 central 扫描（防止还在监听 scanResults）
    FlutterBluePlus.stopScan().catchError((e) => print('Stop scan error: $e'));

    // 停止 peripheral 广播（最关键！）
    ble_peri.BlePeripheral.stopAdvertising().then((_) {
      print('Advertising stopped in reset');
    }).catchError((e) {
      print('Stop advertising error: $e');
    });

    // 可选：清理添加的服务（如果下次 startScan 会重新 addService，避免重复添加冲突）
    // _blePeripheral.clearServices();  // 如果你的逻辑每次都重新 addService，可以调用这个
    // 注意：clearServices 后，下次 start 前需重新 addService

    // 清理变量（防止旧引用导致 bug）
    peerDevice?.disconnect().catchError((e) => print('Disconnect error: $e'));
    peerDevice = null;
    peerDeviceId = null;
    deviceIdChar = null;
    isHost = false;
    state = Idle();
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
    return Center(
      child: ElevatedButton(
        onPressed: () {
          ref.read(battleProvider.notifier).startBattle();
        },
        child: const Text("Ready?- Start Battle"),
      ),
    );
  }
}

class PlayingView extends ConsumerWidget {
  final int questionIndex;
  const PlayingView({super.key, required this.questionIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: ElevatedButton(
        onPressed: () {
          ref.read(battleProvider.notifier).nextQuestion();
        },
        child: Text("Next Question ($questionIndex/4)"),
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