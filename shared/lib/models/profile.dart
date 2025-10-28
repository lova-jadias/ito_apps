// shared/lib/models/profile.dart
// Basé sur
import 'package:shared/models/site_enum.dart';
import 'package:shared/models/user_role_enum.dart';

class Profile {
  final String id;
  final String nomComplet;
  final String email;
  final UserRole role;
  final Site siteRattache;

  Profile({
    required this.id,
    required this.nomComplet,
    required this.email,
    required this.role,
    required this.siteRattache,
  });

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'],
      nomComplet: map['nom_complet'] ?? '',
      email: map['email'] ?? '',
      role: UserRole.values.firstWhere(
            (e) => e.name == map['role'],
        orElse: () => UserRole.etudiant, // Fallback
      ),
      siteRattache: Site.values.firstWhere(
            (e) => e.name == map['site_rattache'],
        orElse: () => Site.T, // Fallback
      ),
    );
  }
}