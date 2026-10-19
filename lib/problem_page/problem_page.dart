import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:flutter_simple_calculator/flutter_simple_calculator.dart';

import 'package:TopsOJ/cached_problem_func.dart';
import 'package:TopsOJ/basic_func.dart';
import 'package:TopsOJ/problem_page/problem_render.dart';
import 'package:TopsOJ/problem_page/problem_submit.dart';
import 'package:TopsOJ/basic/ui_basic.dart';

/// 题目详情数据模型 (Data Class)
class ProblemDetail {
  final String problemId;
  final String name;
  final String markdownData;
  final bool canNxt;
  final bool canPrev;
  final String nxt;
  final String prev;
  final bool isSolved;
  final bool isCached;

  ProblemDetail({
    required this.problemId,
    required this.name,
    required this.markdownData,
    required this.canNxt,
    required this.canPrev,
    required this.nxt,
    required this.prev,
    required this.isSolved,
    required this.isCached,
  });

  ProblemDetail copyWith({
    String? problemId,
    String? name,
    String? markdownData,
    bool? canNxt,
    bool? canPrev,
    String? nxt,
    String? prev,
    bool? isSolved,
    bool? isCached,
  }) {
    return ProblemDetail(
      problemId: problemId ?? this.problemId,
      name: name ?? this.name,
      markdownData: markdownData ?? this.markdownData,
      canNxt: canNxt ?? this.canNxt,
      canPrev: canPrev ?? this.canPrev,
      nxt: nxt ?? this.nxt,
      prev: prev ?? this.prev,
      isSolved: isSolved ?? this.isSolved,
      isCached: isCached ?? this.isCached,
    );
  }
}

// 题目页面。只接受 problemId。内容渲染和提交栏分别来自 problem_render / problem_submit。
class ProblemPage extends StatefulWidget {
  final String problemId;

  const ProblemPage({
    super.key,
    required this.problemId,
  });

  @override
  State<ProblemPage> createState() => _ProblemPageState();
}

