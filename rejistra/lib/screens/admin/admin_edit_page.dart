// rejistra/lib/screens/admin/admin_edit_page.dart
// ignore_for_file: prefer_const_constructors, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
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
            // Section 1: Gérer les Paiements
            Text("Modifier/Annuler un Paiement",
                style: Theme.of(context).textTheme.headlineSmall),
            SizedBox(height: 16),
            SearchModifyPaymentWidget(),

            Divider(height: 48),

            // Section 2: Gérer les Étudiants
            Text("Modifier les Informations Étudiant",
                style: Theme.of(context).textTheme.headlineSmall),
            SizedBox(height: 16),
            SearchModifyStudentWidget(),

            Divider(height: 48),

            // Section 3: Gérer les Configurations
            Text("Ajouter/Gérer les Configurations",
                style: Theme.of(context).textTheme.headlineSmall),
            SizedBox(height: 16),
            ConfigManagementWidget(),

            Divider(height: 48),

            // Section 4: Ajouter un nouveau Site
            Text("Ajouter un Nouveau Site",
                style: Theme.of(context).textTheme.headlineSmall),
            SizedBox(height: 16),
            AddSiteWidget(),
          ],
        ),
      ),
    );
  }
}

// ===============================================
// WIDGET DE RECHERCHE ET MODIFICATION DES PAIEMENTS
// ===============================================
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
  String _searchHint = '';

  // ✅ CORRECTION: Utilise la RPC au lieu de la requête REST complexe
  Future<void> _searchPayments(String query) async {
    if (query.trim().length < 2) {
      setState(() {
        _searchResults = [];
        _searchHint = 'Entrez au moins 2 caractères pour rechercher';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _searchHint = '';
    });

    try {
      final results = await Supabase.instance.client
          .rpc('search_payments', params: {'search_query': query.trim()});

      setState(() {
        _searchResults = List<Map<String, dynamic>>.from(results);
        if (_searchResults.isEmpty) {
          _searchHint = 'Aucun résultat trouvé pour "$query"';
        }
      });
    } catch (e) {
      showErrorSnackBar(context, "Erreur de recherche: $e");
      setState(() => _searchHint = 'Erreur lors de la recherche');
    }

    setState(() => _isLoading = false);
  }

  void _showEditPaymentDialog(Map<String, dynamic> payment) {
    showDialog(
      context: context,
      builder: (context) => _EditPaymentFullDialog(
        payment: payment,
        onSaved: () => _searchPayments(_searchController.text),
      ),
    );
  }

  void _showCancelPaymentDialog(Map<String, dynamic> payment) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Annuler le Paiement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Étudiant: ${payment['etudiant_nom']} ${payment['etudiant_prenom'] ?? ''}'),
            Text('Motif: ${payment['motif']}'),
            Text(
                'Montant: ${NumberFormat.decimalPattern('fr').format(payment['montant'])} Ar'),
            SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: 'Raison de l\'annulation *',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
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

              // Confirmation
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text('Confirmer l\'annulation'),
                  content: Text(
                      'Êtes-vous sûr de vouloir annuler ce paiement ? Cette action est irréversible.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text('Non')),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text('Oui, annuler',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );

              if (confirm != true) return;

              try {
                await Supabase.instance.client.rpc('cancel_payment', params: {
                  'p_item_id': payment['item_id'],
                  'reason': reasonController.text,
                });
                Navigator.of(context).pop();
                showSuccessSnackBar(context, "Paiement annulé.");
                _searchPayments(_searchController.text);
              } catch (e) {
                showErrorSnackBar(context, "Erreur: $e");
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Barre de recherche
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Rechercher par Nom, ID Étudiant ou Nº Reçu',
                prefixIcon: Icon(Icons.search),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchResults = [];
                            _searchHint = '';
                          });
                        },
                      ),
                    IconButton(
                      icon: Icon(Icons.search),
                      onPressed: () => _searchPayments(_searchController.text),
                    ),
                  ],
                ),
              ),
              onSubmitted: _searchPayments,
            ),

            SizedBox(height: 16),

            // Indicateur de chargement ou hint
            if (_isLoading)
              Center(child: CircularProgressIndicator())
            else if (_searchHint.isNotEmpty)
              Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(_searchHint,
                      style: TextStyle(color: Colors.grey)),
                ),
              ),

            // Liste des résultats
            if (_searchResults.isNotEmpty) ...[
              Text('${_searchResults.length} résultat(s) trouvé(s)',
                  style: Theme.of(context).textTheme.bodySmall),
              SizedBox(height: 8),
              ListView.separated(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: _searchResults.length,
                separatorBuilder: (_, __) => Divider(height: 1),
                itemBuilder: (context, index) {
                  final payment = _searchResults[index];
                  final isAnnule =
                      payment['motif']?.toString().startsWith('ANNULÉ') ??
                          false;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isAnnule
                          ? Colors.red.shade100
                          : Colors.blue.shade100,
                      child: Icon(
                        isAnnule ? Icons.cancel : Icons.receipt,
                        color: isAnnule ? Colors.red : Colors.blue,
                      ),
                    ),
                    title: Text(
                      '${payment['etudiant_nom']} ${payment['etudiant_prenom'] ?? ''} (${payment['etudiant_id_genere']})',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            'Reçu: ${payment['n_recu_principal']} | Motif: ${payment['motif']}'),
                        Text(
                          'Montant: ${NumberFormat.decimalPattern('fr').format(payment['montant'])} Ar | ${DateFormat('dd/MM/yyyy').format(DateTime.parse(payment['date_paiement']))}',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    isThreeLine: true,
                    trailing: isAnnule
                        ? Chip(
                            label: Text('Annulé',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 10)),
                            backgroundColor: Colors.red,
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit_note,
                                    color: Colors.blue),
                                tooltip: "Modifier",
                                onPressed: () =>
                                    _showEditPaymentDialog(payment),
                              ),
                              IconButton(
                                icon: Icon(Icons.cancel_outlined,
                                    color: Colors.red),
                                tooltip: "Annuler",
                                onPressed: () =>
                                    _showCancelPaymentDialog(payment),
                              ),
                            ],
                          ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Dialog de modification complète d'un paiement
