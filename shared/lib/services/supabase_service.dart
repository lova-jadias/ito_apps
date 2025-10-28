// shared/lib/services/supabase_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static Future<void> initialize() async {
    await Supabase.initialize(
      // Remplacez par vos clés Supabase
      url: 'https://comxlmmmavqoibgcmvck.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNvbXhsbW1tYXZxb2liZ2NtdmNrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE1ODI0OTgsImV4cCI6MjA3NzE1ODQ5OH0.44qME55AzZhXD80cDv6XIa08w2QT4kyojMGtNZk67TA',
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}