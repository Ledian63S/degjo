import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../services/player_state.dart';
import '../widgets/lesson_list.dart';
import '../widgets/jump_overlay.dart';
import '../widgets/waveform_widget.dart';
import '../widgets/bubble_progress_bar.dart';
import '../theme/degjo_colors.dart';
import 'settings_screen.dart';

class PlayerScreen extends StatefulWidget {
  final VoidCallback? onShowTutorial;
  final bool gesturesEnabled;
  const PlayerScreen({super.key, this.onShowTutorial, this.gesturesEnabled = true});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  bool _showJump = false;

  // Gesture hint
  String _gestureHint = '';
  Timer? _hintTimer;

  // Gesture tracking — per-pointer maps so multi-touch works correctly
  final Map<int, Offset> _pointerStarts = {};
  final Map<int, Offset> _allStarts = {};
  final Map<int, Offset> _allEnds = {};
  final Map<int, DateTime> _pointerDownTimes = {};
  final Set<int> _movedPointers = {};
  int _maxPointers = 0;
  DateTime _gestureStart = DateTime.now();
  static const _ghostThreshold = Duration(milliseconds: 80);

  // Tap tracking
  DateTime? _lastTapTime;
  bool _doubleTapPending = false; // second DOWN already fired double-tap; swallow its UP
  static const _doubleTapWindow = Duration(milliseconds: 300);
  // Prevents gesture overlay from eating taps meant for UI buttons
  bool _ignoreNextSingleTap = false;

