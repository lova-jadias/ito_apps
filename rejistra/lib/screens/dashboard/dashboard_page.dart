// rejistra/lib/screens/dashboard/dashboard_page.dart
// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rejistra/providers/auth_provider.dart';
import 'package:fl_chart/fl_chart.dart';

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
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final SupabaseClient _client = Supabase.instance.client;
  Future<DashboardStats>? _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = _fetchDashboardStats();
  }

  Future<DashboardStats> _fetchDashboardStats() async {
    try {
      // --- Effectifs ---
      // CORRECTION: La méthode .count() est appelée sur le query builder.
      // Elle retourne un objet PostgrestResponse dont on lit la propriété .count.
      final brutRes = await _client.from('etudiants').select().count();
      final abandonRes = await _client.from('etudiants').select().eq('statut', 'Abandon').count();

      final int brut = brutRes.count;
      final int abandons = abandonRes.count;
      final int net = brut - abandons;

      // --- Finances ---
      final now = DateTime.now();
      // Formatage pour être compatible avec le type TIMESTAMPTZ de Supabase
      final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();
      final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();

      // On récupère la liste des montants du jour
      final caJourRes = await _client
          .from('recus')
          .select('montant_total')
          .gte('date_paiement', todayStart)
          .lte('date_paiement', todayEnd);

      // On additionne les montants récupérés
      final double caJournalier = caJourRes.fold(0.0, (sum, item) => sum + (item['montant_total'] ?? 0.0));

      // On fait de même pour le CA global
      final caGlobalRes = await _client.from('recus').select('montant_total');
      final double caGlobal = caGlobalRes.fold(0.0, (sum, item) => sum + (item['montant_total'] ?? 0.0));

      return DashboardStats(
        effectifBrut: brut,
        abandons: abandons,
        effectifNet: net,
        caJournalier: caJournalier,
        caGlobal: caGlobal,
      );
    } catch (e) {
      print("Erreur fetchDashboardStats: $e");
      // Renvoyer une exception plus claire pour l'UI
      throw Exception("Impossible de charger les statistiques. Vérifiez la connexion et les permissions RLS.");
    }
  }


  void _refreshData() {
    setState(() {
      _statsFuture = _fetchDashboardStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final numberFormat = NumberFormat.decimalPattern('fr');

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('Dashboard'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
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
              'Bienvenue sur votre tour de contrôle.',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey.shade700),
            ),
            SizedBox(height: 24),
            FutureBuilder<DashboardStats>(
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
                final stats = snapshot.data!;
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
                        _KpiCard(title: 'CA Global', value: "${numberFormat.format(stats.caGlobal)} Ar", icon: Icons.attach_money, color: Colors.teal),
                      ],
                    ),
                    SizedBox(height: 24),
                    Text("Analyse Visuelle", style: Theme.of(context).textTheme.headlineSmall),
                    SizedBox(height: 16),
                    _buildChartsSection(),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildChartsSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isWide = constraints.maxWidth > 800;
        return isWide
            ? Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: _buildCaChartCard()),
            SizedBox(width: 16),
            Expanded(flex: 1, child: _buildSitePieChartCard("Effectifs par Site")),
          ],
        )
            : Column(
          children: [
            _buildCaChartCard(),
            SizedBox(height: 16),
            _buildSitePieChartCard("Effectifs par Site"),
          ],
        );
      },
    );
  }

  Widget _buildCaChartCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Évolution du Chiffre d'Affaires (Global)", style: Theme.of(context).textTheme.titleLarge),
            Text("Simulation de CA mensuel", style: Theme.of(context).textTheme.bodyMedium),
            SizedBox(height: 24),
            SizedBox(
              height: 300,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 100000),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 60, getTitlesWidget: (value, meta) => Text("${(value / 1000).toStringAsFixed(0)}k Ar"))),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) {
                      const months = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai'];
                      return Text(months[value.toInt()]);
                    })),
                  ),
                  barGroups: [
                    BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 450000, color: Colors.blue, width: 20, borderRadius: BorderRadius.circular(4))]),
                    BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: 320000, color: Colors.blue, width: 20, borderRadius: BorderRadius.circular(4))]),
                    BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: 600000, color: Colors.blue, width: 20, borderRadius: BorderRadius.circular(4))]),
                    BarChartGroupData(x: 3, barRods: [BarChartRodData(toY: 550000, color: Colors.blue, width: 20, borderRadius: BorderRadius.circular(4))]),
                    BarChartGroupData(x: 4, barRods: [BarChartRodData(toY: 710000, color: Colors.blue, width: 20, borderRadius: BorderRadius.circular(4))]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSitePieChartCard(String title) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            Text("Répartition des étudiants (brut)", style: Theme.of(context).textTheme.bodyMedium),
            SizedBox(height: 24),
            SizedBox(
              height: 300,
              child: PieChart(
                  PieChartData(
                      sectionsSpace: 4,
                      centerSpaceRadius: 60,
                      sections: [ // NOTE: Données en dur pour l'instant
                        PieChartSectionData(value: 40, title: 'Tana (40)', color: Colors.blue, radius: 80, titleStyle: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        PieChartSectionData(value: 25, title: 'Toamasina (25)', color: Colors.green, radius: 80, titleStyle: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        PieChartSectionData(value: 20, title: 'Mahajanga (20)', color: Colors.orange, radius: 80, titleStyle: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        PieChartSectionData(value: 15, title: 'Antsirabe (15)', color: Colors.red, radius: 80, titleStyle: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      ]
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