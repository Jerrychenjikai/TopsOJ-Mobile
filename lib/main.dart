import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:TopsOJ/basic/ui_basic.dart';
import 'package:TopsOJ/main_page/liquid_glass_metrics_hook.dart';
import 'package:TopsOJ/main_page/main_page.dart';
import 'package:TopsOJ/main_page/main_split_scope.dart';
import 'package:TopsOJ/problem_page/problem_page.dart';

/// 宽屏分栏阈值（逻辑像素）。
///
/// 左栏固定占 30%。1080 时左栏约 324，接近现在这套手机布局的下限。
/// 因此：手机、iPad 竖屏、以及 iPad 把窗口拉窄到这个宽度以下，都是整页；
/// iPad 横屏全窗口（大约 1080–1366）才是左 30% / 右 70%。
/// 窗口变化时 Flutter 会更新 [MediaQuery]，壳层跟着重建，不需要额外的监听器。
const double kMainSplitMinWidth = 1080;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 开启 Edge-to-Edge，并将系统状态栏与底部导航栏设为全透明
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  await preloadLiquidGlassShader();
  await PackageInfo.fromPlatform();
  runApp(const ProviderScope(child: TopsOJ()));
}

class TopsOJ extends StatelessWidget {
  const TopsOJ({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Tops Online Judge",
      routes: {
        '/home': (context) => const AppShell(),
      },
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromRGBO(107, 38, 37, 1.0),
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
        ),
        textTheme: Theme.of(context).textTheme.apply(
          bodyColor: Colors.black,
          displayColor: Colors.black,
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 6,
          showCloseIcon: true,
          closeIconColor: Theme.of(context).colorScheme.onPrimary,
          dismissDirection: DismissDirection.down,
        ),
      ),
      home: const AppShell(),
    );
  }
}

