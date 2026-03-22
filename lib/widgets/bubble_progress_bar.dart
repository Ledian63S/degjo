import 'dart:math' as math;
import 'package:flutter/material.dart';

class BubbleProgressBar extends StatefulWidget {
  final double played; // 0.0–1.0

  const BubbleProgressBar({super.key, required this.played});

  @override
  State<BubbleProgressBar> createState() => _BubbleProgressBarState();
}

class _BubbleProgressBarState extends State<BubbleProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  double _phase = 0;

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
    setState(() => _phase += 0.06);
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
      height: 40,
      child: CustomPaint(
        painter: _ProgressPainter(
          played: widget.played,
          phase: _phase,
        ),
      ),
    );
  }
}

class _ProgressPainter extends CustomPainter {
  final double played;
  final double phase;

  static const _red = Color(0xFFFF0000);
  static const _grey = Color(0xFFE0E0E0);
  static const _barH = 3.0;
  static const _barY = 20.0; // center of 40px

  const _ProgressPainter({required this.played, required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final playedW = (played * w).clamp(0.0, w);
    final barTop = _barY - _barH / 2;
    const rr = Radius.circular(1.5);

    // ── Layer 1: track ──────────────────────────────────────────
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, barTop, w, _barH), rr),
      Paint()..color = _grey.withOpacity(0.45),
    );

    // ── Layer 2: played fill ────────────────────────────────────
    if (playedW > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(0, barTop, playedW, _barH), rr),
        Paint()..color = _red.withOpacity(0.90),
      );
    }

    // ── Layer 3: bubble thumb ───────────────────────────────────
    final thumbX = playedW.clamp(0.0, w);

    // Outer ring — gentle breathing
    final outerOpacity = 0.06 + math.sin(phase * 2) * 0.04;
    canvas.drawCircle(
      Offset(thumbX, _barY),
      10.0,
      Paint()..color = _red.withOpacity(outerOpacity.clamp(0.02, 0.10)),
    );

    // Middle ring — slightly offset pulse
    final middleOpacity = 0.14 + math.sin(phase * 2 + 0.8) * 0.06;
    canvas.drawCircle(
      Offset(thumbX, _barY),
      7.0,
      Paint()..color = _red.withOpacity(middleOpacity.clamp(0.08, 0.20)),
    );

    // Inner solid dot
    canvas.drawCircle(
      Offset(thumbX, _barY),
      5.0,
      Paint()..color = _red,
    );
  }

  @override
  bool shouldRepaint(_ProgressPainter old) =>
      old.played != played || old.phase != phase;
}
