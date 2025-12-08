import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;

class StorageService {
  final SupabaseClient _client = Supabase.instance.client;

  // Buckets
  static const String _bucketJustificatifs = 'justificatifs';
  static const String _bucketAvatars = 'avatars';

  /// Upload d'un justificatif (Bucket Privé)
  Future<String> uploadJustificatif(File file, int etudiantId) async {
    try {
      final fileExt = path.extension(file.path);
      final fileName = '${etudiantId}_${DateTime.now().millisecondsSinceEpoch}$fileExt';
      final filePath = '$etudiantId/$fileName';

      await _client.storage.from(_bucketJustificatifs).upload(
        filePath,
        file,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
      );

      // Pour un bucket privé, on retourne le path.
      // L'URL signée sera générée à la lecture.
      return filePath;
    } catch (e) {
      throw Exception('Erreur upload justificatif: $e');
    }
  }

  /// Upload d'un avatar (Bucket Public)
  Future<String> uploadAvatar(File file, String userId) async {
    try {
      final fileExt = path.extension(file.path);
      final fileName = '$userId$fileExt'; // On écrase l'ancien si existant
      final filePath = fileName;

      await _client.storage.from(_bucketAvatars).upload(
        filePath,
        file,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
      );

      // Pour un bucket public, on retourne l'URL publique directement
      return _client.storage.from(_bucketAvatars).getPublicUrl(filePath);
    } catch (e) {
      throw Exception('Erreur upload avatar: $e');
    }
  }

  /// Obtenir une URL temporaire pour un fichier privé (Justificatif)
  Future<String> getJustificatifUrl(String filePath) async {
    try {
      // Lien valide pour 1 heure
      return await _client.storage
          .from(_bucketJustificatifs)
          .createSignedUrl(filePath, 3600);
    } catch (e) {
      throw Exception('Impossible de générer le lien: $e');
    }
  }
}