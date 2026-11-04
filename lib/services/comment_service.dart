import '../models/comment.dart';
import 'supabase_service.dart';
import 'post_service.dart';
import 'user_service.dart';

class CommentService {
  final SupabaseService _supabase = SupabaseService.instance;
  final PostService _postService = PostService();
  final UserService _userService = UserService();

  // Add a comment to a post
  Future<Comment> addComment(String postId, String text) async {
    try {
      final currentUser = _supabase.auth.currentSession?.user;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get current user's profile
      final currentProfile = await _userService.getUserByAuthId(currentUser.id);
      if (currentProfile == null) {
        throw Exception('Current user profile not found');
      }

      // Create comment
      final commentData = {
        'post_id': postId,
        'author_id': currentProfile.id,
        'author_username': currentProfile.username,
        'text': text,
      };

      final response = await _supabase.comments.insert(commentData).select();

      if (response.isEmpty) {
        throw Exception('Failed to create comment');
      }

      // Use PostService to update comment count (recalculates from table)
      await _postService.incrementCommentsCount(postId);

      return Comment.fromJson(response.first);
    } catch (e) {
      throw Exception('Add comment error: $e');
    }
  }

  // Delete a comment
  Future<void> deleteComment(String commentId) async {
    try {
      // Get comment first to get post_id
      final commentData = await _supabase.comments
          .select()
          .eq('id', commentId)
          .single();
      final comment = Comment.fromJson(commentData);

      await _supabase.comments.delete().eq('id', commentId);

      // Decrement post comments count
      await _postService.decrementCommentsCount(comment.postId);
    } catch (e) {
      throw Exception('Delete comment error: $e');
    }
  }

  // Get comments for a post
  Future<List<Map<String, dynamic>>> getPostComments({
    required String postId,
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      final response = await _supabase.comments
          .select('id,post_id,author_id,author_username,text,created_at')
          .eq('post_id', postId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return response;
    } catch (e) {
      throw Exception('Get comments error: $e');
    }
  }

  // Update a comment
  Future<Comment?> updateComment({
    required String commentId,
    required String text,
  }) async {
    try {
      final response = await _supabase.comments
          .update({'text': text})
          .eq('id', commentId)
          .select();

      if (response.isEmpty) return null;

      return Comment.fromJson(response.first);
    } catch (e) {
      throw Exception('Update comment error: $e');
    }
  }
}
