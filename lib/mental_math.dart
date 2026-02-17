import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:math';

enum GamePhase {
  config,
  playing,
  summary,
}

class GameState {
  final GamePhase phase;
  final int numDrills;
  final int minNum;
  final int maxNum;
  final int numOps;
  final bool isRanked;
  final List<Map<String, dynamic>> drills;
  final int currentIndex;
  final DateTime? startTime;
  final Duration? totalTime;
  final List<int?> userAnswers;

  GameState({
    required this.phase,
    this.numDrills = 10,
    this.minNum = 1,
    this.maxNum = 10,
    this.numOps = 2,
    this.isRanked = false,
    this.drills = const [],
    this.currentIndex = 0,
    this.startTime,
    this.totalTime,
    this.userAnswers = const [],
  });

  GameState copyWith({
    GamePhase? phase,
    int? numDrills,
    int? minNum,
    int? maxNum,
    int? numOps,
    bool? isRanked,
    List<Map<String, dynamic>>? drills,
    int? currentIndex,
    DateTime? startTime,
    Duration? totalTime,
    List<int?>? userAnswers,
  }) {
    return GameState(
      phase: phase ?? this.phase,
      numDrills: numDrills ?? this.numDrills,
      minNum: minNum ?? this.minNum,
      maxNum: maxNum ?? this.maxNum,
      numOps: numOps ?? this.numOps,
      isRanked: isRanked ?? this.isRanked,
      drills: drills ?? this.drills,
      currentIndex: currentIndex ?? this.currentIndex,
      startTime: startTime ?? this.startTime,
      totalTime: totalTime ?? this.totalTime,
      userAnswers: userAnswers ?? this.userAnswers,
    );
  }
}

class GameNotifier extends StateNotifier<GameState> {
  GameNotifier() : super(GameState(phase: GamePhase.config));

  void updateNumDrills(int value) {
    state = state.copyWith(numDrills: value);
  }

  void updateMinNum(int value) {
    state = state.copyWith(minNum: value);
  }

  void updateMaxNum(int value) {
    state = state.copyWith(maxNum: value);
  }

  void updateNumOps(int value) {
    state = state.copyWith(numOps: value);
  }

  // Start game. If ranked==true, we follow the HTML logic defaults:
  // num = 10, numOps = 2, maxNum = 100, minNum = 1 and use multiplyFlag=true
  void startGame({bool ranked = false}) {
    int useNumDrills = ranked ? 10 : state.numDrills;
    int useMin = ranked ? 1 : state.minNum;
    int useMax = ranked ? 100 : state.maxNum;
    int useNumOps = ranked ? 2 : state.numOps;
    bool multiplyFlag = ranked; // matches HTML: send_time true leads to small multipliers

    final drills = _generateDrills(
      useNumDrills,
      useMin,
      useMax,
      useNumOps,
      multiplyFlag,
    );
    state = state.copyWith(
      phase: GamePhase.playing,
      drills: drills,
      currentIndex: 0,
      startTime: DateTime.now(),
      userAnswers: List<int?>.filled(useNumDrills, null),
      isRanked: ranked,
      numDrills: useNumDrills,
      minNum: useMin,
      maxNum: useMax,
      numOps: useNumOps,
    );
  }

  List<Map<String, dynamic>> _generateDrills(
    int numDrills,
    int minNum,
    int maxNum,
    int numOps,
    bool multiplyFlag,
  ) {
    final List<Map<String, dynamic>> drills = [];
    final rnd = Random();
    int attempts = 0;
    for (int i = 0; i < numDrills; i++) {
      // 生成表达式，直到可计算为止（防止 NaN / 非数字）
      while (true) {
        attempts++;
        if (attempts > 1000) {
          // 兜底：避免无限循环
          break;
        }
        final expr = _generateExpression(rnd, numOps, minNum, maxNum, multiplyFlag);
        final eval = _evaluateExpression(expr);
        if (eval != null) {
          drills.add({'question': expr, 'answer': eval});
          break;
        }
      }
    }
    return drills;
  }

  // 占位函数：将来用于向服务器提交用时（currently empty）
  void sendTimeToServer(Duration timeTaken) {
    // TODO: 实现将来提交用时到服务器的逻辑
    // 目前这是占位函数。不要在这里实现任何耗时/异步逻辑。
  }

