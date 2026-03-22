import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../theme/degjo_colors.dart';

class WaveformWidget extends StatefulWidget {
  final double progress;
  final bool isPlaying;
  final String lessonLabel;
  final String lessonTitle;
  final String timeLabel;

  const WaveformWidget({
    super.key,
    required this.progress,
    required this.isPlaying,
    required this.lessonLabel,
    required this.lessonTitle,
    required this.timeLabel,
  });

  @override
  State<WaveformWidget> createState() => _WaveformWidgetState();
}

class _WaveformWidgetState extends State<WaveformWidget>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  double _phase = 0;
  int? _lastMs;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final ms = elapsed.inMilliseconds;
    final delta = _lastMs == null ? 0 : ms - _lastMs!;
    _lastMs = ms;
    // 0.028 per frame at 60 fps ≈ 0.028 / 16.67 ms per ms
    // When not playing, slow phase accumulation to 15% to appear nearly still
    final multiplier = widget.isPlaying ? 1.0 : 0.15;
    setState(() => _phase += delta * 0.00168 * multiplier);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = DegjoColors.of(context);
    return SizedBox(
      width: double.infinity,
      height: 140,
      child: Stack(
        children: [
          // Waveform bars
          Positioned.fill(
            child: CustomPaint(
              painter: _WaveformPainter(
                progress: widget.progress,
                phase: _phase,
                isIdle: !widget.isPlaying && widget.progress == 0.0,
                accentColor: c.accent,
                mutedColor: c.separator,
              ),
            ),
          ),
          // Floating overlay: lesson label + title + time
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.lessonLabel.isNotEmpty)
                    Text(
                      widget.lessonLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: c.accent,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    widget.lessonTitle,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      color: c.text,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (widget.timeLabel.isNotEmpty)
                    Text(
                      widget.timeLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: c.muted,
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

class _WaveformPainter extends CustomPainter {
  final double progress;
  final double phase;
  final bool isIdle;
  final Color accentColor;
  final Color mutedColor;

  const _WaveformPainter({
    required this.progress,
    required this.phase,
    required this.isIdle,
    required this.accentColor,
    required this.mutedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const bars = 90;
    const gap = 1.8;
    final bw = (size.width - gap * (bars - 1)) / bars;
    final h = size.height;

    for (int i = 0; i < bars; i++) {
      final p = i / bars;

      double bh;
      double alpha;

      if (isIdle) {
        // Flat line effect: all bars at minimum height
        bh = 3.0;
        alpha = 0.5;
      } else {
        // Exact wave formula from HTML design
        final wave = math.sin(i * 0.22 + phase) * 0.42 +
            math.sin(i * 0.41 + phase * 1.6) * 0.28 +
            math.sin(i * 0.09 + phase * 0.55) * 0.18 +
            math.sin(i * 0.67 + phase * 2.4) * 0.12;

        final env =
            math.pow(math.sin(p * math.pi), 0.6).toDouble() * 0.85 + 0.15;
        bh = math.max(3.0, (wave + 1) * 0.5 * h * 0.82 * env);

        final isPlayed = p < progress;
        alpha = isPlayed
            ? (0.6 + 0.4 * ((wave + 1) / 2)).clamp(0.0, 1.0)
            : (0.5 + 0.3 * ((wave + 1) / 2)).clamp(0.0, 1.0);
      }

      final x = i * (bw + gap);
      final by = (h - bh) / 2;

      final isPlayed = !isIdle && p < progress;
      final baseColor = isPlayed ? accentColor : mutedColor;
      final color = baseColor.withOpacity(alpha);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, by, bw, bh),
          const Radius.circular(1.5),
        ),
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.progress != progress ||
      old.phase != phase ||
      old.isIdle != isIdle ||
      old.accentColor != accentColor ||
      old.mutedColor != mutedColor;
}
