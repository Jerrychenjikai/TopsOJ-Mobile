import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:TopsOJ/basic_func.dart';
import 'package:TopsOJ/login_page.dart';
import 'package:TopsOJ/problem_page.dart';

// Assume the base URL for API, replace with actual domain
const String baseUrl = 'https://topsoj.com'; // Replace with actual domain
const int reportYear = 2025; // Or get from context, here hardcoded as example
String username = 'YourUsername'; // Replace with actual session username
const bool isPreview = false; // Set based on context

// Model for API data
class AnnualReportData {
  final int problemSolved;
  final int pointGained;
  final int daysSpent;
  final double problemSolvedPercent;
  final double pointGainedPercent;
  final int numAttemptsMostAttempted;
  final String? mostAttemptedProblemName;
  final String? mostAttemptedProblemId;
  final int highestRating;
  final String? highestRatingContestName;
  final int highestRatingRanking;
  final int numContestParticipated;
  final int highestContestRanking;
  final String? highestRankingContestName;
  final String? mostActiveDate;
  final int mostActiveDateSolved;
  final int mostActiveDatePoint;
  final int mostActiveMonth;
  final int mostActiveMonthSolved;
  final int mostActiveMonthPoint;
  final String? earliestSubmission;
  final String? earliestSubmitProblemName;
  final String? earliestSubmitProblemId;

  AnnualReportData({
    required this.problemSolved,
    required this.pointGained,
    required this.daysSpent,
    required this.problemSolvedPercent,
    required this.pointGainedPercent,
    required this.numAttemptsMostAttempted,
    this.mostAttemptedProblemName,
    this.mostAttemptedProblemId,
    required this.highestRating,
    this.highestRatingContestName,
    required this.highestRatingRanking,
    required this.numContestParticipated,
    required this.highestContestRanking,
    this.highestRankingContestName,
    this.mostActiveDate,
    required this.mostActiveDateSolved,
    required this.mostActiveDatePoint,
    required this.mostActiveMonth,
    required this.mostActiveMonthSolved,
    required this.mostActiveMonthPoint,
    this.earliestSubmission,
    this.earliestSubmitProblemName,
    this.earliestSubmitProblemId,
  });

  factory AnnualReportData.fromJson(Map<String, dynamic> json) {
    return AnnualReportData(
      problemSolved: json['problem solved'] ?? 0,
      pointGained: json['point gained'] ?? 0,
      daysSpent: json['days spent'] ?? 0,
      problemSolvedPercent: (json['problem solved %'] ?? 0.0).toDouble(),
      pointGainedPercent: (json['point gained %'] ?? 0.0).toDouble(),
      numAttemptsMostAttempted: json['# of attempts on most attempted problem'] ?? 0,
      mostAttemptedProblemName: json['most attempted problem name'],
      mostAttemptedProblemId: json['most attempted problem id'],
      highestRating: json['highest rating'] ?? 0,
      highestRatingContestName: json['highest rating contest name'],
      highestRatingRanking: json['highest rating ranking'] ?? 0,
      numContestParticipated: json['# of contest participated'] ?? 0,
      highestContestRanking: json['highest contest ranking'] ?? 0,
      highestRankingContestName: json['highest ranking contest name'],
      mostActiveDate: json['most active date'],
      mostActiveDateSolved: json['most active date solved'] ?? 0,
      mostActiveDatePoint: json['most active date point'] ?? 0,
      mostActiveMonth: json['most active month'] ?? 0,
      mostActiveMonthSolved: json['most active month solved'] ?? 0,
      mostActiveMonthPoint: json['most active month point'] ?? 0,
      earliestSubmission: json['earliest submission'],
      earliestSubmitProblemName: json['earliest submit problem name'],
      earliestSubmitProblemId: json['earliest submit problem id'],
    );
  }
}

// Solver Badge logic
class SolverBadge {
  final String title;
  final List<String> tags;

  SolverBadge(this.title, this.tags);
}

