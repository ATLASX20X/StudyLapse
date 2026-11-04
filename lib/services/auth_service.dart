import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user.dart' as models;
import 'supabase_service.dart';

class AuthService {
  final SupabaseService _supabase = SupabaseService.instance;
  GoogleSignIn? _googleSignIn;

  AuthService() {
    // Google Sign-In only works on mobile
    if (!kIsWeb) {
      _googleSignIn = GoogleSignIn(
        scopes: ['email'],
        serverClientId: const String.fromEnvironment(
          'GOOGLE_SERVER_CLIENT_ID',
          // Fallback to empty - you need to set this in Google Cloud Console
        ),
      );
    }
  }

  // Email/Password Registration
  Future<void> registerWithEmail({
    required String email,
    required String password,
    required String name,
    required String identifier,
  }) async {
    try {
      // Check if identifier is available
      final isAvailable = await checkIdentifierAvailability(identifier);
      if (!isAvailable) {
        throw Exception('Cet identifiant est déjà utilisé');
      }

      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Registration failed');
      }

      // Upsert profile (create if not exists, update if exists)
      // This handles the case where Supabase trigger already created a profile
      final userData = {
        'auth_id': response.user!.id,
        'email': email,
        'username': identifier,
        'name': name,
        'bio': '',
        'friends_count': 0,
        'posts_count': 0,
        'storage_used_bytes': 0,
      };

      await _supabase.users.upsert(userData);
      debugPrint('Profile upserted: name=$name, username=$identifier, email=$email');
    } catch (e) {
      throw Exception('Registration error: $e');
    }
  }

  // Check if identifier is available
  Future<bool> checkIdentifierAvailability(String identifier) async {
    try {
      final response = await _supabase.users
          .select()
          .eq('username', identifier)
          .limit(1);
      
      return response.isEmpty;
    } catch (e) {
      // If check fails, assume not available to be safe
      return false;
    }
  }

  // Email/Password Login
  Future<models.AppUser?> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Login failed');
      }

      // Fetch user profile from database
      models.AppUser? user;
      try {
        final userResponse = await _supabase.users
            .select()
            .eq('auth_id', response.user!.id)
            .single();
        user = models.AppUser.fromJson(userResponse);
      } catch (e) {
        // Profile doesn't exist, create it (fallback)
        debugPrint('Profile not found, creating fallback: $e');
        final userData = {
          'auth_id': response.user!.id,
          'username': 'user_${response.user!.id.substring(0, 8)}',
          'name': 'Étudiant',
          'email': response.user!.email,
        };
        final userResponse = await _supabase.users.insert(userData).select();
        user = models.AppUser.fromJson(userResponse.first);
      }

      return user;
    } catch (e) {
      throw Exception('Login error: $e');
    }
  }

  // Google OAuth Login
  Future<models.AppUser?> loginWithGoogle() async {
    if (_googleSignIn == null) {
      throw Exception('Google Sign-In is not available on this platform');
    }

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn!.signIn();
      if (googleUser == null) {
        throw Exception('Google sign in cancelled');
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('No ID token found');
      }

      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      if (response.user == null) {
        throw Exception('Google auth failed');
      }

      // Fetch user profile from database
      models.AppUser? user;
      try {
        final userResponse = await _supabase.users
            .select()
            .eq('auth_id', response.user!.id)
            .single();
        user = models.AppUser.fromJson(userResponse);
      } catch (e) {
        // Profile doesn't exist, create it (fallback)
        debugPrint('Profile not found, creating fallback: $e');
        final userData = {
          'auth_id': response.user!.id,
          'username': googleUser.displayName ?? 'user_${response.user!.id.substring(0, 8)}',
          'email': googleUser.email,
          'avatar_url': googleUser.photoUrl,
        };
        final userResponse = await _supabase.users.insert(userData).select();
        user = models.AppUser.fromJson(userResponse.first);
      }

      return user;
    } catch (e) {
      throw Exception('Google login error: $e');
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      await _googleSignIn?.signOut();
      await _supabase.auth.signOut();
    } catch (e) {
      throw Exception('Logout error: $e');
    }
  }

  // Get current user
  Future<models.AppUser?> getCurrentUser() async {
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) return null;

      final userResponse = await _supabase.users
          .select()
          .eq('auth_id', session.user.id)
          .single();

      return models.AppUser.fromJson(userResponse);
    } catch (e) {
      return null;
    }
  }

  // Update user profile
  Future<models.AppUser?> updateProfile({
    required String userId,
    String? username,
    String? bio,
    String? avatarUrl,
  }) async {
    try {
      final updateData = <String, dynamic>{};
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

  // Check if user is authenticated
  bool get isAuthenticated => _supabase.auth.currentSession != null;
}
