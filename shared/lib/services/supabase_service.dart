// shared/lib/services/supabase_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static Future<void> initialize() async {
    await Supabase.initialize(
      // Remplacez par vos clés Supabase
      url: 'https://vwzpywgpjalakakinfdq.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ3enB5d2dwamFsYWtha2luZmRxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE4NDgwMTgsImV4cCI6MjA3NzQyNDAxOH0.vm2W-lNMVTeRpjvJZlOWfSzOfvqzkGhAxZGAo-GoEXI',
    );
  }
  static SupabaseClient get client => Supabase.instance.client;
}