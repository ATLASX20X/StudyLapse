class AppUser {
  final String id;
  final String? authId;
  final String username; // Identifier (unique, used for search)
  final String? name; // Display name
  final String email;
  final String? avatarUrl;
  final String? bio;
  final int friendsCount;
  final int postsCount;
  final int storageUsedBytes;
  final int storageLimitBytes;
  final DateTime createdAt;
  final DateTime updatedAt;

  AppUser({
    required this.id,
    this.authId,
    required this.username,
    this.name,
    required this.email,
    this.avatarUrl,
    this.bio,
    this.friendsCount = 0,
    this.postsCount = 0,
    this.storageUsedBytes = 0,
    this.storageLimitBytes = 1073741824, // 1 Go
    required this.createdAt,
    required this.updatedAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      authId: json['auth_id'] as String?,
      username: json['username'] as String,
      name: json['name'] as String?,
      email: json['email'] as String,
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      friendsCount: (json['friends_count'] as num?)?.toInt() ?? 0,
      postsCount: (json['posts_count'] as num?)?.toInt() ?? 0,
      storageUsedBytes: (json['storage_used_bytes'] as num?)?.toInt() ?? 0,
      storageLimitBytes: (json['storage_limit_bytes'] as num?)?.toInt() ?? 1073741824,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'auth_id': authId,
      'username': username,
      'name': name,
      'email': email,
      'avatar_url': avatarUrl,
      'bio': bio,
      'friends_count': friendsCount,
      'posts_count': postsCount,
      'storage_used_bytes': storageUsedBytes,
      'storage_limit_bytes': storageLimitBytes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  double get storageUsedPercentage => storageUsedBytes / storageLimitBytes;

  bool get isStorageFull => storageUsedBytes >= storageLimitBytes;
}
