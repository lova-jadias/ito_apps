// shared/lib/services/supabase_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static Future<void> initialize() async {
    await Supabase.initialize(
      // Remplacez par vos clés Supabase
      url: 'https://imwiyumcxfpezeminqai.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imltd2l5dW1jeGZwZXplbWlucWFpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE5OTg2NTQsImV4cCI6MjA3NzU3NDY1NH0.fu3jDH2fWJjFrVlVVWplDzLA6VVEWgLb1vJfQrtBLIU',
    );
  }
  static SupabaseClient get client => Supabase.instance.client;
}