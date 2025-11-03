// rejistra/lib/screens/admin/admin_edit_page.dart
// ignore_for_file: prefer_const_constructors, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rejistra/providers/data_provider.dart';
import 'package:rejistra/utils/helpers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminEditPage extends StatefulWidget {
  const AdminEditPage({Key? key}) : super(key: key);

  @override
  State<AdminEditPage> createState() => _AdminEditPageState();
}

class _AdminEditPageState extends State<AdminEditPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Administration: Édition Directe'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Modifier/Annuler un Paiement",
                style: Theme.of(context).textTheme.headlineSmall),
            SizedBox(height: 16),
            SearchModifyPaymentWidget(),
            Divider(height: 48),
            Text("Ajouter/Gérer les Configurations",
                style: Theme.of(context).textTheme.headlineSmall),
            SizedBox(height: 16),
            ConfigManagementWidget(),
          ],
        ),
      ),
    );
  }
}

class ConfigManagementWidget extends StatefulWidget {
  const ConfigManagementWidget({Key? key}) : super(key: key);
  @override
  State<ConfigManagementWidget> createState() =>
      _ConfigManagementWidgetState();
}

class _ConfigManagementWidgetState extends State<ConfigManagementWidget> {
  final SupabaseClient _client = Supabase.instance.client;
  String? _selectedCategory;
  final _newValueController = TextEditingController();
  bool _isSaving = false;

  Future<void> _addConfig() async {
    if (_selectedCategory == null || _newValueController.text.isEmpty) {
      showErrorSnackBar(context,
          "Veuillez sélectionner une catégorie et saisir une valeur.");
      return;
    }
    setState(() => _isSaving = true);
    try {
      await _client.from('config_options').insert({
        'categorie': _selectedCategory,
        'valeur': _newValueController.text.trim(),
      });
      showSuccessSnackBar(context, "Configuration ajoutée.");
      _newValueController.clear();
      Provider.of<DataProvider>(context, listen: false).fetchConfigOptions();
    } on PostgrestException catch (e) {
      showErrorSnackBar(context, "Erreur: ${e.message}");
    } catch (e) {
      showErrorSnackBar(context, "Erreur: $e");
    }
    setState(() => _isSaving = false);
  }

