import 'dart:async';
import 'package:flutter/material.dart';

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
              color: Colors.white,
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
                Text(
                  '$_target',
                  style: const TextStyle(
                    fontSize: 72,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFFF0000),
                    height: 1,
                    letterSpacing: -3,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Trokitni për të konfirmuar',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFFAAAAAA),
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
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: const Text(
                      'Anulo',
                      style: TextStyle(
                        color: Color(0xFF0F0F0F),
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
