import 'dart:math' as math;
import 'package:flutter/material.dart';

class WaveformWidget extends StatefulWidget {
  final double played; // 0.0–1.0

  const WaveformWidget({
    super.key,
    required this.played,
  });

  @override
  State<WaveformWidget> createState() => _WaveformWidgetState();
}

// ── Bubble data ──────────────────────────────────────────────────

class _Bubble {
  double x;
  double y;
  final double radius;
  final double speed;
  double alpha;
  double wobblePhase;

  _Bubble({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.alpha,
    required this.wobblePhase,
  });
}

// ── State ────────────────────────────────────────────────────────

class _WaveformWidgetState extends State<WaveformWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  double _phase = 0;
  final _bubbles = <_Bubble>[];
  final _rand = math.Random();
  double _canvasWidth = 0;
  static const double _height = 150;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )
      ..repeat()
      ..addListener(_onTick);
  }

  void _onTick() {
    _phase += 0.028;

    if (_canvasWidth > 0 && _rand.nextDouble() < 0.12) {
      _bubbles.add(_Bubble(
        x: _rand.nextDouble() * _canvasWidth,
        y: _height / 2,
        radius: 2 + _rand.nextDouble() * 5,
        speed: 0.18 + _rand.nextDouble() * 0.28,
        alpha: 0.55 + _rand.nextDouble() * 0.30,
        wobblePhase: _rand.nextDouble() * math.pi * 2,
      ));
    }

    _bubbles.removeWhere((b) {
      b.y -= b.speed;
      b.alpha -= 0.006;
      b.x += math.sin(b.wobblePhase) * 0.3;
      b.wobblePhase += 0.08;
      return b.y < 0 || b.alpha <= 0;
    });

    setState(() {});
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: _height,
      child: LayoutBuilder(builder: (ctx, box) {
        _canvasWidth = box.maxWidth;
        return CustomPaint(
          painter: _WavePainter(
            played: widget.played,
            phase: _phase,
            bubbles: List.unmodifiable(_bubbles),
            canvasHeight: _height,
          ),
        );
      }),
    );
  }
}

// ── Wave + bubble painter ────────────────────────────────────────

class _WavePainter extends CustomPainter {
  final double played;
  final double phase;
  final List<_Bubble> bubbles;
  final double canvasHeight;

  static const _red = Color(0xFFFF0000);
  static const _grey = Color(0xFFE0E0E0);

  const _WavePainter({
    required this.played,
    required this.phase,
    required this.bubbles,
    required this.canvasHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final centerY = h / 2;
    final playedX = played * w;

    // ── Layer 1: mirrored bars ──────────────────────────────────
    const bars = 70;
    const gap = 1.8;
    final bw = (w - gap * (bars - 1)) / bars;

    for (int i = 0; i < bars; i++) {
      final p = i / bars;
      final x = i * (bw + gap);
      final isPlayed = (x + bw / 2) < playedX;
      final color = isPlayed ? _red : _grey;

      final wave = math.sin(i * 0.22 + phase) * 0.40 +
          math.sin(i * 0.41 + phase * 1.6) * 0.26 +
          math.sin(i * 0.09 + phase * 0.55) * 0.18 +
          math.sin(i * 0.67 + phase * 2.4) * 0.12;

      final env =
          math.pow(math.sin(p * math.pi), 0.6).toDouble() * 0.82 + 0.18;
      final topH = math.max(2.0, (wave + 1) * 0.5 * (h / 2) * 0.85 * env);
      final botH = topH * 0.5;

      // Top half — grows upward from center, top corners rounded
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(x, centerY - topH, bw, topH),
          topLeft: const Radius.circular(1),
          topRight: const Radius.circular(1),
        ),
        Paint()
          ..color =
              color.withOpacity(isPlayed ? 0.45 : 0.22),
      );

      // Bottom mirror — grows downward, bottom corners rounded
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(x, centerY, bw, botH),
          bottomLeft: const Radius.circular(1),
          bottomRight: const Radius.circular(1),
        ),
        Paint()
          ..color =
              color.withOpacity(isPlayed ? 0.20 : 0.10),
      );
    }

    // ── Layer 2: bubbles ────────────────────────────────────────
    for (final b in bubbles) {
      final isLeft = b.x < playedX;
      final alpha = (isLeft ? b.alpha * 0.9 : b.alpha * 0.5).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(b.x, b.y),
        b.radius,
        Paint()..color = (isLeft ? _red : _grey).withOpacity(alpha),
      );
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) => true;
}

