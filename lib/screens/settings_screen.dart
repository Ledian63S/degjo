import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/player_state.dart';
import '../services/theme_notifier.dart';
import '../theme/degjo_colors.dart';

Future<void> openSettingsScreen(BuildContext context,
    {required VoidCallback onShowTutorial}) {
  return Navigator.push(
    context,
    PageRouteBuilder(
      pageBuilder: (ctx, animation, secondaryAnimation) =>
          SettingsScreen(onShowTutorial: onShowTutorial),
      transitionsBuilder: (ctx, animation, secondaryAnimation, child) {
        final enter = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
        final exit = Tween<Offset>(begin: Offset.zero, end: const Offset(-0.25, 0))
            .animate(CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeInCubic));
        return SlideTransition(
          position: enter,
          child: SlideTransition(position: exit, child: child),
        );
      },
    ),
  );
}

class SettingsScreen extends StatefulWidget {
  final VoidCallback onShowTutorial;
  const SettingsScreen({super.key, required this.onShowTutorial});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _tutorialEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final neverShow = prefs.getBool('onboarding_never_show') ?? false;
    if (mounted) setState(() => _tutorialEnabled = !neverShow);
  }

  Future<void> _setTutorialEnabled(bool val) async {
    HapticFeedback.selectionClick();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_never_show', !val);
    if (mounted) setState(() => _tutorialEnabled = val);
  }

  @override
  Widget build(BuildContext context) {
    final c = DegjoColors.of(context);
    final ps = context.read<PlayerState>();
    final themeNotifier = context.watch<ThemeNotifier>();

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 24, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: c.inputBg,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          size: 16, color: c.text),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Cilësimet',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      color: c.text,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Appearance ─────────────────────────────────
                    _sectionLabel('Pamja', c),
                    const SizedBox(height: 10),
                    _card(
                      c: c,
                      padding: const EdgeInsets.all(3),
                      child: _ThemeSegment(
                        current: themeNotifier.mode,
                        onChanged: (mode) {
                          HapticFeedback.selectionClick();
                          themeNotifier.setMode(mode);
                        },
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Tutorial (unchanged) ────────────────────────
                    _sectionLabel('Tutorial', c),
                    const SizedBox(height: 10),
                    _card(
                      c: c,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              _iconBox(Icons.school_outlined, c),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Tutorial gjatë hapjes',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        color: c.text,
                                      ),
                                    ),
                                    Text(
                                      'Trego gjestet kur hap aplikacionin',
                                      style: TextStyle(
                                          fontSize: 12, color: c.muted),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _tutorialEnabled,
                                onChanged: _setTutorialEnabled,
                                activeColor: c.accent,
                              ),
                            ],
                          ),
                          Divider(color: c.separator, height: 24),
                          InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              if (ps.isPlaying) ps.togglePlay();
                              widget.onShowTutorial();
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Row(
                              children: [
                                _iconBox(Icons.play_lesson_outlined, c),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Shiko tutorialin tani',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          color: c.text,
                                        ),
                                      ),
                                      Text(
                                        'Hap hapat e gjesteve',
                                        style: TextStyle(
                                            fontSize: 12, color: c.muted),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded,
                                    color: c.muted, size: 20),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Gestures (unchanged) ─────────────────────────
                    _sectionLabel('Gjestet', c),
                    const SizedBox(height: 10),
                    _card(
                      c: c,
                      child: Column(
                        children: [
                          _gestureRow('1 gisht · Prek', 'Luaj / Ndalo', c,
                              last: false),
                          _gestureRow(
                              '1 gisht · 2×', 'Përsërit mësimin', c,
                              last: false),
                          _gestureRow(
                              '2 gishta · Lart', '+30 sekonda', c,
                              last: false),
                          _gestureRow(
                              '2 gishta · Poshtë', '−30 sekonda', c,
                              last: false),
                          _gestureRow(
                              '2 gishta · Anash', 'Ndrysho mësimin', c,
                              last: false),
                          _gestureRow(
                              '3 gishta · Prek', 'Kalo te mësimi', c,
                              last: true),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── About ────────────────────────────────────────
                    _sectionLabel('Rreth aplikacionit', c),
                    const SizedBox(height: 10),
                    _card(
                      c: c,
                      child: Column(
                        children: [
                          const SizedBox(height: 8),

                          // Logo
                          Image.asset('assets/app_logo.png',
                              width: 64, height: 64),
                          const SizedBox(height: 12),

                          // App name
                          Text(
                            'Dëgjo',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              color: c.text,
                            ),
                          ),
                          const SizedBox(height: 6),

                          // Tagline
                          Text(
                            'Dëgjo. Mëso. Kupto.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: c.muted,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Version pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: c.separator,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Versioni v.1.0.0.0 · iOS',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: c.muted,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Story card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: c.inputBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Ky aplikacion u krijua nga një bir për babain e tij. Sepse mësimi nuk duhet të ketë kufij — as mosha, as shikimi.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: c.muted,
                                height: 1.6,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Website row
                          _linkRow(
                            icon: Icons.language_outlined,
                            title: 'Official Website',
                            subtitle: 'ledian63s.github.io/degjo',
                            c: c,
                          ),
                          Divider(color: c.separator, height: 20),

                          // GitHub row
                          _linkRow(
                            icon: Icons.code_rounded,
                            title: 'Source Code',
                            subtitle: 'github.com/Ledian63S/degjo',
                            c: c,
                          ),
                          const SizedBox(height: 4),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────

  Widget _sectionLabel(String text, DegjoColors c) => Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
          color: c.muted,
        ),
      );

  Widget _card({
    required DegjoColors c,
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(18),
  }) =>
      Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: child,
      );

  Widget _iconBox(IconData icon, DegjoColors c) => Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
            color: c.inputBg, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 18, color: c.muted),
      );

  Widget _gestureRow(String gesture, String action, DegjoColors c,
          {required bool last}) =>
      Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Expanded(
                    child: Text(gesture,
                        style: TextStyle(fontSize: 13, color: c.muted))),
                Text(action,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: c.text)),
              ],
            ),
          ),
          if (!last) Divider(color: c.separator, height: 0),
        ],
      );

  Widget _linkRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required DegjoColors c,
  }) =>
      Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
                color: c.inputBg, borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, size: 16, color: c.muted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: c.text)),
                Text(subtitle,
                    style: TextStyle(fontSize: 11, color: c.muted)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: c.muted, size: 18),
        ],
      );
}

// ── Theme segmented control ──────────────────────────────────────

class _ThemeSegment extends StatelessWidget {
  final ThemeMode current;
  final ValueChanged<ThemeMode> onChanged;

  const _ThemeSegment({required this.current, required this.onChanged});

  static const _options = [
    (
      mode: ThemeMode.system,
      svg: 'assets/theme/icon_system.svg',
      label: 'Sistemi',
    ),
    (
      mode: ThemeMode.light,
      svg: 'assets/theme/icon_sun.svg',
      label: 'E ndritshme',
    ),
    (
      mode: ThemeMode.dark,
      svg: 'assets/theme/icon_moon.svg',
      label: 'E errët',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final c = DegjoColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.separator,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: _options.map((opt) {
          final isActive = current == opt.mode;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(opt.mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isActive ? c.card : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.07),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset(
                      opt.svg,
                      width: 18,
                      height: 18,
                      colorFilter: ColorFilter.mode(
                        isActive ? c.accent : c.muted,
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      opt.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                        color: isActive ? c.text : c.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
