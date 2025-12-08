// gojika/lib/screens/roles/student/student_home.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/theme.dart';
import '../../../providers/gojika_provider.dart';
import '../../auth/widgets/common_widgets.dart';
import 'student_calendar_page.dart';
import 'student_notes_page.dart';
import 'student_finance_page.dart';
import 'student_justifications_page.dart';
import 'student_profile_page.dart';

class StudentHomePage extends StatefulWidget {
  const StudentHomePage({Key? key}) : super(key: key);

  @override
  State<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage> {
  int _currentIndex = 0;
  Map<String, dynamic>? _etudiantData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStudentData();
  }

  Future<void> _loadStudentData() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;

      // Récupérer les données de l'étudiant
      final response = await Supabase.instance.client
          .from('etudiants')
          .select('*, profiles!gojika_account_linked(nom_complet, site_rattache)')
          .eq('gojika_account_linked', userId)
          .single();

      setState(() {
        _etudiantData = response;
        _isLoading = false;
      });

      // Charger les données du provider
      if (mounted) {
        final provider = context.read<GojikaProvider>();
        await Future.wait([
          provider.loadMotSemaine(),
          provider.loadNotesEtudiant(_etudiantData!['id']),
          provider.loadAbsencesEtudiant(_etudiantData!['id']),
          provider.loadPublications(
            _etudiantData!['site'],
            _etudiantData!['groupe'],
          ),
          provider.loadEmploiDuTemps(_etudiantData!['groupe']),
          provider.loadNotifications(),
        ]);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de chargement: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Chargement de votre espace...',
                style: GojikaTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    final pages = [
      _DashboardTab(etudiantData: _etudiantData!),
      StudentCalendarPage(etudiantData: _etudiantData!),
      StudentFinancePage(etudiantData: _etudiantData!),
      StudentNotesPage(etudiantData: _etudiantData!),
      StudentProfilePage(etudiantData: _etudiantData!),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Iconsax.home),
            activeIcon: Icon(Iconsax.home_15),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Iconsax.calendar),
            activeIcon: Icon(Iconsax.calendar_15),
            label: 'Calendrier',
          ),
          BottomNavigationBarItem(
            icon: Icon(Iconsax.wallet),
            activeIcon: Icon(Iconsax.wallet_25),
            label: 'Finance',
          ),
          BottomNavigationBarItem(
            icon: Icon(Iconsax.chart),
            activeIcon: Icon(Iconsax.chart_15),
            label: 'Notes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Iconsax.user),
            activeIcon: Icon(Iconsax.user_tick5),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

// ==================== ONGLET DASHBOARD ====================
class _DashboardTab extends StatelessWidget {
  final Map<String, dynamic> etudiantData;

  const _DashboardTab({required this.etudiantData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // AppBar avec dégradé
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: GojikaTheme.primaryGradient,
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundImage: etudiantData['photo_url'] != null
                                  ? NetworkImage(etudiantData['photo_url'])
                                  : null,
                              child: etudiantData['photo_url'] == null
                                  ? const Icon(Iconsax.user, size: 30)
                                  : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Bonjour 👋',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    '${etudiantData['prenom']} ${etudiantData['nom']}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${etudiantData['groupe']} • ${etudiantData['site']}',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Consumer<GojikaProvider>(
                              builder: (context, provider, _) {
                                final count = provider.notificationsNonLues;
                                return Stack(
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Iconsax.notification,
                                        color: Colors.white,
                                      ),
                                      onPressed: () {
                                        // TODO: Ouvrir page notifications
                                      },
                                    ),
                                    if (count > 0)
                                      Positioned(
                                        right: 8,
                                        top: 8,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: GojikaTheme.riskRed,
                                            shape: BoxShape.circle,
                                          ),
                                          constraints: const BoxConstraints(
                                            minWidth: 16,
                                            minHeight: 16,
                                          ),
                                          child: Text(
                                            count > 9 ? '9+' : '$count',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Contenu principal
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Mot de la semaine
                  Consumer<GojikaProvider>(
                    builder: (context, provider, _) {
                      final mot = provider.motSemaine;
                      if (mot == null) return const SizedBox.shrink();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              GojikaTheme.accentGold.withOpacity(0.1),
                              GojikaTheme.lightBlue.withOpacity(0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: GojikaTheme.accentGold.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Iconsax.quote_up,
                                  color: GojikaTheme.accentGold,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Mot de la semaine',
                                  style: GojikaTheme.titleMedium.copyWith(
                                    color: GojikaTheme.accentGold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '"${mot.texte}"',
                              style: const TextStyle(
                                fontSize: 15,
                                fontStyle: FontStyle.italic,
                                height: 1.5,
                              ),
                            ),
                            if (mot.auteur != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                '— ${mot.auteur}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ],
                        ),
                      )
                          .animate()
                          .fadeIn(duration: 600.ms)
                          .slideY(begin: 0.2, end: 0);
                    },
                  ),

                  // Dashboard KPIs
                  _DashboardKPIs(etudiantData: etudiantData),

                  const SizedBox(height: 24),

                  // Cours à venir
                  _CoursAVenir(groupe: etudiantData['groupe']),

                  const SizedBox(height: 24),

                  // Annonces récentes
                  _AnnoncesRecentes(
                    site: etudiantData['site'],
                    groupe: etudiantData['groupe'],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== KPIs DASHBOARD ====================
class _DashboardKPIs extends StatelessWidget {
  final Map<String, dynamic> etudiantData;

  const _DashboardKPIs({required this.etudiantData});

  @override
  Widget build(BuildContext context) {
    return Consumer<GojikaProvider>(
      builder: (context, provider, _) {
        // Calculs des KPIs
        final absences = provider.absences;
        final notes = provider.notes;
        final emploi = provider.emploiDuTemps;

        final totalCours = emploi.length * 4; // Estimation 4 semaines
        final tauxPresence = totalCours > 0
            ? ((totalCours - absences.length) / totalCours * 100)
            : 100.0;

        final meilleureNote = notes.isNotEmpty
            ? notes.map((n) => n.note).reduce((a, b) => a > b ? a : b)
            : 0.0;

        final pireNote = notes.isNotEmpty
            ? notes.map((n) => n.note).reduce((a, b) => a < b ? a : b)
            : 0.0;

        final moyenneGenerale = provider.moyenneEtudiant ?? 0.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Votre Bilan',
              style: GojikaTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.3,
              children: [
                KpiCard(
                  title: 'Taux de Présence',
                  value: '${tauxPresence.toStringAsFixed(1)}%',
                  icon: Iconsax.chart_success,
                  color: tauxPresence >= 80
                      ? GojikaTheme.riskGreen
                      : GojikaTheme.riskOrange,
                ),
                KpiCard(
                  title: 'Moyenne Générale',
                  value: moyenneGenerale.toStringAsFixed(2),
                  icon: Iconsax.award,
                  color: moyenneGenerale >= 10
                      ? GojikaTheme.riskGreen
                      : GojikaTheme.riskRed,
                ),
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
              ],
            ),
          ],
        );
      },
    );
  }
}

// ==================== COURS À VENIR ====================
class _CoursAVenir extends StatelessWidget {
  final String groupe;

  const _CoursAVenir({required this.groupe});

  @override
  Widget build(BuildContext context) {
    return Consumer<GojikaProvider>(
      builder: (context, provider, _) {
        final emploi = provider.emploiDuTemps;
        final now = DateTime.now();
        final jourSemaine = now.weekday % 7; // 0=dimanche, 1=lundi...

        // Filtrer les cours d'aujourd'hui
        final coursAujourdhui = emploi
            .where((e) => e.jourSemaine == jourSemaine)
            .toList()
          ..sort((a, b) => a.heureDebut.compareTo(b.heureDebut));

        if (coursAujourdhui.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Iconsax.calendar_tick, size: 40),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Aucun cours aujourd\'hui 🎉',
                      style: GojikaTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cours Aujourd\'hui', style: GojikaTheme.titleMedium),
            const SizedBox(height: 12),
            ...coursAujourdhui.take(3).map((cours) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: GojikaTheme.primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Iconsax.book, color: GojikaTheme.primaryBlue),
                  ),
                  title: FutureBuilder<String>(
                    future: _getMatiereName(cours.matiereId),
                    builder: (context, snapshot) {
                      return Text(
                        snapshot.data ?? 'Chargement...',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      );
                    },
                  ),
                  subtitle: Text(
                    '${cours.heureDebut} - ${cours.heureFin} • Salle ${cours.salle ?? 'TBD'}',
                  ),
                  trailing: const Icon(Iconsax.arrow_right_3),
                ),
              );
            }).toList(),
          ],
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

// ==================== ANNONCES RÉCENTES ====================
class _AnnoncesRecentes extends StatelessWidget {
  final String site;
  final String groupe;

  const _AnnoncesRecentes({required this.site, required this.groupe});

  @override
  Widget build(BuildContext context) {
    return Consumer<GojikaProvider>(
      builder: (context, provider, _) {
        final publications = provider.publications.take(3).toList();

        if (publications.isEmpty) {
          return const EmptyState(
            message: 'Aucune annonce récente',
            icon: Iconsax.notification_bing,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Annonces Récentes', style: GojikaTheme.titleMedium),
                TextButton(
                  onPressed: () {
                    // TODO: Voir toutes les annonces
                  },
                  child: const Text('Voir tout'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...publications.map((pub) => PublicationCard(
              publication: pub,
              onTap: () {
                // TODO: Ouvrir détail publication
              },
            )).toList(),
          ],
        );
      },
    );
  }
}