class _EditPaymentFullDialog extends StatefulWidget {
  final Map<String, dynamic> payment;
  final VoidCallback onSaved;

  const _EditPaymentFullDialog(
      {Key? key, required this.payment, required this.onSaved})
      : super(key: key);
  @override
  State<_EditPaymentFullDialog> createState() =>
      _EditPaymentFullDialogState();
}

class _EditPaymentFullDialogState extends State<_EditPaymentFullDialog> {
  late TextEditingController _motifController;
  late TextEditingController _montantController;
  late TextEditingController _moisDeController;
  late TextEditingController _recuController;
  late TextEditingController _refController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _motifController = TextEditingController(text: widget.payment['motif']);
    _montantController =
        TextEditingController(text: widget.payment['montant'].toString());
    _moisDeController =
        TextEditingController(text: widget.payment['mois_de'] ?? '');
    _recuController =
        TextEditingController(text: widget.payment['n_recu_principal']);
    _refController =
        TextEditingController(text: widget.payment['ref_transaction'] ?? '');
  }

  Future<void> _save() async {
    // Confirmation avant modification
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Confirmer la modification'),
        content: Text('Êtes-vous sûr de vouloir modifier ce paiement ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);
    try {
      await Supabase.instance.client.rpc('update_payment_full', params: {
        'p_item_id': widget.payment['item_id'],
        'p_new_motif': _motifController.text,
        'p_new_montant': double.parse(_montantController.text),
        'p_new_mois_de':
            _moisDeController.text.isEmpty ? null : _moisDeController.text,
        'p_new_n_recu': _recuController.text,
        'p_new_ref': _refController.text,
      });
      Navigator.of(context).pop();
      showSuccessSnackBar(context, "Paiement mis à jour.");
      widget.onSaved();
    } catch (e) {
      showErrorSnackBar(context, "Erreur: $e");
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
            // Info étudiant (lecture seule)
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.person, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${widget.payment['etudiant_nom']} ${widget.payment['etudiant_prenom'] ?? ''}\nID: ${widget.payment['etudiant_id_genere']}',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _motifController,
              decoration: InputDecoration(labelText: 'Motif de Paiement'),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _montantController,
              decoration:
                  InputDecoration(labelText: 'Montant (Ar)', prefixText: 'Ar '),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 12),
            TextField(
              controller: _moisDeController,
              decoration: InputDecoration(labelText: 'Mois de (si écolage)'),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _recuController,
              decoration: InputDecoration(labelText: 'Numéro de Reçu'),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _refController,
              decoration: InputDecoration(labelText: 'Référence Transaction'),
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

// ===============================================
// WIDGET DE RECHERCHE ET MODIFICATION DES ÉTUDIANTS
// ===============================================
class SearchModifyStudentWidget extends StatefulWidget {
  const SearchModifyStudentWidget({Key? key}) : super(key: key);
  @override
  State<SearchModifyStudentWidget> createState() =>
      _SearchModifyStudentWidgetState();
}

class _SearchModifyStudentWidgetState
    extends State<SearchModifyStudentWidget> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  String _searchHint = '';

  Future<void> _searchStudents(String query) async {
    if (query.trim().length < 2) {
      setState(() {
        _searchResults = [];
        _searchHint = 'Entrez au moins 2 caractères pour rechercher';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _searchHint = '';
    });

    try {
      final results = await Supabase.instance.client.rpc(
          'search_students_for_edit',
          params: {'search_query': query.trim()});

      setState(() {
        _searchResults = List<Map<String, dynamic>>.from(results);
        if (_searchResults.isEmpty) {
          _searchHint = 'Aucun résultat trouvé pour "$query"';
        }
      });
    } catch (e) {
      showErrorSnackBar(context, "Erreur de recherche: $e");
      setState(() => _searchHint = 'Erreur lors de la recherche');
    }

    setState(() => _isLoading = false);
  }

  void _showEditStudentDialog(Map<String, dynamic> student) {
    showDialog(
      context: context,
      builder: (context) => _EditStudentDialog(
        student: student,
        onSaved: () => _searchStudents(_searchController.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Rechercher par Nom, ID ou Email',
                prefixIcon: Icon(Icons.search),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchResults = [];
                            _searchHint = '';
                          });
                        },
                      ),
                    IconButton(
                      icon: Icon(Icons.search),
                      onPressed: () => _searchStudents(_searchController.text),
                    ),
                  ],
                ),
              ),
              onSubmitted: _searchStudents,
            ),

            SizedBox(height: 16),

            if (_isLoading)
              Center(child: CircularProgressIndicator())
            else if (_searchHint.isNotEmpty)
              Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(_searchHint,
                      style: TextStyle(color: Colors.grey)),
                ),
              ),

            if (_searchResults.isNotEmpty) ...[
              Text('${_searchResults.length} résultat(s) trouvé(s)',
                  style: Theme.of(context).textTheme.bodySmall),
              SizedBox(height: 8),
              ListView.separated(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: _searchResults.length,
                separatorBuilder: (_, __) => Divider(height: 1),
                itemBuilder: (context, index) {
                  final student = _searchResults[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green.shade100,
                      child: Icon(Icons.person, color: Colors.green),
                    ),
                    title: Text(
                      '${student['nom']} ${student['prenom'] ?? ''} (${student['id_etudiant_genere']})',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                        'Email: ${student['email_contact']}\nGroupe: ${student['groupe']} | Statut: ${student['statut']}'),
                    isThreeLine: true,
                    trailing: IconButton(
                      icon: Icon(Icons.edit, color: Colors.blue),
                      tooltip: "Modifier",
                      onPressed: () => _showEditStudentDialog(student),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Dialog de modification d'étudiant
class _EditStudentDialog extends StatefulWidget {
  final Map<String, dynamic> student;
  final VoidCallback onSaved;

  const _EditStudentDialog(
      {Key? key, required this.student, required this.onSaved})
      : super(key: key);

  @override
  State<_EditStudentDialog> createState() => _EditStudentDialogState();
}

class _EditStudentDialogState extends State<_EditStudentDialog> {
  late TextEditingController _nomController;
  late TextEditingController _prenomController;
  late TextEditingController _emailController;
  late TextEditingController _telController;
  DateTime? _dateNaissance;
  String? _selectedMention;
  String? _selectedNiveau;
  String? _selectedGroupe;
  String? _selectedDepartement;
  String? _selectedStatut;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nomController = TextEditingController(text: widget.student['nom']);
    _prenomController = TextEditingController(text: widget.student['prenom']);
    _emailController =
        TextEditingController(text: widget.student['email_contact']);
    _telController = TextEditingController(text: widget.student['telephone']);

    // Date de naissance
    if (widget.student['date_naissance'] != null) {
      _dateNaissance = DateTime.parse(widget.student['date_naissance']);
    }

    _selectedMention = widget.student['mention_module'];
    _selectedNiveau = widget.student['niveau'];
    _selectedGroupe = widget.student['groupe'];
    _selectedDepartement = widget.student['departement'];
    _selectedStatut = widget.student['statut'];
  }

  Future<void> _save() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Confirmer la modification'),
        content:
            Text('Êtes-vous sûr de vouloir modifier cet étudiant ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);
    try {
      await Supabase.instance.client.rpc('update_student_info', params: {
        'p_student_id': widget.student['id'],
        'p_nom': _nomController.text,
        'p_prenom': _prenomController.text,
        'p_email': _emailController.text,
        'p_telephone': _telController.text,
        'p_date_naissance': _dateNaissance?.toIso8601String(),
        'p_mention_module': _selectedMention,
        'p_niveau': _selectedNiveau,
        'p_groupe': _selectedGroupe,
        'p_departement': _selectedDepartement,
        'p_statut': _selectedStatut,
      });
      Navigator.of(context).pop();
      showSuccessSnackBar(context, "Étudiant mis à jour.");
      widget.onSaved();
    } catch (e) {
      showErrorSnackBar(context, "Erreur: $e");
    }
    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<DataProvider>().configOptions;

    return AlertDialog(
      title: Text('Modifier l\'Étudiant'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 600,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Info ID (lecture seule)
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.badge, color: Colors.green),
                    SizedBox(width: 8),
                    Text(
                      'ID: ${widget.student['id_etudiant_genere']}',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _nomController,
                decoration: InputDecoration(labelText: 'Nom *'),
              ),
              SizedBox(height: 12),
              TextField(
                controller: _prenomController,
                decoration: InputDecoration(labelText: 'Prénom'),
              ),
              SizedBox(height: 12),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(labelText: 'Email *'),
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 12),
              TextField(
                controller: _telController,
                decoration: InputDecoration(labelText: 'Téléphone'),
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: _dateNaissance ?? DateTime(2005, 1, 1),
                    firstDate: DateTime(1950),
                    lastDate: DateTime.now()
                        .subtract(Duration(days: 365 * 10)),
                  );
                  if (pickedDate != null) {
                    setState(() {
                      _dateNaissance = pickedDate;
                    });
                  }
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                      labelText: 'Date de Naissance',
                      suffixIcon: Icon(Icons.calendar_month)),
                  child: Text(
                    _dateNaissance == null
                        ? 'Sélectionner une date'
                        : DateFormat('dd/MM/yyyy').format(_dateNaissance!),
                  ),
                ),
              ),
              SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: 'Mention/Module'),
                value: _selectedMention,
                items: (config['MentionModule'] ?? [])
                    .map((item) =>
                        DropdownMenuItem(value: item, child: Text(item)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedMention = val),
              ),
              SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: 'Niveau'),
                value: _selectedNiveau,
                items: (config['Niveau'] ?? [])
                    .map((item) =>
                        DropdownMenuItem(value: item, child: Text(item)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedNiveau = val),
              ),
              SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: 'Groupe'),
                value: _selectedGroupe,
                items: (config['Groupe'] ?? [])
                    .map((item) =>
                        DropdownMenuItem(value: item, child: Text(item)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedGroupe = val),
              ),
              SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: 'Département'),
                value: _selectedDepartement,
                items: (config['Département'] ?? [])
                    .map((item) =>
                        DropdownMenuItem(value: item, child: Text(item)))
                    .toList(),
                onChanged: (val) =>
                    setState(() => _selectedDepartement = val),
              ),
              SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: 'Statut'),
                value: _selectedStatut,
                items: (config['Statut'] ?? [])
                    .map((item) =>
                        DropdownMenuItem(value: item, child: Text(item)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedStatut = val),
              ),
            ],
          ),
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