SolverBadge getSolverBadge(int count) {
  if (count >= 1200) {
    return SolverBadge('Legendary Problem Conqueror', ['Boss-level consistency', 'All-out grind', 'Stacked W streak']);
  } else if (count >= 800) {
    return SolverBadge('Relentless Solver', ['Heavy volume', 'High discipline', 'Momentum merchant']);
  } else if (count >= 500) {
    return SolverBadge('Precision Pace Setter', ['Smart efficiency', 'Tactical streaks', 'Problem hunter']);
  } else if (count >= 200) {
    return SolverBadge('Rising Strategist', ['Growth arc', 'Intentional practice', 'Momentum builder']);
  } else {
    return SolverBadge('Curious Challenger', ['Exploration mode', 'First sparks', 'Story just starting']);
  }
}

String getMomentumLabel(int intensity) {
  if (intensity >= 45) return 'Galaxy-bright momentum';
  if (intensity >= 30) return 'Steady cosmic drift';
  if (intensity >= 15) return 'Momentum warming up';
  return 'Every journey starts small — next year is yours';
}

const Map<int, String> monthNames = {
  1: 'January', 2: 'February', 3: 'March', 4: 'April',
  5: 'May', 6: 'June', 7: 'July', 8: 'August',
  9: 'September', 10: 'October', 11: 'November', 12: 'December',
};

//page defined here

class AnnualReportPage extends StatefulWidget {
  const AnnualReportPage({super.key});

  @override
  State<AnnualReportPage> createState() => _AnnualReportPageState();
}

