import 'package:flutter_tts/flutter_tts.dart';

class VoiceService {
  final _tts = FlutterTts();
  bool _ready = false;

  Future<void> init() async {
    await _tts.setLanguage('sq-AL');
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _ready = true;
  }

  Future<void> speak(String text) async {
    // TTS temporarily disabled
  }

  Future<void> stop() async => _tts.stop();

  void dispose() => _tts.stop();
}
