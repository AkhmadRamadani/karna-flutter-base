class ProfileModel {
  final String id;
  final String displayName;
  final String avatarUrl;
  final String bio;

  const ProfileModel({
    required this.id,
    required this.displayName,
    required this.avatarUrl,
    required this.bio,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) => ProfileModel(
    id: json['id'] as String,
    displayName: json['display_name'] as String,
    avatarUrl: json['avatar_url'] as String,
    bio: json['bio'] as String,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'display_name': displayName,
    'avatar_url': avatarUrl,
    'bio': bio,
  };

  ProfileModel copyWith({
    String? id,
    String? displayName,
    String? avatarUrl,
    String? bio,
  }) => ProfileModel(
    id: id ?? this.id,
    displayName: displayName ?? this.displayName,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    bio: bio ?? this.bio,
  );
}