class _AnnualReportPageState extends State<AnnualReportPage> with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animationController;
  double _scrollOffset = 0.0;
  Future<Map<String, dynamic>?>? _dataFuture;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageController.addListener(() {
      setState(() {
        _scrollOffset = _pageController.offset;
      });
    });
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _dataFuture = fetchData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> fetchData() async {
    final s = await checkLogin();
    String? apiKey = s['apikey'];
    username = s['username'];
    if(apiKey == null){
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage(gotopage: '/2025wrap')),
        (route) => false,
      );
    }
    var headers = {'Authorization': 'Bearer $apiKey'};

    try {
      final response = await http.get(Uri.parse('$baseUrl/api/annualreport/$reportYear'), headers: headers);
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['status'] == 'success') {
          print(json['data']);
          return json['data'];
        }
      }
    } catch (e) {
      print("error");
      // Handle error
    }
    return null;
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DefaultTextStyle(
        // 为所有子Text设置默认浅色（merge现有style，未指定color的会用这个）
        style: const TextStyle(color: Colors.white70),  // 浅白色，柔和；或 Colors.grey[200]
        child: Theme(
          data: Theme.of(context).copyWith(
            // 强制dark colorScheme，基于根种子颜色生成暗变体
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color.fromRGBO(107, 38, 37, 1.0),
              brightness: Brightness.dark,  // 切换到暗模式，确保系统用浅文本
            ).copyWith(
              onSurface: Colors.white70,    // 默认表面文本浅色
              onBackground: Colors.white70, // 背景文本浅色
            ),
            // 简化textTheme覆盖：只覆盖常见variants（Flutter会自动匹配）
            textTheme: Theme.of(context).textTheme.copyWith(
              bodyLarge: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70),
              bodyMedium: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
              bodySmall: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
              displayLarge: Theme.of(context).textTheme.displayLarge?.copyWith(color: Colors.white70),
              headlineLarge: Theme.of(context).textTheme.headlineLarge?.copyWith(color: Colors.white70),
              headlineMedium: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white70),
              labelMedium: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.white70),
              titleMedium: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white70),
            ),
            // 覆盖其他组件（如Chip、Button）以确保浅文本
            chipTheme: Theme.of(context).chipTheme.copyWith(
              labelStyle: Theme.of(context).chipTheme.labelStyle?.copyWith(color: Colors.white70),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white70,  // 按钮文本浅色
              ),
            ),
            // 可选：进度条等用浅色
            progressIndicatorTheme: const ProgressIndicatorThemeData(
              color: Colors.white70,
            ),
          ),
          child: FutureBuilder<Map<String, dynamic>?>(
            future: _dataFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LoadingPage();
              }
              final data = snapshot.data;
              if (data == null || (data['problem solved'] ?? 0) <= 0) {
                return const InactivePage();
              }
              final reportData = AnnualReportData.fromJson(data);
              return Stack(
                children: [
                  BackgroundAnimation(scrollOffset: _scrollOffset, animation: _animationController.view),
                  PageView(
                    controller: _pageController,
                    scrollDirection: Axis.vertical,
                    children: [
                      HeroPage(reportData: reportData),
                      SolverPersonaPage(reportData: reportData),
                      TopPercentilePage(reportData: reportData),
                      MostAttemptedPage(reportData: reportData),
                      RatingHighsPage(reportData: reportData),
                      ContestHighlightsPage(reportData: reportData),
                      TimelinePage(reportData: reportData),
                      SummaryPage(reportData: reportData),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// Loading Page
class LoadingPage extends StatelessWidget {
  const LoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 背景動畫 - 需要傳入 Animation
          // 這裡假設你已經在父層級有 AnimationController
          // 如果沒有，請參考下面「重要注意事項」
          const BackgroundAnimation(
            animation: AlwaysStoppedAnimation(0.5), // 臨時替代，正式請用真的動畫
            scrollOffset: 0.0,
          ),
          
          // 主要內容（保持置中）
          const Center(
            child: GlassPanel(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Loading your year in review...',
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 16),
                    Text('Charging the glassmorphic engines and calculating your glow.'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Inactive Page
class InactivePage extends StatelessWidget {
  const InactivePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 同樣的背景
          const BackgroundAnimation(
            animation: AlwaysStoppedAnimation(0.5), // 臨時替代
            scrollOffset: 0.0,
          ),
          
          // 主要內容
          Center(
            child: GlassPanel(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'No Wrapped for this year',
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'You were inactive this year, so there isn\'t a TopsOJ Wrapped to show yet.\n'
                      'Jump back in and we\'ll be ready for the next one!',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text('Start Solving'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Background with bubbles and orbs
class BackgroundAnimation extends AnimatedWidget {
  final double scrollOffset;

  const BackgroundAnimation({super.key, required Animation<double> animation, required this.scrollOffset})
      : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    final animationValue = (listenable as Animation<double>).value * 2 * pi;
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          colors: [Color(0x99781A24), Color(0xFA0C0A0F)],
        ),
      ),
      child: Stack(
        children: [
          // Gradient overlays
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.2, 0.2),
                colors: [const Color(0x26F7B3D7), Colors.transparent],
                stops: const [0.0, 0.55],
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.75, 0.35),
                colors: [const Color(0x2D89F2FF), Colors.transparent],
                stops: const [0.0, 0.6],
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.45, 0.8),
                colors: [const Color(0x1FFFCC7A), Colors.transparent],
                stops: const [0.0, 0.55],
              ),
            ),
          ),
          // Bubbles
          _buildBubble(context, top: -60, leftPct: 6, size: 220, duration: 22, animationValue: animationValue, scrollOffset: scrollOffset),
          _buildBubble(context, top: 18, rightPct: 10, size: 280, duration: 28, animationValue: animationValue, scrollOffset: scrollOffset),
          _buildBubble(context, top: 55, leftPct: 2, size: 180, duration: 24, animationValue: animationValue, scrollOffset: scrollOffset),
          _buildBubble(context, bottom: -60, rightPct: 18, size: 240, duration: 26, animationValue: animationValue, scrollOffset: scrollOffset),
          _buildBubble(context, top: 38, leftPct: 45, size: 140, duration: 20, animationValue: animationValue, scrollOffset: scrollOffset),
          _buildBubble(context, bottom: 20, rightPct: 40, size: 120, duration: 19, animationValue: animationValue, scrollOffset: scrollOffset),
          // Orbs
          _buildOrb(context, top: 10, leftPct: 60, size: 320, delay: -3, animationValue: animationValue, scrollOffset: scrollOffset),
          _buildOrb(context, bottom: 8, leftPct: 12, size: 260, delay: -9, animationValue: animationValue, scrollOffset: scrollOffset),
        ],
      ),
    );
  }

  Widget _buildBubble(BuildContext context, {
    double? top, double? leftPct, double? rightPct, double? bottom,
    required double size, required double duration, required double animationValue, required double scrollOffset,
  }) {
    final depth = (duration - 18) * 0.005; // Approximate index-based depth
    final parallax = scrollOffset * depth;
    final yOffset = sin(animationValue / duration) * 30 + parallax;
    double? left, right;
    if (leftPct != null) left = MediaQuery.of(context).size.width * leftPct / 100;
    if (rightPct != null) right = MediaQuery.of(context).size.width * rightPct / 100;
    return Positioned(
      top: top != null ? top + yOffset : null,
      left: left,
      right: right,
      bottom: bottom != null ? bottom + yOffset : null,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            center: Alignment(0.3, 0.3),
            colors: [Color(0xB3FFFFFF), Color(0x0AFFFFFF)],
          ),
          boxShadow: const [BoxShadow(color: Color(0x26FFFFFF), blurRadius: 35)],
        ),
        child: null,
      ),
    );
  }

  Widget _buildOrb(BuildContext context, {
    double? top, double? leftPct, double? bottom, required double size, required double delay, required double animationValue, required double scrollOffset,
  }) {
    final yOffset = sin((animationValue + delay) / 24) * 25 + scrollOffset * 0.02;
    final xOffset = cos((animationValue + delay) / 24) * 20;
    double? left;
    if (leftPct != null) left = MediaQuery.of(context).size.width * leftPct / 100;
    return Positioned(
      top: top != null ? top + yOffset : null,
      left: left != null ? left + xOffset : null,
      bottom: bottom != null ? bottom + yOffset : null,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            center: Alignment(0.35, 0.35),
            colors: [Color(0x37FFFFFF), Color(0x14F7B3D7), Colors.transparent],
            stops: [0.0, 0.5, 0.7],
          ),
        ),
      ),
    );
  }
}

