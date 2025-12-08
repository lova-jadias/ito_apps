import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '../../../config/theme.dart';
import '../../../providers/gojika_provider.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({Key? key}) : super(key: key);

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GojikaProvider>().loadAllProfiles();
    });
  }

  void _showAddUserDialog() {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final nomCtrl = TextEditingController();
    String role = 'rp';
    String site = 'T';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter un utilisateur'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nomCtrl,
                  decoration: const InputDecoration(labelText: 'Nom Complet'),
                  validator: (v) => v!.isEmpty ? 'Requis' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (v) => !v!.contains('@') ? 'Email invalide' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: passCtrl,
                  decoration: const InputDecoration(labelText: 'Mot de passe'),
                  obscureText: true,
                  validator: (v) => v!.length < 6 ? 'Min 6 caractères' : null,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: role,
                  decoration: const InputDecoration(labelText: 'Rôle'),
                  items: const [
                    DropdownMenuItem(value: 'rp', child: Text('Responsable Pédagogique')),
                    DropdownMenuItem(value: 'responsable', child: Text('Responsable Site')),
                    DropdownMenuItem(value: 'controleur', child: Text('Contrôleur')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  ],
                  onChanged: (v) => role = v!,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: site,
                  decoration: const InputDecoration(labelText: 'Site'),
                  items: const [
                    DropdownMenuItem(value: 'T', child: Text('Antananarivo')),
                    DropdownMenuItem(value: 'TO', child: Text('Toamasina')),
                    DropdownMenuItem(value: 'BO', child: Text('Boeny')),
                    DropdownMenuItem(value: 'FULL', child: Text('FULL ACCESS')),
                  ],
                  onChanged: (v) => site = v!,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context); // Close dialog first
                try {
                  await context.read<GojikaProvider>().createStaffUser({
                    'email': emailCtrl.text,
                    'password': passCtrl.text,
                    'nom_complet': nomCtrl.text,
                    'role': role,
                    'site': site,
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Utilisateur créé avec succès')));
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
                  }
                }
              }
            },
            child: const Text('Créer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GojikaProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Gestion des Utilisateurs')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddUserDialog,
        label: const Text('Ajouter'),
        icon: const Icon(Iconsax.user_add),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: provider.allProfiles.length,
        itemBuilder: (context, index) {
          final user = provider.allProfiles[index];
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _getRoleColor(user['role']),
                child: Icon(_getRoleIcon(user['role']), color: Colors.white, size: 20),
              ),
              title: Text(user['nom_complet'] ?? 'Sans nom'),
              subtitle: Text('${user['email']} • ${user['role'].toString().toUpperCase()} • ${user['site_rattache']}'),
              trailing: IconButton(
                icon: const Icon(Iconsax.trash, color: Colors.red),
                onPressed: () => _confirmDelete(context, user['id'], user['nom_complet']),
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, String id, String? nom) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ?'),
        content: Text('Confirmez la suppression de $nom. Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Non')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<GojikaProvider>().deleteUser(id);
            },
            child: const Text('Oui, supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch(role) {
      case 'admin': return Colors.black;
      case 'rp': return GojikaTheme.primaryBlue;
      case 'responsable': return GojikaTheme.deepPurple;
      case 'etudiant': return GojikaTheme.accentGold;
      default: return Colors.grey;
    }
  }

  IconData _getRoleIcon(String role) {
    switch(role) {
      case 'admin': return Iconsax.security_user;
      case 'rp': return Iconsax.teacher;
      case 'etudiant': return Iconsax.user;
      default: return Iconsax.user_tag;
    }
  }
}