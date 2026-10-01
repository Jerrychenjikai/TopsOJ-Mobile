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
          return json['data'];
        }
      }
    } catch (e) {
      print("error");
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DefaultTextStyle(
        style: const TextStyle(color: Colors.white70),
        child: Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color.fromRGBO(107, 38, 37, 1.0),
              brightness: Brightness.dark,
            ).copyWith(
              onSurface: Colors.white70,
              onBackground: Colors.white70,
            ),
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
            chipTheme: Theme.of(context).chipTheme.copyWith(
              labelStyle: Theme.of(context).chipTheme.labelStyle?.copyWith(color: Colors.white70),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white70,
              ),
            ),
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

// BackgroundPainter
class BackgroundPainter extends CustomPainter {
  final Animation<double> animation;
  final double scrollOffset;

  const BackgroundPainter({
    required this.animation,
    required this.scrollOffset,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.height == 0) return;

    final animationValue = animation.value * 2 * pi;
    final rect = Offset.zero & size;

    const int totalPages = 8; 
    final double pageProgress = (scrollOffset / size.height).clamp(0.0, (totalPages - 1).toDouble());
    final double totalProgress = pageProgress / (totalPages - 1);

    final Color baseColorTop = _lerpColorList([
      const Color(0x99781A24),
      const Color(0x991A3A78),
      const Color(0x991A7848),
      const Color(0x9978581A),
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

    final double opacity1 = (1.0 - (pageProgress - 0.0).abs() / 3.0).clamp(0.0, 1.0);
    if (opacity1 > 0) {
      canvas.saveLayer(rect, Paint()..color = Colors.white.withOpacity(opacity1));
      _drawFullScreenGlow(canvas, size, const Alignment(0.2, 0.2), const [Color(0x26F7B3D7), Colors.transparent], const [0.0, 0.55]);
      _drawBubble(canvas, size, top: -60, leftPct: 6, size: 220, duration: 22, animationValue: animationValue, scrollOffset: scrollOffset);
      _drawBubble(canvas, size, top: 55, leftPct: 2, size: 180, duration: 24, animationValue: animationValue, scrollOffset: scrollOffset);
      canvas.restore();
    }

    final double opacity2 = (1.0 - (pageProgress - 4.0).abs() / 2.5).clamp(0.0, 1.0);
    if (opacity2 > 0) {
      canvas.saveLayer(rect, Paint()..color = Colors.white.withOpacity(opacity2));
      _drawFullScreenGlow(canvas, size, const Alignment(0.75, 0.35), const [Color(0x2D89F2FF), Colors.transparent], const [0.0, 0.6]);
      _drawBubble(canvas, size, top: 18, rightPct: 10, size: 280, duration: 28, animationValue: animationValue, scrollOffset: scrollOffset);
      _drawBubble(canvas, size, top: 38, leftPct: 45, size: 140, duration: 20, animationValue: animationValue, scrollOffset: scrollOffset);
      canvas.restore();
    }

    final double opacity3 = (1.0 - (pageProgress - 7.0).abs() / 3.0).clamp(0.0, 1.0);
    if (opacity3 > 0) {
      canvas.saveLayer(rect, Paint()..color = Colors.white.withOpacity(opacity3));
      _drawFullScreenGlow(canvas, size, const Alignment(0.45, 0.8), const [Color(0x1FFFCC7A), Colors.transparent], const [0.0, 0.55]);
      _drawBubble(canvas, size, bottom: -60, rightPct: 18, size: 240, duration: 26, animationValue: animationValue, scrollOffset: scrollOffset);
      _drawBubble(canvas, size, bottom: 20, rightPct: 40, size: 120, duration: 19, animationValue: animationValue, scrollOffset: scrollOffset);
      canvas.restore();
    }

    final double mainSubjectSize = 240.0;
    final double waveAmplitude = size.width * 0.3;
    final double mainSubjectX = (size.width - mainSubjectSize) / 2 + sin(totalProgress * pi * 3.5) * waveAmplitude;
    final double startY = size.height * 0.05;
    final double endY = size.height * 0.85 - mainSubjectSize;
    final double hoverY = sin(animationValue) * 15;
    final double mainSubjectY = startY + (endY - startY) * totalProgress + hoverY;

    _drawMainSubject(
      canvas, 
      size, 
      x: mainSubjectX, 
      y: mainSubjectY, 
      sizeValue: mainSubjectSize,
      animationValue: animationValue
    );
  }

  Color _lerpColorList(List<Color> colors, double t) {
    if (t <= 0.0) return colors.first;
    if (t >= 1.0) return colors.last;
    
    final double scaledT = t * (colors.length - 1);
    final int index = scaledT.toInt();
    final double fraction = scaledT - index;
    
    return Color.lerp(colors[index], colors[index + 1], fraction) ?? colors.last;
  }

  void _drawMainSubject(
    Canvas canvas,
    Size viewport, {
    required double x,
    required double y,
    required double sizeValue,
    required double animationValue,
  }) {
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

// GlassPanel
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

// Hero Page (第一页保持原样)
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
        sub: '${(reportData.problemSolvedPercent * 100).round()}% percentile in solving',
      ),
      MetricCard(
        label: 'Points Collected',
        value: reportData.pointGained.toString(),
        sub: '${(reportData.pointGainedPercent * 100).round()}% percentile in points',
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
          const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text("scroll down for more")]),
        ],
      ),
    );
  }
}

