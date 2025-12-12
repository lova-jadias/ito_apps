// PARTIE 1/2 - Imports et Classes Principales

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
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadStudentData();
  }

  // ⚠️ CORRECTION CRITIQUE : Ligne 28-35 de student_home.dart
// REMPLACER LA REQUÊTE ACTUELLE PAR CELLE-CI

  Future<void> _loadStudentData() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      debugPrint('🔵 Chargement données étudiant pour user: $userId');

      // ✅ CORRECTION : Utilisation correcte de la jointure
      final response = await Supabase.instance.client
          .from('etudiants')
          .select('*') // Sélectionner tous les champs de l'étudiant
          .eq('gojika_account_linked', userId)
          .eq('gojika_account_active', true) // Vérifier activation dès la requête
          .maybeSingle();

      if (response == null) {
        throw Exception('Aucun profil étudiant trouvé ou compte non activé');
      }

      // Validations
      if (response['nom'] == null || response['nom'].toString().isEmpty) {
        throw Exception('Données étudiant incomplètes (nom manquant)');
      }

      if (response['site'] == null) {
        throw Exception('Site non défini pour cet étudiant');
      }

      debugPrint('✅ Données étudiant chargées: ${response['nom']} ${response['prenom']}');
      debugPrint('✅ Site: ${response['site']}, Groupe: ${response['groupe']}');

      setState(() {
        _etudiantData = response;
        _isLoading = false;
        _errorMessage = null;
      });

      if (mounted) {
        final provider = context.read<GojikaProvider>();

        // Charger les données en parallèle avec gestion d'erreur
        await Future.wait([
          provider.loadMotSemaine().catchError((e) {
            debugPrint('⚠️ Erreur mot semaine: $e');
            return null;
          }),
          provider.loadNotesEtudiant(_etudiantData!['id']).catchError((e) {
            debugPrint('⚠️ Erreur notes: $e');
            return null;
          }),
          provider.loadAbsencesEtudiant(_etudiantData!['id']).catchError((e) {
            debugPrint('⚠️ Erreur absences: $e');
            return null;
          }),
          provider.loadPublications(
            _etudiantData!['site'],
            _etudiantData!['groupe'] ?? '',
          ).catchError((e) {
            debugPrint('⚠️ Erreur publications: $e');
            return null;
          }),
          provider.loadEmploiDuTemps(_etudiantData!['groupe'] ?? '').catchError((e) {
            debugPrint('⚠️ Erreur emploi du temps: $e');
            return null;
          }),
          provider.loadNotifications().catchError((e) {
            debugPrint('⚠️ Erreur notifications: $e');
            return null;
          }),
        ]);

        debugPrint('✅ Toutes les données chargées avec succès');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Erreur chargement données étudiant: $e');
      debugPrint('Stack trace: $stackTrace');

      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Réessayer',
              textColor: Colors.white,
              onPressed: () {
                setState(() => _isLoading = true);
                _loadStudentData();
              },
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: GojikaTheme.lightGradient,
          ),
          child: Center(
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
        ),
      );
    }

    if (_errorMessage != null || _etudiantData == null) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: GojikaTheme.lightGradient,
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Iconsax.danger,
                    size: 80,
                    color: Colors.red[400],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Erreur de chargement',
                    style: GojikaTheme.titleMedium.copyWith(
                      color: Colors.red[700],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage ?? 'Impossible de charger vos données',
                    style: TextStyle(color: Colors.grey[700]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _isLoading = true;
                        _errorMessage = null;
                      });
                      _loadStudentData();
                    },
                    icon: const Icon(Iconsax.refresh),
                    label: const Text('Réessayer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GojikaTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () async {
                      await Supabase.instance.client.auth.signOut();
                      if (context.mounted) {
                        Navigator.of(context).pushReplacementNamed('/login');
                      }
                    },
                    child: const Text('Se déconnecter'),
                  ),
                ],
              ),
            ),
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
        type: BottomNavigationBarType.fixed,
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

// PARTIE 2/2 - Widgets Dashboard (À ajouter après la classe StudentHomePage)

// ==================== ONGLET DASHBOARD ====================
class _DashboardTab extends StatelessWidget {
  final Map<String, dynamic> etudiantData;

  const _DashboardTab({required this.etudiantData});

  @override
  Widget build(BuildContext context) {
    final prenom = etudiantData['prenom'] ?? '';
    final nom = etudiantData['nom'] ?? 'Étudiant';
    final fullName = '$prenom $nom'.trim();
    final groupe = etudiantData['groupe'] ?? 'Non défini';
    final site = etudiantData['site'] ?? 'N/A';
    final photoUrl = etudiantData['photo_url'];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
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
                              backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                              backgroundColor: Colors.white,
                              child: photoUrl == null
                                  ? Text(
                                nom.isNotEmpty ? nom[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: GojikaTheme.primaryBlue,
                                ),
                              )
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
                                    fullName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '$groupe • $site',
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
                                      icon: const Icon(Iconsax.notification, color: Colors.white),
                                      onPressed: () {},
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

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                                const Icon(Iconsax.quote_up, color: GojikaTheme.accentGold),
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
                                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                              ),
                            ],
                          ],
                        ),
                      ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2, end: 0);
                    },
                  ),

                  _DashboardKPIs(etudiantData: etudiantData),
                  const SizedBox(height: 24),
                  _CoursAVenir(groupe: groupe),
                  const SizedBox(height: 24),
                  _AnnoncesRecentes(site: site, groupe: groupe),
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
        final absences = provider.absences;
        final notes = provider.notes;
        final emploi = provider.emploiDuTemps;

        final totalCours = emploi.length * 4;
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
            Text('Votre Bilan', style: GojikaTheme.titleMedium),
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
                  color: tauxPresence >= 80 ? GojikaTheme.riskGreen : GojikaTheme.riskOrange,
                ),
                KpiCard(
                  title: 'Moyenne Générale',
                  value: moyenneGenerale.toStringAsFixed(2),
                  icon: Iconsax.award,
                  color: moyenneGenerale >= 10 ? GojikaTheme.riskGreen : GojikaTheme.riskRed,
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
        final jourSemaine = now.weekday % 7;

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
            }),
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
                  onPressed: () {},
                  child: const Text('Voir tout'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...publications.map((pub) => PublicationCard(
              publication: pub,
              onTap: () {},
            )),
          ],
        );
      },
    );
  }
}