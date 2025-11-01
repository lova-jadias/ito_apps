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
                minWidth: 800,
                columns: const [
                  DataColumn2(label: Text('Quand'), size: ColumnSize.M),
                  DataColumn2(label: Text('Qui (User)'), size: ColumnSize.L),
                  DataColumn2(label: Text('Site'), size: ColumnSize.S),
                  DataColumn2(label: Text('Action'), size: ColumnSize.M),
                  DataColumn2(label: Text('Détails'), size: ColumnSize.L),
                ],
                rows: logs.map((log) {
                  return DataRow(cells: [
                    DataCell(Text(DateFormat('dd/MM/yy HH:mm:ss')
                        .format(DateTime.parse(log['timestamp']).toLocal()))),
                    DataCell(Text(log['user_name'] ?? 'N/A')),
                    DataCell(Text(log['site'] ?? 'N/A')),
                    DataCell(Text(log['action'] ?? 'N/A')),
                    DataCell(Text(log['details']?.toString() ?? 'N/A',
                        maxLines: 2, overflow: TextOverflow.ellipsis)),
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