class _ProblemPageState extends State<ProblemPage>
    with SingleTickerProviderStateMixin {
  // 封装后的题目详情模型
  ProblemDetail? _problemDetail;

  String _activated_tool = "none";
  double? _current_calculator_value = 0;

  // 计算器高度占屏幕比例。点击 / 初次打开落到 0.4，拖动上限 0.5。
  static const double _calculatorDefaultSplit = 0.4;
  static const double _calculatorMaxSplit = 0.5;
  static const Duration _calculatorAnimDuration = Duration(milliseconds: 300);

  late final AnimationController _calculatorController;
  // 收到 0 的动画结束时才真正关掉，避免打开动画从 0 起步时被立刻关闭。
  bool _closeCalculatorAtZero = false;
  BuildContext? _glassContext;

  // 用于捕获题目正文背景的 Key，供液态玻璃折射
  final GlobalKey _backgroundKey = GlobalKey();
  String? _glassSyncedProblemId;

  @override
  void initState() {
    super.initState();
    _calculatorController = AnimationController(
      vsync: this,
      duration: _calculatorAnimDuration,
      value: 0.0,
    )..addStatusListener(_handleCalculatorStatus);
  }

  @override
  void dispose() {
    _calculatorController
      ..removeStatusListener(_handleCalculatorStatus)
      ..dispose();
    super.dispose();
  }

  void _scheduleGlassUpdate(BuildContext glassContext) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!glassContext.mounted) return;
      LiquidGlassScope.notifyUpdate(glassContext);
    });
  }

  void _handleCalculatorStatus(AnimationStatus status) {
    if (!mounted) return;
    final bool settled = status == AnimationStatus.completed ||
        status == AnimationStatus.dismissed;
    if (!settled) return;

    if (_closeCalculatorAtZero && _calculatorController.value <= 0.001) {
      _closeCalculatorAtZero = false;
      if (_activated_tool == "calculator") {
        setState(() {
          _activated_tool = "none";
        });
      }
    }

    final glassContext = _glassContext;
    if (glassContext != null) {
      _scheduleGlassUpdate(glassContext);
    }
  }

  void _animateCalculatorSplitTo(double target) {
    _calculatorController.animateTo(
      target,
      duration: _calculatorAnimDuration,
      curve: Curves.easeOut,
    );
  }

  void _openCalculator() {
    _closeCalculatorAtZero = false;
    if (_activated_tool != "calculator") {
      _calculatorController.value = 0.0;
      setState(() {
        _activated_tool = "calculator";
      });
    }
    _animateCalculatorSplitTo(_calculatorDefaultSplit);
  }

  void _animateCalculatorClose() {
    if (_activated_tool != "calculator") return;
    _closeCalculatorAtZero = true;
    if (_calculatorController.value <= 0.001) {
      _calculatorController.value = 0.0;
      _handleCalculatorStatus(AnimationStatus.dismissed);
      return;
    }
    _animateCalculatorSplitTo(0.0);
  }

  /// 拖动跟手。高度落到 0（不足 1px 视为 0）时关闭计算器。
  void _setCalculatorSplit(double split, double screenHeight) {
    final double next = split.clamp(0.0, _calculatorMaxSplit).toDouble();
    final bool collapsed =
        next <= 0.0 || (screenHeight > 0 && next * screenHeight < 1);
    if (collapsed) {
      _closeCalculatorAtZero = false;
      _calculatorController.value = 0.0;
      if (_activated_tool != "none") {
        setState(() {
          _activated_tool = "none";
        });
      }
      final glassContext = _glassContext;
      if (glassContext != null) {
        _scheduleGlassUpdate(glassContext);
      }
      return;
    }
    _calculatorController.value = next;
  }

  /// flutter_simple_calculator 的按钮色走 CalculatorThemeData：
  /// 数字 numColor、运算符 operatorColor、功能键 commandColor、等号 equalColor。
  /// 库的默认分别是 scaffold、primary、splash、secondary。这里不换色，只降低不透明度。
  CalculatorThemeData _translucentCalculatorTheme(BuildContext context) {
    final theme = Theme.of(context);
    Color soften(Color color) {
      final next = color.opacity >= 0.9 ? 0.5 : color.opacity * 0.8;
      return color.withOpacity(next);
    }

    return CalculatorThemeData(
      numColor: soften(theme.scaffoldBackgroundColor),
      operatorColor: soften(theme.primaryColor),
      commandColor: soften(theme.splashColor),
      equalColor: soften(theme.colorScheme.secondary),
      borderColor: theme.dividerColor.withOpacity(0.35),
    );
  }

  Future<void> _loadProblemData() async {
    if (_problemDetail?.problemId == widget.problemId) return;

    bool isCached = await is_cached(widget.problemId);
    var markdownUrl;
    var markdownResponse;
    var markdownJson;

    // fetch markdown
    try {
      markdownUrl = Uri.parse('https://topsoj.com/api/publicproblem?id=${widget.problemId}');
      markdownResponse = await http.get(markdownUrl);
      markdownJson = jsonDecode(markdownResponse.body);
    } catch (e) {
      if (await is_cached(widget.problemId)) {
        var cachedinfo = (await cached_info(widget.problemId));
        String markdownData = await readMarkdown(widget.problemId + '.md') ?? "Error: problem markdown not found. Delete this cached problem";
        String problemName = cachedinfo['name'] ?? "Error: Problem not cached";
        String nxt = cachedinfo['nxt'] ?? "";
        String prev = cachedinfo['prev'] ?? "";
        bool canNxt = ((!nxt.isEmpty) && (await is_cached(nxt))) ? true : false;
        bool canPrev = ((!prev.isEmpty) && (await is_cached(prev))) ? true : false;
        bool isSolved = cachedinfo['correct'] == 'true' ? true : false;

        _problemDetail = ProblemDetail(
          problemId: widget.problemId,
          name: problemName,
          markdownData: markdownData,
          canNxt: canNxt,
          canPrev: canPrev,
          nxt: nxt,
          prev: prev,
          isSolved: isSolved,
          isCached: true,
        );

        return;
      } else {
        _problemDetail = ProblemDetail(
          problemId: widget.problemId,
          name: "Network error",
          markdownData: "Network error",
          canNxt: false,
          canPrev: false,
          nxt: "",
          prev: "",
          isSolved: false,
          isCached: false,
        );
        return;
      }
    }

    if (markdownResponse.statusCode != 200) {
      _problemDetail = ProblemDetail(
        problemId: widget.problemId,
        name: "Error",
        markdownData: "Markdown load failed: ${markdownResponse.statusCode} ${markdownJson['message']}",
        canNxt: false,
        canPrev: false,
        nxt: "",
        prev: "",
        isSolved: false,
        isCached: isCached,
      );
      return;
    }

    // 设置组合好的 ProblemDetail 实例
    String markdownData = markdownJson['data']['description_md'] ?? '';
    String problemName = markdownJson['data']['problem_name'] ?? '';
    bool canNxt = markdownJson['data']['can_next'];
    bool canPrev = markdownJson['data']['can_prev'];
    String nxt = canNxt ? markdownJson['data']['nxt'].replaceFirst('/problem/', '') : "";
    String prev = canPrev ? markdownJson['data']['prev'].replaceFirst('/problem/', '') : "";
    bool isSolved = await checkSolved(widget.problemId);

    _problemDetail = ProblemDetail(
      problemId: widget.problemId,
      name: problemName,
      markdownData: markdownData,
      canNxt: canNxt,
      canPrev: canPrev,
      nxt: nxt,
      prev: prev,
      isSolved: isSolved,
      isCached: isCached,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _loadProblemData(),
      builder: (context, snapshot) {
        final ready = _problemDetail?.problemId == widget.problemId;
        final problemName = ready ? _problemDetail!.name : "Loading...";
        final isSolved = _problemDetail?.isSolved ?? false;
        final canPrev = ready && (_problemDetail?.canPrev ?? false);
        final canNxt = ready && (_problemDetail?.canNxt ?? false);
        final prev = _problemDetail?.prev ?? "";
        final nxt = _problemDetail?.nxt ?? "";

        return WillPopScope(
          onWillPop: () async {
            Navigator.pop(context, true); // 手动传回是否需要刷新
            return false; // 阻止默认返回行为（因为我们手动pop了）
          },
          child: LiquidGlassScope(
            repaintBoundaryKey: _backgroundKey,
            child: Builder(
              builder: (glassContext) {
                _glassContext = glassContext;
                if (ready && _glassSyncedProblemId != widget.problemId) {
                  _glassSyncedProblemId = widget.problemId;
                  _scheduleGlassUpdate(glassContext);
                }

                return Scaffold(
                  extendBody: true, // 让正文延伸到悬浮底栏下方
                  extendBodyBehindAppBar: true, // 让正文延伸到悬浮顶栏后方
                  appBar: _buildLiquidAppBar(glassContext, problemName, isSolved),
                  floatingActionButton: _buildLiquidSpeedDial(glassContext),
                  body: RepaintBoundary(
                    key: _backgroundKey,
                    // 列表上下仍然铺满全屏；左右只加 margin，不打断纵向滚动。
                    child: Builder(
                      builder: (bodyContext) {
                        final mq = MediaQuery.of(bodyContext);
                        final left = max(mq.padding.left, 20.0);
                        final right = max(mq.padding.right, 20.0);
                        return Padding(
                          padding: EdgeInsets.only(left: left, right: right),
                          child: MediaQuery(
                            data: mq.copyWith(
                              padding: mq.padding.copyWith(
                                top: mq.padding.top + 16,
                                bottom: mq.padding.bottom + 12,
                                left: 0,
                                right: 0,
                              ),
                            ),
                            child: problemRender(widget.problemId),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomNavigationBar: _buildLiquidBottomBar(
                    glassContext,
                    canPrev: canPrev,
                    canNxt: canNxt,
                    prev: prev,
                    nxt: nxt,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  /// 悬浮在题目列表上方的液态玻璃顶栏
  PreferredSizeWidget _buildLiquidAppBar(
    BuildContext context,
    String title,
    bool isSolved,
  ) {
    final mq = MediaQuery.of(context);
    final double statusBarHeight = max(mq.padding.top, mq.viewPadding.top);
    const double barHeight = 52.0;
    const double borderRadius = barHeight / 2;

    return PreferredSize(
      preferredSize: Size.fromHeight(statusBarHeight + barHeight + 8),
      child: Container(
        color: Colors.transparent,
        padding: EdgeInsets.only(
          top: statusBarHeight + 4,
          left: 16,
          right: 16,
          bottom: 4,
        ),
        child: LiquidGlassContainer(
          height: barHeight,
          borderRadius: borderRadius,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () => Navigator.pop(context, true),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSolved)
                  const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: Icon(Icons.check, color: Colors.green, size: 24),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 悬浮在列表上方的 Previous / Next。按钮铺满宽度，图标和文字居中。
  Widget _buildGlassNavButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    const double height = 48.0;
    const double radius = height / 2;

    return LiquidGlassContainer(
      height: height,
      borderRadius: radius,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onPressed,
          child: SizedBox(
            width: double.infinity,
            height: height,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.black, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 计算器上方的把手。上拉增高、下拉降低（0 ~ 0.5 屏），到 0 关闭；点击动画到 0.4 屏。
  Widget _buildCalculatorHandle(double screenHeight) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (_) {
        _closeCalculatorAtZero = false;
        _calculatorController.stop();
      },
      onVerticalDragUpdate: (details) {
        if (screenHeight <= 0) return;
        final double next =
            _calculatorController.value - (details.delta.dy / screenHeight);
        _setCalculatorSplit(next, screenHeight);
      },
      onVerticalDragEnd: (_) {
        if (_activated_tool != "calculator") return;
        final glassContext = _glassContext;
        if (glassContext != null) {
          _scheduleGlassUpdate(glassContext);
        }
      },
      onTap: () {
        _closeCalculatorAtZero = false;
        _animateCalculatorSplitTo(_calculatorDefaultSplit);
      },
      child: const SizedBox(
        width: double.infinity,
        height: 32,
        child: Center(
          child: Icon(Icons.drag_handle, color: Colors.black),
        ),
      ),
    );
  }

  /// 把手固定在上方，计算器高度跟控制器走。打开时从 0 动画到 0.4 屏。
  Widget _buildCalculatorSheet(BuildContext context, double screenHeight) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildCalculatorHandle(screenHeight),
        AnimatedBuilder(
          animation: _calculatorController,
          builder: (context, _) {
            final double calculatorHeight =
                screenHeight * _calculatorController.value;
            if (calculatorHeight <= 0) return const SizedBox.shrink();

            // 太矮时按固定高度布局再裁切，避免展开动画把 26px 按键挤出溢出。
            // 高于这个高度后，计算器按真实高度重排。
            final double layoutFloor = min(200.0, screenHeight * _calculatorMaxSplit);
            final double layoutHeight = max(calculatorHeight, layoutFloor);

            return SizedBox(
              width: double.infinity,
              height: calculatorHeight,
              child: ClipRect(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final double width = constraints.maxWidth.isFinite
                        ? constraints.maxWidth
                        : MediaQuery.sizeOf(context).width;
                    return OverflowBox(
                      alignment: Alignment.topCenter,
                      minWidth: width,
                      maxWidth: width,
                      minHeight: layoutHeight,
                      maxHeight: layoutHeight,
                      child: SimpleCalculator(
                        value: _current_calculator_value ?? 0,
                        hideExpression: false,
                        hideSurroundingBorder: true,
                        autofocus: true,
                        theme: _translucentCalculatorTheme(context),
                        onChanged: (key, value, expression) {
                          setState(() {
                            _current_calculator_value = value;
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  /// 底部悬浮玻璃：可选计算器 + 提交栏，Previous / Next 浮在它上方
  Widget _buildLiquidBottomBar(
    BuildContext context, {
    required bool canPrev,
    required bool canNxt,
    required String prev,
    required String nxt,
  }) {
    final mq = MediaQuery.of(context);
    final double bottomInset = max(max(mq.padding.bottom, mq.viewPadding.bottom), 12);
    final bool showCalculator = _activated_tool == "calculator";
    final double screenHeight = mq.size.height;
    const double panelRadius = 32;

    return Container(
      color: Colors.transparent,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 4,
        bottom: bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canPrev || canNxt) ...[
            Row(
              children: [
                if (canPrev)
                  Expanded(
                    child: _buildGlassNavButton(
                      icon: Icons.arrow_back,
                      label: "Previous",
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => ProblemPage(problemId: prev),
                          ),
                        );
                      },
                    ),
                  ),
                if (canPrev && canNxt) const SizedBox(width: 12),
                if (canNxt)
                  Expanded(
                    child: _buildGlassNavButton(
                      icon: Icons.arrow_forward,
                      label: "Next",
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => ProblemPage(problemId: nxt),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          LiquidGlassContainer(
            borderRadius: panelRadius,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(panelRadius),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showCalculator)
                    _buildCalculatorSheet(context, screenHeight),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: problemSubmit(
                      widget.problemId,
                      onSubmitResult: (passed) {
                        if (passed) {
                          setState(() {
                            _problemDetail = _problemDetail?.copyWith(isSolved: true);
                          });
                        }
                      },
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

  /// Liquid Glass 样式的 SpeedDial
  Widget _buildLiquidSpeedDial(BuildContext context) {
    const double fabSize = 56.0;
    const double fabRadius = fabSize / 2;

    const double childSize = 48.0;
    const double childRadius = childSize / 2;

    return SpeedDial(
      heroTag: 'problem-page-speed-dial',
      elevation: 0,
      backgroundColor: Colors.transparent,
      overlayColor: Theme.of(context).colorScheme.secondary,
      overlayOpacity: 0.25,
      direction: SpeedDialDirection.up,
      animationCurve: Curves.easeInOutCubic,
      spacing: 8,
      spaceBetweenChildren: 12,
      closeManually: false,
      child: LiquidGlassContainer(
        width: fabSize,
        height: fabSize,
        borderRadius: fabRadius,
        child: const Center(
          child: Icon(Icons.keyboard_arrow_up, color: Colors.black),
        ),
      ),
      activeChild: LiquidGlassContainer(
        width: fabSize,
        height: fabSize,
        borderRadius: fabRadius,
        child: const Center(
          child: Icon(Icons.close, color: Colors.black),
        ),
      ),
      children: [
        SpeedDialChild(
          elevation: 0,
          backgroundColor: Colors.transparent,
          label: 'Cache this problem',
          labelBackgroundColor: Colors.white.withOpacity(0.75),
          labelStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
          child: LiquidGlassContainer(
            width: childSize,
            height: childSize,
            borderRadius: childRadius,
            child: const Center(
              child: Icon(Icons.save, color: Colors.black),
            ),
          ),
          onTap: () async {
            if (_problemDetail != null) {
              await cache(
                widget.problemId,
                _problemDetail!.name,
                _problemDetail!.markdownData,
                _problemDetail!.nxt,
                _problemDetail!.prev,
              );
              setState(() {
                _problemDetail = _problemDetail!.copyWith(isCached: true);
              });
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Problem Cached')),
              );
            }
          },
        ),
        SpeedDialChild(
          elevation: 0,
          backgroundColor: Colors.transparent,
          label: 'Calculator',
          labelBackgroundColor: Colors.white.withOpacity(0.75),
          labelStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
          child: LiquidGlassContainer(
            width: childSize,
            height: childSize,
            borderRadius: childRadius,
            child: const Center(
              child: Icon(Icons.calculate, color: Colors.black),
            ),
          ),
          onTap: () {
            if (_activated_tool == "calculator") {
              _animateCalculatorClose();
            } else {
              _openCalculator();
            }
            _scheduleGlassUpdate(context);
          },
        ),
      ],
    );
  }
}