  void submitAnswer(int userAnswer) {
    final newUserAnswers = List<int?>.from(state.userAnswers);
    newUserAnswers[state.currentIndex] = userAnswer;
    state = state.copyWith(userAnswers: newUserAnswers);

    int nextIndex = state.currentIndex + 1;
    if (nextIndex >= state.numDrills) {
      final totalTime = DateTime.now().difference(state.startTime!);
      state = state.copyWith(
        phase: GamePhase.summary,
        totalTime: totalTime,
      );

      // If this was a ranked game, call the placeholder sendTimeToServer.
      if (state.isRanked) {
        sendTimeToServer(totalTime);
      }
    } else {
      state = state.copyWith(currentIndex: nextIndex);
    }
  }

  void resetGame() {
    state = GameState(phase: GamePhase.config);
  }

  // -----------------------
  // Expression generator and evaluator (helper functions)
  // -----------------------

  String _generateExpression(Random rnd, int numOps, int minNum, int maxNum, bool multiplyFlag) {
    // Start with a random number
    int start = _randInRange(rnd, minNum, maxNum);
    String expr = start.toString();
    int numOpen = 0;

    for (int i = 0; i < numOps; i++) {
      // adjust probability from JS: -5/6 * 1/(2**numOpen) + 5/6
      double adjust = -5.0 / 6.0 * 1.0 / pow(2, numOpen) + 5.0 / 6.0;

      if (numOpen > 0 && rnd.nextDouble() < adjust) {
        // close a bracket then append an operator
        expr += ")";
        numOpen--;
        final op = ['+', '-', '*'][rnd.nextInt(3)];
        expr += op;
        // choose next operand
        int nextNum = (op == '*' && multiplyFlag) ? (rnd.nextInt(13) + 1) : _randInRange(rnd, minNum, maxNum);
        expr += nextNum.toString();
      } else {
        final choice = ['(', '+', '-', '*'][rnd.nextInt(4)];
        if (choice == '(') {
          // in JS raw added '*' before '(' to indicate multiplication
          expr += '*(';
          numOpen++;
          // after '(' we need a number (or nested expression)
          int nextNum = (multiplyFlag) ? (rnd.nextInt(13) + 1) : _randInRange(rnd, minNum, maxNum);
          expr += nextNum.toString();
        } else {
          expr += choice;
          int nextNum = (choice == '*' && multiplyFlag) ? (rnd.nextInt(13) + 1) : _randInRange(rnd, minNum, maxNum);
          expr += nextNum.toString();
        }
      }
    }

    // close any remaining open brackets
    while (numOpen > 0) {
      expr += ")";
      numOpen--;
    }

    // ==================== 调试打印（新增） ====================
    final originalExpr = expr;                    // 保存移除前的样子
    expr = expr.replaceAll("--", "+");

    // 移除 trivial parentheses，如 (43) → 43
    expr = expr.replaceAllMapped(RegExp(r'\((\d+)\)'), (m) => m.group(1)!);

    // 打印对比
    debugPrint('Ranked: $multiplyFlag | Ops: $numOps');
    debugPrint('Before remove parens : $originalExpr');
    debugPrint('After  remove parens : $expr');
    debugPrint('------------------------------------------------');
    return expr;
  }

  int _randInRange(Random rnd, int minNum, int maxNum) {
    if (maxNum < minNum) {
      return minNum;
    }
    return rnd.nextInt(maxNum - minNum + 1) + minNum;
  }

