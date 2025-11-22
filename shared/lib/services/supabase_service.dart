import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static Future<void> initialize() async {
    const String supabaseUrl = String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://default-dev-project.supabase.co',
    );
    const String supabaseAnonKey = String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: 'default-dev-key-here',
    );

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );

    if (kDebugMode) {
      debugPrint('✅ Supabase initialisé : ${supabaseUrl.substring(0, 20)}...');
    }
  }

  static SupabaseClient get client => Supabase.instance.client;
}