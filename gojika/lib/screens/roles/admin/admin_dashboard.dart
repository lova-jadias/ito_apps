import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/theme.dart';
import '../../../providers/gojika_provider.dart';
import '../../auth/widgets/common_widgets.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  String _siteFilter = 'FULL';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GojikaProvider>().loadDashboard('FULL');
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GojikaProvider>();
    final kpis = provider.dashboardKpis;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Global Admin'),
        actions: [
          DropdownButton<String>(
            value: _siteFilter,
            dropdownColor: GojikaTheme.primaryBlue,
            style: const TextStyle(color: Colors.white),
            underline: Container(),
            icon: const Icon(Iconsax.filter, color: Colors.white),
            items: ['FULL', 'T', 'TO', 'BO', 'BI'].map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value == 'FULL' ? 'Tous les sites' : 'Site $value'),
              );
            }).toList(),
            onChanged: (newValue) {
              setState(() => _siteFilter = newValue!);
              provider.loadDashboard(newValue);
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: provider.isLoading || kpis == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Indicateurs de Performance (${_siteFilter})', style: GojikaTheme.titleMedium),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 4, // Largeur Desktop
              shrinkWrap: true,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.5,
              children: [
                KpiCard(title: 'Effectif Total', value: '${kpis['effectif_total']}', icon: Iconsax.people, color: Colors.blue),
                KpiCard(title: 'Moyenne Globale', value: (kpis['moyenne_generale'] as num).toStringAsFixed(2), icon: Iconsax.award, color: Colors.purple),
                KpiCard(title: 'Taux Présence', value: '${(kpis['taux_presence'] as num).toStringAsFixed(1)}%', icon: Iconsax.chart, color: Colors.green),
                KpiCard(title: 'Alertes Rouges', value: '${kpis['risque']['rouge']}', icon: Iconsax.danger, color: Colors.red),
              ],
            ),
            const SizedBox(height: 32),
            // Ajout de graphiques possible ici avec fl_chart
            Center(child: Text("Graphiques détaillés et analytiques avancés ici", style: TextStyle(color: Colors.grey))),
          ],
        ),
      ),
    );
  }
}