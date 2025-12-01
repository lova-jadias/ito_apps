import 'package:hive_flutter/hive_flutter.dart';

/// Service de cache local pour les données critiques
class OfflineCacheService {
  static const String _etudiantsBox = 'etudiants_cache';
  static const String _paiementsBox = 'paiements_cache';
  static const String _configBox = 'config_cache';

  late Box<Map> _etudiantsCache;
  late Box<Map> _paiementsCache;
  late Box<Map> _configCache;

  Future<void> initialize() async {
    _etudiantsCache = await Hive.openBox<Map>(_etudiantsBox);
    _paiementsCache = await Hive.openBox<Map>(_paiementsBox);
    _configCache = await Hive.openBox<Map>(_configBox);
  }

  // ==================== ÉTUDIANTS ====================

  Future<void> cacheEtudiants(List<Map<String, dynamic>> etudiants) async {
    await _etudiantsCache.clear();
    for (var etudiant in etudiants) {
      await _etudiantsCache.put(etudiant['id'], etudiant);
    }
  }

  List<Map<String, dynamic>> getCachedEtudiants() {
    return _etudiantsCache.values
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Map<String, dynamic>? getCachedEtudiant(int id) {
    final cached = _etudiantsCache.get(id);
    return cached != null ? Map<String, dynamic>.from(cached) : null;
  }

  // ==================== PAIEMENTS ====================

  Future<void> cachePaiements(List<Map<String, dynamic>> paiements) async {
    await _paiementsCache.clear();
    for (var paiement in paiements) {
      await _paiementsCache.put(paiement['id'], paiement);
    }
  }

  List<Map<String, dynamic>> getCachedPaiements() {
    return _paiementsCache.values
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  // ==================== CONFIG ====================

  Future<void> cacheConfig(Map<String, List<String>> config) async {
    await _configCache.clear();
    config.forEach((key, value) async {
      await _configCache.put(key, {'values': value});
    });
  }

  Map<String, List<String>> getCachedConfig() {
    final result = <String, List<String>>{};
    for (var key in _configCache.keys) {
      final cached = _configCache.get(key);
      if (cached != null) {
        result[key] = List<String>.from(cached['values']);
      }
    }
    return result;
  }

  // ==================== NETTOYAGE ====================

  Future<void> clearAll() async {
    await _etudiantsCache.clear();
    await _paiementsCache.clear();
    await _configCache.clear();
  }
}