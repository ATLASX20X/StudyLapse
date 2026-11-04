import '../models/like.dart';
import 'supabase_service.dart';
import 'post_service.dart';
import 'user_service.dart';

class LikeService {
  final SupabaseService _supabase = SupabaseService.instance;
  final PostService _postService = PostService();
  final UserService _userService = UserService();

  // Like a post
  Future<void> likePost(String postId) async {
    try {
      final currentUser = _supabase.auth.currentSession?.user;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get current user's profile ID
      final currentProfile = await _userService.getUserByAuthId(currentUser.id);
      if (currentProfile == null) {
        throw Exception('Current user profile not found');
      }

      // Create like
      await _supabase.likes.insert({
        'post_id': postId,
        'user_id': currentProfile.id,
      });

      // Increment post likes count
      await _postService.incrementLikesCount(postId);
    } catch (e) {
      throw Exception('Like error: $e');
    }
  }

  // Unlike a post
  Future<void> unlikePost(String postId) async {
    try {
      final currentUser = _supabase.auth.currentSession?.user;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get current user's profile ID
      final currentProfile = await _userService.getUserByAuthId(currentUser.id);
      if (currentProfile == null) {
        throw Exception('Current user profile not found');
      }

      // Delete like
      await _supabase.likes
          .delete()
          .eq('post_id', postId)
          .eq('user_id', currentProfile.id);

      // Decrement post likes count
      await _postService.decrementLikesCount(postId);
    } catch (e) {
      throw Exception('Unlike error: $e');
    }
  }

  // Check if current user liked a post
  Future<bool> isLiked(String postId) async {
    try {
      final currentUser = _supabase.auth.currentSession?.user;
      if (currentUser == null) return false;

      final currentProfile = await _userService.getUserByAuthId(currentUser.id);
      if (currentProfile == null) return false;

      final response = await _supabase.likes
          .select('id')
          .eq('post_id', postId)
          .eq('user_id', currentProfile.id);

      return response.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Get likes for a post
  Future<List<Like>> getPostLikes(String postId) async {
    try {
      final response = await _supabase.likes
          .select('id,post_id,user_id,created_at')
          .eq('post_id', postId)
          .order('created_at', ascending: false);

      return response.map((json) => Like.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Get likes error: $e');
    }
  }
}
