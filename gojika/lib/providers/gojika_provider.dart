import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../services/gojika_service.dart';
import '../services/offline_service.dart.dart';

class GojikaProvider extends ChangeNotifier {
  final GojikaService _service = GojikaService();
  final OfflineService _offlineService = OfflineService();

  // Getter public pour accéder au service depuis les UI si besoin
  GojikaService get service => _service;

  // --- ÉTATS GLOBAUX ---
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  int get pendingSyncCount => _offlineService.pendingSyncCount;

  // --- DONNÉES COMMUNES / DASHBOARD ---
  Map<String, dynamic>? _dashboardKpis;
  Map<String, dynamic>? get dashboardKpis => _dashboardKpis;

  List<Map<String, dynamic>> _frequentationJournaliere = [];
  List<Map<String, dynamic>> get frequentationJournaliere => _frequentationJournaliere;

  List<Map<String, dynamic>> _moyennesGroupes = [];
  List<Map<String, dynamic>> get moyennesGroupes => _moyennesGroupes;

  // --- DONNÉES ÉTUDIANT ---
  List<Note> _notes = [];
  List<Note> get notes => _notes;

  double? _moyenneEtudiant;
  double? get moyenneEtudiant => _moyenneEtudiant;

  List<Absence> _absences = [];
  List<Absence> get absences => _absences;

  List<Justification> _justifications = [];
  List<Justification> get justifications => _justifications;

  List<Publication> _publications = [];
  List<Publication> get publications => _publications;

  List<Publication> _publicationsAValider = [];
  List<Publication> get publicationsAValider => _publicationsAValider;

  List<NotificationModel> _notifications = [];
  List<NotificationModel> get notifications => _notifications;
  int get notificationsNonLues => _notifications.where((n) => !n.lu).length;

  List<EmploiDuTemps> _emploiDuTemps = [];
  List<EmploiDuTemps> get emploiDuTemps => _emploiDuTemps;

  MotSemaine? _motSemaine;
  MotSemaine? get motSemaine => _motSemaine;

  List<EvenementAcademique> _evenementsProchains = [];
  List<EvenementAcademique> get evenementsProchains => _evenementsProchains;

  List<Map<String, dynamic>> _etudiantsRisque = [];
  List<Map<String, dynamic>> get etudiantsRisque => _etudiantsRisque;

  // --- DONNÉES ADMIN / RP ---
  List<Map<String, dynamic>> _allProfiles = [];
  List<Map<String, dynamic>> get allProfiles => _allProfiles;

  List<Map<String, dynamic>> _auditLogs = [];
  List<Map<String, dynamic>> get auditLogs => _auditLogs;

  // Cache pour les sélecteurs RP (Saisie)
  List<Map<String, dynamic>> _etudiantsGroupeActuel = [];
  List<Map<String, dynamic>> get etudiantsGroupeActuel => _etudiantsGroupeActuel;

  List<Map<String, dynamic>> _categoriesExamens = [];
  List<Map<String, dynamic>> get categoriesExamens => _categoriesExamens;

  List<Semestre> _semestresActifs = [];
  List<Semestre> get semestresActifs => _semestresActifs;

  List<Matiere> _matieresSite = [];
  List<Matiere> get matieresSite => _matieresSite;


  // ==================== INITIALISATION ====================
  Future<void> initialize() async {
    await _offlineService.initialize();
  }

