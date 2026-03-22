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
                key: ValueKey(lesson.videoId),
                lesson: lesson,
                index: i,
                isCurrent: isCurrent,
                isDone: isDone,
                isPlaying: isCurrent && widget.isPlaying,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LessonRow extends StatefulWidget {
  final Lesson lesson;
  final int index;
  final bool isCurrent;
  final bool isDone;
  final bool isPlaying;

  const _LessonRow({
    super.key,
    required this.lesson,
    required this.index,
    required this.isCurrent,
    required this.isDone,
    required this.isPlaying,
  });

  @override
  State<_LessonRow> createState() => _LessonRowState();
}

class _LessonRowState extends State<_LessonRow> with SingleTickerProviderStateMixin {
  late AnimationController _marqueeCtrl;
  late Animation<double> _marqueeAnim;
  final ScrollController _scrollCtrl = ScrollController();
  final GlobalKey _textKey = GlobalKey();
  double _containerWidth = 0;
  bool _overflow = false;
  double _maxScrollExtent = 0;

  static const _titleStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.w500);

  @override
  void initState() {
    super.initState();
    _marqueeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    // 2s pause → 3s easeInOut left → 1.5s pause → 1.5s easeInOut back
    _marqueeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 25),
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 37.5,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 18.75),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 18.75,
      ),
    ]).animate(_marqueeCtrl);
    _marqueeAnim.addListener(_updateScroll);
  }

  void _updateScroll() {
    if (_scrollCtrl.hasClients && _overflow) {
      _scrollCtrl.jumpTo(_marqueeAnim.value * _maxScrollExtent);
    }
  }

  void _measure(_) {
    if (!mounted) return;
    final rb = _textKey.currentContext?.findRenderObject() as RenderBox?;
    if (rb == null) return;
    final textWidth = rb.size.width;
    final newOverflow = textWidth > _containerWidth;
    final newExtent = (textWidth - _containerWidth).clamp(0.0, double.infinity);
    if (newOverflow == _overflow && (newExtent - _maxScrollExtent).abs() < 0.5) return;

    setState(() {
      _overflow = newOverflow;
      _maxScrollExtent = newExtent;
    });

    if (_overflow && widget.isCurrent) {
      if (!_marqueeCtrl.isAnimating) _marqueeCtrl.repeat();
    } else {
      _marqueeCtrl.stop();
      _marqueeCtrl.reset();
      if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(0);
    }
  }

  @override
  void didUpdateWidget(_LessonRow old) {
    super.didUpdateWidget(old);
    if (widget.lesson.title != old.lesson.title || widget.isCurrent != old.isCurrent) {
      _marqueeCtrl.stop();
      _marqueeCtrl.reset();
      _overflow = false;
      _maxScrollExtent = 0;
      if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _marqueeCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = DegjoColors.of(context);
    final isCurrent = widget.isCurrent;

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
                      '${widget.index + 1}',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                        color: isCurrent ? c.accent : c.muted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Accent bar
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
                  // Title + subtitle
                  Expanded(
                    child: isCurrent
                        ? _buildCurrentTitle(c)
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                widget.lesson.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: c.muted,
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(width: 12),
                  _StatusDot(isCurrent: isCurrent, isDone: widget.isDone, isPlaying: widget.isPlaying),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Trailing status dot (22px) + its left gap (12px) = 34px reserved space.
  static const double _trailingReserved = 34;

  Widget _buildCurrentTitle(DegjoColors c) {
    return LayoutBuilder(builder: (ctx, constraints) {
      // Exclude the trailing dot area so overflow is measured against what's
      // actually visible, not the full Expanded width.
      _containerWidth = constraints.maxWidth - _trailingReserved;
      WidgetsBinding.instance.addPostFrameCallback(_measure);

      final textWidget = Text(
        widget.lesson.title,
        key: _textKey,
        style: _titleStyle.copyWith(color: c.text),
        maxLines: 1,
        softWrap: false,
      );

      // Constrain the scroll view to the usable width so the text clips
      // before the button, not underneath it.
      final scrollView = SizedBox(
        width: _containerWidth,
        child: SingleChildScrollView(
          controller: _scrollCtrl,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: textWidget,
        ),
      );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 20,
            child: _overflow
                ? ShaderMask(
                    shaderCallback: (rect) => LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      stops: [
                        ((rect.width - 24) / rect.width).clamp(0.0, 1.0),
                        1.0,
                      ],
                      colors: [Colors.white, Colors.transparent],
                    ).createShader(rect),
                    blendMode: BlendMode.dstIn,
                    child: scrollView,
                  )
                : scrollView,
          ),
          const SizedBox(height: 3),
          Text(
            'Duke luajtur',
            style: TextStyle(fontSize: 12, color: c.accent),
          ),
        ],
      );
    });
  }
}

class _StatusDot extends StatelessWidget {
  final bool isCurrent;
  final bool isDone;
  final bool isPlaying;

  const _StatusDot({required this.isCurrent, required this.isDone, required this.isPlaying});

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
          child: isPlaying
              // Pause bars
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 3, height: 8,
                        decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(1))),
                    const SizedBox(width: 2.5),
                    Container(width: 3, height: 8,
                        decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(1))),
                  ],
                )
              // Play triangle
              : Icon(Icons.play_arrow_rounded, color: c.card, size: 14),
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

