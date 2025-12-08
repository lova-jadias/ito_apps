import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../config/theme.dart';
import '../../../models/models.dart';
import '../../../providers/gojika_provider.dart';
import '../../auth/widgets/common_widgets.dart';

class RPPedagogyPage extends StatefulWidget {
  const RPPedagogyPage({Key? key}) : super(key: key);

  @override
  State<RPPedagogyPage> createState() => _RPPedagogyPageState();
}

class _RPPedagogyPageState extends State<RPPedagogyPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<AnneeAcademique> _annees = [];

  // Liste statique des groupes (idéalement viendrait de config_options)
  final List<String> _groupes = ['GL1', 'GL2', 'GM1', 'DL1', 'AS1', 'IG1'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    // Dans une vraie implémentation, on chargerait via le provider
    // Ici on simule ou on utilise le service si disponible
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion Pédagogique'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Années & Semestres', icon: Icon(Iconsax.calendar_1)),
            Tab(text: 'Classes & Groupes', icon: Icon(Iconsax.teacher)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
        controller: _tabController,
        children: [
          _AnneesTab(),
          _ClassesTab(groupes: _groupes),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fonctionnalité création à venir dans Phase 3')),
          );
        },
        label: const Text('Nouveau'),
        icon: const Icon(Iconsax.add),
      ),
    );
  }
}

class _AnneesTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Utilisation de FutureBuilder pour charger les années
    return FutureBuilder<List<AnneeAcademique>>(
      future: Provider.of<GojikaProvider>(context, listen: false).service.getAnneesAcademiques(), // Accès direct au service via getter (à ajouter si besoin) ou appel direct
      // Note: Pour simplifier ici, supposons que le service a été appelé.
      // Si la méthode n'est pas exposée dans le provider, on l'appelle ainsi :
      // Mais pour la propreté, on devrait l'avoir dans le provider.
      // Utilisons un mock visuel basé sur la structure si les données sont vides pour l'instant.
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Données simulées si vide pour démonstration immédiate, sinon snapshot.data
        final annees = snapshot.data ?? [];

        if (annees.isEmpty) {
          return const EmptyState(message: 'Aucune année académique configurée');
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: annees.length,
          itemBuilder: (context, index) {
            final annee = annees[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: ExpansionTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: annee.isActive ? GojikaTheme.riskGreen.withOpacity(0.1) : Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Iconsax.calendar,
                    color: annee.isActive ? GojikaTheme.riskGreen : Colors.grey,
                  ),
                ),
                title: Text(
                  annee.libelle,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${DateFormat('dd/MM/yyyy').format(annee.dateDebut)} - ${DateFormat('dd/MM/yyyy').format(annee.dateFin)}',
                ),
                trailing: annee.isActive
                    ? const Chip(label: Text('En cours', style: TextStyle(color: Colors.white)), backgroundColor: GojikaTheme.riskGreen)
                    : null,
                children: [
                  // Liste des semestres (Simulé ici car requiert un autre fetch)
                  ListTile(
                    title: const Text('Semestre 1'),
                    leading: const Icon(Iconsax.timer_1),
                    trailing: const Icon(Iconsax.arrow_right_3, size: 16),
                    onTap: () {},
                  ),
                  ListTile(
                    title: const Text('Semestre 2'),
                    leading: const Icon(Iconsax.timer_1),
                    trailing: const Icon(Iconsax.arrow_right_3, size: 16),
                    onTap: () {},
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ClassesTab extends StatelessWidget {
  final List<String> groupes;
  const _ClassesTab({required this.groupes});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groupes.length,
      itemBuilder: (context, index) {
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: GojikaTheme.primaryBlue,
              child: Text(groupes[index].substring(0, 2), style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
            title: Text('Groupe ${groupes[index]}'),
            subtitle: const Text('Licence 1 • Gestion'), // Exemple statique
            trailing: IconButton(
              icon: const Icon(Iconsax.setting_2),
              onPressed: () {
                // Configurer matières / emploi du temps du groupe
              },
            ),
            onTap: () {
              // Voir liste étudiants
            },
          ),
        );
      },
    );
  }
}