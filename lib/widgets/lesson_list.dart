import 'package:flutter/material.dart';
import '../models/lesson.dart';
import '../theme/degjo_colors.dart';

class LessonList extends StatefulWidget {
  final List<Lesson> lessons;
  final int currentIndex;
  final bool isPlaying;

  const LessonList({
    super.key,
    required this.lessons,
    required this.currentIndex,
    required this.isPlaying,
  });

  @override
  State<LessonList> createState() => _LessonListState();
}

class _LessonListState extends State<LessonList> {
  final _controller = ScrollController();
  static const double _itemHeight = 64.0;

  @override
  void didUpdateWidget(LessonList old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex) {
      _scrollToCurrent();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
  }

  void _scrollToCurrent() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_controller.hasClients) return;
      final viewport = _controller.position.viewportDimension;
      final target = widget.currentIndex * _itemHeight - viewport / 2 + _itemHeight / 2;
      _controller.animateTo(
        target.clamp(0.0, _controller.position.maxScrollExtent),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = DegjoColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Mësimet',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: c.text,
                ),
              ),
              Text(
                '${widget.lessons.length} gjithsej',
                style: TextStyle(
                  fontSize: 12,
                  color: c.muted,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: _controller,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.lessons.length,
            itemExtent: _itemHeight,
            padding: EdgeInsets.zero,
            itemBuilder: (context, i) {
              final lesson = widget.lessons[i];
              final isCurrent = i == widget.currentIndex;
              final isDone = lesson.done && !isCurrent;
              return _LessonRow(
                lesson: lesson,
                index: i,
                isCurrent: isCurrent,
                isDone: isDone,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LessonRow extends StatelessWidget {
  final Lesson lesson;
  final int index;
  final bool isCurrent;
  final bool isDone;

  const _LessonRow({
    required this.lesson,
    required this.index,
    required this.isCurrent,
    required this.isDone,
  });

  @override
  Widget build(BuildContext context) {
    final c = DegjoColors.of(context);
    return Container(
      color: isCurrent ? c.activeLessonBg : c.card,
      child: Column(
        children: [
          Container(height: 0.5, color: c.separator),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  // Lesson number
                  SizedBox(
                    width: 18,
                    child: Text(
                      '${index + 1}',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isCurrent ? FontWeight.w700 : FontWeight.w500,
                        color: isCurrent
                            ? c.accent
                            : c.muted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // 5px vertical accent bar
                  Container(
                    width: 5,
                    height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      gradient: isCurrent
                          ? LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                c.accent.withOpacity(0.7),
                                c.accent,
                              ],
                            )
                          : null,
                      color: isCurrent ? null : c.dotInactive,
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Title + "Duke luajtur" for active
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        isCurrent
                          ? _MarqueeText(
                              text: lesson.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: c.text,
                              ),
                            )
                          : Text(
                              lesson.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: c.muted,
                              ),
                            ),
                        if (isCurrent) ...[
                          const SizedBox(height: 3),
                          Text(
                            'Duke luajtur',
                            style: TextStyle(
                              fontSize: 12,
                              color: c.accent,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Status dot
                  _StatusDot(isCurrent: isCurrent, isDone: isDone),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final bool isCurrent;
  final bool isDone;

  const _StatusDot({required this.isCurrent, required this.isDone});

  @override
  Widget build(BuildContext context) {
    final c = DegjoColors.of(context);
    if (isCurrent) {
      // Accent circle with pause bars
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: c.accent,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: c.accent.withOpacity(0.35),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 3,
                height: 8,
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(width: 2.5),
              Container(
                width: 3,
                height: 8,
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (isDone) {
      // Separator-colored circle with checkmark
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: c.separator,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: CustomPaint(
            size: const Size(11, 11),
            painter: _CheckmarkPainter(color: c.muted),
          ),
        ),
      );
    }

    // Upcoming – empty circle with thin border
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: c.dashedBorder, width: 0.5),
      ),
    );
  }
}

class _CheckmarkPainter extends CustomPainter {
  final Color color;
  const _CheckmarkPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Matches HTML: M1.5 5.5 L4 8 L9.5 2.5 in 11x11
    final path = Path()
      ..moveTo(size.width * 0.136, size.height * 0.5)
      ..lineTo(size.width * 0.364, size.height * 0.727)
      ..lineTo(size.width * 0.864, size.height * 0.227);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CheckmarkPainter old) => old.color != color;
}

class _MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;
  const _MarqueeText({required this.text, required this.style});
  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final tp = TextPainter(
        text: TextSpan(text: widget.text, style: widget.style),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: double.infinity);

      if (tp.width <= constraints.maxWidth) {
        return Text(widget.text, style: widget.style, maxLines: 1);
      }

      final overflow = tp.width - constraints.maxWidth + 16;
      // SizedBox fixes the clip window width; ClipRect clips rendering to it;
      // UnconstrainedBox lets the Text render at full natural width.
      return SizedBox(
        width: constraints.maxWidth,
        child: ClipRect(
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) {
              final v = _ctrl.value;
              double offset;
              if (v < 0.15) {
                offset = 0;
              } else if (v < 0.65) {
                offset = ((v - 0.15) / 0.5) * overflow;
              } else if (v < 0.80) {
                offset = overflow;
              } else {
                offset = (1 - (v - 0.80) / 0.20) * overflow;
              }
              return Transform.translate(
                offset: Offset(-offset, 0),
                child: UnconstrainedBox(
                  constrainedAxis: Axis.vertical,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.text,
                    style: widget.style,
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
              );
            },
          ),
        ),
      );
    });
  }
}