  int? _evaluateExpression(String expr) {
    // Tokenize
    final tokens = <String>[];
    final buf = StringBuffer();
    for (int i = 0; i < expr.length; i++) {
      final ch = expr[i];
      if (_isDigit(ch)) {
        buf.write(ch);
      } else {
        if (buf.isNotEmpty) {
          tokens.add(buf.toString());
          buf.clear();
        }
        if (ch.trim().isNotEmpty) {
          tokens.add(ch);
        }
      }
    }
    if (buf.isNotEmpty) {
      tokens.add(buf.toString());
      buf.clear();
    }

    try {
      // Shunting-yard to RPN
      final output = <String>[];
      final opStack = <String>[];
      for (final t in tokens) {
        if (_isNumberToken(t)) {
          output.add(t);
        } else if (_isOperator(t)) {
          while (opStack.isNotEmpty && _isOperator(opStack.last) &&
              ((_precedence(opStack.last) > _precedence(t)) ||
                  (_precedence(opStack.last) == _precedence(t)))) {
            output.add(opStack.removeLast());
          }
          opStack.add(t);
        } else if (t == '(') {
          opStack.add(t);
        } else if (t == ')') {
          while (opStack.isNotEmpty && opStack.last != '(') {
            output.add(opStack.removeLast());
          }
          if (opStack.isNotEmpty && opStack.last == '(') {
            opStack.removeLast();
          } else {
            // mismatched parentheses
            return null;
          }
        } else {
          // unexpected token
          return null;
        }
      }
      while (opStack.isNotEmpty) {
        final op = opStack.removeLast();
        if (op == '(' || op == ')') return null;
        output.add(op);
      }

      // Evaluate RPN
      final stack = <int>[];
      for (final t in output) {
        if (_isNumberToken(t)) {
          stack.add(int.parse(t));
        } else if (_isOperator(t)) {
          if (stack.length < 2) return null;
          final b = stack.removeLast();
          final a = stack.removeLast();
          int res;
          if (t == '+') res = a + b;
          else if (t == '-') res = a - b;
          else if (t == '*') res = a * b;
          else return null;
          stack.add(res);
        } else {
          return null;
        }
      }
      if (stack.length != 1) return null;
      return stack.first;
    } catch (e) {
      return null;
    }
  }

  bool _isDigit(String s) {
    return RegExp(r'^\d$').hasMatch(s);
  }

  bool _isNumberToken(String s) {
    return RegExp(r'^\d+$').hasMatch(s);
  }

  bool _isOperator(String s) {
    return s == '+' || s == '-' || s == '*';
  }

  int _precedence(String op) {
    if (op == '*') return 2;
    if (op == '+' || op == '-') return 1;
    return 0;
  }
}

final gameProvider = StateNotifierProvider<GameNotifier, GameState>((ref) => GameNotifier());

class MentalMathWidget extends ConsumerStatefulWidget {
  const MentalMathWidget({super.key});

  @override
  ConsumerState<MentalMathWidget> createState() => _MentalMathWidgetState();
}

