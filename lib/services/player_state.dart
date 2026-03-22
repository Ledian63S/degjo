import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'youtube_service.dart';
import 'voice_service.dart';
import '../models/lesson.dart';

enum AppStatus { loading, ready, error }

class PlayerState extends ChangeNotifier {
  final _youtube = YouTubeService();
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

  StreamSubscription? _playerSub;
  StreamSubscription? _positionSub;

  // In-memory cache of stream info (signed URLs valid for the session)
  final Map<String, MuxedStreamInfo> _infoCache = {};

  Future<void> retry() async {
    status = AppStatus.loading;
    errorMessage = null;
    _infoCache.clear();
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

      final doneList = prefs.getStringList('done_lessons') ?? [];
      for (final id in doneList) {
        final idx = lessons.indexWhere((l) => l.videoId == id);
        if (idx >= 0) lessons[idx].done = true;
      }

      status = AppStatus.ready;
      notifyListeners();

      // Pre-fetch stream info for the current lesson while refreshing playlist
      _prefetchInfo(_currentIndex);
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
  }

  Future<void> _configureAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      avAudioSessionCategoryOptions:
          AVAudioSessionCategoryOptions.defaultToSpeaker,
      avAudioSessionMode: AVAudioSessionMode.defaultMode,
    ));
  }

  Future<void> _refreshPlaylist() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final fresh = await _youtube.fetchPlaylist();

      // Preserve done state from the currently loaded lessons
      final doneIds = {for (final l in lessons) if (l.done) l.videoId};
      for (final l in fresh) {
        if (doneIds.contains(l.videoId)) l.done = true;
      }

      lessons = fresh;

      // Only update current index if nothing is playing
      if (!_player.playing) {
        final savedIdx = prefs.getInt('current_index') ?? 0;
        _currentIndex = savedIdx.clamp(0, lessons.length - 1);
      }

      final doneList = prefs.getStringList('done_lessons') ?? [];
      for (final id in doneList) {
        final idx = lessons.indexWhere((l) => l.videoId == id);
        if (idx >= 0) lessons[idx].done = true;
      }

      // Persist for next launch
      await prefs.setStringList(
        'cached_playlist',
        fresh.map((l) => jsonEncode(l.toJson())).toList(),
      );

      status = AppStatus.ready;
    } catch (e) {
      if (lessons.isEmpty) {
        status = AppStatus.error;
        errorMessage =
            'Nuk u lidh me YouTube.\nKontrollo internetin dhe provo sërish.';
      }
      // If we have cached data, silently keep it shown
    }

    notifyListeners();
    if (lessons.isNotEmpty) _prefetchInfo(_currentIndex);
  }

  // Kick off a background stream-info fetch so it's ready when user taps play
  void _prefetchInfo(int index) {
    if (index < 0 || index >= lessons.length) return;
    final videoId = lessons[index].videoId;
    if (_infoCache.containsKey(videoId)) return;
    _youtube.getStreamInfo(videoId).then((info) {
      _infoCache[videoId] = info;
    }).catchError((_) {});
  }

  Future<void> loadAndPlay(int index, {bool autoPlay = true}) async {
    if (lessons.isEmpty) return;
    index = index.clamp(0, lessons.length - 1);
    _currentIndex = index;
    _sentenceStart = Duration.zero;

    if (_speed != 1.0) {
      _speed = 1.0;
      await _player.setSpeed(1.0);
    }

    _loading = true;
    notifyListeners();

    try {
      await _player.stop();

      final videoId = lessons[index].videoId;
      // Use cached stream info if available, otherwise fetch
      final info = _infoCache[videoId] ?? await _youtube.getStreamInfo(videoId);
      _infoCache[videoId] = info;

      // iOS client URLs work natively with AVPlayer — try direct URL first
      final url = _youtube.getDirectUrl(info);
      try {
        await _player.setUrl(url);
      } catch (_) {
        // Fall back to StreamAudioSource if direct URL fails
        final source = _youtube.createAudioSource(info);
        await _player.setAudioSource(source);
      }

      if (autoPlay) {
        await _player.play();
        _sentenceStart = Duration.zero;
      }

      // Pre-fetch the next lesson's stream info while this one plays
      _prefetchInfo(index + 1);
    } catch (e, st) {
      debugPrint('loadAndPlay error: $e\n$st');
      errorMessage = 'Gabim gjatë ngarkimit të mësimit.';
    } finally {
      _loading = false;
      notifyListeners();
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('current_index', index);
  }

  Future<void> togglePlay() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      _sentenceStart = _player.position;
      await _player.play();
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
      final done = lessons.where((l) => l.done).map((l) => l.videoId).toList();
      await prefs.setStringList('done_lessons', done);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _playerSub?.cancel();
    _positionSub?.cancel();
    _player.dispose();
    _youtube.dispose();
    voice.dispose();
    super.dispose();
  }
}
