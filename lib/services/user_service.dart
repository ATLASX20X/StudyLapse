import 'package:flutter/foundation.dart';
import '../models/user.dart' as models;
import 'supabase_service.dart';

class UserService {
  final SupabaseService _supabase = SupabaseService.instance;

  // Get user by ID
  Future<models.AppUser?> getUser(String userId) async {
    try {
      final response = await _supabase.users
          .select('id,auth_id,email,username,name,bio,friends_count,posts_count,storage_used_bytes,storage_limit_bytes,avatar_url,created_at,updated_at')
          .eq('id', userId)
          .single();
      return models.AppUser.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  // Get user by auth ID
  Future<models.AppUser?> getUserByAuthId(String authId) async {
    try {
      debugPrint('getUserByAuthId: searching for auth_id=$authId');
      final response = await _supabase.users
          .select('id,auth_id,email,username,name,bio,friends_count,posts_count,storage_used_bytes,storage_limit_bytes,avatar_url,created_at,updated_at')
          .eq('auth_id', authId)
          .single();
      debugPrint('getUserByAuthId: found user ${response['username']}');
      return models.AppUser.fromJson(response);
    } catch (e) {
      debugPrint('getUserByAuthId error: $e');
      return null;
    }
  }

  // Check if username is available
  Future<bool> isUsernameAvailable(String username) async {
    try {
      final response = await _supabase.users
          .select('id')
          .eq('username', username);
      return response.isEmpty;
    } catch (e) {
      debugPrint('Error checking username availability: $e');
      return false;
    }
  }

  // Search users by username or name (username prioritized)
  Future<List<models.AppUser>> searchUsers(String query) async {
    try {
      // First get username matches (prioritized)
      final usernameMatches = await _supabase.users
          .select('id,auth_id,email,username,name,bio,friends_count,posts_count,storage_used_bytes,storage_limit_bytes,avatar_url,created_at,updated_at')
          .ilike('username', '%$query%')
          .limit(10);

      // Then get name matches
      final nameMatches = await _supabase.users
          .select('id,auth_id,email,username,name,bio,friends_count,posts_count,storage_used_bytes,storage_limit_bytes,avatar_url,created_at,updated_at')
          .ilike('name', '%$query%')
          .limit(10);

      // Combine and deduplicate (username matches first)
      final seenIds = <String>{};
      final results = <models.AppUser>[];

      for (final json in [...usernameMatches, ...nameMatches]) {
        final id = json['id'] as String;
        if (!seenIds.contains(id)) {
          seenIds.add(id);
          results.add(models.AppUser.fromJson(json));
        }
      }

      return results;
    } catch (e) {
      debugPrint('Error searching users: $e');
      return [];
    }
  }

  // Update user profile
  Future<models.AppUser?> updateProfile({
    required String userId,
    String? name,
    String? username,
    String? bio,
    String? avatarUrl,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      if (name != null) updateData['name'] = name;
      if (username != null) updateData['username'] = username;
      if (bio != null) updateData['bio'] = bio;
      if (avatarUrl != null) updateData['avatar_url'] = avatarUrl;

      final response = await _supabase.users
          .update(updateData)
          .eq('id', userId)
          .select();

      if (response.isEmpty) return null;

      return models.AppUser.fromJson(response.first);
    } catch (e) {
      throw Exception('Profile update error: $e');
    }
  }

  // Update storage used
  Future<void> updateStorageUsed(String userId, int bytesUsed) async {
    try {
      await _supabase.users
          .update({'storage_used_bytes': bytesUsed})
          .eq('id', userId);
    } catch (e) {
      throw Exception('Storage update error: $e');
    }
  }

  // Increment followers count
  Future<void> incrementFollowersCount(String userId) async {
    try {
      final user = await _supabase.users.select().eq('id', userId).single();
      final currentCount = (user['followers_count'] as num?)?.toInt() ?? 0;
      await _supabase.users
          .update({'followers_count': currentCount + 1})
          .eq('id', userId);
    } catch (e) {
      // Ignore error
    }
  }

  // Decrement followers count
  Future<void> decrementFollowersCount(String userId) async {
    try {
      final user = await _supabase.users.select().eq('id', userId).single();
      final currentCount = (user['followers_count'] as num?)?.toInt() ?? 0;
      if (currentCount > 0) {
        await _supabase.users
            .update({'followers_count': currentCount - 1})
            .eq('id', userId);
      }
    } catch (e) {
      // Ignore error
    }
  }

  // Increment following count
  Future<void> incrementFollowingCount(String userId) async {
    try {
      final user = await _supabase.users.select().eq('id', userId).single();
      final currentCount = (user['following_count'] as num?)?.toInt() ?? 0;
      await _supabase.users
          .update({'following_count': currentCount + 1})
          .eq('id', userId);
    } catch (e) {
      // Ignore error
    }
  }

  // Decrement following count
  Future<void> decrementFollowingCount(String userId) async {
    try {
      final user = await _supabase.users.select().eq('id', userId).single();
      final currentCount = (user['following_count'] as num?)?.toInt() ?? 0;
      if (currentCount > 0) {
        await _supabase.users
            .update({'following_count': currentCount - 1})
            .eq('id', userId);
      }
    } catch (e) {
      // Ignore error
    }
  }


}
