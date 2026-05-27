class FeedModel {
  final String id;
  final String authorName;
  final String content;
  final String? imageUrl;
  final DateTime createdAt;
  final int likeCount;

  const FeedModel({
    required this.id,
    required this.authorName,
    required this.content,
    this.imageUrl,
    required this.createdAt,
    this.likeCount = 0,
  });

  factory FeedModel.fromJson(Map<String, dynamic> json) => FeedModel(
    id: json['id'] as String,
    authorName: json['author_name'] as String,
    content: json['content'] as String,
    imageUrl: json['image_url'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
    likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'author_name': authorName,
    'content': content,
    'image_url': imageUrl,
    'created_at': createdAt.toIso8601String(),
    'like_count': likeCount,
  };

  FeedModel copyWith({
    String? id,
    String? authorName,
    String? content,
    String? imageUrl,
    DateTime? createdAt,
    int? likeCount,
  }) => FeedModel(
    id: id ?? this.id,
    authorName: authorName ?? this.authorName,
    content: content ?? this.content,
    imageUrl: imageUrl ?? this.imageUrl,
    createdAt: createdAt ?? this.createdAt,
    likeCount: likeCount ?? this.likeCount,
  );
}
