import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/user.dart' as models;
import 'supabase_service.dart';

class StorageService {
  final SupabaseService _supabase = SupabaseService.instance;

  // Upload video to Supabase Storage
  Future<String> uploadVideo({
    required File videoFile,
    required String userId,
    required String postId,
  }) async {
    try {
      // Check user storage limit
      final user = await _getUser(userId);
      if (user == null) {
        throw Exception('User not found');
      }

      final fileSize = await videoFile.length();
      if (user.storageUsedBytes + fileSize > user.storageLimitBytes) {
        throw Exception('Storage limit exceeded (${(user.storageLimitBytes / (1024 * 1024)).toStringAsFixed(1)} MB)');
      }

      // Upload video
      final fileName = '$postId/${DateTime.now().millisecondsSinceEpoch}.mp4';
      final filePath = 'videos/$userId/$fileName';

      await _supabase.storage
          .from('videos')
          .upload(filePath, videoFile);

      // Get public URL
      final response = await _supabase.storage
          .from('videos')
          .createSignedUrl(filePath, 60 * 60 * 24 * 365 * 10); // 10 years

      final publicUrl = response;

      // Update user storage used
      await _updateStorageUsed(userId, user.storageUsedBytes + fileSize);

      return publicUrl;
    } catch (e) {
      throw Exception('Upload error: $e');
    }
  }

  // Upload thumbnail
  Future<String> uploadThumbnail({
    required File thumbnailFile,
    required String userId,
    required String postId,
  }) async {
    try {
      final fileName = '$postId/${DateTime.now().millisecondsSinceEpoch}_thumb.png';
      final filePath = 'videos/$userId/$fileName';

      await _supabase.storage
          .from('videos')
          .upload(filePath, thumbnailFile);

      final response = await _supabase.storage
          .from('videos')
          .createSignedUrl(filePath, 60 * 60 * 24 * 365 * 10);

      return response;
    } catch (e) {
      throw Exception('Thumbnail upload error: $e');
    }
  }

  // Delete video
  Future<void> deleteVideo({
    required String videoUrl,
    required String userId,
  }) async {
    try {
      // Extract file path from URL
      final filePath = _extractFilePath(videoUrl);
      if (filePath == null) return;

      await _supabase.storage.from('videos').remove([filePath]);

      // Update user storage used
      final user = await _getUser(userId);
      if (user != null) {
        // Note: This won't be exact without file size, but for now just decrease
        // A better approach would be to store file sizes in a separate table
        await _updateStorageUsed(userId, user.storageUsedBytes - 10000000); // Assume ~10MB
      }
    } catch (e) {
      throw Exception('Delete error: $e');
    }
  }

  // Delete file by URL (general method)
  Future<void> deleteFile(String fileUrl) async {
    try {
      final filePath = _extractFilePath(fileUrl);
      if (filePath == null) return;

      await _supabase.storage.from('videos').remove([filePath]);
    } catch (e) {
      debugPrint('Error deleting file: $e');
      // Don't throw - we want to continue with database deletion even if storage fails
    }
  }

  // Get storage usage percentage
  Future<double> getStorageUsagePercentage(String userId) async {
    final user = await _getUser(userId);
    if (user == null) return 0.0;
    return user.storageUsedPercentage;
  }

  // Helper: Get user from database
  Future<models.AppUser?> _getUser(String userId) async {
    try {
      final response = await _supabase.users
          .select()
          .eq('id', userId)
          .single();
      return models.AppUser.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  // Helper: Update storage used
  Future<void> _updateStorageUsed(String userId, int newStorageUsed) async {
    try {
      await _supabase.users
          .update({'storage_used_bytes': newStorageUsed})
          .eq('id', userId);
    } catch (e) {
      throw Exception('Failed to update storage used: $e');
    }
  }

  // Helper: Extract file path from URL
  String? _extractFilePath(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path;
      // Extract the part after /storage/v1/object/public/videos/
      final parts = path.split('/videos/');
      if (parts.length > 1) {
        return 'videos/${parts[1]}';
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
