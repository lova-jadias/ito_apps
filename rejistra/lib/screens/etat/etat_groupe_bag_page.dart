// rejistra/lib/screens/etat/etat_groupe_bag_page.dart
// ignore_for_file: prefer_const_constructors, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rejistra/providers/auth_provider.dart';
import 'package:rejistra/providers/data_provider.dart';
import 'package:rejistra/utils/helpers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:data_table_2/data_table_2.dart';

class EtatGroupeBagPage extends StatefulWidget {
  const EtatGroupeBagPage({Key? key}) : super(key: key);

  @override
  State<EtatGroupeBagPage> createState() => _EtatGroupeBagPageState();
}

class _EtatGroupeBagPageState extends State<EtatGroupeBagPage> {
  String? _selectedSite;
  String? _selectedGroupe;
  bool _isLoading = false;
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
      // Appel de la fonction RPC
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

      // Construire les colonnes dynamiquement à partir du premier résultat
      final firstRow = result.first as Map<String, dynamic>;
      _bagColumns = firstRow.keys.map((key) {
        return DataColumn2(
          label: Text(key.replaceAll('_', ' ')),
          size: (key == 'nom' || key == 'prenom') ? ColumnSize.L : ColumnSize.S,
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
          if (_bagRows.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: ElevatedButton.icon(
                onPressed: () {
                  showSuccessSnackBar(context, "Export Excel non implémenté.");
                },
                icon: Icon(Icons.grid_on, size: 18),
                label: Text('Exporter Excel'),
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
                  minWidth: 1200,
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