class GlassPanel extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double borderWidth;
  final EdgeInsets padding;
  final EdgeInsets safeAreaMinimum;

  const GlassPanel({
    super.key,
    required this.child,
    this.borderRadius = 28,
    this.borderWidth = 1.8,
    this.padding = const EdgeInsets.all(24),
    this.safeAreaMinimum = const EdgeInsets.all(12),
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: safeAreaMinimum,
      child: Padding(
        // 这里给一个水平的 page padding（如果你想要紧贴边缘可以把 horizontal 设置为 0）
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: SizedBox(
          width: double.infinity, // <- 关键：让 panel 横向撑满可用空间
          child: Container(
            // 外层负责 gradient 描边（完整包裹圆角）
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0x66FFFFFF),
                  Color(0x22FFFFFF),
                  Color(0x11FFFFFF),
                ],
              ),
            ),
            padding: EdgeInsets.all(borderWidth),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius - borderWidth),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: Container(
                  width: double.infinity,
                  padding: padding,
                  decoration: BoxDecoration(
                    color: const Color(0x1AFFFFFF),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0x2DFFFFFF), Color(0x14FFFFFF)],
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x730C0914),
                        blurRadius: 60,
                        offset: Offset(0, 20),
                      ),
                    ],
                    borderRadius:
                        BorderRadius.circular(borderRadius - borderWidth),
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Hero Page
class HeroPage extends StatelessWidget {
  final AnnualReportData reportData;
  final bool isPreview;

  const HeroPage({
    super.key,
    required this.reportData,
    this.isPreview = false,
  });

