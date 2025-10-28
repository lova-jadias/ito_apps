import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rejistra/providers/auth_provider.dart';


class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

// Classe simple pour contenir les stats (Source: 221)
class DashboardStats {
  final int effectifBrut;
  final int abandons;
  final int effectifNet;
  // ... (champs financiers pour Bloc 1.2)

  DashboardStats({
    this.effectifBrut = 0,
    this.abandons = 0,
    this.effectifNet = 0,
  });
}

class _DashboardPageState extends State<DashboardPage> {
  final SupabaseClient _client = Supabase.instance.client;
  Future<DashboardStats>? _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = _fetchDashboardStats();
  }

  // Récupère les stats depuis Supabase (Source: 1240)
  Future<DashboardStats> _fetchDashboardStats() async {
    try {
      // NOTE: Nous utilisons .count() qui retourne un objet PostgrestResponse.
      // Le nombre se trouve dans la propriété .count de cet objet.

      // 1. Compte total (CORRIGÉ)
      final brutResponse = await _client
          .from('etudiants')
          .select('id') // 'id' est un exemple, n'importe quel champ suffit
          .count(); // Appel de la fonction count()

      // 2. Compte des abandons (CORRIGÉ)
      final abandonResponse = await _client
          .from('etudiants')
          .select('id')
          .eq('statut', 'Abandon') // <-- CORRECTION: .match remplacé par .eq
          .count(); // Appel de la fonction count()

      final int brut = brutResponse.count; // <-- CORRECTION
      final int abandons = abandonResponse.count; // <-- CORRECTION
      final int net = brut - abandons;

      return DashboardStats(
        effectifBrut: brut,
        abandons: abandons,
        effectifNet: net,
      );
    } catch (e) {
      // Gérer l'erreur
      print("Erreur fetchDashboardStats: $e");
      throw Exception("Impossible de charger les statistiques");
    }
  }

  // Fonction pour rafraîchir les données
  void _refreshData() {
    setState(() {
      _statsFuture = _fetchDashboardStats();
    });
  }


  @override
  Widget build(BuildContext context) {
    // CORRECTION: Nous utilisons 'watch' ici pour que l'UI se mette à jour
    // si l'utilisateur change (ex: après connexion)
    final auth = context.watch<AuthProvider>();

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
              // <-- CORRECTION: Utilisation de .nomComplet
              'Bonjour, ${auth.currentUser?.nomComplet ?? "Utilisateur"}',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              'Bienvenue sur votre tour de contrôle.',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.grey.shade700),
            ),
            SizedBox(height: 24),

            // Section des KPIs
            Text(
              "Indicateurs Clés (KPIs) - Effectifs",
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 16),

            // Le FutureBuilder gère l'état (chargement, erreur, succès)
            FutureBuilder<DashboardStats>(
              future: _statsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                        "Erreur de chargement: ${snapshot.error}",
                        style: TextStyle(color: Colors.red)),
                  );
                }
                if (!snapshot.hasData) {
                  return Center(child: Text("Aucune donnée."));
                }

                // Les données sont prêtes
                final stats = snapshot.data!;

                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _KpiCard(
                      title: 'Effectif Brut',
                      value: stats.effectifBrut.toString(),
                      icon: Icons.groups,
                      color: Colors.blue,
                    ),
                    _KpiCard(
                      title: 'Abandons',
                      value: stats.abandons.toString(),
                      icon: Icons.person_off,
                      color: Colors.orange,
                    ),
                    _KpiCard(
                      title: 'Effectif Net',
                      value: stats.effectifNet.toString(),
                      icon: Icons.check_circle,
                      color: Colors.green,
                    ),
                  ],
                );
              },
            ),
            // ... (Sections futures pour les graphiques et les finances)
          ],
        ),
      ),
    );
  }
}

// Widget KPI (Source: 276-284)
// (Copiez-collez ce widget au bas de votre fichier dashboard_page.dart)
class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiCard({
    Key? key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey.shade800,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}