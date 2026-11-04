import 'package:flutter/foundation.dart';
import '../models/friend_request.dart';
import 'supabase_service.dart';
import 'user_service.dart';

class FriendService {
  final SupabaseService _supabase = SupabaseService.instance;
  final UserService _userService = UserService();

  // Send friend request (expires in 24 hours)
  Future<FriendRequest> sendFriendRequest(String toUserId) async {
    try {
      final currentUser = _supabase.auth.currentSession?.user;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final currentProfile = await _userService.getUserByAuthId(currentUser.id);
      if (currentProfile == null) {
        throw Exception('Current user profile not found');
      }

      final toProfile = await _userService.getUser(toUserId);
      if (toProfile == null) {
        throw Exception('Target user not found');
      }

      // Check if already friends
      final existingFriend = await _checkFriendship(currentProfile.id, toUserId);
      if (existingFriend) {
        throw Exception('Already friends');
      }

      // Check if pending request exists
      final existingRequest = await _checkPendingRequest(currentProfile.id, toUserId);
      if (existingRequest != null) {
        throw Exception('Friend request already pending');
      }

      final requestData = {
        'from_user_id': currentProfile.id,
        'from_username': currentProfile.username,
        'to_user_id': toUserId,
        'to_username': toProfile.username,
        'expires_at': DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
        'status': 'pending',
      };

      final response = await _supabase.friendRequests.insert(requestData).select();

      if (response.isEmpty) {
        throw Exception('Failed to send friend request');
      }

      return FriendRequest.fromJson(response.first);
    } catch (e) {
      throw Exception('Send friend request error: $e');
    }
  }

  // Accept friend request
  Future<void> acceptFriendRequest(String requestId) async {
    try {
      final request = await _supabase.friendRequests
          .select()
          .eq('id', requestId)
          .single();

      debugPrint('Accepting friend request: $requestId, from: ${request['from_user_id']}, to: ${request['to_user_id']}');

      // Delete the request first to avoid unique constraint issues
      final deleteResult = await _supabase.friendRequests.delete().eq('id', requestId);
      debugPrint('Delete result: $deleteResult');

      // Create bidirectional friendship records
      final friendshipData1 = {
        'user_id': request['from_user_id'],
        'friend_id': request['to_user_id'],
      };

      final friendshipData2 = {
        'user_id': request['to_user_id'],
        'friend_id': request['from_user_id'],
      };

      await _supabase.friends.insert(friendshipData1);
      await _supabase.friends.insert(friendshipData2);
      debugPrint('Bidirectional friendship created');

      // Increment friends count for both users
      await _incrementFriendsCount(request['from_user_id']);
      await _incrementFriendsCount(request['to_user_id']);
    } catch (e) {
      debugPrint('Accept friend request error: $e');
      throw Exception('Accept friend request error: $e');
    }
  }

  // Reject friend request
  Future<void> rejectFriendRequest(String requestId) async {
    try {
      await _supabase.friendRequests
          .update({'status': 'rejected'})
          .eq('id', requestId);
    } catch (e) {
      throw Exception('Reject friend request error: $e');
    }
  }

