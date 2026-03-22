import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:audio_session/audio_session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'r2_service.dart';
import 'voice_service.dart';
import '../models/lesson.dart';

enum AppStatus { loading, ready, error }

class PlayerState extends ChangeNotifier {
  final _r2 = R2Service();
  final _player = AudioPlayer();
  final voice = VoiceService();

  List<Lesson> lessons = [];
  AppStatus status = AppStatus.loading;
  String? errorMessage;

  int _currentIndex = 0;
  int get currentIndex => _currentIndex;
  Lesson? get currentLesson =>
      lessons.isNotEmpty ? lessons[_currentIndex] : null;

  bool get isPlaying => _player.playing;
  Duration get position => _player.position;
  Duration get duration => _player.duration ?? Duration.zero;

  double _speed = 1.0;
  double get speed => _speed;

  bool _loading = false;
  bool get isLoading => _loading;

  Duration _sentenceStart = Duration.zero;
  Duration _savedPosition = Duration.zero;

  StreamSubscription? _playerSub;
  StreamSubscription? _positionSub;
  Timer? _saveTimer;

  Future<void> retry() async {
    status = AppStatus.loading;
    errorMessage = null;
    notifyListeners();
    await _refreshPlaylist();
  }

  Future<void> init() async {
    // 1. Load cached playlist immediately — instant startup on 2nd+ launch
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getStringList('cached_playlist');
    if (cached != null && cached.isNotEmpty) {
      lessons = cached
          .map((s) => Lesson.fromJson(jsonDecode(s) as Map<String, dynamic>))
          .toList();

      final savedIdx = prefs.getInt('current_index') ?? 0;
      _currentIndex = savedIdx.clamp(0, lessons.length - 1);

      _savedPosition = Duration(
        seconds: prefs.getInt('pos_${lessons[_currentIndex].videoId}') ?? 0,
      );

      final doneList = prefs.getStringList('done_lessons') ?? [];
      for (final id in doneList) {
        final idx = lessons.indexWhere((l) => l.videoId == id);
        if (idx >= 0) lessons[idx].done = true;
      }

      status = AppStatus.ready;
      notifyListeners();
    }

    // 2. Run all independent inits in parallel
    await Future.wait([
      voice.init(),
      _configureAudioSession(),
      _refreshPlaylist(),
    ]);

    // 3. Set up player listeners
    _playerSub = _player.playerStateStream.listen((ps) {
      if (ps.processingState == ProcessingState.completed) _onLessonEnded();
      notifyListeners();
    });
    _positionSub = _player.positionStream.listen((_) => notifyListeners());

    // 4. Announce current lesson on app open
    if (lessons.isNotEmpty) {
      final lesson = lessons[_currentIndex];
      voice.speak('Mësimi ${_currentIndex + 1}: ${lesson.title}');
    }
  }

