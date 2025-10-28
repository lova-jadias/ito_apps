// ignore_for_file: prefer_const_constructors
import 'dart:async';
//import 'packagedart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Modèle de profil local (corrigé)
class Profile {
  final String id;
  final String email;
  final String role;
  final String site;
  final String nomComplet; // <-- CORRECTION: 'nom' est devenu 'nomComplet'

  Profile({
    required this.id,
    required this.email,
    required this.role,
    required this.site,
    required this.nomComplet, // <-- CORRECTION
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'inconnu',
      site: json['site_rattache'] ?? 'inconnu',
      nomComplet: json['nom_complet'] ?? 'Utilisateur', // <-- CORRECTION
    );
  }
}

class AuthProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;
  StreamSubscription<AuthState>? _authStateSubscription;

  Profile? _currentUser;
  Profile? get currentUser => _currentUser;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool get isLoggedIn => _currentUser != null;

  AuthProvider() {
    _authStateSubscription =
        _client.auth.onAuthStateChange.listen((data) async {
          final session = data.session;
          if (session != null) {
            // L'utilisateur est connecté, chercher son profil
            await _fetchUserProfile(session.user.id);
          } else {
            _currentUser = null;
            _isLoading = false;
            notifyListeners();
          }
        });
    // Vérifier l'état de connexion au démarrage
    _checkInitialSession();
  }

  Future<void> _checkInitialSession() async {
    final session = _client.auth.currentSession;
    if (session != null) {
      await _fetchUserProfile(session.user.id);
    } else {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchUserProfile(String userId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _client
          .from('profiles')
          .select('id, email, role, site_rattache, nom_complet') // <-- CORRECTION
          .eq('id', userId)
          .single();

      _currentUser = Profile.fromJson(response);
    } catch (e) {
      _currentUser = null;
      // Gérer l'erreur, par exemple:
      print("Erreur fetchUserProfile: $e");
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<String?> login(String email, String password) async {
    try {
      final response = await _client.auth
          .signInWithPassword(email: email, password: password);
      if (response.user != null) {
        await _fetchUserProfile(response.user!.id);
        return null; // Succès
      }
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return "Une erreur inattendue est survenue.";
    }
    return "Erreur inconnue.";
  }

  Future<void> logout() async {
    await _client.auth.signOut();
    _currentUser = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }
}