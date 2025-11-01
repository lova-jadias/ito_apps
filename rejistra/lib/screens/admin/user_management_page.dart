// rejistra/lib/screens/admin/user_management_page.dart
// ignore_for_file: prefer_const_constructors, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rejistra/providers/data_provider.dart';
import 'package:rejistra/utils/helpers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:rejistra/services/admin_service.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({Key? key}) : super(key: key);

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final _client = Supabase.instance.client;
  Stream<List<Map<String, dynamic>>>? _profilesStream;

  @override
  void initState() {
    super.initState();
    _profilesStream = _client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) => data);
  }

  void _showAddUserDialog() {
    showDialog(
      context: context,
      builder: (context) => _AddUserDialog(),
    );
  }

  Future<void> _deleteUser(String userId, String userName) async {
    final bool didConfirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Supprimer l\'utilisateur ?'),
        content: Text('Voulez-vous vraiment supprimer définitivement $userName ? Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;

    if (didConfirm) {
      try {
        await AdminService().deleteUser(userId);
        showSuccessSnackBar(context, "Utilisateur supprimé.");
      } catch (e) {
        showErrorSnackBar(context, "Erreur: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Administration: Gérer les Utilisateurs'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton.icon(
              onPressed: _showAddUserDialog,
              icon: Icon(Icons.add),
              label: Text('Créer un nouvel utilisateur'),
            ),
            SizedBox(height: 16),
            Expanded(
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _profilesStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text("Erreur: ${snapshot.error}"));
                    }
                    final profiles = snapshot.data ?? [];
                    return DataTable2(
                      columnSpacing: 12,
                      horizontalMargin: 12,
                      minWidth: 700,
                      columns: const [
                        DataColumn2(label: Text('Nom Complet'), size: ColumnSize.L),
                        DataColumn2(label: Text('Email'), size: ColumnSize.L),
                        DataColumn2(label: Text('Rôle'), size: ColumnSize.M),
                        DataColumn2(label: Text('Site'), size: ColumnSize.S),
                        DataColumn2(label: Text('Actions'), size: ColumnSize.S),
                      ],
                      rows: profiles.map((profile) {
                        return DataRow(cells: [
                          DataCell(Text(profile['nom_complet'] ?? 'N/A')),
                          DataCell(Text(profile['email'] ?? 'N/A')),
                          DataCell(Text(profile['role'] ?? 'N/A')),
                          DataCell(Text(profile['site_rattache'] ?? 'N/A')),
                          DataCell(Row(
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                                tooltip: "Modifier (non implémenté)",
                                onPressed: () {
                                  showErrorSnackBar(context, "La modification sera bientôt disponible.");
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                tooltip: "Supprimer",
                                onPressed: () => _deleteUser(profile['id'], profile['nom_complet'] ?? 'Utilisateur'),
                              ),
                            ],
                          )),
                        ]);
                      }).toList(),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Dialogue d'ajout d'utilisateur (corrigé pour appeler la RPC)
class _AddUserDialog extends StatefulWidget {
  const _AddUserDialog({Key? key}) : super(key: key);
  @override
  State<_AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<_AddUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nomController = TextEditingController();
  String? _selectedRole;
  String? _selectedSite;
  bool _isLoading = false;

  // Rôles du personnel (on ne crée pas d'étudiants ici)
  final List<String> _roles = ['accueil', 'responsable', 'controleur', 'rp', 'enseignant'];

  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // ✅ UTILISER AdminService (Edge Function)
      await AdminService().createStaff(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        nomComplet: _nomController.text.trim(),
        role: _selectedRole!,
        site: _selectedSite!,
      );

      if (!mounted) return;
      showSuccessSnackBar(context, "Utilisateur créé avec succès.");
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, "Erreur: $e");
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final config = context.read<DataProvider>().configOptions;
    final sites = config['Site'] ?? [];

    return AlertDialog(
      title: Text('Créer un utilisateur (Personnel)'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nomController,
                decoration: InputDecoration(labelText: 'Nom Complet *'),
                validator: (val) => val!.isEmpty ? 'Requis' : null,
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(labelText: 'Email *'),
                keyboardType: TextInputType.emailAddress,
                validator: (val) => (val!.isEmpty || !val.contains('@')) ? 'Email invalide' : null,
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(labelText: 'Mot de passe provisoire *'),
                validator: (val) => (val!.isEmpty || val.length < 6) ? 'Min 6 caractères' : null,
              ),
              SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: 'Rôle *'),
                items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (val) => setState(() => _selectedRole = val),
                validator: (val) => val == null ? 'Requis' : null,
              ),
              SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: 'Site Rattaché *'),
                items: sites.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (val) => setState(() => _selectedSite = val),
                validator: (val) => val == null ? 'Requis' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _createUser,
          child: _isLoading ? CircularProgressIndicator(strokeWidth: 2) : Text('Créer'),
        ),
      ],
    );
  }
}
