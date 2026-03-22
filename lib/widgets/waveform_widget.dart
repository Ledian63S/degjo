import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class WaveformWidget extends StatefulWidget {
  final double progress;
  final String lessonLabel;
  final String lessonTitle;
  final String timeLabel;

  const WaveformWidget({
    super.key,
    required this.progress,
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
    setState(() => _phase += delta * 0.00168);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFFF0000),
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
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      color: Color(0xFF0F0F0F),
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (widget.timeLabel.isNotEmpty)
                    Text(
                      widget.timeLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFAAAAAA),
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

  const _WaveformPainter({required this.progress, required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    const bars = 90;
    const gap = 1.8;
    final bw = (size.width - gap * (bars - 1)) / bars;
    final h = size.height;

    for (int i = 0; i < bars; i++) {
      final p = i / bars;

      // Exact wave formula from HTML design
      final wave = math.sin(i * 0.22 + phase) * 0.42 +
          math.sin(i * 0.41 + phase * 1.6) * 0.28 +
          math.sin(i * 0.09 + phase * 0.55) * 0.18 +
          math.sin(i * 0.67 + phase * 2.4) * 0.12;

      final env =
          math.pow(math.sin(p * math.pi), 0.6).toDouble() * 0.85 + 0.15;
      final bh = math.max(3.0, (wave + 1) * 0.5 * h * 0.82 * env);

      final x = i * (bw + gap);
      final by = (h - bh) / 2;

      final isPlayed = p < progress;
      final alpha = isPlayed
          ? (0.6 + 0.4 * ((wave + 1) / 2)).clamp(0.0, 1.0)
          : (0.5 + 0.3 * ((wave + 1) / 2)).clamp(0.0, 1.0);

      final color = isPlayed
          ? Color.fromRGBO(255, 0, 0, alpha)
          : Color.fromRGBO(224, 224, 224, alpha);

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
      old.progress != progress || old.phase != phase;
}
