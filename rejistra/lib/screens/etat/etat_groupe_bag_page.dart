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
  Map<String, int> _groupStats = {};

  Future<void> _generateReport() async {
    if (_selectedSite == null || _selectedGroupe == null) {
      showErrorSnackBar(
          context, "Veuillez sélectionner un Site ET un Groupe.");
      return;
    }

    setState(() => _isLoading = true);
    _bagColumns = [];
    _bagRows = [];
    _groupStats = {};

    try {
      final List<dynamic> result = await Supabase.instance.client.rpc(
        'get_bag_report',
        params: {
          'site_filter': _selectedSite,
          'groupe_filter': _selectedGroupe,
        },
      );

      if (result.isEmpty) {
        showSuccessSnackBar(
            context, "Aucun étudiant trouvé pour cette sélection.");
        setState(() => _isLoading = false);
        return;
      }

      int effectifBrut = result.length;
      int actifs = 0;
      int abandons = 0;
      int accords = 0;

      for (var row in result) {
        final statut = row['statut'] as String?;
        if (statut == 'Actif') actifs++;
        if (statut == 'Abandon') abandons++;
        if (statut == 'Accord Spécial') accords++;
      }

      _groupStats = {
        'effectif_brut': effectifBrut,
        'actifs': actifs,
        'abandons': abandons,
        'accords': accords,
      };

      final firstRow = result.first as Map<String, dynamic>;
      _bagColumns = firstRow.keys.map((key) {
        return DataColumn2(
          label: Text(key == 'row_num' ? 'Nº' : key.replaceAll('_', ' '),
              style: TextStyle(fontWeight: FontWeight.bold)),
          size: (key == 'nom' || key == 'prenom')
              ? ColumnSize.L
              : (key == 'row_num'
              ? ColumnSize.S
              : ColumnSize.M),
          numeric: key == 'row_num',
        );
      }).toList();

      _bagRows = result.map((row) {
        return DataRow(
          cells: row.entries.map<DataCell>((cell) {
            final value = cell.value?.toString() ?? '-';
            final isStatus = cell.key == 'statut';
            final isRecu = value != '-' &&
                !isStatus &&
                cell.key != 'id' &&
                cell.key != 'row_num' &&
                cell.key != 'id_etudiant_genere' &&
                cell.key != 'nom' &&
                cell.key != 'prenom';

            Color? color = isStatus
                ? (value == 'Abandon'
                ? Colors.red
                : (value == 'Accord Spécial'
                ? Colors.orange
                : Colors.green))
                : (isRecu ? Colors.blue.shade800 : null);

            return DataCell(
              Text(
                value,
                style: TextStyle(
                    color: color,
                    fontWeight: isStatus ? FontWeight.bold : null),
              ),
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
    final isFullAccess = user?.role == 'admin' ||
        user?.role == 'controleur' ||
        user?.site == 'FULL';

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
          if (_groupStats.isNotEmpty) _buildStatsBar(),
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
                  minWidth: 1400,
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
                  .map((item) =>
                  DropdownMenuItem(value: item, child: Text(item)))
                  .toList(),
              onChanged: isFullAccess
                  ? (val) => setState(() => _selectedSite = val)
                  : null,
            ),
          ),
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<String>(
              decoration: InputDecoration(labelText: 'Groupe *'),
              value: _selectedGroupe,
              items: (config['Groupe'] ?? [])
                  .map((item) =>
                  DropdownMenuItem(value: item, child: Text(item)))
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

  Widget _buildStatsBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border(
          top: BorderSide(color: Colors.blue.shade200),
          bottom: BorderSide(color: Colors.blue.shade200),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatChip(
              label: 'Site',
              value: _selectedSite ?? 'N/A',
              color: Colors.blue),
          _StatChip(
              label: 'Groupe',
              value: _selectedGroupe ?? 'N/A',
              color: Colors.purple),
          _StatChip(
              label: 'Effectif Brut',
              value: '${_groupStats['effectif_brut']}',
              color: Colors.teal),
          _StatChip(
              label: 'Actifs',
              value: '${_groupStats['actifs']}',
              color: Colors.green),
          _StatChip(
              label: 'Accord Spécial',
              value: '${_groupStats['accords']}',
              color: Colors.orange),
          _StatChip(
              label: 'Abandons',
              value: '${_groupStats['abandons']}',
              color: Colors.red),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        SizedBox(height: 4),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color, width: 2),
          ),
          child: Text(
            value,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
        ),
      ],
    );
  }
}