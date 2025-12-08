// gojika/lib/screens/roles/student/student_notes_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/theme.dart';
import '../../../providers/gojika_provider.dart';
import '../../../models/models.dart';
import '../../auth/widgets/common_widgets.dart';

class StudentNotesPage extends StatefulWidget {
  final Map<String, dynamic> etudiantData;

  const StudentNotesPage({Key? key, required this.etudiantData}) : super(key: key);

  @override
  State<StudentNotesPage> createState() => _StudentNotesPageState();
}

class _StudentNotesPageState extends State<StudentNotesPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int? _selectedSemestre;
  int? _selectedCategorie;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final provider = context.read<GojikaProvider>();
    await provider.loadNotesEtudiant(
      widget.etudiantData['id'],
      semestreId: _selectedSemestre,
      categorieId: _selectedCategorie,
    );
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
        title: const Text('Mes Notes'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Vue d\'ensemble', icon: Icon(Iconsax.chart)),
            Tab(text: 'Par matière', icon: Icon(Iconsax.book)),
            Tab(text: 'Statistiques', icon: Icon(Iconsax.activity)),
          ],
        ),
      ),
      body: Consumer<GojikaProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.notes.isEmpty) {
            return const EmptyState(
              message: 'Aucune note disponible',
              icon: Iconsax.clipboard_text,
            );
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _VueEnsemble(
                notes: provider.notes,
                moyenneGenerale: provider.moyenneEtudiant ?? 0,
              ),
              _ParMatiere(notes: provider.notes),
              _Statistiques(notes: provider.notes),
            ],
          );
        },
      ),
    );
  }
}

// ==================== VUE D'ENSEMBLE ====================
class _VueEnsemble extends StatelessWidget {
  final List<Note> notes;
  final double moyenneGenerale;

  const _VueEnsemble({required this.notes, required this.moyenneGenerale});

  @override
  Widget build(BuildContext context) {
    // Calculer les statistiques
    final meilleureNote = notes.isNotEmpty
        ? notes.map((n) => n.note).reduce((a, b) => a > b ? a : b)
        : 0.0;
    final pireNote = notes.isNotEmpty
        ? notes.map((n) => n.note).reduce((a, b) => a < b ? a : b)
        : 0.0;
    final nbNotes = notes.length;
    final notesValidees = notes.where((n) => n.approuveParRp).length;

    return RefreshIndicator(
      onRefresh: () async {
        // TODO: Refresh notes
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Carte moyenne générale
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    moyenneGenerale >= 10 ? GojikaTheme.riskGreen : GojikaTheme.riskRed,
                    (moyenneGenerale >= 10 ? GojikaTheme.riskGreen : GojikaTheme.riskRed)
                        .withOpacity(0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: (moyenneGenerale >= 10 ? GojikaTheme.riskGreen : GojikaTheme.riskRed)
                        .withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'Moyenne Générale',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    moyenneGenerale.toStringAsFixed(2),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 56,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '/ 20',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // KPIs
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.3,
              children: [
                KpiCard(
                  title: 'Meilleure Note',
                  value: meilleureNote.toStringAsFixed(1),
                  icon: Iconsax.medal_star,
                  color: GojikaTheme.accentGold,
                ),
                KpiCard(
                  title: 'Note la plus basse',
                  value: pireNote.toStringAsFixed(1),
                  icon: Iconsax.chart_fail,
                  color: GojikaTheme.riskOrange,
                ),
                KpiCard(
                  title: 'Nombre de notes',
                  value: '$nbNotes',
                  icon: Iconsax.clipboard_text,
                  color: GojikaTheme.primaryBlue,
                ),
                KpiCard(
                  title: 'Notes validées',
                  value: '$notesValidees',
                  icon: Iconsax.tick_circle,
                  color: GojikaTheme.riskGreen,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Notes récentes
            Text('Notes Récentes', style: GojikaTheme.titleMedium),
            const SizedBox(height: 12),
            ...notes.take(5).map((note) => _NoteCard(note: note)).toList(),
          ],
        ),
      ),
    );
  }
}

// ==================== PAR MATIÈRE ====================
class _ParMatiere extends StatelessWidget {
  final List<Note> notes;

  const _ParMatiere({required this.notes});

