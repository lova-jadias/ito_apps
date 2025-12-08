import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static Future<void> initialize() async {
    const String supabaseUrl = String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://kkewkqompmjvyxibqglg.supabase.co/',
    );
    const String supabaseAnonKey = String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtrZXdrcW9tcG1qdnl4aWJxZ2xnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ2MDUwOTIsImV4cCI6MjA4MDE4MTA5Mn0.w5wJFEZKa_80edk8VF0UVcpOmg0ESZfgIJxuVlPEDvo',
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