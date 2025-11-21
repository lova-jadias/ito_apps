// shared/lib/services/supabase_service.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static Future<void> initialize() async {
    // Lire depuis les variables d'environnement (passées au build)
    // Si elles n'existent pas, utiliser les valeurs par défaut (pour dev local)
    const String supabaseUrl = String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://imwiyumcxfpezeminqai.supabase.co', // ✅ Vos VRAIES valeurs
    );
    const String supabaseAnonKey = String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imltd2l5dW1jeGZwZXplbWlucWFpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE5OTg2NTQsImV4cCI6MjA3NzU3NDY1NH0.fu3jDH2fWJjFrVlVVWplDzLA6VVEWgLb1vJfQrtBLIU', // ✅ Vos VRAIES valeurs
    );

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );

    if (kDebugMode) {
      debugPrint('✅ Supabase initialisé : ${supabaseUrl.substring(0, 30)}...');
    }
  }

  static SupabaseClient get client => Supabase.instance.client;
}
