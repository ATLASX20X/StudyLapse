import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseService? _instance;
  late SupabaseClient _client;

  SupabaseService._internal();

  static SupabaseService get instance {
    _instance ??= SupabaseService._internal();
    return _instance!;
  }

  Future<void> initialize() async {
    String supabaseUrl;
    String supabaseAnonKey;

    // Load from .env file (works on all platforms)
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      // .env absent (ex: build Netlify sans fichier) — on utilisera
      // les variables --dart-define ci-dessous.
    }
    supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
    supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

    if (kIsWeb) {
      // Web (ex: Netlify) : surcharge possible via --dart-define ou
      // variables d'environnement injectées au build.
      const envUrl = String.fromEnvironment('SUPABASE_URL');
      const envKey = String.fromEnvironment('SUPABASE_ANON_KEY');
      if (envUrl.isNotEmpty) supabaseUrl = envUrl;
      if (envKey.isNotEmpty) supabaseAnonKey = envKey;
    }

    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw Exception(
        'Supabase credentials not found. '
        'Please create a .env file with SUPABASE_URL and SUPABASE_ANON_KEY. '
        'See .env.example for reference.',
      );
    }

    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
    );

    _client = Supabase.instance.client;
  }

  SupabaseClient get client => _client;

  // Database access shortcuts
  SupabaseQueryBuilder get users => _client.from('users');
  SupabaseQueryBuilder get posts => _client.from('posts');
  SupabaseQueryBuilder get followers => _client.from('followers');
  SupabaseQueryBuilder get likes => _client.from('likes');
  SupabaseQueryBuilder get comments => _client.from('comments');
  SupabaseQueryBuilder get friendRequests => _client.from('friend_requests');
  SupabaseQueryBuilder get friends => _client.from('friends');

  // Auth access
  GoTrueClient get auth => _client.auth;

  // Storage access
  SupabaseStorageClient get storage => _client.storage;
}
