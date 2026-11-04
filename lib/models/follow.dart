class Follow {
  final String id;
  final String userId;
  final String followerId;
  final DateTime createdAt;

  Follow({
    required this.id,
    required this.userId,
    required this.followerId,
    required this.createdAt,
  });

  factory Follow.fromJson(Map<String, dynamic> json) {
    return Follow(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      followerId: json['follower_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'follower_id': followerId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
