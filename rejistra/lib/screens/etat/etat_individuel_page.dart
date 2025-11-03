// rejistra/lib/screens/etat/etat_individuel_page.dart
// ignore_for_file: prefer_const_constructors, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:rejistra/providers/auth_provider.dart';
import 'package:rejistra/providers/data_provider.dart';
import 'package:rejistra/utils/helpers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:data_table_2/data_table_2.dart';

class EtatIndividuelPage extends StatefulWidget {
  const EtatIndividuelPage({Key? key}) : super(key: key);

  @override
  State<EtatIndividuelPage> createState() => _EtatIndividuelPageState();
}

class _EtatIndividuelPageState extends State<EtatIndividuelPage> {
  final SupabaseClient _client = Supabase.instance.client;
  Map<String, dynamic>? _selectedStudent;
  List<Map<String, dynamic>> _studentPayments = [];
  bool _isLoading = false;

  Future<void> _searchStudent(Map<String, dynamic> student) async {
    setState(() {
      _isLoading = true;
      _selectedStudent = student;
      _studentPayments = [];
    });

    try {
      final paymentsRes = await _client
          .from('paiement_items')
          .select('*, recus(n_recu_principal, date_paiement, created_by_user_id)')
          .eq('id_etudiant', student['id'])
          .order('date_paiement', referencedTable: 'recus', ascending: false);

      setState(() {
        _studentPayments = List<Map<String, dynamic>>.from(paymentsRes);
        _isLoading = false;
      });
    } catch (e) {
      showErrorSnackBar(context, "Erreur lors de la récupération des paiements: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStudentStatus(String newStatus) async {
    try {
      await _client
          .from('etudiants')
          .update({'statut': newStatus, 'statut_maj_le': DateTime.now().toIso8601String()})
          .eq('id', _selectedStudent!['id']);

      setState(() => _selectedStudent!['statut'] = newStatus);
      showSuccessSnackBar(context, "Statut de l'étudiant mis à jour.");
    } catch (e) {
      showErrorSnackBar(context, "Erreur: $e");
    }
  }

  Future<void> _updateGojikaStatus(bool isActive) async {
    try {
      await _client
          .from('etudiants')
          .update({'gojika_account_active': isActive})
          .eq('id', _selectedStudent!['id']);

      setState(() => _selectedStudent!['gojika_account_active'] = isActive);
      showSuccessSnackBar(context, "Compte GOJIKA mis à jour.");
    } catch (e) {
      showErrorSnackBar(context, "Erreur: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isAdminOrControleur = auth.currentUser?.role == 'admin' || auth.currentUser?.role == 'controleur';

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('Consulter l\'État Individuel'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_selectedStudent != null)
            Padding(
              padding: const EdgeInsets.only(right: 20.0),
              child: ElevatedButton.icon(
                onPressed: () {
                  showSuccessSnackBar(context, "Export PDF non implémenté.");
                },
                icon: Icon(Icons.picture_as_pdf, size: 18),
                label: Text('Exporter en PDF'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white),
              ),
            )
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            color: Colors.white,
            child: Autocomplete<Map<String, dynamic>>(
              displayStringForOption: (option) =>
              '${option['id_etudiant_genere']} - ${option['nom']} ${option['prenom'] ?? ''}',
              optionsBuilder: (TextEditingValue textEditingValue) async {
                if (textEditingValue.text.isEmpty) {
                  return const Iterable<Map<String, dynamic>>.empty();
                }
                final response = await _client
                    .from('etudiants')
                    .select('id, id_etudiant_genere, nom, prenom, groupe, statut, gojika_account_active, photo_url')
                    .or(
                    'nom.ilike.%${textEditingValue.text}%,prenom.ilike.%${textEditingValue.text}%,id_etudiant_genere.ilike.%${textEditingValue.text}%')
                    .limit(10);
                return response;
              },
              onSelected: (selection) => _searchStudent(selection),
              fieldViewBuilder:
                  (context, controller, focusNode, onFieldSubmitted) {
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    labelText: 'Rechercher un étudiant (par ID ou Nom)',
                    prefixIcon: Icon(Icons.search),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _selectedStudent == null
                ? Center(child: Text('Veuillez rechercher un étudiant.'))
                : _buildStudentReport(context, isAdminOrControleur),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentReport(BuildContext context, bool isAdminOrControleur) {
    final config = context.read<DataProvider>().configOptions;
    final statuts = config['Statut'] ?? ['Actif', 'Abandon', 'Accord Spécial'];

    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Informations Personnelles",
              style: Theme.of(context).textTheme.headlineSmall),
          SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey.shade300, width: 2),
                          image: _selectedStudent!['photo_url'] != null
                              ? DecorationImage(
                            image: NetworkImage(_selectedStudent!['photo_url']),
                            fit: BoxFit.cover,
                          )
                              : null,
                        ),
                        child: _selectedStudent!['photo_url'] == null
                            ? Icon(Icons.person, size: 50, color: Colors.grey)
                            : null,
                      ),
                      SizedBox(width: 24),
                      Expanded(
                        child: Wrap(
                          spacing: 24,
                          runSpacing: 16,
                          children: [
                            ReadOnlyField(
                                label: "Nom",
                                value: "${_selectedStudent!['nom']} ${_selectedStudent!['prenom'] ?? ''}",
                                icon: Icons.person),
                            ReadOnlyField(
                                label: "ID",
                                value: _selectedStudent!['id_etudiant_genere'] ?? 'N/A',
                                icon: Icons.vpn_key),
                            ReadOnlyField(
                                label: "Groupe",
                                value: _selectedStudent!['groupe'] ?? 'N/A',
                                icon: Icons.group),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Divider(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Statut Académique:",
                              style: Theme.of(context).textTheme.titleMedium),
                          if (isAdminOrControleur)
                            DropdownButton<String>(
                              value: _selectedStudent!['statut'],
                              items: statuts
                                  .map((statut) => DropdownMenuItem(
                                  value: statut, child: Text(statut)))
                                  .toList(),
                              onChanged: (newStatus) {
                                if (newStatus != null) {
                                  _updateStudentStatus(newStatus);
                                }
                              },
                            )
                          else
                            Text(_selectedStudent!['statut'] ?? 'N/A',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Compte GOJIKA:",
                              style: Theme.of(context).textTheme.titleMedium),
                          if (isAdminOrControleur)
                            Switch(
                              value: _selectedStudent!['gojika_account_active'] ?? false,
                              onChanged: _updateGojikaStatus,
                            )
                          else
                            Text(
                              (_selectedStudent!['gojika_account_active'] ?? false)
                                  ? "Activé"
                                  : "Désactivé",
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: (_selectedStudent!['gojika_account_active'] ?? false)
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                            ),
                        ],
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
          SizedBox(height: 24),
          Text("Historique Financier",
              style: Theme.of(context).textTheme.headlineSmall),
          SizedBox(height: 16),
          Card(
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: double.infinity,
              height: 400,
              child: _studentPayments.isEmpty
                  ? Center(child: Text("Aucun paiement trouvé."))
                  : DataTable2(
                columnSpacing: 12,
                horizontalMargin: 12,
                minWidth: 600,
                columns: const [
                  DataColumn2(label: Text('Date'), size: ColumnSize.M),
                  DataColumn2(label: Text('Motif'), size: ColumnSize.L),
                  DataColumn2(label: Text('Mois'), size: ColumnSize.S),
                  DataColumn2(label: Text('Nº Reçu'), size: ColumnSize.M),
                  DataColumn2(
                      label: Text('Montant'),
                      numeric: true,
                      size: ColumnSize.M),
                ],
                rows: _studentPayments.map((p) {
                  final recu = p['recus'];
                  return DataRow(cells: [
                    DataCell(Text(DateFormat('dd/MM/yy')
                        .format(DateTime.parse(recu['date_paiement'])))),
                    DataCell(Text(p['motif'] ?? 'N/A')),
                    DataCell(Text(p['mois_de'] ?? 'N/A')),
                    DataCell(Text(recu['n_recu_principal'] ?? 'N/A')),
                    DataCell(Text(
                        '${NumberFormat.decimalPattern('fr').format(p['montant'])} Ar')),
                  ]);
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}