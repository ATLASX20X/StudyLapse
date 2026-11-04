enum PostVisibility {
  public,
  friends,
  private,
}

class Post {
  final String id;
  final String authorId;
  final String authorUsername;
  final String videoUrl;
  final String? thumbnailUrl;
  final String? description;
  final String? subject;
  final int durationSeconds;
  final PostVisibility visibility;
  final int likesCount;
  final int commentsCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  Post({
    required this.id,
    required this.authorId,
    required this.authorUsername,
    required this.videoUrl,
    this.thumbnailUrl,
    this.description,
    this.subject,
    required this.durationSeconds,
    this.visibility = PostVisibility.public,
    this.likesCount = 0,
    this.commentsCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] as String,
      authorId: json['author_id'] as String,
      authorUsername: json['author_username'] as String,
      videoUrl: json['video_url'] as String,
      thumbnailUrl: json['thumbnail_url'] as String?,
      description: json['description'] as String?,
      subject: json['subject'] as String?,
      durationSeconds: (json['duration_seconds'] as num).toInt(),
      visibility: _parseVisibility(json['visibility'] as String?),
      likesCount: (json['likes_count'] as num?)?.toInt() ?? 0,
      commentsCount: (json['comments_count'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  static PostVisibility _parseVisibility(String? value) {
    switch (value) {
      case 'public':
        return PostVisibility.public;
      case 'friends':
        return PostVisibility.friends;
      case 'private':
        return PostVisibility.private;
      default:
        return PostVisibility.public;
    }
  }

  String get visibilityString {
    switch (visibility) {
      case PostVisibility.public:
        return 'public';
      case PostVisibility.friends:
        return 'friends';
      case PostVisibility.private:
        return 'private';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'author_id': authorId,
      'author_username': authorUsername,
      'video_url': videoUrl,
      'thumbnail_url': thumbnailUrl,
      'description': description,
      'subject': subject,
      'duration_seconds': durationSeconds,
      'visibility': visibilityString,
      'likes_count': likesCount,
      'comments_count': commentsCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String get formattedDuration {
    final hours = durationSeconds ~/ 3600;
    final minutes = (durationSeconds % 3600) ~/ 60;
    final seconds = durationSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }
}