  // Get pending friend requests for current user
  Future<List<FriendRequest>> getPendingRequests() async {
    try {
      final currentUser = _supabase.auth.currentSession?.user;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final currentProfile = await _userService.getUserByAuthId(currentUser.id);
      if (currentProfile == null) {
        throw Exception('Current user profile not found');
      }

      final response = await _supabase.friendRequests
          .select('id,from_user_id,from_username,to_user_id,to_username,expires_at,status,created_at')
          .eq('to_user_id', currentProfile.id)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      debugPrint('Pending requests: ${response.length} for user ${currentProfile.id}');
      return response.map((json) => FriendRequest.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Get pending requests error: $e');
      return [];
    }
  }

  // Get friends list
  Future<List<dynamic>> getFriends(String userId) async {
    try {
      // Get friends where user is the requester
      final friendsAsUser = await _supabase.friends
          .select()
          .eq('user_id', userId);

      // Get friends where user is the friend
      final friendsAsFriend = await _supabase.friends
          .select()
          .eq('friend_id', userId);

      debugPrint('Friends as user: ${friendsAsUser.length}, Friends as friend: ${friendsAsFriend.length}');

      // Combine and deduplicate friend IDs
      final friendIds = <String>{};
      for (final friend in friendsAsUser) {
        friendIds.add(friend['friend_id'] as String);
      }
      for (final friend in friendsAsFriend) {
        friendIds.add(friend['user_id'] as String);
      }

      // Explicitly exclude the user's own ID (just in case)
      friendIds.remove(userId);

      debugPrint('Total unique friend IDs (excluding self): ${friendIds.length}');

      // Fetch user profiles for all friend IDs
      if (friendIds.isEmpty) {
        return [];
      }

      // Use OR filter for friend IDs (Supabase supports up to 50 conditions)
      // If more than 50 friends, we need to fetch in batches
      final friendIdList = friendIds.toList();
      final friendProfiles = <dynamic>[];

      // Process in batches of 50 to avoid OR limit
      for (int i = 0; i < friendIdList.length; i += 50) {
        final batch = friendIdList.skip(i).take(50).toList();
        final orConditions = batch.map((id) => 'id.eq.$id').join(',');

        try {
          final batchProfiles = await _supabase.users
              .select('id,username,name,bio,friends_count,posts_count,storage_used_bytes,avatar_url')
              .or(orConditions);
          friendProfiles.addAll(batchProfiles);
        } catch (e) {
          debugPrint('Error fetching friend batch: $e');
        }
      }

      debugPrint('Fetched ${friendProfiles.length} friend profiles in batches');
      return friendProfiles;
    } catch (e) {
      debugPrint('Get friends error: $e');
      return [];
    }
  }

  // Check if two users are friends
  Future<bool> _checkFriendship(String userId1, String userId2) async {
    try {
      final response = await _supabase.friends
          .select()
          .or('and(user_id.eq.$userId1,friend_id.eq.$userId2),and(user_id.eq.$userId2,friend_id.eq.$userId1)')
          .limit(1);

      return response.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Check if pending request exists
  Future<FriendRequest?> _checkPendingRequest(String fromUserId, String toUserId) async {
    try {
      final response = await _supabase.friendRequests
          .select()
          .eq('from_user_id', fromUserId)
          .eq('to_user_id', toUserId)
          .eq('status', 'pending')
          .limit(1);

      if (response.isEmpty) return null;
      return FriendRequest.fromJson(response.first);
    } catch (e) {
      return null;
    }
  }

  // Increment friends count
  Future<void> _incrementFriendsCount(String userId) async {
    try {
      final user = await _supabase.users.select().eq('id', userId).single();
      final currentCount = (user['friends_count'] as num?)?.toInt() ?? 0;
      await _supabase.users
          .update({'friends_count': currentCount + 1})
          .eq('id', userId);
      debugPrint('Incremented friends count for user $userId from $currentCount to ${currentCount + 1}');
    } catch (e) {
      debugPrint('Error incrementing friends count for $userId: $e');
    }
  }

  // Remove friend
  Future<void> removeFriend(String friendId) async {
    try {
      final currentUser = _supabase.auth.currentSession?.user;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final currentProfile = await _userService.getUserByAuthId(currentUser.id);
      if (currentProfile == null) {
        throw Exception('Current user profile not found');
      }

      // Delete both bidirectional friendship records
      await _supabase.friends
          .delete()
          .or('and(user_id.eq.${currentProfile.id},friend_id.eq.$friendId),and(user_id.eq.$friendId,friend_id.eq.${currentProfile.id})');

      // Decrement friends count for both users
      await _decrementFriendsCount(currentProfile.id);
      await _decrementFriendsCount(friendId);
    } catch (e) {
      throw Exception('Remove friend error: $e');
    }
  }

  // Decrement friends count
  Future<void> _decrementFriendsCount(String userId) async {
    try {
      final user = await _supabase.users.select().eq('id', userId).single();
      final currentCount = (user['friends_count'] as num?)?.toInt() ?? 0;
      if (currentCount > 0) {
        await _supabase.users
            .update({'friends_count': currentCount - 1})
            .eq('id', userId);
      }
    } catch (e) {
      // Ignore error
    }
  }
}
