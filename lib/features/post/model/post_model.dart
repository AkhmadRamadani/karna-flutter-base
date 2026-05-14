/// Example model — a simple blog post.
///
/// This demonstrates the Karna MVC model conventions:
/// - Immutable fields (`final`)
/// - `fromJson` / `toJson` for serialization
/// - `copyWith` for state updates
class PostModel {
  final String id;
  final String title;
  final String body;
  final String authorId;

  const PostModel({
    required this.id,
    required this.title,
    required this.body,
    required this.authorId,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) => PostModel(
    id: json['id'] as String,
    title: json['title'] as String,
    body: json['body'] as String,
    authorId: json['author_id'] as String,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'author_id': authorId,
  };

  PostModel copyWith({
    String? id,
    String? title,
    String? body,
    String? authorId,
  }) => PostModel(
    id: id ?? this.id,
    title: title ?? this.title,
    body: body ?? this.body,
    authorId: authorId ?? this.authorId,
  );
}