  // ==================== HELPERS PRIVÉS ====================
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _handleError(String message, dynamic error) {
    _error = message;
    debugPrint('$message: $error');
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ==================== 1. DASHBOARD & KPIS (Commun) ====================

  // Corrige l'erreur: The method 'loadDashboard' isn't defined [cite: 740]
  Future<void> loadDashboard(String? siteFilter) async {
    _setLoading(true);
    try {
      _dashboardKpis = await _service.getDashboardKpis(siteFilter);
      _frequentationJournaliere = await _service.getFrequentationJournaliere(siteFilter);
      _moyennesGroupes = await _service.getMoyennesGroupes(siteFilter);
      _isOnline = true;
    } catch (e) {
      _handleError('Erreur dashboard', e);
      _isOnline = false;
    } finally {
      _setLoading(false);
    }
  }

  // ==================== 2. ÉTUDIANT : LOGIQUE MÉTIER ====================

  // Corrige: The method 'loadNotesEtudiant' isn't defined [cite: 747]
  Future<void> loadNotesEtudiant(int etudiantId, {int? semestreId, int? categorieId}) async {
    _setLoading(true);
    try {
      _notes = await _service.getNotesEtudiant(etudiantId, semestreId: semestreId, categorieId: categorieId);
      _moyenneEtudiant = await _service.calculerMoyenneEtudiant(etudiantId, semestreId: semestreId, categorieId: categorieId);

      // Cache local
      await _offlineService.cacheNotes(_notes.map((n) => n.toJson()).toList());
      _isOnline = true;
    } catch (e) {
      _handleError('Erreur notes', e);
      // Fallback cache
      final cached = _offlineService.getCachedNotes();
      if (cached.isNotEmpty) {
        _notes = cached.map((e) => Note.fromJson(e)).toList();
        _error = 'Mode hors ligne';
      }
      _isOnline = false;
    } finally {
      _setLoading(false);
    }
  }

  // Corrige: The method 'loadAbsencesEtudiant' isn't defined [cite: 757]
  Future<void> loadAbsencesEtudiant(int etudiantId) async {
    _setLoading(true);
    try {
      _absences = await _service.getAbsencesEtudiant(etudiantId);
      _isOnline = true;
      // Cache simple
      await _offlineService.cacheAbsences(_absences.map((a) => {
        'id': a.id,
        'etudiant_id': a.etudiantId,
        'date_absence': a.dateAbsence.toIso8601String(),
      }).toList());
    } catch (e) {
      _handleError('Erreur absences', e);
      _isOnline = false;
    } finally {
      _setLoading(false);
    }
  }

  // Corrige: The method 'loadJustificationsEtudiant' isn't defined
  Future<void> loadJustificationsEtudiant(int etudiantId) async {
    _setLoading(true);
    try {
      // Appel direct Supabase car manquant dans le service initial
      final data = await Supabase.instance.client
          .from('justifications')
          .select()
          .eq('etudiant_id', etudiantId)
          .order('date_soumission', ascending: false);

      _justifications = (data as List).map((e) => Justification.fromJson(e)).toList();
      _isOnline = true;
    } catch (e) {
      _handleError('Erreur justifications', e);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> createJustification(Map<String, dynamic> data) async {
    try {
      final newItem = await _service.createJustification(data);
      _justifications.insert(0, newItem);
      notifyListeners();
    } catch (e) {
      _handleError('Erreur envoi justification', e);
      rethrow;
    }
  }

  // Corrige: The method 'loadPublications' isn't defined [cite: 772]
  Future<void> loadPublications(String site, String? groupe) async {
    _setLoading(true);
    try {
      _publications = await _service.getPublications(site, groupe);
      _isOnline = true;
    } catch (e) {
      _handleError('Erreur publications', e);
      _isOnline = false;
    } finally {
      _setLoading(false);
    }
  }

  // Corrige: The method 'loadEmploiDuTemps' isn't defined [cite: 789]
  Future<void> loadEmploiDuTemps(String groupe) async {
    _setLoading(true);
    try {
      _emploiDuTemps = await _service.getEmploiDuTemps(groupe);
      _isOnline = true;
    } catch (e) {
      _handleError('Erreur emploi du temps', e);
      _isOnline = false;
    } finally {
      _setLoading(false);
    }
  }

  // Corrige: The method 'loadNotifications' isn't defined [cite: 783]
  Future<void> loadNotifications() async {
    try {
      _notifications = await _service.getNotifications();
      notifyListeners();
    } catch (e) {
      _handleError('Erreur notifications', e);
    }
  }

  // Corrige: The method 'loadMotSemaine' isn't defined [cite: 796]
  Future<void> loadMotSemaine() async {
    try {
      _motSemaine = await _service.getMotSemaineActif();
      notifyListeners();
    } catch (e) {
      debugPrint('Erreur mot semaine: $e');
    }
  }

  // Corrige: The method 'loadEvenementsProchains' isn't defined [cite: 798]
  Future<void> loadEvenementsProchains() async {
    try {
      _evenementsProchains = await _service.getEvenementsProchains();
      notifyListeners();
    } catch (e) {
      debugPrint('Erreur événements: $e');
    }
  }

  Future<void> marquerNotificationLue(int notifId) async {
    try {
      await _service.marquerNotificationLue(notifId);
      final index = _notifications.indexWhere((n) => n.id == notifId);
      if (index != -1) {
        // Mise à jour locale optimiste
        _notifications[index] = NotificationModel(
          id: _notifications[index].id,
          userId: _notifications[index].userId,
          titre: _notifications[index].titre,
          message: _notifications[index].message,
          type: _notifications[index].type,
          lien: _notifications[index].lien,
          lu: true,
          luLe: DateTime.now(),
          createdAt: _notifications[index].createdAt,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Erreur notif lue: $e');
    }
  }

  // ==================== 3. RP / ADMIN : LOGIQUE MÉTIER ====================

  // Chargement des données pour les écrans de saisie (RP)
  Future<void> loadDonneesSaisie(String site, String groupe) async {
    _setLoading(true);
    try {
      final results = await Future.wait([
        _service.getEtudiantsParGroupe(site, groupe),
        _service.getMatieres(site),
        _service.getCategoriesExamens(),
        _service.getSemestresActifs(),
      ]);
      _etudiantsGroupeActuel = results[0] as List<Map<String, dynamic>>;
      _matieresSite = results[1] as List<Matiere>;
      _categoriesExamens = results[2] as List<Map<String, dynamic>>;
      _semestresActifs = results[3] as List<Semestre>;
      _isOnline = true;
    } catch (e) {
      _handleError('Erreur chargement saisie', e);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> soumettreNotesGroupe(List<Map<String, dynamic>> notes) async {
    _setLoading(true);
    try {
      await _service.saveNotesBatch(notes);
      notifyListeners();
    } catch (e) {
      _handleError('Erreur sauvegarde notes', e);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> soumettreAbsencesGroupe(List<Map<String, dynamic>> absencesData) async {
    _setLoading(true);
    try {
      await _service.saveAbsencesBatch(absencesData);
      notifyListeners();
    } catch (e) {
      _handleError('Erreur sauvegarde absences', e);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Gestion Utilisateurs (Admin)
  Future<void> loadAllProfiles() async {
    _setLoading(true);
    try {
      _allProfiles = await _service.getAllProfiles();
      notifyListeners();
    } catch (e) {
      _handleError('Erreur profils', e);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> createStaffUser(Map<String, dynamic> data) async {
    _setLoading(true);
    try {
      await _service.createStaffUser(
        email: data['email'],
        password: data['password'],
        nomComplet: data['nom_complet'],
        role: data['role'],
        site: data['site'],
      );
      await loadAllProfiles();
    } catch (e) {
      _handleError('Erreur création staff', e);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteUser(String userId) async {
    _setLoading(true);
    try {
      await _service.deleteUser(userId);
      _allProfiles.removeWhere((p) => p['id'] == userId);
      notifyListeners();
    } catch (e) {
      _handleError('Erreur suppression', e);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadAuditLogs() async {
    _setLoading(true);
    try {
      _auditLogs = await _service.getAuditLogs();
      notifyListeners();
    } catch (e) {
      _handleError('Erreur audit', e);
    } finally {
      _setLoading(false);
    }
  }

  // ==================== SYNC ====================
  Future<void> syncNow() async {
    await _offlineService.trySyncNow();
    notifyListeners();
  }

  @override
  void dispose() {
    _offlineService.dispose();
    super.dispose();
  }
}