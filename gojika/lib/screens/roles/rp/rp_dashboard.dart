import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/theme.dart';
import '../../../providers/gojika_provider.dart';
import '../../auth/widgets/common_widgets.dart';

class RPDashboard extends StatelessWidget {
  final String site;
  const RPDashboard({Key? key, required this.site}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<GojikaProvider>(
      builder: (context, provider, _) {
        final kpis = provider.dashboardKpis;
        if (kpis == null) return const Center(child: CircularProgressIndicator());

        final risque = kpis['risque'] as Map<String, dynamic>;

        return Scaffold(
          appBar: AppBar(
            title: Text('Tableau de Bord - Site $site'),
            actions: [
              IconButton(
                icon: const Icon(Iconsax.refresh),
                onPressed: () => provider.loadDashboard(site),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section Alertes (EWS)
                Text('Système d\'Alerte Précoce', style: GojikaTheme.titleMedium),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _RiskCard(label: 'Critique', count: risque['rouge'], color: GojikaTheme.riskRed)),
                    const SizedBox(width: 12),
                    Expanded(child: _RiskCard(label: 'Élevé', count: risque['orange'], color: GojikaTheme.riskOrange)),
                    const SizedBox(width: 12),
                    Expanded(child: _RiskCard(label: 'Vigilance', count: risque['jaune'], color: GojikaTheme.riskYellow)),
                  ],
                ),

                const SizedBox(height: 24),

                // KPIs Globaux
                Text('Performance Globale', style: GojikaTheme.titleMedium),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 4, // Pour tablette on pourrait mettre 4
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.5,
                  children: [
                    KpiCard(
                      title: 'Effectif Total',
                      value: kpis['effectif_total'].toString(),
                      icon: Iconsax.people,
                      color: GojikaTheme.primaryBlue,
                    ),
                    KpiCard(
                      title: 'Taux de Présence',
                      value: '${(kpis['taux_presence'] as num).toStringAsFixed(1)}%',
                      icon: Iconsax.chart_success,
                      color: GojikaTheme.riskGreen,
                    ),
                    KpiCard(
                      title: 'Moyenne Site',
                      value: (kpis['moyenne_generale'] as num).toStringAsFixed(2),
                      icon: Iconsax.award,
                      color: GojikaTheme.accentGold,
                    ),
                    KpiCard(
                      title: 'Étudiants Sains',
                      value: risque['vert'].toString(),
                      icon: Iconsax.shield_tick,
                      color: GojikaTheme.riskGreen,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Graphique Fréquentation
                Text('Fréquentation Journalière (30j)', style: GojikaTheme.titleMedium),
                const SizedBox(height: 16),
                SizedBox(
                  height: 250,
                  child: provider.frequentationJournaliere.isEmpty
                      ? const Center(child: Text("Pas assez de données"))
                      : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: 100,
                      barTouchData: BarTouchData(enabled: true),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false), // Trop dense pour afficher les dates
                        ),
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      barGroups: provider.frequentationJournaliere.asMap().entries.map((entry) {
                        final data = entry.value;
                        final tx = (data['taux_presence'] as num).toDouble();
                        return BarChartGroupData(
                          x: entry.key,
                          barRods: [
                            BarChartRodData(
                              toY: tx,
                              color: tx > 80 ? GojikaTheme.primaryBlue : GojikaTheme.riskOrange,
                              width: 12,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RiskCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _RiskCard({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(count.toString(), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}