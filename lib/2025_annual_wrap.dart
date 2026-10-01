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

// 引入液态玻璃组件定义
import 'basic/ui_basic.dart'; 

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
    var s = await checkLogin();
    if(s == null){
      final success = await popLogin(context);
      if (success != true) {
        return null;
      }
      s = await checkLogin();
    }
    String apiKey = s['apikey'];
    username = s['username'];
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
              final backgroundPainter = BackgroundPainter(
                animation: _animationController,
                scrollOffset: _scrollOffset,
              );

              return LiquidGlassScope(
                painter: backgroundPainter,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(painter: backgroundPainter),
                    ),
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
                ),
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
    const backgroundPainter = BackgroundPainter(
      animation: AlwaysStoppedAnimation(0.5),
      scrollOffset: 0.0,
    );

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(painter: backgroundPainter),
          ),
          const Center(
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
    const backgroundPainter = BackgroundPainter(
      animation: AlwaysStoppedAnimation(0.5),
      scrollOffset: 0.0,
    );

    return Scaffold(
      body: LiquidGlassScope(
        painter: backgroundPainter,
        child: Stack(
          children: [
            const Positioned.fill(
              child: CustomPaint(painter: backgroundPainter),
            ),
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
      ),
    );
  }
}

// Background painter used by both the visible background and LiquidGlassScope.
//
// The animation is supplied as a repaint Listenable, so the visible background
// keeps animating without rebuilding the whole page. The painter itself remains
// immutable; changes such as scrollOffset create a new painter instance, which
// LiquidGlassScope can detect through shouldRepaint() and use to refresh its
// shared background snapshot.
// 替换原本的 BackgroundPainter 类
class BackgroundPainter extends CustomPainter {
  final Animation<double> animation;
  final double scrollOffset;

  const BackgroundPainter({
    required this.animation,
    required this.scrollOffset,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    // 防止初始化时 height 为 0 导致除数为 0 异常
    if (size.height == 0) return;

    final animationValue = animation.value * 2 * pi;
    final rect = Offset.zero & size;

    // 根据代码的 PageView，总共有 8 个页面
    const int totalPages = 8; 
    
    // pageProgress: 当前滑动到了第几页 (0.0 到 7.0)
    final double pageProgress = (scrollOffset / size.height).clamp(0.0, (totalPages - 1).toDouble());
    
    // totalProgress: 总体的百分比 (0.0 到 1.0)
    final double totalProgress = pageProgress / (totalPages - 1);

    // ==========================================
    // 1. 背景底色的大幅改变 (平滑过渡)
    // ==========================================
    final Color baseColorTop = _lerpColorList([
      const Color(0x99781A24), // 第1-2页：红色系
      const Color(0x991A3A78), // 第3-4页：蓝色系
      const Color(0x991A7848), // 第5-6页：蓝绿色系
      const Color(0x9978581A), // 第7-8页：金橙色系
    ], totalProgress);
    
    final Color baseColorBottom = _lerpColorList([
      const Color(0xFA0C0A0F),
      const Color(0xFA0A0F1A),
      const Color(0xFA0A140F),
      const Color(0xFA140F0A),
    ], totalProgress);

    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.topCenter,
          colors: [baseColorTop, baseColorBottom],
        ).createShader(rect),
    );

    // ==========================================
    // 2. 其它背景元素的淡入淡出 (分组显示，营造换页氛围)
    // ==========================================
    // 第一组 (起始氛围): 页面 0.0 ~ 2.5 显示，之后淡出
    final double opacity1 = (1.0 - (pageProgress - 0.0).abs() / 3.0).clamp(0.0, 1.0);
    if (opacity1 > 0) {
      canvas.saveLayer(rect, Paint()..color = Colors.white.withOpacity(opacity1));
      _drawFullScreenGlow(canvas, size, const Alignment(0.2, 0.2), const [Color(0x26F7B3D7), Colors.transparent], const [0.0, 0.55]);
      _drawBubble(canvas, size, top: -60, leftPct: 6, size: 220, duration: 22, animationValue: animationValue, scrollOffset: scrollOffset);
      _drawBubble(canvas, size, top: 55, leftPct: 2, size: 180, duration: 24, animationValue: animationValue, scrollOffset: scrollOffset);
      canvas.restore();
    }

    // 第二组 (中段氛围): 页面 2.5 ~ 5.5 淡入并淡出
    final double opacity2 = (1.0 - (pageProgress - 4.0).abs() / 2.5).clamp(0.0, 1.0);
    if (opacity2 > 0) {
      canvas.saveLayer(rect, Paint()..color = Colors.white.withOpacity(opacity2));
      _drawFullScreenGlow(canvas, size, const Alignment(0.75, 0.35), const [Color(0x2D89F2FF), Colors.transparent], const [0.0, 0.6]);
      _drawBubble(canvas, size, top: 18, rightPct: 10, size: 280, duration: 28, animationValue: animationValue, scrollOffset: scrollOffset);
      _drawBubble(canvas, size, top: 38, leftPct: 45, size: 140, duration: 20, animationValue: animationValue, scrollOffset: scrollOffset);
      canvas.restore();
    }

    // 第三组 (结尾氛围): 页面 5.5 ~ 7.0 淡入
    final double opacity3 = (1.0 - (pageProgress - 7.0).abs() / 3.0).clamp(0.0, 1.0);
    if (opacity3 > 0) {
      canvas.saveLayer(rect, Paint()..color = Colors.white.withOpacity(opacity3));
      _drawFullScreenGlow(canvas, size, const Alignment(0.45, 0.8), const [Color(0x1FFFCC7A), Colors.transparent], const [0.0, 0.55]);
      _drawBubble(canvas, size, bottom: -60, rightPct: 18, size: 240, duration: 26, animationValue: animationValue, scrollOffset: scrollOffset);
      _drawBubble(canvas, size, bottom: 20, rightPct: 40, size: 120, duration: 19, animationValue: animationValue, scrollOffset: scrollOffset);
      canvas.restore();
    }

    // ==========================================
    // 3. 一直保持在画面上沿曲线往下移动的主体
    // ==========================================
    final double mainSubjectSize = 240.0;
    
    // 曲线运动 (X轴)：基于总进度使用正弦波计算偏移，使其呈蛇形/S型曲线
    final double waveAmplitude = size.width * 0.3; // 曲线左右摆动的幅度
    final double mainSubjectX = (size.width - mainSubjectSize) / 2 + sin(totalProgress * pi * 3.5) * waveAmplitude;
    
    // 向下运动 (Y轴)：随着总进度，从屏幕上方平缓移动到屏幕下方
    final double startY = size.height * 0.05; // 限制在顶部往下一点开始
    final double endY = size.height * 0.85 - mainSubjectSize; // 限制在底部偏上一点结束
    
    // 叠加时间动画带来的微弱呼吸悬浮感（继承原有的灵动感）
    final double hoverY = sin(animationValue) * 15;
    
    // 计算主体在当前屏幕上的绝对位置
    final double mainSubjectY = startY + (endY - startY) * totalProgress + hoverY;

    // 绘制主体
    _drawMainSubject(
      canvas, 
      size, 
      x: mainSubjectX, 
      y: mainSubjectY, 
      sizeValue: mainSubjectSize,
      animationValue: animationValue
    );
  }

  // 辅助方法：在多个颜色之间根据 0~1 的进度平滑插值
  Color _lerpColorList(List<Color> colors, double t) {
    if (t <= 0.0) return colors.first;
    if (t >= 1.0) return colors.last;
    
    final double scaledT = t * (colors.length - 1);
    final int index = scaledT.toInt();
    final double fraction = scaledT - index;
    
    return Color.lerp(colors[index], colors[index + 1], fraction) ?? colors.last;
  }

  // 专属主体的绘制方法（沿用原本的 Orb 样式，但去掉了 parallax 的依赖，改为纯屏幕相对坐标）
  void _drawMainSubject(
    Canvas canvas,
    Size viewport, {
    required double x,
    required double y,
    required double sizeValue,
    required double animationValue,
  }) {
    // 依然保留轻微的自转/内部位移感
    final xOffset = cos(animationValue) * 15;
    
    final center = Offset(x + sizeValue / 2 + xOffset, y + sizeValue / 2);
    final circleRect = Rect.fromCircle(center: center, radius: sizeValue / 2);

    canvas.drawCircle(
      center,
      sizeValue / 2,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0.35, 0.35),
          colors: [Color(0x55FFFFFF), Color(0x33F7B3D7), Colors.transparent], 
          stops: [0.0, 0.45, 0.75],
        ).createShader(circleRect),
    );
  }

  // 以下保留原本的 Helper 函数，无需改动
  void _drawFullScreenGlow(Canvas canvas, Size size, Alignment center, List<Color> colors, List<double> stops) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(center: center, colors: colors, stops: stops).createShader(rect),
    );
  }

  void _drawBubble(Canvas canvas, Size viewport, {double? top, double? leftPct, double? rightPct, double? bottom, required double size, required double duration, required double animationValue, required double scrollOffset,}) {
    final depth = (duration - 18) * 0.005;
    final parallax = scrollOffset * depth;
    final yOffset = sin(animationValue / duration) * 30 + parallax;

    double x = leftPct != null ? viewport.width * leftPct / 100 : viewport.width - viewport.width * (rightPct ?? 0) / 100 - size;
    double y = top != null ? top + yOffset : viewport.height - (bottom ?? 0) - size - yOffset;

    final center = Offset(x + size / 2, y + size / 2);
    final circleRect = Rect.fromCircle(center: center, radius: size / 2);

    canvas.drawCircle(center, size / 2, Paint()..color = const Color(0x26FFFFFF)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 35));
    canvas.drawCircle(center, size / 2, Paint()..shader = const RadialGradient(center: Alignment(0.3, 0.3), colors: [Color(0xB3FFFFFF), Color(0x0AFFFFFF)]).createShader(circleRect));
  }

  @override
  bool shouldRepaint(covariant BackgroundPainter oldDelegate) {
    return oldDelegate.animation != animation ||
        oldDelegate.scrollOffset != scrollOffset;
  }
}

// 采用 ui_basic 中的 LiquidGlassContainer 重构原有的磨砂组件
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
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: LiquidGlassContainer(
          width: double.infinity, 
          borderRadius: borderRadius,
          child: Padding(
            padding: padding,
            child: child,
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

          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GridView(
                  padding: EdgeInsets.zero,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 520, 
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 2.2, 
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
        return GlassPanel(
          padding: const EdgeInsets.all(32),
          child: SingleChildScrollView( // 滚动视图放在里面
            child: Column(
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
        );
      },
    );
  }
}