/// 自适应壳层。
///
/// - 窄屏：和原来一样，主界面整页；从主界面或题目列表点开的题目整页盖上来。
/// - 宽屏：主界面在左 30%，右 70% 空着，直到从主界面点开题目。
/// - 年度报告、对战、缓存题，以及「不是从主界面进去」的题目，仍是 Navigator.push 的全屏页。
/// - 窗口变窄：右栏空着就回到主界面；右栏有题就把那道题变成整页。
///   窗口再变宽：恢复分栏，题还在右栏。
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final GlobalKey<_ProblemSlideState> _slideKey = GlobalKey<_ProblemSlideState>();

  String? _paneProblemId;
  bool _animateEntrance = false;
  bool _animatingProblem = false;
  bool _closing = false;

  bool _isWide(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= kMainSplitMinWidth;
  }

  void _openProblem(String id) {
    if (_closing || id.isEmpty || id == _paneProblemId) return;
    final wide = _isWide(context);
    setState(() {
      // 只有「窄屏、从主界面新开一层」才做滑入。换题和窗口拉伸都不重播。
      _animateEntrance = !wide && _paneProblemId == null;
      _animatingProblem = _animateEntrance;
      _paneProblemId = id;
    });
  }

  void _onProblemEntranceSettled() {
    if (!mounted || !_animatingProblem) return;
    setState(() => _animatingProblem = false);
  }

  Future<void> _closeProblem() async {
    if (_paneProblemId == null || _closing) return;
    final wide = _isWide(context);
    if (!wide && _slideKey.currentState != null) {
      _closing = true;
      setState(() => _animatingProblem = true);
      try {
        await _slideKey.currentState?.reverse();
      } finally {
        _closing = false;
      }
    }
    if (!mounted) return;
    setState(() {
      _paneProblemId = null;
      _animatingProblem = false;
      _animateEntrance = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= kMainSplitMinWidth;
    final leftWidth = size.width * 0.3;
    final rightWidth = size.width - leftWidth;
    // 窄屏题目滑入/滑出时主界面留在下面，动画结束后再停掉它的绘制。
    final hideMain =
        !wide && _paneProblemId != null && !_animatingProblem && !_closing;

    return MainSplitScope(
      onOpenProblem: _openProblem,
      child: WillPopScope(
        onWillPop: () async {
          if (_paneProblemId != null) {
            _closeProblem();
            return false;
          }
          return true;
        },
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: wide ? leftWidth : size.width,
              child: Offstage(
                offstage: hideMain,
                child: TickerMode(
                  enabled: !hideMain,
                  child: IgnorePointer(
                    ignoring: !wide && _paneProblemId != null,
                    child: ShellPaneActive(
                      active: !hideMain,
                      child: _PaneFrame(
                        width: wide ? leftWidth : size.width,
                        clipRightSafe: wide,
                        child: const MainPage(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (wide && _paneProblemId == null)
              Positioned(
                left: leftWidth,
                top: 0,
                bottom: 0,
                right: 0,
                child: _PaneFrame(
                  width: rightWidth,
                  clipLeftSafe: true,
                  child: const _EmptyProblemPane(),
                ),
              ),
            if (_paneProblemId != null)
              Positioned(
                key: const ValueKey('shell-problem'),
                left: wide ? leftWidth : 0,
                top: 0,
                bottom: 0,
                right: 0,
                child: ClipRect(
                  child: _PaneFrame(
                    width: wide ? rightWidth : size.width,
                    clipLeftSafe: wide,
                    child: _ProblemSlide(
                      key: _slideKey,
                      animate: _animateEntrance && !wide,
                      onSettled: _onProblemEntranceSettled,
                      child: ProblemPage(
                        key: ValueKey<String>(_paneProblemId!),
                        problemId: _paneProblemId!,
                        shell: ProblemShellLink(
                          onClose: () {
                            _closeProblem();
                          },
                          onOpenProblem: _openProblem,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (wide)
              Positioned(
                left: leftWidth,
                top: 0,
                bottom: 0,
                width: 1,
                child: const IgnorePointer(
                  child: ColoredBox(color: Color(0x14000000)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 把一栏的 [MediaQuery.size] 收成这一栏自己的宽度。
/// 主界面里的抽屉、题目列表的底栏间距都读的是 size，不收的话会按整窗来排。
class _PaneFrame extends StatelessWidget {
  final double width;
  final bool clipLeftSafe;
  final bool clipRightSafe;
  final Widget child;

  const _PaneFrame({
    required this.width,
    required this.child,
    this.clipLeftSafe = false,
    this.clipRightSafe = false,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    var padding = mq.padding;
    var viewPadding = mq.viewPadding;
    if (clipLeftSafe) {
      padding = padding.copyWith(left: 0);
      viewPadding = viewPadding.copyWith(left: 0);
    }
    if (clipRightSafe) {
      padding = padding.copyWith(right: 0);
      viewPadding = viewPadding.copyWith(right: 0);
    }
    return MediaQuery(
      data: mq.copyWith(
        size: Size(width, mq.size.height),
        padding: padding,
        viewPadding: viewPadding,
      ),
      child: child,
    );
  }
}

class _EmptyProblemPane extends StatelessWidget {
  const _EmptyProblemPane();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surface,
      child: Center(
        child: Text(
          'Select a problem',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: scheme.onSurface.withOpacity(0.35),
          ),
        ),
      ),
    );
  }
}

class _ProblemSlide extends StatefulWidget {
  final bool animate;
  final VoidCallback onSettled;
  final Widget child;

  const _ProblemSlide({
    super.key,
    required this.animate,
    required this.onSettled,
    required this.child,
  });

  @override
  State<_ProblemSlide> createState() => _ProblemSlideState();
}

class _ProblemSlideState extends State<_ProblemSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _curve;
  late final Animation<Offset> _offset;
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _offset = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(_curve);
    if (widget.animate) {
      _controller.addStatusListener(_onStatus);
      _listening = true;
      _controller.forward();
    } else {
      _controller.value = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onSettled();
      });
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onSettled();
    });
  }

  @override
  void didUpdateWidget(_ProblemSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 窗口拉宽时右栏直接到位。正在关闭（reverse）时不能把进度打回去。
    if (!widget.animate &&
        _controller.status != AnimationStatus.reverse &&
        _controller.value != 1) {
      _controller.value = 1;
    }
  }

  Future<void> reverse() async {
    if (_controller.value == 0) return;
    try {
      await _controller.reverse();
    } catch (_) {
      // 动画中途壳层被拆掉时，controller 会先 dispose。
    }
  }

  @override
  void dispose() {
    if (_listening) {
      _controller.removeStatusListener(_onStatus);
    }
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _offset,
      child: widget.child,
    );
  }
}
