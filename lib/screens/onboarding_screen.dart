import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/degjo_colors.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  int _step = 0;
  bool _stepDone = false;
  late AnimationController _flashCtrl;
  late AnimationController _gestureAnimCtrl;
  late Animation<double> _gestureAnim;
  late AnimationController _lrAnimCtrl; // separate controller for horizontal oscillation

  // Per-pointer gesture tracking (same approach as player_screen)
  final Map<int, Offset> _pointerStarts = {};
  final Map<int, Offset> _allStarts = {};
  final Map<int, Offset> _allEnds = {};
  final Set<int> _movedPointers = {};
  int _maxPointers = 0;
  DateTime _gestureStart = DateTime.now();

  // Prevents skip-button tap from also triggering gesture handler
  bool _skipPressed = false;

  static const double _swipeThreshold = 40;
  static const Duration _tapMax = Duration(milliseconds: 400);

  static const _steps = [
    _StepData(
      stepLabel: 'Gjesti 1 nga 5',
      gestureName: 'Luaj / Ndalo',
      descPre: 'Prek ekranin kudo me',
      descBold: '1 gisht',
      hintText: 'Prek kudo në ekran për ta provuar',
    ),
    _StepData(
      stepLabel: 'Gjesti 2 nga 5',
      gestureName: '+30 sekonda',
      descPre: 'Rrëshqit lart me',
      descBold: '2 gishta',
      hintText: 'Prek kudo në ekran për ta provuar',
    ),
    _StepData(
      stepLabel: 'Gjesti 3 nga 5',
      gestureName: '−30 sekonda',
      descPre: 'Rrëshqit poshtë me',
      descBold: '2 gishta',
      hintText: 'Prek kudo në ekran për ta provuar',
    ),
    _StepData(
      stepLabel: 'Gjesti 4 nga 5',
      gestureName: 'Ndrysho mësimin',
      descPre: 'Rrëshqit djathtas ose majtas me',
      descBold: '2 gishta',
      hintText: 'Prek kudo në ekran për ta provuar',
    ),
    _StepData(
      stepLabel: 'Gjesti 5 nga 5',
      gestureName: 'Kalo te mësimi',
      descPre: 'Prek me',
      descBold: '3 gishta',
      hintText: 'Prek kudo në ekran për ta provuar',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _flashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _gestureAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _gestureAnim = CurvedAnimation(
      parent: _gestureAnimCtrl,
      curve: Curves.easeInOut,
    );
    // Full-cycle controller for left↔right oscillation (no reverse)
    _lrAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _flashCtrl.dispose();
    _gestureAnimCtrl.dispose();
    _lrAnimCtrl.dispose();
    super.dispose();
  }

  void _resetGesture() {
    _allStarts.clear();
    _allEnds.clear();
    _movedPointers.clear();
    _maxPointers = 0;
  }

  /// Returns true if the completed gesture matches what step [s] requires.
  bool _gestureMatchesStep(int s, int count, bool anyMoved,
      double avgDx, double avgDy, Duration elapsed) {
    final absDx = avgDx.abs();
    final absDy = avgDy.abs();
    switch (s) {
      case 0: // 1-finger tap
        return count == 1 && !anyMoved && elapsed < _tapMax;
      case 1: // 2-finger swipe UP
        return count == 2 && avgDy < -_swipeThreshold && absDy > absDx;
      case 2: // 2-finger swipe DOWN
        return count == 2 && avgDy > _swipeThreshold && absDy > absDx;
      case 3: // 2-finger swipe horizontal (either direction)
        return count == 2 && absDx > _swipeThreshold && absDx > absDy;
      case 4: // 3-finger tap
        return count == 3 && !anyMoved && elapsed < _tapMax;
      default:
        return false;
    }
  }

  void _completeStep() {
    if (_stepDone) return;
    setState(() => _stepDone = true);

    HapticFeedback.lightImpact();
    _flashCtrl.forward().then((_) => _flashCtrl.reverse());

    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      if (_step < _steps.length - 1) {
        HapticFeedback.selectionClick();
        setState(() {
          _step++;
          _stepDone = false;
        });
      } else {
        HapticFeedback.mediumImpact();
        widget.onComplete();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_step];
    final c = DegjoColors.of(context);

    return Material(
      color: c.card,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) {
          _pointerStarts[e.pointer] = e.position;
          final n = _pointerStarts.length;
          if (n > _maxPointers) _maxPointers = n;
          if (n == 1) {
            _resetGesture();
            _maxPointers = 1;
            _gestureStart = DateTime.now();
            _allStarts[e.pointer] = e.position;
          } else {
            _allStarts[e.pointer] = e.position;
          }
        },
        onPointerMove: (e) {
          final start = _allStarts[e.pointer];
          if (start != null && (e.position - start).distance > 8) {
            _movedPointers.add(e.pointer);
          }
        },
        onPointerCancel: (e) => _pointerStarts.remove(e.pointer),
        onPointerUp: (e) {
          _allEnds[e.pointer] = e.position;
          _pointerStarts.remove(e.pointer);

          // Wait for all fingers to lift
          if (_pointerStarts.isNotEmpty) return;

          // Skip button takes priority
          if (_skipPressed) { _skipPressed = false; _resetGesture(); return; }

          final count = _maxPointers;
          final anyMoved = _movedPointers.isNotEmpty;
          final elapsed = DateTime.now().difference(_gestureStart);

          // Average displacement
          double avgDx = 0, avgDy = 0;
          int measured = 0;
          for (final id in _allEnds.keys) {
            final s = _allStarts[id];
            if (s != null) {
              avgDx += _allEnds[id]!.dx - s.dx;
              avgDy += _allEnds[id]!.dy - s.dy;
              measured++;
            }
          }
          if (measured > 0) { avgDx /= measured; avgDy /= measured; }

          _resetGesture();

          if (_gestureMatchesStep(_step, count, anyMoved, avgDx, avgDy, elapsed)) {
            _completeStep();
          }
        },
        child: Stack(
          children: [
            // Background blobs
            Positioned(
              top: -80,
              right: -80,
              child: _blob(300, c.blobRed, 0.06),
            ),
            Positioned(
              bottom: -60,
              left: -60,
              child: _blob(260, c.blobPurple, 0.05),
            ),

            // Flash overlay
            AnimatedBuilder(
              animation: _flashCtrl,
              builder: (context, _) => Opacity(
                opacity: _flashCtrl.value,
                child: Container(color: c.accent.withOpacity(0.04)),
              ),
            ),

            // Main content
            SafeArea(
              child: Column(
                children: [
                  // Top bar: logo + skip
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 12, 28, 0),
                    child: Row(
                      children: [
                        // Logo
                        Image.asset('assets/app_logo.png', width: 32, height: 32),
                        const SizedBox(width: 8),
                        Text(
                          'Dëgjo',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                            color: c.text,
                          ),
                        ),
                        const Spacer(),
                        // Skip — sets flag so Listener doesn't also advance
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (_) => _skipPressed = true,
                          onTap: widget.onComplete,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 5),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: c.dashedBorder),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Kalo →',
                              style: TextStyle(
                                  fontSize: 13, color: c.muted),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Progress dots
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_steps.length, (i) {
                      final isActive = i == _step;
                      final isDone = i < _step;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 350),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: isActive ? 22 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: isActive
                              ? c.accent
                              : isDone
                                  ? c.dotDone
                                  : c.dotInactive,
                          borderRadius:
                              BorderRadius.circular(isActive ? 4 : 50),
                        ),
                      );
                    }),
                  ),

                  // Gesture icon area with movement animation
                  Expanded(
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: AnimatedBuilder(
                          key: ValueKey(_step),
                          animation: Listenable.merge([_gestureAnim, _lrAnimCtrl]),
                          builder: (context, _) {
                            return Container(
                              width: 160,
                              height: 160,
                              decoration: BoxDecoration(
                                color: _stepDone
                                    ? c.activeLessonBg
                                    : c.inputBg,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _stepDone
                                      ? c.dotDone
                                      : c.dashedBorder,
                                  width: 1.5,
                                ),
                              ),
                              child: ClipOval(
                                child: Center(
                                  child: _buildAnimatedIcon(
                                      _step, _gestureAnim.value),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                  // Info area
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 36),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      transitionBuilder: (child, animation) {
                        final offsetAnimation = Tween<Offset>(
                          begin: const Offset(1.0, 0.0),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                            parent: animation, curve: Curves.easeOutCubic));
                        return SlideTransition(
                            position: offsetAnimation, child: child);
                      },
                      child: Column(
                        key: ValueKey(_step),
                        children: [
                          Text(
                            step.stepLabel,
                            style: TextStyle(
                              fontSize: 11,
                              color: c.accent,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            step.gestureName,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.7,
                              height: 1.2,
                              color: c.text,
                            ),
                          ),
                          const SizedBox(height: 10),
                          RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 16,
                                color: c.muted,
                                height: 1.5,
                                fontFamily: 'Roboto',
                              ),
                              children: [
                                TextSpan(text: '${step.descPre} '),
                                TextSpan(
                                  text: step.descBold,
                                  style: TextStyle(
                                    color: c.text,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Dashed hint box
                  Padding(
                    padding: const EdgeInsets.fromLTRB(36, 28, 36, 0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: _stepDone
                            ? c.activeLessonBg
                            : c.inputBg,
                        borderRadius: BorderRadius.circular(16),
                        border: _stepDone
                            ? Border.all(
                                color: c.dotDone, width: 1.5)
                            : null,
                      ),
                      foregroundDecoration: _stepDone
                          ? null
                          : BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: _DashedBorder(
                                color: c.dashedBorder,
                                width: 1.5,
                                dash: 6,
                                gap: 4,
                              ),
                            ),
                      child: Center(
                        child: Text(
                          _stepDone ? '✓ Shumë mirë!' : step.hintText,
                          style: TextStyle(
                            fontSize: 14,
                            color: _stepDone
                                ? c.accent
                                : c.muted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Returns the animated SVG icon for [step].
  /// [v] is the main animation value (0→1, easeInOut, reverses).
  /// For horizontal, [_lrAnimCtrl.value] drives a full sin oscillation.
  Widget _buildAnimatedIcon(int step, double v) {
    const assets = [
      'assets/gestures/gesture_tap.svg',
      'assets/gestures/gesture_swipe_up.svg',
      'assets/gestures/gesture_swipe_down.svg',
      'assets/gestures/gesture_swipe_lr.svg',
      'assets/gestures/gesture_three_tap.svg',
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // In dark mode, the dark (#0f0f0f) SVG elements are invisible.
    // Apply a color filter to swap them to a light gray.
    // The tap icon (step 0) only uses red — no filter needed.
    Widget svgWidget = SvgPicture.asset(assets[step], width: 70, height: 70);
    if (isDark && step != 0) {
      svgWidget = ColorFiltered(
        colorFilter: const ColorFilter.mode(
          Color(0xFFDDDDDD),
          BlendMode.srcIn,
        ),
        child: svgWidget,
      );
    }

    final svg = svgWidget;

    switch (step) {
      case 0: // tap — ripple pulse outward
        return Transform.scale(scale: 1.0 + v * 0.22, child: svg);

      case 1: // swipe up — slides up with slight fade
        return Opacity(
          opacity: 1.0 - v * 0.25,
          child: Transform.translate(offset: Offset(0, -v * 38), child: svg),
        );

      case 2: // swipe down — slides down with slight fade
        return Opacity(
          opacity: 1.0 - v * 0.25,
          child: Transform.translate(offset: Offset(0, v * 38), child: svg),
        );

      case 3: // horizontal — smooth left ↔ right oscillation via sin
        final dx = math.sin(_lrAnimCtrl.value * 2 * math.pi) * 32;
        return Transform.translate(offset: Offset(dx, 0), child: svg);

      case 4: // 3-finger tap — ripple pulse outward
        return Transform.scale(scale: 1.0 + v * 0.22, child: svg);

      default:
        return svg;
    }
  }

  Widget _blob(double size, Color color, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: opacity), color.withValues(alpha: 0)],
          stops: const [0, 0.7],
        ),
      ),
    );
  }

}

// ── Step data model ────────────────────────────────────────────

class _StepData {
  final String stepLabel;
  final String gestureName;
  final String descPre;
  final String descBold;
  final String hintText;

  const _StepData({
    required this.stepLabel,
    required this.gestureName,
    required this.descPre,
    required this.descBold,
    required this.hintText,
  });
}

// ── Dashed border decoration ───────────────────────────────────

class _DashedBorder extends BoxBorder {
  final Color color;
  final double width;
  final double dash;
  final double gap;

  const _DashedBorder({
    required this.color,
    required this.width,
    required this.dash,
    required this.gap,
  });

  @override
  BorderSide get bottom => BorderSide.none;
  @override
  BorderSide get top => BorderSide.none;
  @override
  bool get isUniform => true;
  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(width);

  @override
  void paint(Canvas canvas, Rect rect,
      {TextDirection? textDirection,
      BoxShape shape = BoxShape.rectangle,
      BorderRadius? borderRadius}) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final rRect = borderRadius != null
        ? borderRadius.toRRect(rect)
        : RRect.fromRectAndRadius(rect, const Radius.circular(16));

    final path = Path()..addRRect(rRect);
    final pathMetrics = path.computeMetrics();

    for (final metric in pathMetrics) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  ShapeBorder scale(double t) => this;
}
