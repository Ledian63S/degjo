import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/degjo_colors.dart';

class JumpOverlay extends StatefulWidget {
  final int lessonCount;
  final Function(int) onConfirm;
  final VoidCallback onCancel;
  final Function(int) onAnnounce;

  const JumpOverlay({
    super.key,
    required this.lessonCount,
    required this.onConfirm,
    required this.onCancel,
    required this.onAnnounce,
  });

  @override
  State<JumpOverlay> createState() => _JumpOverlayState();
}

class _JumpOverlayState extends State<JumpOverlay> {
  int _target = 1;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    widget.onAnnounce(1);
    _scheduleNext();
  }

  void _scheduleNext() {
    _timer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() {
        _target = (_target % widget.lessonCount) + 1;
      });
      widget.onAnnounce(_target);
      _scheduleNext();
    });
  }

  void _confirm() {
    _timer?.cancel();
    widget.onConfirm(_target - 1); // 0-based
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = DegjoColors.of(context);
    return GestureDetector(
      onTap: _confirm,
      child: Container(
        color: Colors.black.withOpacity(0.6),
        child: Center(
          child: Container(
            width: 260,
            padding:
                const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.keyboard_arrow_up_rounded,
                  color: c.muted,
                  size: 28,
                ),
                Text(
                  '$_target',
                  style: TextStyle(
                    fontSize: 72,
                    fontWeight: FontWeight.w800,
                    color: c.accent,
                    height: 1,
                    letterSpacing: -3,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Trokitni për të konfirmuar',
                  style: TextStyle(
                    fontSize: 14,
                    color: c.muted,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () {
                    _timer?.cancel();
                    widget.onCancel();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 12),
                    decoration: BoxDecoration(
                      color: c.separator,
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Text(
                      'Anulo',
                      style: TextStyle(
                        color: c.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
