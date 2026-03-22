import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';
import 'services/player_state.dart';
import 'screens/player_screen.dart';
import 'screens/onboarding_screen.dart';

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
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF0000),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF0F0F0),
        fontFamily: 'Roboto',
      ),
      home: const _RootScreen(),
    );
  }
}

class _RootScreen extends StatefulWidget {
  const _RootScreen();

  @override
  State<_RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<_RootScreen> {
  // Show onboarding every launch (session-only flag)
  bool _onboardingDone = false;

  void _completeOnboarding() => setState(() => _onboardingDone = true);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const PlayerScreen(),
        if (!_onboardingDone)
          OnboardingScreen(onComplete: _completeOnboarding),
      ],
    );
  }
}
