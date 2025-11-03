// rejistra/lib/screens/admin/audit_log_page.dart
// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:data_table_2/data_table_2.dart';

class AuditLogPage extends StatefulWidget {
  const AuditLogPage({Key? key}) : super(key: key);

  @override
  State<AuditLogPage> createState() => _AuditLogPageState();
}

class _AuditLogPageState extends State<AuditLogPage> {
  final _client = Supabase.instance.client;
  Stream<List<Map<String, dynamic>>>? _auditStream;

  @override
  void initState() {
    super.initState();
    _auditStream = _client
        .from('audit_log')
        .stream(primaryKey: ['id'])
        .order('timestamp', ascending: false)
        .limit(100)
        .map((data) => data);
  }

  String _formatDetails(Map<String, dynamic>? details) {
    if (details == null) return 'N/A';

    final String table = details['table'] ?? 'N/A';
    final Map<String, dynamic>? oldData = details['old_data'];
    final Map<String, dynamic>? newData = details['new_data'];

    if (oldData != null && newData != null) {
      return 'Table: $table | Modification de données';
    } else if (newData != null) {
      return 'Table: $table | Création de données';
    } else if (oldData != null) {
      return 'Table: $table | Suppression de données';
    }

    return 'Table: $table | Action inconnue';
  }

  void _showDetailsDialog(Map<String, dynamic> log) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Détails de l\'Audit'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Action: ${log['action'] ?? 'N/A'}',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('Utilisateur: ${log['user_name'] ?? 'N/A'}'),
              Text('Site: ${log['site'] ?? 'N/A'}'),
              Text('Timestamp: ${DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.parse(log['timestamp']).toLocal())}'),
              SizedBox(height: 16),
              Text('Détails Complets:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SelectableText(
                  log['details']?.toString() ?? 'Aucun détail',
                  style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Fermer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Administration: Audit Log'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _auditStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
                child: Text("Erreur: ${snapshot.error}",
                    style: TextStyle(color: Colors.red)));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text("Aucun log d'audit trouvé."));
          }

          final logs = snapshot.data!;

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: DataTable2(
                columnSpacing: 12,
                horizontalMargin: 12,
                minWidth: 1000,
                columns: const [
                  DataColumn2(label: Text('Quand'), size: ColumnSize.M),
                  DataColumn2(label: Text('Qui (User)'), size: ColumnSize.L),
                  DataColumn2(label: Text('Site'), size: ColumnSize.S),
                  DataColumn2(label: Text('Action'), size: ColumnSize.M),
                  DataColumn2(label: Text('Résumé'), size: ColumnSize.L),
                  DataColumn2(
                      label: Text('Détails'), size: ColumnSize.S),
                ],
                rows: logs.map((log) {
                  return DataRow(cells: [
                    DataCell(Text(DateFormat('dd/MM/yy HH:mm:ss').format(
                        DateTime.parse(log['timestamp']).toLocal()))),
                    DataCell(Text(log['user_name'] ?? 'N/A')),
                    DataCell(Text(log['site'] ?? 'N/A')),
                    DataCell(Text(log['action'] ?? 'N/A')),
                    DataCell(Text(
                      _formatDetails(log['details']),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    )),
                    DataCell(
                      IconButton(
                        icon: Icon(Icons.info_outline, color: Colors.blue),
                        onPressed: () => _showDetailsDialog(log),
                        tooltip: 'Voir détails complets',
                      ),
                    ),
                  ]);
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }
}