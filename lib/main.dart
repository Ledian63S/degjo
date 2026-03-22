import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';
import 'services/player_state.dart';
import 'screens/player_screen.dart';
import 'screens/onboarding_screen.dart';
import 'theme/degjo_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.degjo.audio',
    androidNotificationChannelName: 'Dëgjo',
    androidNotificationOngoing: true,
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => PlayerState()..init(),
      child: const DegjoApp(),
    ),
  );
}

class DegjoApp extends StatelessWidget {
  const DegjoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dëgjo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF0000), brightness: Brightness.light),
        scaffoldBackgroundColor: const Color(0xFFF0F0F0),
        fontFamily: 'Roboto',
        extensions: const [DegjoColors.light],
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF453A), brightness: Brightness.dark),
        scaffoldBackgroundColor: const Color(0xFF0D0D0D),
        fontFamily: 'Roboto',
        extensions: const [DegjoColors.dark],
      ),
      themeMode: ThemeMode.system,
      home: const _RootScreen(),
    );
  }
}

class _RootScreen extends StatefulWidget {
  const _RootScreen();

  @override
  State<_RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<_RootScreen> with WidgetsBindingObserver {
  bool _onboardingDone = false;
  double _overlayOpacity = 0.0;
  Color _overlayColor = Colors.transparent;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final bgColor = brightness == Brightness.dark
        ? const Color(0xFF0D0D0D)
        : const Color(0xFFF0F0F0);

    setState(() {
      _overlayColor = bgColor;
      _overlayOpacity = 1.0;
    });

    // One frame later, fade the overlay out to reveal the switched theme
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) setState(() => _overlayOpacity = 0.0);
    });
  }

  void _completeOnboarding() => setState(() => _onboardingDone = true);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const PlayerScreen(),
        if (!_onboardingDone)
          OnboardingScreen(onComplete: _completeOnboarding),
        IgnorePointer(
          child: AnimatedOpacity(
            opacity: _overlayOpacity,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
            child: Container(color: _overlayColor),
          ),
        ),
      ],
    );
  }
}
