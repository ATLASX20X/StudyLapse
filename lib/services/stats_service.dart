import 'post_service.dart';
import 'user_service.dart';

class StatsService {
  final PostService _postService = PostService();
  final UserService _userService = UserService();

  // Get user statistics
  Future<Map<String, dynamic>> getUserStats(String userId) async {
    try {
      final user = await _userService.getUser(userId);
      if (user == null) {
        throw Exception('User not found');
      }

      final posts = await _postService.getUserPosts(userId: userId);

      // Calculate total study time
      int totalStudySeconds = 0;
      for (final post in posts) {
        totalStudySeconds += post.durationSeconds;
      }

      // Count posts by subject
      final Map<String, int> subjectCounts = {};
      for (final post in posts) {
        if (post.subject != null) {
          subjectCounts[post.subject!] = (subjectCounts[post.subject!] ?? 0) + 1;
        }
      }

      // Find favorite subject
      String? favoriteSubject;
      int maxCount = 0;
      subjectCounts.forEach((subject, count) {
        if (count > maxCount) {
          maxCount = count;
          favoriteSubject = subject;
        }
      });

      return {
        'user': user,
        'total_posts': posts.length,
        'total_study_seconds': totalStudySeconds,
        'total_study_hours': totalStudySeconds / 3600,
        'subject_counts': subjectCounts,
        'favorite_subject': favoriteSubject,
        'total_friends': user.friendsCount,
        'storage_used_mb': user.storageUsedBytes / (1024 * 1024),
        'storage_limit_gb': user.storageLimitBytes / (1024 * 1024 * 1024),
      };
    } catch (e) {
      throw Exception('Get stats error: $e');
    }
  }

  // Get weekly study data (mock for now)
  Future<List<Map<String, dynamic>>> getWeeklyStudyData(String userId) async {
    // TODO: Implement actual weekly data from posts with timestamps
    return [
      {'day': 'Lun', 'hours': 2.5},
      {'day': 'Mar', 'hours': 3.0},
      {'day': 'Mer', 'hours': 1.5},
      {'day': 'Jeu', 'hours': 4.0},
      {'day': 'Ven', 'hours': 2.0},
      {'day': 'Sam', 'hours': 5.0},
      {'day': 'Dim', 'hours': 1.0},
    ];
  }
}