// ===============================================
// WIDGET DE GESTION DES CONFIGURATIONS
// ===============================================
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
    // Exclure 'Site' car géré séparément
    final categories = config.keys.where((k) => k != 'Site').toList();

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
                        .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedCategory = val),
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
                      deleteIcon:
                          Icon(Icons.remove_circle_outline, size: 18),
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

// ===============================================
// WIDGET POUR AJOUTER UN NOUVEAU SITE
// ===============================================
class AddSiteWidget extends StatefulWidget {
  const AddSiteWidget({Key? key}) : super(key: key);
  @override
  State<AddSiteWidget> createState() => _AddSiteWidgetState();
}

class _AddSiteWidgetState extends State<AddSiteWidget> {
  final _codeController = TextEditingController();
  final _nomController = TextEditingController();
  bool _isLoading = false;

  Future<void> _addSite() async {
    if (_codeController.text.isEmpty || _nomController.text.isEmpty) {
      showErrorSnackBar(
          context, "Veuillez remplir le code et le nom du site.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await Supabase.instance.client
          .rpc('add_new_site', params: {
        'p_code': _codeController.text.trim(),
        'p_nom': _nomController.text.trim(),
      });

      showSuccessSnackBar(
          context, "Site '${result['code']}' ajouté avec succès !");
      _codeController.clear();
      _nomController.clear();

      // Rafraîchir les options de configuration
      Provider.of<DataProvider>(context, listen: false).fetchConfigOptions();
    } catch (e) {
      showErrorSnackBar(context, "Erreur: $e");
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<DataProvider>().configOptions;
    final existingSites = config['Site'] ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Créer un nouveau site qui sera automatiquement disponible dans tout le système (inscriptions, paiements, utilisateurs, etc.)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            SizedBox(height: 16),
            Wrap(
              spacing: 16.0,
              runSpacing: 16.0,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                SizedBox(
                  width: 150,
                  child: TextField(
                    controller: _codeController,
                    decoration: InputDecoration(
                      labelText: 'Code *',
                      hintText: 'Ex: PEF',
                      helperText: 'Max 4 caractères',
                    ),
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 4,
                  ),
                ),
                SizedBox(
                  width: 250,
                  child: TextField(
                    controller: _nomController,
                    decoration: InputDecoration(
                      labelText: 'Nom complet *',
                      hintText: 'Ex: Fianarantsoa',
                    ),
                  ),
                ),
                _isLoading
                    ? CircularProgressIndicator()
                    : ElevatedButton.icon(
                        onPressed: _addSite,
                        icon: Icon(Icons.add_location_alt),
                        label: Text('Ajouter le Site'),
                      ),
              ],
            ),
            SizedBox(height: 24),
            Text('Sites existants:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: existingSites.map((site) {
                final isFull = site == 'FULL';
                return Chip(
                  label: Text(site),
                  backgroundColor: isFull
                      ? Colors.purple.shade100
                      : Colors.blue.shade100,
                  avatar: isFull
                      ? Icon(Icons.public, size: 18)
                      : Icon(Icons.location_on, size: 18),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}