  @override
  Widget build(BuildContext context) {
    final momentumScore = min(100, (reportData.daysSpent * 100 / 365)).round();

    final radialWidget = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RadialMeter(score: momentumScore),
        const SizedBox(height: 8),
        Text(
          getMomentumLabel(momentumScore),
          style: const TextStyle(color: Color(0xB3FFFFFF)),
        ),
      ],
    );

    final items = <Widget>[
      MetricCard(
        label: 'Problems Solved',
        value: reportData.problemSolved.toString(),
        sub:
            '${(reportData.problemSolvedPercent * 100).round()}% percentile in solving',
      ),
      MetricCard(
        label: 'Points Collected',
        value: reportData.pointGained.toString(),
        sub:
            '${(reportData.pointGainedPercent * 100).round()}% percentile in points',
      ),
      MetricCard(
        label: 'Days Activated',
        value: reportData.daysSpent.toString(),
        sub: 'Active days with a solve',
      ),
      radialWidget,
    ];

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header block
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('TopsOJ Wrapped',
                  style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 2.8,
                      color: Color(0xFF89F2FF))),
              Text('Welcome back, $username.',
                  style: const TextStyle(
                      fontSize: 48, fontWeight: FontWeight.bold)),
              const Text(
                  'We stitched together your boldest wins, toughest battles, and most glittering streaks.',
                  style: TextStyle(color: Color(0xB3FFFFFF))),
              const SizedBox(height: 12),
              if (isPreview)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Preview mode enabled. Only you can see this right now.',
                    style: TextStyle(color: Colors.yellow),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 20),

          // Responsive grid: 使用 Expanded 包裹 GridView 以填充剩余高度
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // 这里用 maxCrossAxisExtent 控制每个卡片的最大宽度（窗口越宽，列数自动增加）
                // 调整 maxCrossAxisExtent 与 childAspectRatio 以匹配你的卡片视觉比例
                return GridView(
                  padding: EdgeInsets.zero,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 520, // 每格最大宽度（改这个值来控制列数断点）
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 2.2, // 宽高比，按需要调整
                  ),
                  children: items,
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Text("scroll down for more")]),
        ],
      ),
    );
  }
}

//submetriccard
class SubMetricCard extends StatelessWidget {
    final Widget whatsinside;

    const SubMetricCard({super.key, required this.whatsinside});

    @override
    Widget build(BuildContext context) {
        return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x29FFFFFF), Color(0x0AFFFFFF)],
        ),
        border: Border.all(color: const Color(0x2DFFFFFF)),
        ),
        child: whatsinside,
      );
    }
}

// MetricCard
class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String sub;

  const MetricCard({super.key, required this.label, required this.value, required this.sub});

  @override
  Widget build(BuildContext context) {
    return SubMetricCard(
      whatsinside: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, letterSpacing: 2, color: Color(0xB3FFFFFF))),
          Text(value, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
          Text(sub, style: const TextStyle(color: Color(0xFFF7B3D7))),
        ],
      ),
    );
  }
}

// RadialMeter
class RadialMeter extends StatelessWidget {
  final int score;