  @override
  Widget build(BuildContext context) {
    // Grouper par matière
    final notesParMatiere = <int, List<Note>>{};
    for (var note in notes) {
      notesParMatiere.putIfAbsent(note.matiereId, () => []).add(note);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: notesParMatiere.length,
      itemBuilder: (context, index) {
        final matiereId = notesParMatiere.keys.elementAt(index);
        final notesMatiere = notesParMatiere[matiereId]!;

        // Calculer la moyenne de la matière
        final moyenne = notesMatiere.map((n) => n.note * n.coefficient).reduce((a, b) => a + b) /
            notesMatiere.map((n) => n.coefficient).reduce((a, b) => a + b);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: GojikaTheme.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Iconsax.book, color: GojikaTheme.primaryBlue),
            ),
            title: FutureBuilder<String>(
              future: _getMatiereName(matiereId),
              builder: (context, snapshot) {
                return Text(
                  snapshot.data ?? 'Matière #$matiereId',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                );
              },
            ),
            subtitle: Text('Moyenne: ${moyenne.toStringAsFixed(2)} / 20'),
            children: notesMatiere.map((note) => _NoteListTile(note: note)).toList(),
          ),
        );
      },
    );
  }

  Future<String> _getMatiereName(int matiereId) async {
    try {
      final response = await Supabase.instance.client
          .from('matieres')
          .select('nom')
          .eq('id', matiereId)
          .single();
      return response['nom'];
    } catch (e) {
      return 'Matière #$matiereId';
    }
  }
}

// ==================== STATISTIQUES ====================
class _Statistiques extends StatelessWidget {
  final List<Note> notes;

  const _Statistiques({required this.notes});

  @override
  Widget build(BuildContext context) {
    // Préparer les données pour le graphique
    final notesParCategorie = <String, List<double>>{};
    for (var note in notes) {
      notesParCategorie
          .putIfAbsent(note.type, () => [])
          .add(note.note);
    }

    final moyennesParCategorie = notesParCategorie.map(
          (key, value) => MapEntry(key, value.reduce((a, b) => a + b) / value.length),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Évolution des Notes', style: GojikaTheme.titleMedium),
          const SizedBox(height: 20),

          // Graphique linéaire
          SizedBox(
            height: 250,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) => const Text(''),
                    ),
                  ),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: true),
                minY: 0,
                maxY: 20,
                lineBarsData: [
                  LineChartBarData(
                    spots: notes
                        .asMap()
                        .entries
                        .map((e) => FlSpot(e.key.toDouble(), e.value.note))
                        .toList(),
                    isCurved: true,
                    color: GojikaTheme.primaryBlue,
                    barWidth: 3,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: GojikaTheme.primaryBlue.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Moyennes par catégorie
          Text('Moyennes par Type d\'Examen', style: GojikaTheme.titleMedium),
          const SizedBox(height: 16),

          ...moyennesParCategorie.entries.map((entry) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: GojikaTheme.primaryBlue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: GojikaTheme.primaryBlue.withOpacity(0.2),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    entry.key,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    '${entry.value.toStringAsFixed(2)} / 20',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: entry.value >= 10 ? GojikaTheme.riskGreen : GojikaTheme.riskRed,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}

// ==================== WIDGETS RÉUTILISABLES ====================
class _NoteCard extends StatelessWidget {
  final Note note;

  const _NoteCard({required this.note});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: note.note >= 10 ? GojikaTheme.riskGreen.withOpacity(0.1) : GojikaTheme.riskRed.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              note.note.toStringAsFixed(1),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: note.note >= 10 ? GojikaTheme.riskGreen : GojikaTheme.riskRed,
              ),
            ),
          ),
        ),
        title: FutureBuilder<String>(
          future: _getMatiereName(note.matiereId),
          builder: (context, snapshot) {
            return Text(snapshot.data ?? 'Chargement...');
          },
        ),
        subtitle: Text('${note.type} • Coef. ${note.coefficient}'),
        trailing: note.approuveParRp
            ? const Icon(Iconsax.tick_circle, color: GojikaTheme.riskGreen)
            : const Icon(Iconsax.clock, color: GojikaTheme.riskOrange),
      ),
    );
  }

  Future<String> _getMatiereName(int matiereId) async {
    try {
      final response = await Supabase.instance.client
          .from('matieres')
          .select('nom')
          .eq('id', matiereId)
          .single();
      return response['nom'];
    } catch (e) {
      return 'Matière';
    }
  }
}

class _NoteListTile extends StatelessWidget {
  final Note note;

  const _NoteListTile({required this.note});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text('${note.type} • ${note.note.toStringAsFixed(2)} / 20'),
      subtitle: Text('Coefficient: ${note.coefficient}'),
      trailing: note.approuveParRp
          ? const Icon(Iconsax.tick_circle, color: GojikaTheme.riskGreen, size: 20)
          : const Icon(Iconsax.clock, color: GojikaTheme.riskOrange, size: 20),
    );
  }
}