  static const double _swipeThreshold = 40;
  static const Duration _tapMax = Duration(milliseconds: 400);
  static const Duration _seekAmount = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  void _showHint(String hint) {
    _hintTimer?.cancel();
    setState(() => _gestureHint = hint);
    _hintTimer = Timer(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _gestureHint = '');
    });
  }

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
                  played: _progress(ps),
                  gestureHint: _gestureHint,
                ),
                _buildLessonInfo(ps, c),
                _buildProgressBar(ps, c),
                Expanded(child: _buildWhiteCard(ps, c)),
              ],
            ),
          ),

          // ── Gesture overlay ───────────────────────────────────
          if (widget.gesturesEnabled)
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
                onTapDown: (_) => _ignoreNextSingleTap = true,
                onTap: () {
                  openSettingsScreen(
                    context,
                    onShowTutorial: widget.onShowTutorial ?? () {},
                  ).then((_) {
                    if (!mounted) return;
                    _lastTapTime = null;
                    _ignoreNextSingleTap = false;
                    if (_pointerStarts.isEmpty) _resetGesture();
                  });
                },
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

  // ── LESSON INFO (below wave) ───────────────────────────────

  Widget _buildLessonInfo(PlayerState ps, DegjoColors c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 10, 28, 0),
      child: Column(
        children: [
          if (ps.currentLesson != null)
            Text(
              'Mësimi ${ps.currentIndex + 1}',
              style: TextStyle(
                fontSize: 11,
                color: c.accent,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          const SizedBox(height: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              key: ValueKey(ps.currentIndex),
              ps.currentLesson?.title ?? 'Duke ngarkuar...',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                color: c.text,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── PROGRESS BAR ──────────────────────────────────────────

  Widget _buildProgressBar(PlayerState ps, DegjoColors c) {
    final pos = ps.position;
    final dur = ps.duration;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
      child: Column(
        children: [
          BubbleProgressBar(played: _progress(ps)),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _fmtDuration(pos),
                style: TextStyle(fontSize: 12, color: c.muted),
              ),
              if (ps.speed != 1.0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: c.activeLessonBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${ps.speed}×',
                    style: TextStyle(
                      fontSize: 11,
                      color: c.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              Text(
                _fmtDuration(dur),
                style: TextStyle(fontSize: 12, color: c.muted),
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

  void _resetGesture() {
    _allStarts.clear();
    _allEnds.clear();
    _pointerDownTimes.clear();
    _movedPointers.clear();
    _maxPointers = 0;
    _doubleTapPending = false;
  }

  Widget _buildGestureOverlay(PlayerState ps) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) {
        // Purge stale pointers: if existing tracked pointers are from >600ms ago,
        // their UP/cancel was never delivered (e.g. route push mid-gesture).
        if (_pointerStarts.isNotEmpty &&
            !_pointerStarts.containsKey(e.pointer) &&
            DateTime.now().difference(_gestureStart) >
                const Duration(milliseconds: 100)) {
          _pointerStarts.clear();
          _resetGesture();
        }

        _pointerStarts[e.pointer] = e.position;
        final n = _pointerStarts.length;
        if (n > _maxPointers) _maxPointers = n;

        if (n == 1) {
          _resetGesture();
          _maxPointers = 1;
          _gestureStart = DateTime.now();
          _allStarts[e.pointer] = e.position;
          _pointerDownTimes[e.pointer] = DateTime.now();

          // Double-tap: second DOWN within window → fire immediately, swallow UP
          if (_lastTapTime != null &&
              DateTime.now().difference(_lastTapTime!) < _doubleTapWindow &&
              !_ignoreNextSingleTap) {
            _doubleTapPending = true;
            _lastTapTime = null;
            if (ps.lessons.isNotEmpty && !ps.isLoading) {
              HapticFeedback.mediumImpact();
              ps.seekTo(Duration.zero);
              if (!ps.isPlaying) ps.togglePlay();
              ps.voice.speak('Nga fillimi');
              _showHint('↺');
            }
          }
        } else {
          _allStarts[e.pointer] = e.position;
          _pointerDownTimes[e.pointer] = DateTime.now();
        }
      },
      onPointerMove: (e) {
        final start = _allStarts[e.pointer];
        if (start != null && (e.position - start).distance > 8) {
          _movedPointers.add(e.pointer);
        }
      },
      // Fix: clean up cancelled pointers so stale IDs don't inflate _maxPointers
      onPointerCancel: (e) {
        _pointerStarts.remove(e.pointer);
      },
      onPointerUp: (e) {
        _allEnds[e.pointer] = e.position;
        _pointerStarts.remove(e.pointer);

        if (_pointerStarts.isNotEmpty) return;

        if (_showJump) { _resetGesture(); return; }

        final now = DateTime.now();
        // Ghost-touch forgiveness: a finger held < 80ms is likely accidental.
        // Compute effectiveCount excluding those brief touches.
        final effectiveCount = _allEnds.keys.where((id) {
          final dt = _pointerDownTimes[id];
          return dt == null || now.difference(dt) >= _ghostThreshold;
        }).length.clamp(1, _maxPointers);
        final count = (_maxPointers == 1) ? 1 : effectiveCount;
        final anyMoved = _movedPointers.isNotEmpty;
        final elapsed = now.difference(_gestureStart);

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

        // 1-finger tap → play/pause (immediate); double-tap fires on second DOWN
        if (count == 1 && !anyMoved && elapsed < _tapMax) {
          if (_ignoreNextSingleTap) {
            _ignoreNextSingleTap = false;
            _resetGesture();
            return;
          }
          // This UP belongs to the second tap of a double-tap — already handled on DOWN
          if (_doubleTapPending) {
            _resetGesture();
            return;
          }
          if (ps.lessons.isNotEmpty && !ps.isLoading) {
            _lastTapTime = DateTime.now();
            HapticFeedback.lightImpact();
            if (ps.currentLesson != null && ps.duration == Duration.zero) {
              ps.loadAndPlay(ps.currentIndex);
              _showHint('▶');
            } else {
              final wasPlaying = ps.isPlaying;
              ps.togglePlay();
              ps.voice.speak(wasPlaying ? 'Ndalo' : 'Duke luajtur');
              _showHint(wasPlaying ? 'II' : '▶');
            }
          }
          _resetGesture();
          return;
        }

        // 2-finger swipe → next/prev lesson OR seek ±30s
        if (count == 2) {
          if (absDx > _swipeThreshold && absDx > absDy) {
            HapticFeedback.mediumImpact();
            if (avgDx > 0) {
              ps.nextLesson();
              _showHint('→');
            } else {
              ps.prevLesson();
              _showHint('←');
            }
            Future.microtask(() => ps.voice.speak(
                'Mësimi ${ps.currentIndex + 1}: ${ps.currentLesson?.title ?? ''}'));
          } else if (absDy > _swipeThreshold && absDy > absDx) {
            HapticFeedback.selectionClick();
            final newPos = avgDy < 0
                ? ps.position + _seekAmount
                : ps.position - _seekAmount;
            final clampedPos = newPos.isNegative ? Duration.zero : newPos;
            ps.seekTo(clampedPos);
            _showHint(avgDy < 0 ? '+30' : '−30');
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

