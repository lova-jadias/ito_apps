// gojika/lib/screens/roles/student/student_calendar_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../../config/theme.dart';
import '../../../providers/gojika_provider.dart';
import '../../../models/models.dart';

class StudentCalendarPage extends StatefulWidget {
  final Map<String, dynamic> etudiantData;

  const StudentCalendarPage({Key? key, required this.etudiantData}) : super(key: key);

  @override
  State<StudentCalendarPage> createState() => _StudentCalendarPageState();
}

class _StudentCalendarPageState extends State<StudentCalendarPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedDay = _focusedDay;

    // Charger les événements
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GojikaProvider>().loadEvenementsProchains();
    });
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
        title: const Text('Calendrier'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Emploi du Temps', icon: Icon(Iconsax.calendar_2)),
            Tab(text: 'Événements', icon: Icon(Iconsax.calendar_tick)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _EmploiDuTempsTab(groupe: widget.etudiantData['groupe']),
          _EvenementsTab(
            site: widget.etudiantData['site'],
            groupe: widget.etudiantData['groupe'],
          ),
        ],
      ),
    );
  }
}

// ==================== ONGLET EMPLOI DU TEMPS ====================
class _EmploiDuTempsTab extends StatelessWidget {
  final String groupe;

  const _EmploiDuTempsTab({required this.groupe});

  @override
  Widget build(BuildContext context) {
    return Consumer<GojikaProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final emploi = provider.emploiDuTemps;

        if (emploi.isEmpty) {
          return const Center(
            child: Text('Aucun emploi du temps disponible'),
          );
        }

        // Organiser par jour
        final parJour = <int, List<EmploiDuTemps>>{};
        for (var cours in emploi) {
          parJour.putIfAbsent(cours.jourSemaine, () => []).add(cours);
        }

        // Trier chaque jour par heure
        parJour.forEach((key, value) {
          value.sort((a, b) => a.heureDebut.compareTo(b.heureDebut));
        });

        return SingleChildScrollView(
          child: Column(
            children: [
              // Affichage statique en tableau
              _TableauEmploi(parJour: parJour),
              const SizedBox(height: 20),
              // Vue liste (alternative)
              _ListeEmploi(parJour: parJour),
            ],
          ),
        );
      },
    );
  }
}

// Tableau de l'emploi du temps
class _TableauEmploi extends StatelessWidget {
  final Map<int, List<EmploiDuTemps>> parJour;

  const _TableauEmploi({required this.parJour});

  static const joursLabels = [
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vue Hebdomadaire',
              style: GojikaTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(
                  GojikaTheme.primaryBlue.withOpacity(0.1),
                ),
                columns: const [
                  DataColumn(label: Text('Heure', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Lundi')),
                  DataColumn(label: Text('Mardi')),
                  DataColumn(label: Text('Mercredi')),
                  DataColumn(label: Text('Jeudi')),
                  DataColumn(label: Text('Vendredi')),
                  DataColumn(label: Text('Samedi')),
                ],
                rows: _buildRows(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<DataRow> _buildRows() {
    // Extraire toutes les heures uniques
    final heures = <String>{};
    for (var cours in parJour.values.expand((e) => e)) {
      heures.add('${cours.heureDebut}-${cours.heureFin}');
    }

    final heuresTriees = heures.toList()..sort();

    return heuresTriees.map((heure) {
      return DataRow(
        cells: [
          DataCell(Text(heure, style: const TextStyle(fontWeight: FontWeight.bold))),
          for (int jour = 1; jour <= 6; jour++)
            DataCell(_getCellForDayAndTime(jour, heure)),
        ],
      );
    }).toList();
  }

  Widget _getCellForDayAndTime(int jour, String heure) {
    final coursJour = parJour[jour] ?? [];
    final parts = heure.split('-');

    for (var cours in coursJour) {
      if (cours.heureDebut == parts[0]) {
        return FutureBuilder<String>(
          future: _getMatiereName(cours.matiereId),
          builder: (context, snapshot) {
            return Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: GojikaTheme.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    snapshot.data ?? '...',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (cours.salle != null)
                    Text(
                      'Salle ${cours.salle}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),
            );
          },
        );
      }
    }

    return const Text('-');
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

// Liste de l'emploi du temps
class _ListeEmploi extends StatelessWidget {
  final Map<int, List<EmploiDuTemps>> parJour;

  const _ListeEmploi({required this.parJour});

  static const joursLabels = [
    'Dimanche',
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Vue Détaillée', style: GojikaTheme.titleMedium),
          const SizedBox(height: 16),
          ...parJour.entries.map((entry) {
            return _JourCard(
              jour: joursLabels[entry.key],
              cours: entry.value,
            );
          }).toList(),
        ],
      ),
    );
  }
}

class _JourCard extends StatelessWidget {
  final String jour;
  final List<EmploiDuTemps> cours;

  const _JourCard({required this.jour, required this.cours});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: const Icon(Iconsax.calendar),
        title: Text(
          jour,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${cours.length} cours'),
        children: cours.map((c) {
          return FutureBuilder<String>(
            future: _getMatiereName(c.matiereId),
            builder: (context, snapshot) {
              return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: GojikaTheme.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Iconsax.book, size: 20),
                ),
                title: Text(snapshot.data ?? 'Chargement...'),
                subtitle: Text('Salle ${c.salle ?? 'TBD'}'),
                trailing: Text(
                  '${c.heureDebut}\n${c.heureFin}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
              );
            },
          );
        }).toList(),
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
      return 'Matière #$matiereId';
    }
  }
}

