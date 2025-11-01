// rejistra/lib/screens/dashboard/dashboard_page.dart
// ignore_for_file: prefer_const_constructors, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rejistra/providers/auth_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:rejistra/providers/data_provider.dart';
import 'package:rejistra/utils/helpers.dart';

// Classe pour stocker les données du dashboard
class DashboardData {
  final DashboardStats kpis;
  final DashboardCharts charts;
  DashboardData({required this.kpis, required this.charts});
}

// Classe pour les KPIs (venant de la RPC)
class DashboardStats {
  final int effectifBrut;
  final int abandons;
  final int effectifNet;
  final double caJournalier;
  final double caGlobal;

  DashboardStats({
    this.effectifBrut = 0,
    this.abandons = 0,
    this.effectifNet = 0,
    this.caJournalier = 0,
    this.caGlobal = 0,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      effectifBrut: json['effectifBrut'] ?? 0,
      abandons: json['abandons'] ?? 0,
      effectifNet: json['effectifNet'] ?? 0,
      caJournalier: (json['caJournalier'] as num?)?.toDouble() ?? 0.0,
      caGlobal: (json['caGlobal'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

// Classe pour les données des graphiques
class DashboardCharts {
  // Clé = nom du site/groupe, Valeur = count
  final Map<String, dynamic> effectifs;
  // Clé = 'YYYY-MM', Valeur = total
  final Map<String, dynamic> caMensuel;

  DashboardCharts({this.effectifs = const {}, this.caMensuel = const {}});

  factory DashboardCharts.fromJson(Map<String, dynamic> json) {
    return DashboardCharts(
      effectifs: json['effectifs'] ?? {},
      caMensuel: json['caMensuel'] ?? {},
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final SupabaseClient _client = Supabase.instance.client;
  Future<DashboardData>? _statsFuture;

  String? _selectedSite; // null = 'FULL'

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialiser le filtre basé sur le rôle de l'utilisateur
    if (_statsFuture == null) {
      final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
      if (user != null && user.site != 'FULL') {
        _selectedSite = user.site;
      }
      _refreshData();
    }
  }

  Future<DashboardData> _fetchDashboardData() async {
    try {
      // 1. Appeler la RPC pour les KPIs
      final kpiRes = await _client.rpc(
        'get_dashboard_kpis',
        params: {'site_filter': _selectedSite},
      );
      final kpis = DashboardStats.fromJson(kpiRes);

      // 2. Appeler la RPC pour les graphiques
      final chartRes = await _client.rpc(
        'get_dashboard_charts',
        params: {'site_filter': _selectedSite},
      );
      final charts = DashboardCharts.fromJson(chartRes);

      return DashboardData(kpis: kpis, charts: charts);
    } catch (e) {
      if(mounted) {
        showErrorSnackBar(context, "Erreur RPC: $e");
      }
      throw Exception("Impossible de charger les données du dashboard.");
    }
  }

  void _refreshData() {
    setState(() {
      _statsFuture = _fetchDashboardData();
    });
  }

  void _onFilterChanged(String? newSite) {
    setState(() {
      _selectedSite = (newSite == "FULL") ? null : newSite;
      _refreshData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final numberFormat = NumberFormat.decimalPattern('fr');
    final bool canFilter = auth.currentUser?.site == 'FULL';

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('Dashboard'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Affiche le filtre de site
          if (canFilter) _buildFilterBar(context),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: "Rafraîchir",
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bonjour, ${auth.currentUser?.nomComplet ?? "Utilisateur"}',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              _selectedSite == null
                  ? 'Vue d\'ensemble de tous les sites.'
                  : 'Vue d\'ensemble du site: $_selectedSite',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey.shade700),
            ),
            SizedBox(height: 24),
            FutureBuilder<DashboardData>(
              future: _statsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text("Erreur de chargement: ${snapshot.error}", style: TextStyle(color: Colors.red)));
                }
                if (!snapshot.hasData) {
                  return Center(child: Text("Aucune donnée."));
                }

                final stats = snapshot.data!.kpis;
                final charts = snapshot.data!.charts;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Indicateurs Clés (KPIs) - Effectifs", style: Theme.of(context).textTheme.headlineSmall),
                    SizedBox(height: 16),
                    Wrap(
                      spacing: 16, runSpacing: 16,
                      children: [
                        _KpiCard(title: 'Effectif Brut', value: stats.effectifBrut.toString(), icon: Icons.groups, color: Colors.blue),
                        _KpiCard(title: 'Abandons', value: stats.abandons.toString(), icon: Icons.person_off, color: Colors.orange),
                        _KpiCard(title: 'Effectif Net', value: stats.effectifNet.toString(), icon: Icons.check_circle, color: Colors.green),
                      ],
                    ),
                    SizedBox(height: 24),
                    Text("Indicateurs Clés (KPIs) - Finances", style: Theme.of(context).textTheme.headlineSmall),
                    SizedBox(height: 16),
                    Wrap(
                      spacing: 16, runSpacing: 16,
                      children: [
                        _KpiCard(title: 'CA Journalier', value: "${numberFormat.format(stats.caJournalier)} Ar", icon: Icons.today, color: Colors.purple),
                        _KpiCard(title: 'CA Global (Filtré)', value: "${numberFormat.format(stats.caGlobal)} Ar", icon: Icons.attach_money, color: Colors.teal),
                      ],
                    ),
                    SizedBox(height: 24),
                    Text("Analyse Visuelle", style: Theme.of(context).textTheme.headlineSmall),
                    SizedBox(height: 16),
                    _buildChartsSection(charts),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Filtre de site (pour utilisateurs FULL)
  Widget _buildFilterBar(BuildContext context) {
    final config = context.watch<DataProvider>().configOptions;
    final sites = config['Site'] ?? [];

    // Ajoute l'option "FULL" si elle n'existe pas
    if (!sites.contains('FULL')) {
      sites.insert(0, 'FULL');
    }

    return Padding(
      padding: const EdgeInsets.only(right: 16.0),
      child: DropdownButton<String>(
        value: _selectedSite ?? "FULL",
        underline: SizedBox.shrink(),
        items: sites.map((site) => DropdownMenuItem(
          value: site,
          child: Text(site == 'FULL' ? "Tous les sites" : "Site: $site"),
        )).toList(),
        onChanged: _onFilterChanged,
      ),
    );
  }

  Widget _buildChartsSection(DashboardCharts charts) {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isWide = constraints.maxWidth > 800;
        return isWide
            ? Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: _buildCaChartCard(charts.caMensuel)),
            SizedBox(width: 16),
            Expanded(flex: 1, child: _buildPieChartCard(charts.effectifs)),
          ],
        )
            : Column(
          children: [
            _buildCaChartCard(charts.caMensuel),
            SizedBox(height: 16),
            _buildPieChartCard(charts.effectifs),
          ],
        );
      },
    );
  }

  // Graphique CA (dynamique)
  Widget _buildCaChartCard(Map<String, dynamic> caMensuel) {
    final numberFormat = NumberFormat.compact(locale: 'fr');
    final List<BarChartGroupData> barGroups = [];
    final List<String> months = caMensuel.keys.toList();

    for (int i = 0; i < months.length; i++) {
      barGroups.add(
        BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                  toY: (caMensuel[months[i]] as num).toDouble(),
                  color: Colors.blue,
                  width: 20,
                  borderRadius: BorderRadius.circular(4)
              )
            ]
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Évolution du Chiffre d'Affaires", style: Theme.of(context).textTheme.titleLarge),
            Text("12 derniers mois", style: Theme.of(context).textTheme.bodyMedium),
            SizedBox(height: 24),
            SizedBox(
              height: 300,
              child: caMensuel.isEmpty
                  ? Center(child: Text("Aucune donnée de CA."))
                  : BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 50000),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 60,
                        getTitlesWidget: (value, meta) => Text(numberFormat.format(value))
                    )),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < months.length) {
                            // Format 'YYYY-MM' en 'MM/YY'
                            final parts = months[index].split('-');
                            return Text("${parts[1]}/${parts[0].substring(2)}");
                          }
                          return Text("");
                        }
                    )),
                  ),
                  barGroups: barGroups,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Graphique Camembert (dynamique)
  Widget _buildPieChartCard(Map<String, dynamic> effectifs) {
    final List<Color> colors = [Colors.blue, Colors.green, Colors.orange, Colors.red, Colors.purple, Colors.teal];
    int colorIndex = 0;

    final sections = effectifs.entries.map((entry) {
      final color = colors[colorIndex % colors.length];
      colorIndex++;
      return PieChartSectionData(
          value: (entry.value as num).toDouble(),
          title: '${entry.key}\n(${(entry.value as num)})',
          color: color,
          radius: 80,
          titleStyle: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12)
      );
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                _selectedSite == null ? "Effectifs par Site" : "Effectifs par Groupe",
                style: Theme.of(context).textTheme.titleLarge
            ),
            Text("Répartition des étudiants (brut)", style: Theme.of(context).textTheme.bodyMedium),
            SizedBox(height: 24),
            SizedBox(
              height: 300,
              child: effectifs.isEmpty
                  ? Center(child: Text("Aucune donnée d'effectif."))
                  : PieChart(
                  PieChartData(
                      sectionsSpace: 4,
                      centerSpaceRadius: 60,
                      sections: sections
                  )
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _KpiCard({Key? key, required this.title, required this.value, required this.icon, required this.color}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey.shade800)),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 24),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
