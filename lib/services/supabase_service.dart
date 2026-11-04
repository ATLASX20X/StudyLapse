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

    if (kIsWeb) {
      // Web: Use hardcoded values for Netlify deployment
      // In production, these should be set in Netlify environment variables
      supabaseUrl = const String.fromEnvironment(
        'SUPABASE_URL',
        defaultValue: 'https://haxmvucxlekfxiqvvevs.supabase.co',
      );
      supabaseAnonKey = const String.fromEnvironment(
        'SUPABASE_ANON_KEY',
        defaultValue: 'sb_publishable_-QkaHy32MnLjZ6E0foxjOA_9vbX1GnS',
      );
    } else {
      // Mobile: Load from .env file
      await dotenv.load(fileName: '.env');
      supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
      supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
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
