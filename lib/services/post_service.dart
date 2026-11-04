import 'package:flutter/foundation.dart';
import '../models/post.dart';
import 'supabase_service.dart';

class PostService {
  final SupabaseService _supabase = SupabaseService.instance;

  // Create a new post
  Future<Post> createPost({
    required String authorId,
    required String authorUsername,
    required String videoUrl,
    String? thumbnailUrl,
    String? description,
    String? subject,
    required int durationSeconds,
    PostVisibility visibility = PostVisibility.public,
  }) async {
    try {
      final postData = {
        'author_id': authorId,
        'author_username': authorUsername,
        'video_url': videoUrl,
        'thumbnail_url': thumbnailUrl,
        'description': description,
        'subject': subject,
        'duration_seconds': durationSeconds,
        'visibility': visibility.toString().split('.').last,
      };

      final response = await _supabase.posts.insert(postData).select();

      if (response.isEmpty) {
        throw Exception('Failed to create post');
      }

      // Increment user posts count
      await _incrementPostsCount(authorId);

      return Post.fromJson(response.first);
    } catch (e) {
      throw Exception('Create post error: $e');
    }
  }

  // Get feed posts (public posts only for now)
  Future<List<Post>> getFeed({
    required String userId,
    int limit = 20,
    int offset = 0,
    String? subject,
    bool friendsOnly = false,
    List<String>? friendIds,
  }) async {
    try {
      List<Map<String, dynamic>> response;

      if (friendsOnly) {
        // For friends feed, ONLY show posts from friends (strict - NO own posts)
        if (friendIds == null || friendIds.isEmpty) {
          // No friends yet, return empty list
          debugPrint('Friends feed: No friends, returning empty list');
          return [];
        }

        // Do NOT include own posts - ONLY friends' posts
        // Fetch all posts and filter in memory (Supabase doesn't support IN filter with list)
        response = await _supabase.posts
            .select('id,author_id,author_username,video_url,thumbnail_url,description,subject,duration_seconds,visibility,created_at,likes_count,comments_count')
            .order('created_at', ascending: false)
            .range(offset, offset + limit * 2); // Fetch more to account for filtering

        // Filter ONLY by friend IDs (strict filtering - exclude own posts)
        final friendIdSet = friendIds.toSet();
        final filtered = response.where((post) {
          final authorId = post['author_id'] as String?;

          // Show if: author is a friend (NOT own)
          if (authorId == null) return false;
          if (authorId == userId) return false; // Exclude own posts
          if (!friendIdSet.contains(authorId)) return false;

          // For friends feed, show any visibility from friends
          return true;
        }).toList();

        debugPrint('Friends feed: BEFORE filter: ${response.length} posts, AFTER filter: ${filtered.length} posts from ${friendIds.length} friends');

        // Apply pagination after filtering
        response = filtered.skip(offset).take(limit).toList();
      } else {
        // For community feed: show public posts + friends' posts with friends visibility
        response = await _supabase.posts
            .select('id,author_id,author_username,video_url,thumbnail_url,description,subject,duration_seconds,visibility,created_at,likes_count,comments_count')
            .or('visibility.eq.public,visibility.eq.friends')
            .order('created_at', ascending: false)
            .range(offset, offset + limit - 1);

        // Filter: show public posts OR friends' posts with friends visibility
        final friendIdSet = friendIds?.toSet() ?? <String>{};
        final filtered = response.where((post) {
          final authorId = post['author_id'] as String?;
          final visibility = post['visibility'] as String?;

          // Always show public posts
          if (visibility == 'public') return true;

          // Show friends visibility only if author is a friend
          if (visibility == 'friends' && authorId != null) {
            return friendIdSet.contains(authorId) || authorId == userId;
          }

          // Private posts: only show if own
          if (visibility == 'private' && authorId == userId) return true;

          return false;
        }).toList();

        debugPrint('Community feed: BEFORE filter: ${response.length} posts, AFTER filter: ${filtered.length} posts');

        response = filtered;
      }

      // Filter by subject in memory if needed
      var posts = response.map((json) => Post.fromJson(json)).toList();

      if (subject != null && subject.isNotEmpty) {
        posts = posts.where((post) => post.subject == subject).toList();
      }

      return posts;
    } catch (e) {
      throw Exception('Get feed error: $e');
    }
  }

