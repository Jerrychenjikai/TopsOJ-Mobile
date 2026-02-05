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
  final String gameMode;
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
    this.gameMode = 'standard',
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
    String? gameMode,
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
      gameMode: gameMode ?? this.gameMode,
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

  void updateGameMode(String value) {
    state = state.copyWith(gameMode: value);
  }

  void startGame() {
    final drills = _generateDrills(
      state.numDrills,
      state.minNum,
      state.maxNum,
      state.gameMode,
    );
    state = state.copyWith(
      phase: GamePhase.playing,
      drills: drills,
      currentIndex: 0,
      startTime: DateTime.now(),
      userAnswers: List<int?>.filled(state.numDrills, null),
    );
  }

  List<Map<String, dynamic>> _generateDrills(
    int numDrills,
    int minNum,
    int maxNum,
    String gameMode,
  ) {
    final List<Map<String, dynamic>> drills = [];
    for (int i = 0; i < numDrills; i++) {
      final num = Random().nextInt(maxNum - minNum + 1) + minNum;
      if (gameMode == 'standard') {
        drills.add({'question': num, 'answer': num * num});
      } else {
        drills.add({'question': num * num, 'answer': num});
      }
    }
    return drills;
  }

  void submitAnswer(int userAnswer) {
    final newUserAnswers = List<int?>.from(state.userAnswers);
    newUserAnswers[state.currentIndex] = userAnswer;
    state = state.copyWith(userAnswers: newUserAnswers);

    // Move to next regardless of correct or wrong to allow showing wrongs in summary
    int nextIndex = state.currentIndex + 1;
    if (nextIndex >= state.numDrills) {
      final totalTime = DateTime.now().difference(state.startTime!);
      state = state.copyWith(
        phase: GamePhase.summary,
        totalTime: totalTime,
      );
    } else {
      state = state.copyWith(currentIndex: nextIndex);
    }
  }

  void resetGame() {
    state = GameState(phase: GamePhase.config);
  }
}

final gameProvider = StateNotifierProvider<GameNotifier, GameState>((ref) => GameNotifier());

class BePerfectWidget extends ConsumerStatefulWidget {
  const BePerfectWidget({super.key});

  @override
  ConsumerState<BePerfectWidget> createState() => _BePerfectWidgetState();
}

class _BePerfectWidgetState extends ConsumerState<BePerfectWidget> {
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
    // 当 widget 依赖变化或 route 重新激活（e.g., 从其他页面返回）时，重置到 config
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
    String twoDigits(int n) =>
        n.toString().padLeft(2, '0');
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
        title: const Text('Be Perfect²'),
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
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(
            labelText: 'Game Mode',
          ),
          value: gameNotifier.state.gameMode,
          items: const [
            DropdownMenuItem(value: 'standard', child: Text('Standard')),
            DropdownMenuItem(value: 'reversed', child: Text('Reversed')),
          ],
          onChanged: (value) {
            if (value != null) gameNotifier.updateGameMode(value);
          },
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
          ),
          onPressed: () {
            if (gameNotifier.state.numDrills > 0 &&
                gameNotifier.state.minNum <= gameNotifier.state.maxNum) {
              gameNotifier.startGame();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter valid values.')),
              );
            }
          },
          child: const Text('Create Game'),
        ),
        const SizedBox(height: 16),
        Card(
          color: Colors.grey[200],
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
                  'Train your ability to memorize perfect squares! The objective of this drill is to recall and state perfect squares as quickly and accurately as possible, without using any paper. Being able to swiftly and correctly identify perfect squares is very beneficial in math contests. Focus on memorizing squares of numbers to enhance your mental math skills.',
                ),
                SizedBox(height: 8),
                Text('• Number of drills: how many questions/drills to generate.'),
                Text('• Minimum number: the minimum number to be used in the perfect square.'),
                Text('• Maximum number: the maximum number to be used in the perfect square.'),
                Text('• Game mode: you can either give the square given a base (standard), or give a base given a square (reversed).'),
                SizedBox(height: 8),
                Text('You will be given the questions one-by-one, every time you submit your answer it will move on.'),
              ],
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
              gameState.gameMode == 'standard'
                  ? '${drill['question']}² = '
                  : '√${drill['question']} = ',
              style: const TextStyle(fontSize: 40),
            ),
            SizedBox(
              width: 150,
              child: TextField(
                controller: _answerController,
                keyboardType: TextInputType.number,
                autofocus: true,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 40),
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
            final userAnswer = gameState.userAnswers[index] ?? -1; // -1 if not answered, but should be filled
            final correctAnswer = drill['answer'];
            final isCorrect = userAnswer == correctAnswer;
            return Card(
              child: ListTile(
                title: Text(
                  gameState.gameMode == 'standard'
                      ? '${drill['question']}²'
                      : '√${drill['question']}',
                ),
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