// rejistra/lib/screens/etat/etat_groupe_bag_page.dart
// ignore_for_file: prefer_const_constructors, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rejistra/providers/auth_provider.dart';
import 'package:rejistra/providers/data_provider.dart';
import 'package:rejistra/utils/helpers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:data_table_2/data_table_2.dart';

// --- AJOUT POUR EXPORT ---
import 'package:rejistra/services/export_service.dart';
// --- FIN AJOUT ---

class EtatGroupeBagPage extends StatefulWidget {
  const EtatGroupeBagPage({Key? key}) : super(key: key);

  @override
  State<EtatGroupeBagPage> createState() => _EtatGroupeBagPageState();
}

class _EtatGroupeBagPageState extends State<EtatGroupeBagPage> {
  String? _selectedSite;
  String? _selectedGroupe;
  bool _isLoading = false;

  // Stocker les résultats pour l'export (Variables de classe)
  List<DataColumn> _bagColumns = [];
  List<DataRow> _bagRows = [];

  Future<void> _generateReport() async {
    if (_selectedSite == null || _selectedGroupe == null) {
      showErrorSnackBar(context, "Veuillez sélectionner un Site ET un Groupe.");
      return;
    }

    setState(() => _isLoading = true);
    _bagColumns = [];
    _bagRows = [];

    try {
      // La logique RPC est INCHANGÉE
      final List<dynamic> result = await Supabase.instance.client.rpc(
        'get_bag_report',
        params: {
          'site_filter': _selectedSite,
          'groupe_filter': _selectedGroupe,
        },
      );

      if (result.isEmpty) {
        showSuccessSnackBar(context, "Aucun étudiant trouvé pour cette sélection.");
        setState(() => _isLoading = false);
        return;
      }
      // --- CORRECTION DÉBUT ---

      // 1. TRIER par "id_etudiant_genere" (la colonne exacte renvoyée par votre RPC)
      result.sort((a, b) {
        final idA = a['id_etudiant_genere']?.toString() ?? '';
        final idB = b['id_etudiant_genere']?.toString() ?? '';

        // Tri alphabétique croissant (ex: 1-25-T avant 10-25-T)
        return idA.compareTo(idB);
      });

      // 2. RÉ-NUMÉROTER la colonne "row_num"
      for (int i = 0; i < result.length; i++) {
        // 'row_num' est le nom de la colonne défini dans votre RPC
        result[i]['row_num'] = i + 1;
      }

      // --- CORRECTION FIN ---

      // Construire les colonnes avec largeurs adaptées
      final firstRow = result.first as Map<String, dynamic>;
      _bagColumns = firstRow.keys.map((key) {
        // Déterminer la taille selon le type de colonne
        ColumnSize columnSize;
        if (key == 'id' || key.toLowerCase().contains('etudiant')) {

          columnSize = ColumnSize.M;
        } else if (key == 'nom' || key == 'prenom') {
          // Nom et Prénom : largeur large
          columnSize = ColumnSize.L;
        } else {
          // Autres colonnes : petite largeur
          columnSize = ColumnSize.S;
        }

        return DataColumn2(
          label: Text(
            key.replaceAll('_', ' '),
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          size: columnSize,
          numeric: false,
        );
      }).toList();

      // Construire les lignes
      _bagRows = result.map((row) {
        return DataRow(
          cells: row.entries.map<DataCell>((cell) {
            final value = cell.value?.toString() ?? '-';
            final isStatus = cell.key == 'statut';
            final isRecu = value != '-' && !isStatus && cell.key != 'id' && cell.key != 'nom' && cell.key != 'prenom';

            Color? color = isStatus
                ? (value == 'Abandon' ? Colors.red : (value == 'Accord Spécial' ? Colors.orange : Colors.green))
                : (isRecu ? Colors.blue.shade800 : null);

            return DataCell(
                Text(
                  value,
                  style: TextStyle(color: color, fontWeight: isStatus ? FontWeight.bold : null),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  softWrap: false,
                )
            );
          }).toList(),
        );
      }).toList();

    } catch (e) {
      showErrorSnackBar(context, "Erreur RPC: $e");
    }

    setState(() => _isLoading = false);
  }

  // --- ACTIONS D'EXPORT (Point 4 & 5) ---
  void _exportExcel() {
    if (_bagRows.isEmpty || _selectedGroupe == null) return;
    ExportService.exportGroupeToExcel(
      columns: _bagColumns,
      rows: _bagRows,
      groupe: _selectedGroupe!,
    );
    showSuccessSnackBar(context, "Génération Excel en cours...");
  }

  void _exportPdf() {
    if (_bagRows.isEmpty || _selectedGroupe == null || _selectedSite == null) return;
    ExportService.exportGroupeToPdf(
      columns: _bagColumns,
      rows: _bagRows,
      site: _selectedSite!,
      groupe: _selectedGroupe!,
    );
  }
  // --- FIN ACTIONS D'EXPORT ---

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<DataProvider>().configOptions;
    final user = context.watch<AuthProvider>().currentUser;
    final isFullAccess = user?.role == 'admin' || user?.role == 'controleur' || user?.site == 'FULL';

    if (!isFullAccess && _selectedSite == null) {
      _selectedSite = user?.site;
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('État par Groupe (BAG)'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          // --- BOUTONS D'EXPORT ---
          if (_bagRows.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
              child: ElevatedButton.icon(
                onPressed: _exportExcel,
                icon: Icon(Icons.grid_on, size: 18),
                label: Text('Exporter Excel'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          if (_bagRows.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 20.0, left: 4.0, top: 8.0, bottom: 8.0),
              child: ElevatedButton.icon(
                onPressed: _exportPdf,
                icon: Icon(Icons.picture_as_pdf, size: 18),
                label: Text('Exporter PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(config, isFullAccess),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _bagRows.isEmpty
                ? Center(child: Text('Veuillez générer un rapport.'))
                : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: DataTable2(
                  columnSpacing: 12,
                  horizontalMargin: 12,
                  minWidth: 2500,
                  dataRowHeight: 40,
                  headingRowHeight: 50,
                  showBottomBorder: true,
                  columns: _bagColumns,
                  rows: _bagRows,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(Map<String, List<String>> config, bool isFullAccess) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: Colors.white,
      child: Wrap(
        spacing: 16.0,
        runSpacing: 16.0,
        children: [
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<String>(
              decoration: InputDecoration(labelText: 'Site *'),
              value: _selectedSite,
              items: (config['Site'] ?? [])
                  .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                  .toList(),
              onChanged: isFullAccess ? (val) => setState(() => _selectedSite = val) : null,
            ),
          ),
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<String>(
              decoration: InputDecoration(labelText: 'Groupe *'),
              value: _selectedGroupe,
              items: (config['Groupe'] ?? [])
                  .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedGroupe = val),
            ),
          ),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _generateReport,
            icon: Icon(Icons.analytics),
            label: Text('Générer'),
          ),
        ],
      ),
    );
  }
}