// ==================== ONGLET ÉVÉNEMENTS ====================
class _EvenementsTab extends StatefulWidget {
  final String site;
  final String groupe;

  const _EvenementsTab({required this.site, required this.groupe});

  @override
  State<_EvenementsTab> createState() => _EvenementsTabState();
}

class _EvenementsTabState extends State<_EvenementsTab> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GojikaProvider>(
      builder: (context, provider, _) {
        final evenements = provider.evenementsProchains;

        return Column(
          children: [
            // Calendrier
            Card(
              margin: const EdgeInsets.all(16),
              child: TableCalendar(
                firstDay: DateTime.now().subtract(const Duration(days: 365)),
                lastDay: DateTime.now().add(const Duration(days: 365)),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                calendarFormat: CalendarFormat.month,
                locale: 'fr_FR',
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                ),
                calendarStyle: CalendarStyle(
                  selectedDecoration: const BoxDecoration(
                    color: GojikaTheme.primaryBlue,
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: GojikaTheme.primaryBlue.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  markersMaxCount: 3,
                ),
                eventLoader: (day) {
                  return evenements
                      .where((e) => isSameDay(e.dateDebut, day))
                      .toList();
                },
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
              ),
            ),

            // Liste des événements du jour sélectionné
            Expanded(
              child: _EvenementsDuJour(
                selectedDay: _selectedDay!,
                evenements: evenements,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EvenementsDuJour extends StatelessWidget {
  final DateTime selectedDay;
  final List<EvenementAcademique> evenements;

  const _EvenementsDuJour({
    required this.selectedDay,
    required this.evenements,
  });

  @override
  Widget build(BuildContext context) {
    final evenementsDuJour = evenements
        .where((e) => isSameDay(e.dateDebut, selectedDay))
        .toList();

    if (evenementsDuJour.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Iconsax.calendar_remove,
              size: 60,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun événement le ${DateFormat('dd/MM/yyyy').format(selectedDay)}',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: evenementsDuJour.length,
      itemBuilder: (context, index) {
        final event = evenementsDuJour[index];
        final color = _getEventColor(event.typeEvenement);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_getEventIcon(event.typeEvenement), color: color),
            ),
            title: Text(
              event.titre,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (event.description != null) Text(event.description!),
                const SizedBox(height: 4),
                Text(
                  event.dateFin != null
                      ? 'Du ${DateFormat('dd/MM').format(event.dateDebut)} au ${DateFormat('dd/MM').format(event.dateFin!)}'
                      : DateFormat('dd/MM/yyyy').format(event.dateDebut),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                event.typeEvenement,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getEventColor(String type) {
    switch (type.toLowerCase()) {
      case 'examen':
        return GojikaTheme.riskRed;
      case 'ferie':
        return GojikaTheme.riskGreen;
      case 'rentree':
        return GojikaTheme.primaryBlue;
      default:
        return GojikaTheme.accentGold;
    }
  }

  IconData _getEventIcon(String type) {
    switch (type.toLowerCase()) {
      case 'examen':
        return Iconsax.edit;
      case 'ferie':
        return Iconsax.sun_1;
      case 'rentree':
        return Iconsax.teacher;
      default:
        return Iconsax.calendar;
    }
  }
}