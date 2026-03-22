import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/lesson.dart';

/// A just_audio StreamAudioSource backed by youtube_explode's HTTP client.
/// This streams audio directly without saving to disk, while correctly
/// handling YouTube's required auth headers and range requests.
class _YoutubeStreamAudioSource extends StreamAudioSource {
  final MuxedStreamInfo _info;
  final YoutubeHttpClient _httpClient;
  final StreamClient _streamClient;

  _YoutubeStreamAudioSource(this._info, this._httpClient, this._streamClient);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final total = _info.size.totalBytes;
    final from = start ?? 0;

    return StreamAudioResponse(
      sourceLength: total,
      contentLength: total - from,
      offset: from,
      stream: _httpClient.getStream(
        _info,
        start: from,
        streamClient: _streamClient,
      ),
      contentType:
          _info.container.name == 'webm' ? 'audio/webm' : 'video/mp4',
    );
  }
}

class YouTubeService {
  final _yt = YoutubeExplode();
  final _httpClient = YoutubeHttpClient();

  static const String playlistId = 'PLWN-brI7dUEl5tRRglCks_2LZLCdvOWTZ';

  Future<List<Lesson>> fetchPlaylist() async {
    final playlist = await _yt.playlists
        .getVideos(playlistId)
        .toList()
        .timeout(const Duration(seconds: 20));
    return playlist.asMap().entries.map((e) {
      return Lesson(videoId: e.value.id.value, title: e.value.title, index: e.key);
    }).toList();
  }

  /// Fetches stream metadata using the iOS client.
  /// iOS client URLs work natively with AVPlayer and support multiple range requests.
  Future<MuxedStreamInfo> getStreamInfo(String videoId) async {
    final manifest = await _yt.videos.streamsClient
        .getManifest(videoId, ytClients: [YoutubeApiClient.ios])
        .timeout(const Duration(seconds: 20));
    return manifest.muxed.withHighestBitrate();
  }

  /// Returns the direct stream URL (iOS client — works natively with AVPlayer).
  String getDirectUrl(MuxedStreamInfo info) => info.url.toString();

  /// Creates a StreamAudioSource backed by youtube_explode's HTTP client.
  /// Fallback if the direct URL doesn't work.
  StreamAudioSource createAudioSource(MuxedStreamInfo info) {
    return _YoutubeStreamAudioSource(info, _httpClient, _yt.videos.streamsClient);
  }

  void dispose() {
    _yt.close();
    _httpClient.close();
  }
}
