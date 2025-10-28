// rejistra/lib/providers/auth_provider.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared/models/profile.dart';
import 'package:shared/models/user_role_enum.dart'; // <-- CORRECTION AJOUTÉE ICI

class AuthProvider extends ChangeNotifier {
  final GoTrueClient _auth = Supabase.instance.client.auth;
  Profile? _currentUser;
  Profile? get currentUser => _currentUser;

  bool get isLoggedIn => _currentUser != null;
  bool _isLoading = true;
  bool get isLoading => _isLoading;

  AuthProvider() {
    _isLoading = true;
    notifyListeners();

    // Écouter les changements d'état d'authentification
    _auth.onAuthStateChange.listen((data) {
      final Session? session = data.session;
      if (session != null) {
        _fetchUserProfile(session.user.id);
      } else {
        _currentUser = null;
        _isLoading = false;
        notifyListeners();
      }
    });
  }

  // Récupérer le profil depuis la table 'profiles'
  Future<void> _fetchUserProfile(String userId) async {
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      _currentUser = Profile.fromMap(response);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint("Erreur de fetch profile: $e");
      _currentUser = null;
      _isLoading = false;
      notifyListeners();
    }
  }

  // Connexion
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _auth.signInWithPassword(
        email: email,
        password: password,
      );
      // Le listener 'onAuthStateChange' s'occupera du reste
      return response.session != null;
    } catch (e) {
      debugPrint("Erreur de login: $e");
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Déconnexion
  void logout() {
    _auth.signOut();
  }

  // Utile pour la navigation (ex: Rôle 'accueil')
  bool hasRole(List<UserRole> roles) {
    if (_currentUser == null) return false;
    return roles.contains(_currentUser!.role);
  }
}