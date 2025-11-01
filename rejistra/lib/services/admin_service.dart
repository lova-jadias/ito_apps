import 'package:supabase_flutter/supabase_flutter.dart';

class AdminService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Créer un étudiant via Edge Function
  Future<Map<String, dynamic>> createStudent({
    required Map<String, dynamic> studentData,
    required String tempPassword,
    required bool activateGojika,
  }) async {
    final response = await _client.functions.invoke(
      'create-student',
      body: {
        'student_data': studentData,
        'temp_password': tempPassword,
        'activate_gojika': activateGojika,
      },
    );

    if (response.status != 200) {
      throw Exception(response.data['error'] ?? 'Erreur lors de la création');
    }

    return response.data as Map<String, dynamic>;
  }

  /// Créer un membre du personnel via Edge Function
  Future<Map<String, dynamic>> createStaff({
    required String email,
    required String password,
    required String nomComplet,
    required String role,
    required String site,
  }) async {
    final response = await _client.functions.invoke(
      'create-staff',
      body: {
        'email': email,
        'password': password,
        'nom_complet': nomComplet,
        'role': role,
        'site': site,
      },
    );

    if (response.status != 200) {
      throw Exception(response.data['error'] ?? 'Erreur lors de la création');
    }

    return response.data as Map<String, dynamic>;
  }

  /// Supprimer un utilisateur via Edge Function
  Future<void> deleteUser(String userId) async {
    final response = await _client.functions.invoke(
      'delete-user',
      body: {'user_id': userId},
    );

    if (response.status != 200) {
      throw Exception(response.data['error'] ?? 'Erreur lors de la suppression');
    }
  }
}