class _MentalMathWidgetState extends ConsumerState<MentalMathWidget> {
  Timer? _timer;
  Duration _elapsedTime = Duration.zero;
  final TextEditingController _answerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 首次创建时重置到 config
    final gameNotifier = ref.read(gameProvider.notifier);
    if (gameNotifier.state.phase != GamePhase.config) {
      gameNotifier.resetGame();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 当 widget 依赖变化或 route 重新激活时，重置到 config
    final gameNotifier = ref.read(gameProvider.notifier);
    if (gameNotifier.state.phase != GamePhase.config) {
      gameNotifier.resetGame();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _answerController.dispose();

    super.dispose();
  }

  void _startTimer() {
    _elapsedTime = Duration.zero;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _elapsedTime += const Duration(seconds: 1);
        });
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameProvider);
    final gameNotifier = ref.read(gameProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mental Math'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: _buildPhaseUI(gameState, gameNotifier),
      ),
    );
  }

  Widget _buildPhaseUI(GameState gameState, GameNotifier gameNotifier) {
    switch (gameState.phase) {
      case GamePhase.config:
        return _buildConfigUI(gameNotifier);
      case GamePhase.playing:
        if (_timer == null || !_timer!.isActive) {
          _startTimer();
        }
        return _buildPlayingUI(gameState, gameNotifier);
      case GamePhase.summary:
        _timer?.cancel();
        return _buildSummaryUI(gameState, gameNotifier);
    }
  }

  Widget _buildConfigUI(GameNotifier gameNotifier) {
    return Column(
      children: [
        TextField(
          decoration: const InputDecoration(
            labelText: '# of Drills (Default: 10)',
          ),
          keyboardType: TextInputType.number,
          onChanged: (value) => gameNotifier.updateNumDrills(int.tryParse(value) ?? 10),
        ),
        const SizedBox(height: 16),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Min Number (Default: 1)',
          ),
          keyboardType: TextInputType.number,
          onChanged: (value) => gameNotifier.updateMinNum(int.tryParse(value) ?? 1),
        ),
        const SizedBox(height: 16),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Max Number (Default: 10)',
          ),
          keyboardType: TextInputType.number,
          onChanged: (value) => gameNotifier.updateMaxNum(int.tryParse(value) ?? 10),
        ),
        const SizedBox(height: 16),
        TextField(  // 新增：numOps 输入框
          decoration: const InputDecoration(
            labelText: '# of Operations (Default: 2)',
          ),
          keyboardType: TextInputType.number,
          onChanged: (value) => gameNotifier.updateNumOps(int.tryParse(value) ?? 2),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
          ),
          onPressed: () {
            // Generate drills using current user parameters (non-ranked)
            if (gameNotifier.state.numDrills > 0 &&
                gameNotifier.state.minNum <= gameNotifier.state.maxNum) {
              gameNotifier.startGame(ranked: false);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter valid values.')),
              );
            }
          },
          child: const Text('Generate Drills'),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
          ),
          onPressed: () {
            gameNotifier.startGame(ranked: true);
          },
          child: const Text('Play Ranked Game'),
        ),
        const SizedBox(height: 16),
        Card(
          color: Colors.grey[200],
          child: SizedBox(width: double.infinity,
            child: const Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What is this Drill?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF741F22),
                      fontSize: 18,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Currently your score will not count towards the leaderboard when you play a ranked game",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'The objective of this drill is to calculate the result of the mathematical expressions, without using any paper.',
                  ),
                  SizedBox(height: 8),
                  Text('• Number of drills: how many questions/drills to generate.'),
                  Text('• Minimum number: the minimum number to be used in each drill.'),
                  Text('• Maximum number: the maximum number to be used in each drill.'),
                  Text('• Number of operations: generated randomly; expressions may contain brackets and operations (+, -, ×).'),
                  SizedBox(height: 8),
                  Text('When playing a ranked game, fixed defaults are used (10 drills, small multipliers).'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayingUI(GameState gameState, GameNotifier gameNotifier) {
    final drill = gameState.drills[gameState.currentIndex];

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Time Passed: ${_formatDuration(_elapsedTime)}',
            style: const TextStyle(fontSize: 25, color: Colors.white),
          ),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${drill['question']} = ',
              style: const TextStyle(fontSize: 28),
            ),
            SizedBox(
              width: 150,
              child: TextField(
                controller: _answerController,
                keyboardType: const TextInputType.numberWithOptions(signed: true),
                autofocus: true,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 28),
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue[100],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Drill ${gameState.currentIndex + 1} of ${gameState.numDrills}',
            style: const TextStyle(fontSize: 20),
          ),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () {
            final value = _answerController.text;
            final int? userAnswer = int.tryParse(value);
            if (userAnswer != null) {
              _answerController.clear();
              gameNotifier.submitAnswer(userAnswer);
              // reset local timer display to keep correctness with server time
              setState(() {});
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter a number.')),
              );
            }
          },
          child: const Text('Submit'),
        ),
      ],
    );
  }

  Widget _buildSummaryUI(GameState gameState, GameNotifier gameNotifier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: Colors.green[100],
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Total Time: ${_formatDuration(gameState.totalTime!)}',
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'All Drills:',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: gameState.drills.length,
          itemBuilder: (context, index) {
            final drill = gameState.drills[index];
            final userAnswer = gameState.userAnswers[index] ?? -1; // -1 if not answered
            final correctAnswer = drill['answer'];
            final isCorrect = userAnswer == correctAnswer;
            return Card(
              child: ListTile(
                title: Text('${drill['question']}'),
                subtitle: Text('Correct Answer: $correctAnswer\nYour Answer: $userAnswer'),
                trailing: Icon(
                  isCorrect ? Icons.check_circle : Icons.cancel,
                  color: isCorrect ? Colors.green : Colors.red,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
          ),
          onPressed: gameNotifier.resetGame,
          child: const Text('Back to Config'),
        ),
      ],
    );
  }
}
