import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DataProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  // Stocke toutes les options de config
  Map<String, List<String>> _configOptions = {};
  Map<String, List<String>> get configOptions => _configOptions;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  DataProvider() {
    fetchConfigOptions();
  }

  // Récupère toutes les listes déroulantes de la DB (Source: 1239)
  Future<void> fetchConfigOptions() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _client
          .from('config_options')
          .select('categorie, valeur');

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

    } catch (e) {
      _error = "Erreur lors du chargement de la configuration : $e";
    }

    _isLoading = false;
    notifyListeners();
  }
}