  const RadialMeter({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        children: [
          CustomPaint(
            size: const Size(140, 140),
            painter: RadialPainter(score: score),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children:[
                Text('$score%', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const Text("days activated"),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RadialPainter extends CustomPainter {
  final int score;

  RadialPainter({required this.score});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    final backgroundPaint = Paint()
      ..color = const Color(0x14FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12;
    canvas.drawCircle(center, radius, backgroundPaint);

    final foregroundPaint = Paint()
      ..shader = const LinearGradient(colors: [Color(0xFFF7B3D7), Color(0xFF89F2FF)]).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -pi / 2, (score / 100) * 2 * pi, false, foregroundPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// SolverPersonaPage
class SolverPersonaPage extends StatelessWidget {
  final AnnualReportData reportData;

  const SolverPersonaPage({super.key, required this.reportData});

  @override
  Widget build(BuildContext context) {
    final badge = getSolverBadge(reportData.problemSolved);
    return GlassPanel(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(badge.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text('You solved ${reportData.problemSolved} problems and stacked ${reportData.pointGained} points. That is a signature run.', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: badge.tags.map((tag) => SubMetricCard(whatsinside: Text(tag))).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// TopPercentilePage
class TopPercentilePage extends StatelessWidget {
  final AnnualReportData reportData;

  const TopPercentilePage({super.key, required this.reportData});

  @override
  Widget build(BuildContext context) {
    final solvedPercent = (reportData.problemSolvedPercent * 100).round();
    final pointsPercent = (reportData.pointGainedPercent * 100).round();
    return GlassPanel(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Top Percentile Power', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const Text('When it comes to problems solved and points gained, you stood above the crowd.'),
            const SizedBox(height: 16),
            SubMetricCard(
              whatsinside: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  LinearProgressIndicator(value: reportData.problemSolvedPercent, backgroundColor: const Color(0x1FFFFFFF), color: const Color(0xFFF7B3D7)),
                  Text('$solvedPercent% of users solved fewer problems than you.'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SubMetricCard(
              whatsinside: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  LinearProgressIndicator(value: reportData.pointGainedPercent, backgroundColor: const Color(0x1FFFFFFF), color: const Color(0xFFF7B3D7)),
                  Text('$pointsPercent% of users earned fewer points than you.'),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            const Text('You’re building your own era on TopsOJ. Keep stacking highlights.'),
          ],
        ),
      ),
    );
  }
}

// MostAttemptedPage
class MostAttemptedPage extends StatelessWidget {
  final AnnualReportData reportData;

  const MostAttemptedPage({super.key, required this.reportData});

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Most Attempted Challenge', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (reportData.mostAttemptedProblemName != null)
              SubMetricCard(
                whatsinside: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => ProblemPage(problemId: reportData.mostAttemptedProblemId ?? ""),
                            ),
                        );
                      },
                      child: Text(reportData.mostAttemptedProblemName!, style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline)),
                    ),
                    Text('${reportData.numAttemptsMostAttempted} attempts on your most attempted problem.')
                  ],
                ),
              )
            else
              const Text('No most attempted highlight logged.')
            
          ],
        ),
      ),
    );
  }
}

// RatingHighsPage
class RatingHighsPage extends StatelessWidget {
  final AnnualReportData reportData;

  const RatingHighsPage({super.key, required this.reportData});

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Rating Highs', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            if (reportData.highestRating <= 0)
                const Text('Unrated this year. Next contest, next glow-up.'),
            const SizedBox(height: 16),

            if (reportData.highestRating > 0)
                SubMetricCard(
                    whatsinside: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                            Text('Peak rating: ${reportData.highestRating}'),
                            Text('Peak contest: ${reportData.highestRatingContestName ?? "--"}'),
                            Text('Ranking at peak: #${reportData.highestRatingRanking}'),
                        ]
                    )
                )
            else
                SubMetricCard(
                    whatsinside: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                    
                            const Text('Peak contest: --'),
                            const Text('Ranking at peak: --'),
                        ]
                    )
                )
          ],
        ),
      ),
    );
  }
}

// ContestHighlightsPage
class ContestHighlightsPage extends StatelessWidget {
  final AnnualReportData reportData;

  const ContestHighlightsPage({super.key, required this.reportData});

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Contest Highlights', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            if (reportData.numContestParticipated <= 0)
                Text('You jumped into ${reportData.numContestParticipated} contests.'),
            const SizedBox(height: 16),

            if (reportData.numContestParticipated > 0)
                SubMetricCard(
                    whatsinside: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                            Text('Best placement: #${reportData.highestContestRanking}'),
                            Text('Top contest: ${reportData.highestRankingContestName ?? "--"}'),
                        ]
                    )
                )
            else
                SubMetricCard(
                    whatsinside: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                            const Text('No contest runs this year. The arena awaits.'),
                            const Text('Best placement: --'),
                            const Text('Top contest: --'),
                        ]
                    )
                )
          ],
        ),
      ),
    );
  }
}

// TimelinePage
class TimelinePage extends StatelessWidget {
  final AnnualReportData reportData;

  const TimelinePage({super.key, required this.reportData});

