import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/player_state.dart';
import '../widgets/lesson_list.dart';
import '../widgets/jump_overlay.dart';
import '../widgets/waveform_widget.dart';
import '../theme/degjo_colors.dart';

class PlayerScreen extends StatefulWidget {
  final VoidCallback? onShowTutorial;
  const PlayerScreen({super.key, this.onShowTutorial});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  bool _showJump = false;

  // Gesture tracking — per-pointer maps so multi-touch works correctly
  final Map<int, Offset> _pointerStarts = {};
  final Map<int, Offset> _allStarts = {};
  final Map<int, Offset> _allEnds = {};
  final Set<int> _movedPointers = {};
  int _maxPointers = 0;
  DateTime _gestureStart = DateTime.now();

  static const double _swipeThreshold = 40;
  static const Duration _tapMax = Duration(milliseconds: 400);
  static const Duration _seekAmount = Duration(seconds: 30);

  @override
  Widget build(BuildContext context) {
    final ps = context.watch<PlayerState>();
    final c = DegjoColors.of(context);

    return Scaffold(
      backgroundColor: c.background,
      body: Stack(
        children: [
          // ── Background blobs ──────────────────────────────────
          Positioned(
            top: -60,
            right: -60,
            child: _blob(260, c.blobRed, 0.07),
          ),
          Positioned(
            top: 180,
            left: -80,
            child: _blob(220, c.blobPurple, 0.06),
          ),

          // ── Main layout ───────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildHeader(ps, c),
                WaveformWidget(
                  progress: _progress(ps),
                  isPlaying: ps.isPlaying,
                  lessonLabel: ps.currentLesson != null
                      ? 'Mësimi ${ps.currentIndex + 1}'
                      : '',
                  lessonTitle:
                      ps.currentLesson?.title ?? 'Duke ngarkuar...',
                  timeLabel: _timeLabel(ps),
                ),
                _buildProgressBar(ps, c),
                Expanded(child: _buildWhiteCard(ps, c)),
              ],
            ),
          ),

          // ── Gesture overlay ───────────────────────────────────
          Positioned.fill(child: _buildGestureOverlay(ps)),

          // ── Jump overlay ──────────────────────────────────────
          if (_showJump)
            Positioned.fill(
              child: JumpOverlay(
                lessonCount: ps.lessons.length,
                onConfirm: (idx) {
                  setState(() => _showJump = false);
                  ps.loadAndPlay(idx);
                  ps.voice.speak('Mësimi ${idx + 1}');
                },
                onCancel: () {
                  setState(() => _showJump = false);
                  ps.voice.speak('Anuluar');
                },
                onAnnounce: (n) => ps.voice.speak('$n'),
              ),
            ),


          // ── Per-lesson error banner ───────────────────────────
          if (ps.status != AppStatus.error && ps.errorMessage != null)
            Positioned(
              bottom: 40,
              left: 24,
              right: 24,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: c.errorBorder, width: 0.5),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 12),
                  ],
                ),
                child: Text(
                  ps.errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: c.muted, fontSize: 13),
                ),
              ),
            ),

          // ── Full error state ──────────────────────────────────
          if (ps.status == AppStatus.error)
            Positioned.fill(
              child: Container(
                color: c.background,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.wifi_off_rounded,
                            color: c.muted, size: 44),
                        const SizedBox(height: 20),
                        Text(
                          ps.errorMessage ?? 'Gabim i panjohur.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: c.muted,
                              fontSize: 15,
                              height: 1.5),
                        ),
                        const SizedBox(height: 28),
                        GestureDetector(
                          onTap: ps.retry,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 28, vertical: 13),
                            decoration: BoxDecoration(
                              color: c.accent,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              'Provo sërish',
                              style: TextStyle(
                                  color: c.card,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ── Initial loading overlay ───────────────────────────
          if (ps.status == AppStatus.loading && ps.lessons.isEmpty)
            Positioned.fill(
              child: ColoredBox(
                color: c.background,
                child: Center(
                  child: CircularProgressIndicator(
                    color: c.accent,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── HELPERS ───────────────────────────────────────────────

  Widget _blob(double size, Color color, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withOpacity(opacity), color.withOpacity(0)],
          stops: const [0, 0.7],
        ),
      ),
    );
  }

  double _progress(PlayerState ps) {
    final pos = ps.position.inMilliseconds.toDouble();
    final dur = ps.duration.inMilliseconds.toDouble();
    return dur > 0 ? (pos / dur).clamp(0.0, 1.0) : 0.0;
  }

  String _timeLabel(PlayerState ps) {
    if (ps.duration == Duration.zero) return '';
    String fmt(Duration d) {
      final m = d.inMinutes;
      final s = (d.inSeconds % 60).toString().padLeft(2, '0');
      return '$m:$s';
    }
    return '${fmt(ps.position)} · -${fmt(ps.duration - ps.position)}';
  }

  String _fmtDuration(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── HEADER ────────────────────────────────────────────────

  Widget _buildHeader(PlayerState ps, DegjoColors c) {
    final counter = ps.lessons.isNotEmpty
        ? '${ps.currentIndex + 1} / ${ps.lessons.length}'
        : '';
    final doneLessons = ps.lessons.where((l) => l.done).length;
    final totalLessons = ps.lessons.length;
    final completionProgress =
        totalLessons > 0 ? doneLessons / totalLessons : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
          child: Row(
            children: [
              Image.asset('assets/app_logo.png', width: 32, height: 32),
              const SizedBox(width: 8),
              Text(
                'Dëgjo',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: c.text,
                ),
              ),
              const Spacer(),
              if (counter.isNotEmpty)
                Text(
                  counter,
                  style: TextStyle(fontSize: 12, color: c.muted),
                ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: widget.onShowTutorial,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: c.inputBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.help_outline_rounded,
                      size: 16, color: c.muted),
                ),
              ),
            ],
          ),
        ),
        if (totalLessons > 0) ...[
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) {
              return Container(
                height: 2,
                width: constraints.maxWidth * completionProgress,
                color: c.accent,
              );
            },
          ),
        ],
      ],
    );
  }

  // ── PROGRESS BAR ──────────────────────────────────────────

  Widget _buildProgressBar(PlayerState ps, DegjoColors c) {
    final progress = _progress(ps);
    final pos = ps.position;
    final dur = ps.duration;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final fillWidth = w * progress;
              final thumbX = fillWidth.clamp(6.5, w - 6.5);
              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.centerLeft,
                children: [
                  // Track
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: c.separator,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  // Accent fill
                  Container(
                    height: 4,
                    width: fillWidth,
                    decoration: BoxDecoration(
                      color: c.accent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  // Circular thumb
                  Positioned(
                    left: thumbX - 6.5,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: c.accent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: c.accent.withOpacity(0.15),
                            spreadRadius: 3,
                            blurRadius: 0,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _fmtDuration(pos),
                style: TextStyle(
                    fontSize: 12, color: c.muted),
              ),
              if (ps.speed != 1.0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: c.activeLessonBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${ps.speed}x',
                    style: TextStyle(
                      fontSize: 11,
                      color: c.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              Text(
                _fmtDuration(dur),
                style: TextStyle(
                    fontSize: 12, color: c.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── WHITE CARD ────────────────────────────────────────────

  Widget _buildWhiteCard(PlayerState ps, DegjoColors c) {
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 24,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(28)),
        child: ps.lessons.isEmpty
            ? const SizedBox.expand()
            : LessonList(
                lessons: ps.lessons,
                currentIndex: ps.currentIndex,
                isPlaying: ps.isPlaying,
              ),
      ),
    );
  }

  // ── GESTURE OVERLAY ───────────────────────────────────────
  // Uses per-pointer tracking so 2/3-finger gestures are reliable:
  // _moved is only set when a pointer moved relative to ITS OWN start.

  void _resetGesture() {
    _allStarts.clear();
    _allEnds.clear();
    _movedPointers.clear();
    _maxPointers = 0;
  }

  Widget _buildGestureOverlay(PlayerState ps) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) {
        _pointerStarts[e.pointer] = e.position;
        final n = _pointerStarts.length;
        if (n > _maxPointers) _maxPointers = n;

        if (n == 1) {
          // First finger — start a fresh gesture
          _resetGesture();
          _maxPointers = 1;
          _gestureStart = DateTime.now();
          _allStarts[e.pointer] = e.position;
        } else {
          // Additional finger — record its start
          _allStarts[e.pointer] = e.position;
        }
      },
      onPointerMove: (e) {
        final start = _allStarts[e.pointer];
        if (start != null && (e.position - start).distance > 8) {
          _movedPointers.add(e.pointer);
        }
      },
      onPointerUp: (e) {
        _allEnds[e.pointer] = e.position;
        _pointerStarts.remove(e.pointer);

        // Wait until ALL fingers are lifted before evaluating
        if (_pointerStarts.isNotEmpty) return;

        if (_showJump) { _resetGesture(); return; }

        final count = _maxPointers;
        final anyMoved = _movedPointers.isNotEmpty;
        final elapsed = DateTime.now().difference(_gestureStart);

        // Average displacement across all participating pointers
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
        final absDx = avgDx.abs();
        final absDy = avgDy.abs();

        // 1-finger tap → play/pause
        if (count == 1 && !anyMoved && elapsed < _tapMax) {
          if (ps.lessons.isNotEmpty && !ps.isLoading) {
            HapticFeedback.lightImpact();
            if (ps.currentLesson != null && ps.duration == Duration.zero) {
              ps.loadAndPlay(ps.currentIndex);
            } else {
              final wasPlaying = ps.isPlaying;
              ps.togglePlay();
              ps.voice.speak(wasPlaying ? 'Ndalo' : 'Duke luajtur');
            }
          }
          _resetGesture();
          return;
        }

        // 2-finger tap → cycle speed
        if (count == 2 && !anyMoved && elapsed < _tapMax) {
          HapticFeedback.mediumImpact();
          ps.cycleSpeed();
          final speedStr = ps.speed == 1.0
              ? 'normale'
              : ps.speed == 1.5
                  ? 'shpejt'
                  : 'ngadalë';
          ps.voice.speak('Shpejtësia $speedStr');
          _resetGesture();
          return;
        }

        // 2-finger swipe → next/prev lesson OR seek ±30s
        if (count == 2) {
          if (absDx > _swipeThreshold && absDx > absDy) {
            // Horizontal: change lesson
            HapticFeedback.mediumImpact();
            if (avgDx > 0) {
              ps.nextLesson();
            } else {
              ps.prevLesson();
            }
            Future.microtask(() => ps.voice.speak(
                'Mësimi ${ps.currentIndex + 1}: ${ps.currentLesson?.title ?? ''}'));
          } else if (absDy > _swipeThreshold && absDy > absDx) {
            // Vertical: seek ±30 seconds
            HapticFeedback.selectionClick();
            final newPos = avgDy < 0
                ? ps.position + _seekAmount   // swipe up → forward
                : ps.position - _seekAmount;  // swipe down → back
            final clampedPos = newPos.isNegative ? Duration.zero : newPos;
            ps.seekTo(clampedPos);
            final mins = clampedPos.inMinutes;
            final secs = clampedPos.inSeconds % 60;
            ps.voice.speak(secs == 0 ? '$mins minuta' : '$mins minuta $secs sekonda');
          }
          _resetGesture();
          return;
        }

        // 3-finger tap → jump overlay
        if (count == 3 && !anyMoved && elapsed < _tapMax) {
          if (ps.lessons.isNotEmpty) {
            HapticFeedback.mediumImpact();
            setState(() => _showJump = true);
          }
          _resetGesture();
          return;
        }

        _resetGesture();
      },
      child: const SizedBox.expand(),
    );
  }
}
