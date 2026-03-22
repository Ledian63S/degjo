import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _gestureAnim = CurvedAnimation(
      parent: _gestureAnimCtrl,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _flashCtrl.dispose();
    _gestureAnimCtrl.dispose();
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

    return Material(
      color: Colors.white,
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
              child: _blob(300, const Color(0xFFFF0000), 0.06),
            ),
            Positioned(
              bottom: -60,
              left: -60,
              child: _blob(260, const Color(0xFF6C63FF), 0.05),
            ),

            // Red flash overlay
            AnimatedBuilder(
              animation: _flashCtrl,
              builder: (context, _) => Opacity(
                opacity: _flashCtrl.value,
                child: Container(color: const Color(0x0AFF0000)),
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
                        Container(
                          width: 28,
                          height: 20,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF0000),
                            borderRadius: BorderRadius.circular(5),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF0000).withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: CustomPaint(
                              size: Size(12, 12),
                              painter: _PlayTrianglePainter(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Dëgjo',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                            color: Color(0xFF0F0F0F),
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
                                  color: const Color(0xFFEEEEEE)),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Kalo →',
                              style: TextStyle(
                                  fontSize: 13, color: Color(0xFFCCCCCC)),
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
                              ? const Color(0xFFFF0000)
                              : isDone
                                  ? const Color(0xFFFFc0c0)
                                  : const Color(0xFFF0F0F0),
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
                          animation: _gestureAnim,
                          builder: (context, _) {
                            return Container(
                              width: 160,
                              height: 160,
                              decoration: BoxDecoration(
                                color: _stepDone
                                    ? const Color(0xFFFFF0F0)
                                    : const Color(0xFFFAFAFA),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _stepDone
                                      ? const Color(0xFFFFCCCC)
                                      : const Color(0xFFF0F0F0),
                                  width: 1.5,
                                ),
                              ),
                              child: Center(
                                child: _buildAnimatedIcon(
                                    _step, _gestureAnim.value),
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
                    child: Column(
                      children: [
                        Text(
                          step.stepLabel,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFFFF0000),
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          step.gestureName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.7,
                            height: 1.2,
                            color: Color(0xFF0F0F0F),
                          ),
                        ),
                        const SizedBox(height: 10),
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFFAAAAAA),
                              height: 1.5,
                              fontFamily: 'Roboto',
                            ),
                            children: [
                              TextSpan(text: '${step.descPre} '),
                              TextSpan(
                                text: step.descBold,
                                style: const TextStyle(
                                  color: Color(0xFF0F0F0F),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
                            ? const Color(0xFFFFF5F5)
                            : const Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.circular(16),
                        border: _stepDone
                            ? Border.all(
                                color: const Color(0xFFFFCCCC), width: 1.5)
                            : null,
                      ),
                      foregroundDecoration: _stepDone
                          ? null
                          : BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: _DashedBorder(
                                color: const Color(0xFFE8E8E8),
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
                                ? const Color(0xFFFF0000)
                                : const Color(0xFFCCCCCC),
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

  /// Returns the icon for [step] with a movement/scale animation driven by [v] (0→1).
  Widget _buildAnimatedIcon(int step, double v) {
    // (hand emoji, direction symbol, direction color)
    const data = [
      ('👆', '', false),        // tap
      ('✌️', '↑', true),       // 2-finger swipe up
      ('✌️', '↓', true),       // 2-finger swipe down
      ('✌️', '↔', true),       // 2-finger horizontal
      ('🖐', '', false),        // 3-finger tap — open hand
    ];
    final (emoji, arrow, hasArrow) = data[step];

    Widget icon = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 64, height: 1)),
        if (hasArrow) ...[
          const SizedBox(height: 6),
          Text(
            arrow,
            style: const TextStyle(
              fontSize: 26,
              color: Color(0xFFFF0000),
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ],
      ],
    );

    switch (step) {
      case 0:
        return Transform.scale(scale: 0.88 + v * 0.12, child: icon);
      case 1:
        return Transform.translate(offset: Offset(0, -v * 11), child: icon);
      case 2:
        return Transform.translate(offset: Offset(0, v * 11), child: icon);
      case 3:
        return Transform.translate(offset: Offset(v * 11, 0), child: icon);
      case 4:
        return Transform.translate(offset: Offset(0, v * 7), child: icon);
      default:
        return icon;
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

// ── Play triangle logo icon ────────────────────────────────────

class _PlayTrianglePainter extends CustomPainter {
  const _PlayTrianglePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(4, 2)
      ..lineTo(10, 6)
      ..lineTo(4, 10)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_PlayTrianglePainter old) => false;
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