  Future<void> _deleteConfig(String category, String value) async {
    try {
      await _client
          .from('config_options')
          .delete()
          .eq('categorie', category)
          .eq('valeur', value);
      showSuccessSnackBar(context, "Configuration supprimée.");
      Provider.of<DataProvider>(context, listen: false).fetchConfigOptions();
    } catch (e) {
      showErrorSnackBar(context, "Erreur: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<DataProvider>().configOptions;
    final categories = config.keys.toList();

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Wrap(
              spacing: 16.0,
              runSpacing: 16.0,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 250,
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(labelText: 'Catégorie'),
                    items: categories
                        .map((k) =>
                        DropdownMenuItem(value: k, child: Text(k)))
                        .toList(),
                    onChanged: (val) =>
                        setState(() => _selectedCategory = val),
                  ),
                ),
                SizedBox(
                  width: 300,
                  child: TextField(
                    controller: _newValueController,
                    decoration: InputDecoration(
                        labelText: 'Nouvelle valeur (ex: GL4)'),
                  ),
                ),
                _isSaving
                    ? CircularProgressIndicator()
                    : ElevatedButton(
                  onPressed: _addConfig,
                  child: Text("Ajouter"),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 24),
        ExpansionPanelList.radio(
          children: categories.map<ExpansionPanelRadio>((String category) {
            return ExpansionPanelRadio(
              value: category,
              headerBuilder: (BuildContext context, bool isExpanded) {
                return ListTile(
                  title: Text(category,
                      style: TextStyle(fontWeight: FontWeight.bold)),
                );
              },
              body: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: config[category]!.map((value) {
                    return Chip(
                      label: Text(value),
                      onDeleted: () => _deleteConfig(category, value),
                      deleteIcon: Icon(Icons.remove_circle_outline, size: 18),
                    );
                  }).toList(),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class SearchModifyPaymentWidget extends StatefulWidget {
  const SearchModifyPaymentWidget({Key? key}) : super(key: key);
  @override
  State<SearchModifyPaymentWidget> createState() =>
      _SearchModifyPaymentWidgetState();
}

class _SearchModifyPaymentWidgetState
    extends State<SearchModifyPaymentWidget> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final results = await Supabase.instance.client
          .from('paiement_items')
          .select(
          '*, etudiants(nom, prenom), recus(n_recu_principal, ref_transaction)')
          .or(
          'recus.n_recu_principal.ilike.*$query*,etudiants.nom.ilike.*$query*,etudiants.prenom.ilike.*$query*')
          .limit(10);
      setState(() => _searchResults = List<Map<String, dynamic>>.from(results));
    } catch (e) {
      showErrorSnackBar(context, "Erreur: $e");
    }
    setState(() => _isLoading = false);
  }

  void _showEditDialog(Map<String, dynamic> paymentItem) {
    showDialog(
      context: context,
      builder: (context) => _EditPaymentDialog(
        paymentItem: paymentItem,
        onSaved: _search,
      ),
    );
  }

  void _showCancelDialog(Map<String, dynamic> paymentItem) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Annuler le Paiement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                'Voulez-vous annuler ce paiement ?\nMotif: ${paymentItem['motif']}\nMontant: ${paymentItem['montant']} Ar'),
            SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration:
              InputDecoration(labelText: 'Raison de l\'annulation *'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Fermer')),
          TextButton(
            onPressed: () async {
              if (reasonController.text.isEmpty) {
                showErrorSnackBar(context, "La raison est obligatoire.");
                return;
              }
              try {
                await Supabase.instance.client
                    .rpc('cancel_payment', params: {
                  'p_item_id': paymentItem['id'],
                  'reason': reasonController.text,
                });
                Navigator.of(context).pop();
                showSuccessSnackBar(context, "Paiement annulé.");
                _search();
              } catch (e) {
                showErrorSnackBar(context, "Erreur RPC: $e");
              }
            },
            child: Text('Confirmer l\'Annulation',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Rechercher (Étudiant, Reçu)',
                prefixIcon: Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _search,
                ),
              ),
              onSubmitted: (_) => _search(),
            ),
            SizedBox(height: 16),
            if (_isLoading) CircularProgressIndicator(),
            ..._searchResults.map((item) {
              final student = item['etudiants'];
              final recu = item['recus'];
              return ListTile(
                title: Text(
                    '${student?['nom'] ?? 'N/A'} ${student?['prenom'] ?? ''} - ${item['motif']}'),
                subtitle: Text(
                    'Reçu: ${recu?['n_recu_principal'] ?? 'N/A'} | Montant: ${item['montant']} Ar'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit_note, color: Colors.blue),
                      tooltip: "Modifier",
                      onPressed: () => _showEditDialog(item),
                    ),
                    IconButton(
                      icon: Icon(Icons.cancel_outlined, color: Colors.red),
                      tooltip: "Annuler",
                      onPressed: () => _showCancelDialog(item),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _EditPaymentDialog extends StatefulWidget {
  final Map<String, dynamic> paymentItem;
  final VoidCallback onSaved;

  const _EditPaymentDialog(
      {Key? key, required this.paymentItem, required this.onSaved})
      : super(key: key);
  @override
  State<_EditPaymentDialog> createState() => _EditPaymentDialogState();
}

class _EditPaymentDialogState extends State<_EditPaymentDialog> {
  late TextEditingController _motifController;
  late TextEditingController _recuController;
  late TextEditingController _refController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _motifController = TextEditingController(text: widget.paymentItem['motif']);
    _recuController = TextEditingController(
        text: widget.paymentItem['recus']?['n_recu_principal'] ?? '');
    _refController = TextEditingController(
        text: widget.paymentItem['recus']?['ref_transaction'] ?? '');
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await Supabase.instance.client.rpc('update_payment_details', params: {
        'p_item_id': widget.paymentItem['id'],
        'p_new_motif': _motifController.text,
        'p_new_n_recu': _recuController.text,
        'p_new_ref': _refController.text,
      });
      Navigator.of(context).pop();
      showSuccessSnackBar(context, "Paiement mis à jour.");
      widget.onSaved();
    } catch (e) {
      showErrorSnackBar(context, "Erreur RPC: $e");
    }
    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Modifier le Paiement'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _motifController,
              decoration: InputDecoration(labelText: 'Motif de Paiement'),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _recuController,
              decoration: InputDecoration(labelText: 'Numéro de Reçu'),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _refController,
              decoration:
              InputDecoration(labelText: 'Référence de Paiement'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Annuler')),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? CircularProgressIndicator(strokeWidth: 2)
              : Text('Enregistrer'),
        ),
      ],
    );
  }
}