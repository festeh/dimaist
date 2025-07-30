class Note {
  final int? id;
  final String title;
  final String content;
  final int? audioId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Note({
    this.id,
    required this.title,
    required this.content,
    this.audioId,
    this.createdAt,
    this.updatedAt,
  });

  Note copyWith({
    int? id,
    String? title,
    String? content,
    int? audioId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      audioId: audioId ?? this.audioId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'],
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      audioId: json['audio_id'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'audio_id': audioId,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
