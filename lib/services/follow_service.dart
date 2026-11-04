import '../models/follow.dart';
import 'supabase_service.dart';
import 'user_service.dart';

class FollowService {
  final SupabaseService _supabase = SupabaseService.instance;
  final UserService _userService = UserService();

  // Follow a user
  Future<void> followUser(String userIdToFollow) async {
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

      // Create follow relationship
      await _supabase.followers.insert({
        'user_id': userIdToFollow,
        'follower_id': currentProfile.id,
      });

      // Update counts
      await _userService.incrementFollowersCount(userIdToFollow);
      await _userService.incrementFollowingCount(currentProfile.id);
    } catch (e) {
      throw Exception('Follow error: $e');
    }
  }

  // Unfollow a user
  Future<void> unfollowUser(String userIdToUnfollow) async {
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

      // Delete follow relationship
      await _supabase.followers
          .delete()
          .eq('user_id', userIdToUnfollow)
          .eq('follower_id', currentProfile.id);

      // Update counts
      await _userService.decrementFollowersCount(userIdToUnfollow);
      await _userService.decrementFollowingCount(currentProfile.id);
    } catch (e) {
      throw Exception('Unfollow error: $e');
    }
  }

  // Check if current user follows a user
  Future<bool> isFollowing(String userId) async {
    try {
      final currentUser = _supabase.auth.currentSession?.user;
      if (currentUser == null) return false;

      final currentProfile = await _userService.getUserByAuthId(currentUser.id);
      if (currentProfile == null) return false;

      final response = await _supabase.followers
          .select()
          .eq('user_id', userId)
          .eq('follower_id', currentProfile.id);

      return response.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Get followers of a user
  Future<List<Follow>> getFollowers(String userId) async {
    try {
      final response = await _supabase.followers
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return response.map((json) => Follow.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Get followers error: $e');
    }
  }

  // Get following of a user
  Future<List<Follow>> getFollowing(String userId) async {
    try {
      final response = await _supabase.followers
          .select()
          .eq('follower_id', userId)
          .order('created_at', ascending: false);

      return response.map((json) => Follow.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Get following error: $e');
    }
  }

  // Get follow count
  Future<int> getFollowersCount(String userId) async {
    try {
      final response = await _supabase.followers
          .select()
          .eq('user_id', userId);
      return response.length;
    } catch (e) {
      return 0;
    }
  }

  // Get following count
  Future<int> getFollowingCount(String userId) async {
    try {
      final response = await _supabase.followers
          .select()
          .eq('follower_id', userId);
      return response.length;
    } catch (e) {
      return 0;
    }
  }
}
