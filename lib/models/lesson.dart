class Lesson {
  final String videoId;
  final String title;
  final int index;
  final String? audioUrl;
  bool done;

  Lesson({
    required this.videoId,
    required this.title,
    required this.index,
    this.audioUrl,
    this.done = false,
  });

  Map<String, dynamic> toJson() => {
        'videoId': videoId,
        'title': title,
        'index': index,
        if (audioUrl != null) 'audioUrl': audioUrl,
      };

  factory Lesson.fromJson(Map<String, dynamic> json) => Lesson(
        videoId: json['videoId'] as String,
        title: json['title'] as String,
        index: json['index'] as int,
        audioUrl: json['audioUrl'] as String?,
      );
}