  Future<void> _configureAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.none,
      avAudioSessionMode: AVAudioSessionMode.defaultMode,
    ));
  }

  Future<void> _refreshPlaylist() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final fresh = await _r2.fetchPlaylist();

      // Preserve done state
      final doneIds = {for (final l in lessons) if (l.done) l.videoId};
      for (final l in fresh) {
        if (doneIds.contains(l.videoId)) l.done = true;
      }

      lessons = fresh;

      if (!_player.playing) {
        final savedIdx = prefs.getInt('current_index') ?? 0;
        _currentIndex = savedIdx.clamp(0, lessons.length - 1);
      }

      final doneList = prefs.getStringList('done_lessons') ?? [];
      for (final id in doneList) {
        final idx = lessons.indexWhere((l) => l.videoId == id);
        if (idx >= 0) lessons[idx].done = true;
      }

      await prefs.setStringList(
        'cached_playlist',
        fresh.map((l) => jsonEncode(l.toJson())).toList(),
      );

      status = AppStatus.ready;
    } catch (e) {
      if (lessons.isEmpty) {
        status = AppStatus.error;
        errorMessage =
            'Nuk u lidh me serverin.\nKontrollo internetin dhe provo sërish.';
        voice.speak('Gabim. Nuk u lidh me internet.');
      }
    }

    notifyListeners();
  }

  void _startSaveTimer() {
    _saveTimer?.cancel();
    _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (currentLesson == null) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        'pos_${currentLesson!.videoId}',
        _player.position.inSeconds,
      );
    });
  }

  void _stopSaveTimer() {
    _saveTimer?.cancel();
    _saveTimer = null;
  }

  Future<void> loadAndPlay(int index, {bool autoPlay = true}) async {
    if (lessons.isEmpty) return;
    index = index.clamp(0, lessons.length - 1);
    _currentIndex = index;
    _sentenceStart = Duration.zero;

    SharedPreferences.getInstance()
        .then((p) => p.setInt('current_index', index));

    if (_speed != 1.0) {
      _speed = 1.0;
      await _player.setSpeed(1.0);
    }

    _loading = true;
    notifyListeners();

    try {
      await _player.stop();

      final lesson = lessons[index];
      final url = lesson.audioUrl ??
          'https://pub-5576bc247f054ed182ef2c8aba07d122.r2.dev/${(index + 1).toString().padLeft(3, '0')}.mp3';

      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(url),
          tag: MediaItem(
            id: lesson.videoId,
            title: lesson.title,
            artUri: Uri.parse('https://pub-5576bc247f054ed182ef2c8aba07d122.r2.dev/app_icon.png'),
          ),
        ),
      );

      if (autoPlay) {
        await _player.play();
        _sentenceStart = Duration.zero;

        if (_savedPosition > Duration.zero && index == _currentIndex) {
          await _player.seek(_savedPosition);
          _savedPosition = Duration.zero;
        }

        _startSaveTimer();
      }
    } catch (e, st) {
      debugPrint('loadAndPlay error: $e\n$st');
      errorMessage = 'Gabim: $e';
      voice.speak('Gabim gjatë ngarkimit.');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> togglePlay() async {
    if (_player.playing) {
      await _player.pause();
      _stopSaveTimer();
    } else {
      _sentenceStart = _player.position;
      await _player.play();
      _startSaveTimer();
    }
  }

  Future<void> nextLesson() async {
    if (_currentIndex >= lessons.length - 1) return;
    await loadAndPlay(_currentIndex + 1);
  }

  Future<void> prevLesson() async {
    if (_currentIndex <= 0) return;
    await loadAndPlay(_currentIndex - 1);
  }

  Future<void> repeatSentence() async {
    await _player.seek(_sentenceStart);
    if (!_player.playing) await _player.play();
  }

  Future<void> cycleSpeed() async {
    const speeds = [0.75, 1.0, 1.5];
    final next = speeds.indexOf(_speed) + 1;
    _speed = speeds[next % speeds.length];
    await _player.setSpeed(_speed);
    notifyListeners();
  }

  Future<void> seekTo(Duration position) async {
    await _player.seek(position);
    _sentenceStart = position;
  }

  void _onLessonEnded() async {
    if (currentLesson != null) {
      currentLesson!.done = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pos_${currentLesson!.videoId}');
      final done = lessons.where((l) => l.done).map((l) => l.videoId).toList();
      await prefs.setStringList('done_lessons', done);
    }
    _stopSaveTimer();
    notifyListeners();

    if (_currentIndex < lessons.length - 1) {
      await Future.delayed(const Duration(seconds: 2));
      voice.speak('Mësimi ${_currentIndex + 2}');
      await Future.delayed(const Duration(milliseconds: 1200));
      await loadAndPlay(_currentIndex + 1);
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _playerSub?.cancel();
    _positionSub?.cancel();
    _player.dispose();
    voice.dispose();
    super.dispose();
  }
}