  @override
  Widget build(BuildContext context) {
    final activeMonth = monthNames[reportData.mostActiveMonth] ?? '--';
    return GlassPanel(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Your Most Electric Moments', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
        TimelineChip(
            title: 'Most active day',
            subtitle: '$reportYear.${reportData.mostActiveDate ?? "--"}',
            details: '${reportData.mostActiveDateSolved} solves, ${reportData.mostActiveDatePoint} points',
            note: 'You were really on the grind that day',
        ),
        const SizedBox(height: 16),
        TimelineChip(
            title: 'Most active month',
            subtitle: activeMonth,
            details: '${reportData.mostActiveMonthSolved} solves, ${reportData.mostActiveMonthPoint} points',
            note: 'What an exciting month!',
        ),
        const SizedBox(height: 16),
        TimelineChip(
            title: 'Earliest win',
            subtitle: 'At ${reportData.earliestSubmission ?? "--"}',
            details: reportData.earliestSubmitProblemName ?? 'No early submission highlight logged.',
            note: 'That\'s an early hit!',
        ),
        ],
      ),
    );
  }
}

class TimelineChip extends StatelessWidget {
  final String title;
  final String subtitle;
  final String details;
  final String note;

  const TimelineChip({super.key, required this.title, required this.subtitle, required this.details, required this.note});

  @override
  Widget build(BuildContext context) {
    return SubMetricCard(
      whatsinside: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(subtitle, style: const TextStyle(color: Color(0xFF89F2FF))),
          Text(details, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(note),
        ],
      ),
    );
  }
}

class SummaryPage extends StatelessWidget {
  final AnnualReportData reportData;

  const SummaryPage({super.key, required this.reportData});

  String getSummary() {
    final badge = getSolverBadge(reportData.problemSolved);
    return 'TopsOJ Wrapped $reportYear: ${badge.title}. ${reportData.problemSolved} problems solved, ${reportData.pointGained} points, ${reportData.daysSpent} active days. Peak rating ${reportData.highestRating > 0 ? reportData.highestRating.toString() : "unrated"}.';
  }

  @override
  Widget build(BuildContext context) {
    final summary = getSummary();

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            // 关键：确保子部件最小高度为可用高度 -> 可以撑满屏幕
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: GlassPanel(
              padding: const EdgeInsets.all(32),
              child: Column(
                // 让 Column 占据 ConstrainedBox 给定的最小高度
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Your Wrapped Summary',
                          style:
                              TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Text(summary, style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children:[
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE84C78),
                              shape: const StadiumBorder(),
                            ),
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(text: summary));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Summary copied!')));
                              }
                            },
                            child: const Text('Copy Summary'),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE84C78),
                              shape: const StadiumBorder(),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: const Text('Back'),
                          ),
                        ]
                      ),
                    ],
                  ),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 32),
                      const Text('All Highlights:',
                          style:
                              TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Text('Problems Solved: ${reportData.problemSolved} (${(reportData.problemSolvedPercent * 100).round()}% percentile)'),
                      Text('Points Collected: ${reportData.pointGained} (${(reportData.pointGainedPercent * 100).round()}% percentile)'),
                      Text('Days Activated: ${reportData.daysSpent}'),
                      Text('Most Attempted Challenge: ${reportData.mostAttemptedProblemName ?? "--"} (${reportData.numAttemptsMostAttempted} attempts)'),
                      Text('Highest Rating: ${reportData.highestRating > 0 ? reportData.highestRating : "Unrated"}'),
                      Text('Highest Rating Contest: ${reportData.highestRatingContestName ?? "--"}'),
                      Text('Highest Rating Ranking: #${reportData.highestRatingRanking}'),
                      Text('Contests Participated: ${reportData.numContestParticipated}'),
                      Text('Highest Contest Ranking: #${reportData.highestContestRanking}'),
                      Text('Highest Ranking Contest: ${reportData.highestRankingContestName ?? "--"}'),
                      Text('Most Active Day: $reportYear.${reportData.mostActiveDate ?? "--"} (${reportData.mostActiveDateSolved} solves, ${reportData.mostActiveDatePoint} points)'),
                      Text('Most Active Month: ${monthNames[reportData.mostActiveMonth] ?? "--"} (${reportData.mostActiveMonthSolved} solves, ${reportData.mostActiveMonthPoint} points)'),
                      Text('Earliest Win: At ${reportData.earliestSubmission ?? "--"}, solved ${reportData.earliestSubmitProblemName ?? "--"}'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}