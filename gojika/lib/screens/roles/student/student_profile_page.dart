import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/theme.dart';
import '../../../providers/gojika_provider.dart';
import '../../auth/login_page.dart';

class StudentProfilePage extends StatelessWidget {
  final Map<String, dynamic> etudiantData;

  const StudentProfilePage({Key? key, required this.etudiantData}) : super(key: key);

  Future<void> _signOut(BuildContext context) async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (context.mounted) {
        // Vider le provider
        // context.read<GojikaProvider>().clearAll(); // À implémenter si besoin
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
              (route) => false,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la déconnexion: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon Profil'),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.logout),
            onPressed: () => _showLogoutDialog(context),
            tooltip: 'Se déconnecter',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header Profil
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: GojikaTheme.primaryBlue.withOpacity(0.1),
                    backgroundImage: etudiantData['photo_url'] != null
                        ? NetworkImage(etudiantData['photo_url'])
                        : null,
                    child: etudiantData['photo_url'] == null
                        ? const Icon(Iconsax.user, size: 50, color: GojikaTheme.primaryBlue)
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${etudiantData['prenom']} ${etudiantData['nom']}',
                    style: GojikaTheme.titleMedium.copyWith(fontSize: 20),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: GojikaTheme.accentGold.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: GojikaTheme.accentGold),
                    ),
                    child: Text(
                      'Étudiant - ${etudiantData['niveau']}',
                      style: const TextStyle(
                        color: GojikaTheme.accentGold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Informations Académiques
            _SectionHeader(title: 'Informations Académiques'),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  _ProfileInfoTile(
                    icon: Iconsax.building,
                    label: 'Site',
                    value: etudiantData['site'],
                  ),
                  _Divider(),
                  _ProfileInfoTile(
                    icon: Iconsax.teacher,
                    label: 'Mention',
                    value: etudiantData['mention_module'] ?? 'Non défini',
                  ),
                  _Divider(),
                  _ProfileInfoTile(
                    icon: Iconsax.people,
                    label: 'Groupe',
                    value: etudiantData['groupe'],
                  ),
                  _Divider(),
                  _ProfileInfoTile(
                    icon: Iconsax.cd,
                    label: 'Matricule (ID)',
                    value: etudiantData['id_etudiant_genere'] ?? '-',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Coordonnées
            _SectionHeader(title: 'Coordonnées'),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  _ProfileInfoTile(
                    icon: Iconsax.sms,
                    label: 'Email',
                    value: etudiantData['email_contact'] ?? 'Non renseigné',
                  ),
                  _Divider(),
                  _ProfileInfoTile(
                    icon: Iconsax.call,
                    label: 'Téléphone',
                    value: etudiantData['telephone'] ?? 'Non renseigné',
                  ),
                  _Divider(),
                  _ProfileInfoTile(
                    icon: Iconsax.calendar_1,
                    label: 'Date de naissance',
                    value: etudiantData['date_naissance'] ?? 'Non renseigné',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Paramètres App
            _SectionHeader(title: 'Paramètres'),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Mode Sombre'),
                    subtitle: const Text('Changer l\'apparence de l\'application'),
                    secondary: const Icon(Iconsax.moon),
                    value: Theme.of(context).brightness == Brightness.dark,
                    onChanged: (value) {
                      // TODO: Implémenter le ThemeProvider pour changer dynamiquement
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Changement de thème bientôt disponible')),
                      );
                    },
                  ),
                  _Divider(),
                  ListTile(
                    leading: const Icon(Iconsax.message_question),
                    title: const Text('Contacter l\'Admin'),
                    trailing: const Icon(Iconsax.arrow_right_3),
                    onTap: () {
                      // TODO: Ouvrir chat avec Admin
                    },
                  ),
                  _Divider(),
                  ListTile(
                    leading: const Icon(Iconsax.info_circle),
                    title: const Text('À propos'),
                    subtitle: const Text('Version 1.0.0+1'),
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _signOut(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: GojikaTheme.riskRed),
            child: const Text('Déconnecter', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: GojikaTheme.titleMedium.copyWith(
          color: Colors.grey[600],
          fontSize: 14,
        ),
      ),
    );
  }
}

class _ProfileInfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileInfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: GojikaTheme.primaryBlue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: GojikaTheme.primaryBlue, size: 20),
      ),
      title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, indent: 56, endIndent: 16);
  }
}