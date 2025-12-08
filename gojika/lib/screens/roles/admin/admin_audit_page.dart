import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../providers/gojika_provider.dart';



class AdminAuditPage extends StatefulWidget {
  const AdminAuditPage({Key? key}) : super(key: key);

  @override
  State<AdminAuditPage> createState() => _AdminAuditPageState();
}

class _AdminAuditPageState extends State<AdminAuditPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GojikaProvider>().loadAuditLogs();
    });
  }

  @override
  Widget build(BuildContext context) {
    final logs = context.watch<GojikaProvider>().auditLogs;

    return Scaffold(
      appBar: AppBar(title: const Text('Journal d\'Audit')),
      body: ListView.separated(
        itemCount: logs.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final log = logs[index];
          final details = log['details'] ?? {};
          final date = DateTime.parse(log['timestamp']);

          return ListTile(
            title: Text('${log['action']} sur ${details['table'] ?? '?'}'),
            subtitle: Text('Par ${log['user_name']} (${log['site']}) • ${DateFormat('dd/MM HH:mm').format(date)}'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () {
              // Voir détails JSON brute
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Détails'),
                  content: SingleChildScrollView(child: Text(details.toString())),
                  actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer'))],
                ),
              );
            },
          );
        },
      ),
    );
  }
}