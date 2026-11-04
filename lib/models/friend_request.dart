class FriendRequest {
  final String id;
  final String fromUserId;
  final String fromUsername;
  final String toUserId;
  final String toUsername;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String status; // 'pending', 'accepted', 'rejected', 'expired'

  FriendRequest({
    required this.id,
    required this.fromUserId,
    required this.fromUsername,
    required this.toUserId,
    required this.toUsername,
    required this.createdAt,
    required this.expiresAt,
    required this.status,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    return FriendRequest(
      id: json['id'] as String,
      fromUserId: json['from_user_id'] as String,
      fromUsername: json['from_username'] as String,
      toUserId: json['to_user_id'] as String,
      toUsername: json['to_username'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      status: json['status'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'from_user_id': fromUserId,
      'from_username': fromUsername,
      'to_user_id': toUserId,
      'to_username': toUsername,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'status': status,
    };
  }

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isRejected => status == 'rejected';
  bool get isExpired => status == 'expired';
  bool get isExpiredNow => DateTime.now().isAfter(expiresAt);
}