  // Get posts by user
  Future<List<Post>> getUserPosts({
    required String userId,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _supabase.posts
          .select()
          .eq('author_id', userId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return response.map((json) => Post.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Get user posts error: $e');
    }
  }

  // Get post by ID
  Future<Post?> getPost(String postId) async {
    try {
      final response = await _supabase.posts
          .select()
          .eq('id', postId)
          .single();

      return Post.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  // Update post
  Future<Post?> updatePost({
    required String postId,
    String? description,
    String? subject,
    PostVisibility? visibility,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      if (description != null) updateData['description'] = description;
      if (subject != null) updateData['subject'] = subject;
      if (visibility != null) updateData['visibility'] = visibility.toString().split('.').last;

      final response = await _supabase.posts
          .update(updateData)
          .eq('id', postId)
          .select();

      if (response.isEmpty) return null;

      return Post.fromJson(response.first);
    } catch (e) {
      throw Exception('Update post error: $e');
    }
  }

  // Delete post
  Future<void> deletePost(String postId) async {
    try {
      final post = await getPost(postId);
      if (post == null) return;

      await _supabase.posts.delete().eq('id', postId);

      // Decrement user posts count
      await _decrementPostsCount(post.authorId);
    } catch (e) {
      throw Exception('Delete post error: $e');
    }
  }

  // Search posts by subject
  Future<List<Post>> searchBySubject({
    required String subject,
    int limit = 20,
  }) async {
    try {
      final response = await _supabase.posts
          .select()
          .eq('visibility', 'public')
          .order('created_at', ascending: false)
          .limit(limit);

      // Filter by subject locally for now
      final filtered = response.where((post) {
        final postSubject = post['subject'] as String?;
        return postSubject != null && postSubject.toLowerCase().contains(subject.toLowerCase());
      }).toList();

      return filtered.map((json) => Post.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Search posts error: $e');
    }
  }

  // Search posts by description
  Future<List<Post>> searchByDescription({
    required String query,
    int limit = 20,
  }) async {
    try {
      final response = await _supabase.posts
          .select()
          .eq('visibility', 'public')
          .order('created_at', ascending: false)
          .limit(limit);

      // Filter by description locally for now
      final filtered = response.where((post) {
        final description = post['description'] as String?;
        return description != null && description.toLowerCase().contains(query.toLowerCase());
      }).toList();

      return filtered.map((json) => Post.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Search posts error: $e');
    }
  }

  // Helper: Increment posts count
  Future<void> _incrementPostsCount(String userId) async {
    try {
      final user = await _supabase.users.select().eq('id', userId).single();
      final currentCount = (user['posts_count'] as num?)?.toInt() ?? 0;
      await _supabase.users
          .update({'posts_count': currentCount + 1})
          .eq('id', userId);
    } catch (e) {
      // Ignore error
    }
  }

  // Helper: Decrement posts count
  Future<void> _decrementPostsCount(String userId) async {
    try {
      final user = await _supabase.users.select().eq('id', userId).single();
      final currentCount = (user['posts_count'] as num?)?.toInt() ?? 0;
      if (currentCount > 0) {
        await _supabase.users
            .update({'posts_count': currentCount - 1})
            .eq('id', userId);
      }
    } catch (e) {
      // Ignore error
    }
  }

  // Increment likes count
  Future<void> incrementLikesCount(String postId) async {
    try {
      // Optimized: increment by 1 instead of recalculating
      final post = await _supabase.posts
          .select('likes_count')
          .eq('id', postId)
          .single();
      final currentCount = (post['likes_count'] as num?)?.toInt() ?? 0;

      await _supabase.posts
          .update({'likes_count': currentCount + 1})
          .eq('id', postId);
      debugPrint('Incremented likes count for post $postId from $currentCount to ${currentCount + 1}');
    } catch (e) {
      debugPrint('Error incrementing likes count: $e');
    }
  }

  // Decrement likes count
  Future<void> decrementLikesCount(String postId) async {
    try {
      // Optimized: decrement by 1 instead of recalculating
      final post = await _supabase.posts
          .select('likes_count')
          .eq('id', postId)
          .single();
      final currentCount = (post['likes_count'] as num?)?.toInt() ?? 0;

      if (currentCount > 0) {
        await _supabase.posts
            .update({'likes_count': currentCount - 1})
            .eq('id', postId);
        debugPrint('Decremented likes count for post $postId from $currentCount to ${currentCount - 1}');
      }
    } catch (e) {
      debugPrint('Error decrementing likes count: $e');
    }
  }

  // Increment comments count
  Future<void> incrementCommentsCount(String postId) async {
    try {
      // Optimized: increment by 1 instead of recalculating
      final post = await _supabase.posts
          .select('comments_count')
          .eq('id', postId)
          .single();
      final currentCount = (post['comments_count'] as num?)?.toInt() ?? 0;

      await _supabase.posts
          .update({'comments_count': currentCount + 1})
          .eq('id', postId);
      debugPrint('Incremented comments count for post $postId from $currentCount to ${currentCount + 1}');
    } catch (e) {
      debugPrint('Error incrementing comments count: $e');
    }
  }

  // Decrement comments count
  Future<void> decrementCommentsCount(String postId) async {
    try {
      // Optimized: decrement by 1 instead of recalculating
      final post = await _supabase.posts
          .select('comments_count')
          .eq('id', postId)
          .single();
      final currentCount = (post['comments_count'] as num?)?.toInt() ?? 0;

      if (currentCount > 0) {
        await _supabase.posts
            .update({'comments_count': currentCount - 1})
            .eq('id', postId);
        debugPrint('Decremented comments count for post $postId from $currentCount to ${currentCount - 1}');
      }
    } catch (e) {
      debugPrint('Error decrementing comments count: $e');
    }
  }
}