// SubMetricCard
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

// SolverPersonaPage (>2个元素，保持轻微左右交替错落，宽度自适应)
class SolverPersonaPage extends StatelessWidget {
  final AnnualReportData reportData;

  const SolverPersonaPage({super.key, required this.reportData});

  @override
  Widget build(BuildContext context) {
    final badge = getSolverBadge(reportData.problemSolved);
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = min(screenWidth * 0.75, 480.0);

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SOLVER PERSONA',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 2.8,
                  color: Color(0xFF89F2FF),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                badge.title,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'You solved ${reportData.problemSolved} problems and stacked ${reportData.pointGained} points. That is a signature run.',
                style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 14),
              ),
            ],
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(badge.tags.length, (index) {
                    final isLeft = index % 2 == 0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Align(
                        alignment: Alignment(isLeft ? -0.25 : 0.25, 0),
                        child: Container(
                          width: cardWidth,
                          constraints: const BoxConstraints(
                            minHeight: 50,
                            maxHeight: 90,
                          ),
                          child: SubMetricCard(
                            whatsinside: Center(
                              child: Text(
                                badge.tags[index],
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// TopPercentilePage (刚好2个容器，居中排列取消偏移，宽度自适应)
class TopPercentilePage extends StatelessWidget {
  final AnnualReportData reportData;

  const TopPercentilePage({super.key, required this.reportData});

  @override
  Widget build(BuildContext context) {
    final solvedPercent = (reportData.problemSolvedPercent * 100).round();
    final pointsPercent = (reportData.pointGainedPercent * 100).round();
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = min(screenWidth * 0.85, 550.0);

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PERCENTILE RANKING',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 2.8,
                  color: Color(0xFF89F2FF),
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Top Percentile Power',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'When it comes to problems solved and points gained, you stood above the crowd.',
                style: TextStyle(color: Color(0xB3FFFFFF), fontSize: 14),
              ),
              SizedBox(height: 4),
              Text(
                'You’re building your own era on TopsOJ. Keep stacking highlights.',
                style: TextStyle(color: Color(0xB3FFFFFF), fontSize: 14),
              ),
            ],
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: cardWidth,
                    constraints: const BoxConstraints(maxHeight: 120),
                    child: SubMetricCard(
                      whatsinside: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LinearProgressIndicator(
                            value: reportData.problemSolvedPercent,
                            backgroundColor: const Color(0x1FFFFFFF),
                            color: const Color(0xFFF7B3D7),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '$solvedPercent% of users solved fewer problems than you.',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: cardWidth,
                    constraints: const BoxConstraints(maxHeight: 120),
                    child: SubMetricCard(
                      whatsinside: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LinearProgressIndicator(
                            value: reportData.pointGainedPercent,
                            backgroundColor: const Color(0x1FFFFFFF),
                            color: const Color(0xFF89F2FF),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '$pointsPercent% of users earned fewer points than you.',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// MostAttemptedPage (只有1个容器，居中展示，宽度自适应)
class MostAttemptedPage extends StatelessWidget {
  final AnnualReportData reportData;

  const MostAttemptedPage({super.key, required this.reportData});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = min(screenWidth * 0.85, 550.0);

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'GRIND & GRIT',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 2.8,
                  color: Color(0xFF89F2FF),
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Most Attempted Challenge',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'The single problem that pushed you to your limits this year.',
                style: TextStyle(color: Color(0xB3FFFFFF), fontSize: 14),
              ),
            ],
          ),
          Expanded(
            child: Center(
              child: Container(
                width: cardWidth,
                constraints: const BoxConstraints(maxHeight: 160),
                child: reportData.mostAttemptedProblemName != null
                    ? SubMetricCard(
                        whatsinside: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ProblemPage(
                                      problemId: reportData.mostAttemptedProblemId ?? "",
                                    ),
                                  ),
                                );
                              },
                              child: Text(
                                reportData.mostAttemptedProblemName!,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF89F2FF),
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '${reportData.numAttemptsMostAttempted} attempts logged.',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : const SubMetricCard(
                        whatsinside: Center(
                          child: Text('No most attempted highlight logged.'),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// RatingHighsPage (只有1个容器，居中展示，宽度自适应)
class RatingHighsPage extends StatelessWidget {
  final AnnualReportData reportData;

  const RatingHighsPage({super.key, required this.reportData});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = min(screenWidth * 0.85, 550.0);

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'RATING HIGHS',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 2.8,
                  color: Color(0xFF89F2FF),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Rating Highs',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                reportData.highestRating <= 0
                    ? 'Unrated this year. Next contest, next glow-up.'
                    : 'Your maximum rating reached across competitive rounds.',
                style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 14),
              ),
            ],
          ),
          Expanded(
            child: Center(
              child: Container(
                width: cardWidth,
                constraints: const BoxConstraints(maxHeight: 160),
                child: reportData.highestRating > 0
                    ? SubMetricCard(
                        whatsinside: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Peak Rating: ${reportData.highestRating}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFF7B3D7),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Contest: ${reportData.highestRatingContestName ?? "--"}',
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Ranking at Peak: #${reportData.highestRatingRanking}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : const SubMetricCard(
                        whatsinside: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Peak Contest: --'),
                            SizedBox(height: 4),
                            Text('Ranking at Peak: --'),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ContestHighlightsPage (只有1个容器，居中展示，宽度自适应)
class ContestHighlightsPage extends StatelessWidget {
  final AnnualReportData reportData;

  const ContestHighlightsPage({super.key, required this.reportData});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = min(screenWidth * 0.85, 550.0);

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ARENA RUNS',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 2.8,
                  color: Color(0xFF89F2FF),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Contest Highlights',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                reportData.numContestParticipated > 0
                    ? 'You jumped into ${reportData.numContestParticipated} contests.'
                    : 'No contest runs this year. The arena awaits.',
                style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 14),
              ),
            ],
          ),
          Expanded(
            child: Center(
              child: Container(
                width: cardWidth,
                constraints: const BoxConstraints(maxHeight: 160),
                child: reportData.numContestParticipated > 0
                    ? SubMetricCard(
                        whatsinside: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Best Placement: #${reportData.highestContestRanking}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF89F2FF),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Top Contest: ${reportData.highestRankingContestName ?? "--"}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : const SubMetricCard(
                        whatsinside: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Best Placement: --'),
                            SizedBox(height: 4),
                            Text('Top Contest: --'),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// TimelinePage (有3个容器，保持轻微左右交替错落，宽度自适应)
class TimelinePage extends StatelessWidget {
  final AnnualReportData reportData;

  const TimelinePage({super.key, required this.reportData});

  @override
  Widget build(BuildContext context) {
    final activeMonth = monthNames[reportData.mostActiveMonth] ?? '--';
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = min(screenWidth * 0.75, 480.0);

    final items = [
      _TimelineData(
        title: 'Most Active Day',
        subtitle: '$reportYear.${reportData.mostActiveDate ?? "--"}',
        details: '${reportData.mostActiveDateSolved} solves, ${reportData.mostActiveDatePoint} points',
        note: 'You were really on the grind that day',
      ),
      _TimelineData(
        title: 'Most Active Month',
        subtitle: activeMonth,
        details: '${reportData.mostActiveMonthSolved} solves, ${reportData.mostActiveMonthPoint} points',
        note: 'What an exciting month!',
      ),
      _TimelineData(
        title: 'Earliest Win',
        subtitle: 'At ${reportData.earliestSubmission ?? "--"}',
        details: reportData.earliestSubmitProblemName ?? 'No early submission highlight logged.',
        note: 'That\'s an early hit!',
      ),
    ];

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TIMELINE',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 2.8,
                  color: Color(0xFF89F2FF),
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Your Most Electric Moments',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'A timestamped record of your peak momentum moments.',
                style: TextStyle(color: Color(0xB3FFFFFF), fontSize: 14),
              ),
            ],
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(items.length, (index) {
                    final isLeft = index % 2 == 0;
                    final item = items[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Align(
                        alignment: Alignment(isLeft ? -0.22 : 0.22, 0),
                        child: Container(
                          width: cardWidth,
                          constraints: const BoxConstraints(maxHeight: 130),
                          child: SubMetricCard(
                            whatsinside: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  item.title,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.subtitle,
                                  style: const TextStyle(
                                    color: Color(0xFF89F2FF),
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  item.details,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  item.note,
                                  style: const TextStyle(
                                    color: Color(0xB3FFFFFF),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineData {
  final String title;
  final String subtitle;
  final String details;
  final String note;

  _TimelineData({
    required this.title,
    required this.subtitle,
    required this.details,
    required this.note,
  });
}

// SummaryPage (2个容器，居中排列取消偏移，宽度自适应大屏)
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
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = min(screenWidth * 0.85, 650.0);

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'WRAP UP',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 2.8,
                  color: Color(0xFF89F2FF),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Your Wrapped Summary',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE84C78),
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: summary));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Summary copied!')),
                        );
                      }
                    },
                    child: const Text('Copy Summary', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE84C78),
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text('Back', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Center(
                child: Column(
                  children: [
                    Container(
                      width: cardWidth,
                      child: SubMetricCard(
                        whatsinside: Text(
                          summary,
                          style: const TextStyle(fontSize: 15, height: 1.4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: cardWidth,
                      child: SubMetricCard(
                        whatsinside: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'All Highlights',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF89F2FF),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text('Problems Solved: ${reportData.problemSolved} (${(reportData.problemSolvedPercent * 100).round()}% percentile)'),
                            Text('Points Collected: ${reportData.pointGained} (${(reportData.pointGainedPercent * 100).round()}% percentile)'),
                            Text('Days Activated: ${reportData.daysSpent}'),
                            Text('Most Attempted: ${reportData.mostAttemptedProblemName ?? "--"} (${reportData.numAttemptsMostAttempted} attempts)'),
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
                      ),
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