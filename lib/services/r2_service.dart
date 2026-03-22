import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/lesson.dart';

class R2Service {
  static const String _playlistUrl =
      'https://pub-5576bc247f054ed182ef2c8aba07d122.r2.dev/playlist.json';

  Future<List<Lesson>> fetchPlaylist() async {
    final response = await http
        .get(Uri.parse(_playlistUrl))
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw Exception('Failed to load playlist: ${response.statusCode}');
    }

    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data.asMap().entries.map((e) {
      final item = e.value as Map<String, dynamic>;
      return Lesson(
        videoId: item['index'].toString(),
        title: item['title'] as String,
        index: e.key,
        audioUrl: item['url'] as String,
      );
    }).toList();
  }
}
