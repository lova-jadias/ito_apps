import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rejistra/services/offline_cache_service.dart';
import 'package:rejistra/services/sync_service.dart';

class DataProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;
  final OfflineCacheService _cache = OfflineCacheService();
  final SyncService _syncService;

  Map<String, List<String>> _configOptions = {};
  Map<String, List<String>> get configOptions => _configOptions;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  DataProvider(this._syncService) {
    _initialize();
  }

  Future<void> _initialize() async {
    await _cache.initialize();
    await fetchConfigOptions();
  }

  /// Récupérer les options de config (avec fallback cache)
  Future<void> fetchConfigOptions() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Essayer de charger depuis Supabase
      final response = await _client
          .from('config_options')
          .select('categorie, valeur')
          .timeout(Duration(seconds: 5));

      final Map<String, List<String>> tempMap = {};
      for (var item in response) {
        final categorie = item['categorie'] as String;
        final valeur = item['valeur'] as String;

        if (tempMap.containsKey(categorie)) {
          tempMap[categorie]!.add(valeur);
        } else {
          tempMap[categorie] = [valeur];
        }
      }

      _configOptions = tempMap;
      _isOnline = true;

      // Mettre à jour le cache
      await _cache.cacheConfig(_configOptions);

    } catch (e) {
      _error = "Erreur réseau, utilisation du cache local";
      _isOnline = false;

      // Charger depuis le cache
      _configOptions = _cache.getCachedConfig();

      if (_configOptions.isEmpty) {
        _error = "Aucune donnée en cache, connexion requise";
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Ajouter une nouvelle config (avec queue offline)
  Future<void> addConfigOption(String categorie, String valeur) async {
    try {
      // Ajouter localement
      if (_configOptions.containsKey(categorie)) {
        _configOptions[categorie]!.add(valeur);
      } else {
        _configOptions[categorie] = [valeur];
      }
      notifyListeners();

      // Mettre à jour le cache
      await _cache.cacheConfig(_configOptions);

      // Ajouter à la queue de sync
      await _syncService.addToQueue(SyncOperation(
        type: SyncOperationType.insert,
        table: 'config_options',
        data: {'categorie': categorie, 'valeur': valeur},
      ));

    } catch (e) {
      _error = "Erreur lors de l'ajout: $e";
      notifyListeners();
    }
  }

  /// Obtenir le nombre d'opérations en attente de sync
  int get pendingSyncCount => _syncService.pendingOperationsCount;
}