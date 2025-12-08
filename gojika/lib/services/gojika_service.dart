import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

class GojikaService {
  final SupabaseClient _client = Supabase.instance.client;

  // ==================== DASHBOARD ====================
  Future<Map<String, dynamic>> getDashboardKpis(String? siteFilter) async {
    final result = await _client.rpc('get_dashboard_gojika', params: {
      'p_site': siteFilter,
    });
    return result as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getFrequentationJournaliere(String? siteFilter) async {
    final result = await _client.rpc('get_frequentation_journaliere', params: {
      'p_site': siteFilter,
    });
    return List<Map<String, dynamic>>.from(result);
  }

  Future<List<Map<String, dynamic>>> getMoyennesGroupes(String? siteFilter) async {
    final result = await _client.rpc('get_moyennes_groupes', params: {
      'p_site': siteFilter,
    });
    return List<Map<String, dynamic>>.from(result);
  }

  // ==================== ÉTUDIANTS À RISQUE ====================
  Future<List<Map<String, dynamic>>> getEtudiantsRisque(
      String site, {
        String? niveauRisque,
      }) async {
    final result = await _client.rpc('get_etudiants_risque', params: {
      'p_site': site,
      'p_niveau_risque': niveauRisque,
    });
    return List<Map<String, dynamic>>.from(result);
  }

  Future<void> mettreAJourRiskScores() async {
    await _client.rpc('mettre_a_jour_risk_scores');
  }

  // ==================== ANNÉE ACADÉMIQUE ====================
  Future<List<AnneeAcademique>> getAnneesAcademiques() async {
    final response = await _client
        .from('annees_academiques')
        .select()
        .order('date_debut', ascending: false);
    return (response as List).map((e) => AnneeAcademique.fromJson(e)).toList();
  }

  Future<AnneeAcademique> createAnneeAcademique(AnneeAcademique annee) async {
    final response = await _client
        .from('annees_academiques')
        .insert(annee.toJson())
        .select()
        .single();
    return AnneeAcademique.fromJson(response);
  }

  // ==================== ÉVÉNEMENTS ====================
  Future<List<EvenementAcademique>> getEvenementsProchains() async {
    final response = await _client.from('vw_evenements_prochains').select();
    return (response as List).map((e) => EvenementAcademique.fromJson(e)).toList();
  }

  Future<EvenementAcademique> createEvenement(EvenementAcademique evenement) async {
    final response = await _client
        .from('evenements_academiques')
        .insert(evenement.toJson())
        .select()
        .single();
    return EvenementAcademique.fromJson(response);
  }

  // ==================== MATIÈRES ====================
  Future<List<Matiere>> getMatieres(String site) async {
    final response = await _client
        .from('matieres')
        .select()
        .eq('site', site);
    return (response as List).map((e) => Matiere.fromJson(e)).toList();
  }

  Future<Matiere> createMatiere(String nom, String site, String? enseignantId) async {
    final response = await _client
        .from('matieres')
        .insert({
      'nom': nom,
      'site': site,
      'enseignant_id': enseignantId,
    })
        .select()
        .single();
    return Matiere.fromJson(response);
  }

  // ==================== NOTES ====================
  Future<List<Note>> getNotesEtudiant(
      int etudiantId, {
        int? semestreId,
        int? categorieId,
      }) async {
    var query = _client
        .from('notes')
        .select()
        .eq('etudiant_id', etudiantId);

    if (semestreId != null) {
      query = query.eq('semestre_id', semestreId);
    }
    if (categorieId != null) {
      query = query.eq('categorie_examen_id', categorieId);
    }

    final response = await query.order('date_saisie', ascending: false);
    return (response as List).map((e) => Note.fromJson(e)).toList();
  }

  Future<Note> createNote(Note note) async {
    final response = await _client
        .from('notes')
        .insert(note.toJson())
        .select()
        .single();
    return Note.fromJson(response);
  }

  Future<double> calculerMoyenneEtudiant(
      int etudiantId, {
        int? semestreId,
        int? categorieId,
      }) async {
    final result = await _client.rpc('calculer_moyenne_etudiant', params: {
      'p_etudiant_id': etudiantId,
      'p_semestre_id': semestreId,
      'p_categorie_id': categorieId,
    });
    return (result as num).toDouble();
  }

  // ==================== ABSENCES ====================
  Future<List<Absence>> getAbsencesEtudiant(int etudiantId) async {
    final response = await _client
        .from('absences')
        .select()
        .eq('etudiant_id', etudiantId)
        .order('date_absence', ascending: false);
    return (response as List).map((e) => Absence.fromJson(e)).toList();
  }

  Future<Absence> createAbsence(Map<String, dynamic> absenceData) async {
    final response = await _client
        .from('absences')
        .insert(absenceData)
        .select()
        .single();
    return Absence.fromJson(response);
  }

  Future<void> approuverAbsences(List<int> absenceIds) async {
    await _client
        .from('absences')
        .update({'approuve_par_rp': true, 'approuve_le': DateTime.now().toIso8601String()})
        .filter('id', 'in', absenceIds);
  }

  // ==================== JUSTIFICATIONS ====================
  Future<List<Justification>> getJustificationsEnAttente(String site) async {
    final response = await _client
        .from('justifications')
        .select('*, etudiants!inner(site)')
        .eq('status', 'en_attente')
        .eq('etudiants.site', site)
        .order('date_soumission', ascending: false);
    return (response as List).map((e) => Justification.fromJson(e)).toList();
  }

  Future<void> validerJustification(int justifId, bool valider) async {
    await _client
        .from('justifications')
        .update({
      'status': valider ? 'validee' : 'refusee',
      'valide_par_user_id': _client.auth.currentUser!.id,
    })
        .eq('id', justifId);
  }

  Future<Justification> createJustification(Map<String, dynamic> justifData) async {
    final response = await _client
        .from('justifications')
        .insert(justifData)
        .select()
        .single();
    return Justification.fromJson(response);
  }

  // ==================== PUBLICATIONS ====================
  Future<List<Publication>> getPublications(String site, String? groupe) async {
    var query = _client
        .from('publications')
        .select()
        .eq('status', 'publiee')
        .or('site_cible.eq.$site,site_cible.eq.FULL');

    if (groupe != null) {
      query = query.or('groupe_cible.eq.$groupe,groupe_cible.is.null');
    }

    final response = await query.order('date_publication', ascending: false);
    return (response as List).map((e) => Publication.fromJson(e)).toList();
  }

  Future<List<Publication>> getPublicationsAValider(String site) async {
    final response = await _client
        .from('publications')
        .select()
        .eq('status', 'en_attente_validation')
        .eq('site_cible', site)
        .order('date_publication', ascending: false);
    return (response as List).map((e) => Publication.fromJson(e)).toList();
  }

  Future<void> validerPublication(int pubId, bool valider) async {
    await _client
        .from('publications')
        .update({
      'status': valider ? 'publiee' : 'brouillon',
      'approuve_par_rp': valider,
      'approuve_le': DateTime.now().toIso8601String(),
      'valide_par': _client.auth.currentUser!.id,
    })
        .eq('id', pubId);
  }

  Future<Publication> createPublication(Map<String, dynamic> pubData) async {
    final response = await _client
        .from('publications')
        .insert(pubData)
        .select()
        .single();
    return Publication.fromJson(response);
  }

  // ==================== NOTIFICATIONS ====================
  Future<List<NotificationModel>> getNotifications() async {
    final userId = _client.auth.currentUser!.id;
    final response = await _client
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(50);
    return (response as List).map((e) => NotificationModel.fromJson(e)).toList();
  }

  Future<void> marquerNotificationLue(int notifId) async {
    await _client
        .from('notifications')
        .update({'lu': true, 'lu_le': DateTime.now().toIso8601String()})
        .eq('id', notifId);
  }

  // ==================== EMPLOI DU TEMPS ====================
  Future<List<EmploiDuTemps>> getEmploiDuTemps(String groupe) async {
    final response = await _client
        .from('emplois_du_temps')
        .select()
        .eq('groupe', groupe)
        .order('jour_semaine');
    return (response as List).map((e) => EmploiDuTemps.fromJson(e)).toList();
  }

  // ==================== MOT DE LA SEMAINE ====================
  Future<MotSemaine?> getMotSemaineActif() async {
    try {
      final response = await _client
          .from('mot_semaine')
          .select()
          .eq('is_active', true)
          .single();
      return MotSemaine.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<MotSemaine> createMotSemaine(MotSemaine mot) async {
    final response = await _client
        .from('mot_semaine')
        .insert({
      'texte': mot.texte,
      'auteur': mot.auteur,
      'date_debut': mot.dateDebut.toIso8601String().split('T')[0],
      'date_fin': mot.dateFin.toIso8601String().split('T')[0],
      'is_active': mot.isActive,
    })
        .select()
        .single();
    return MotSemaine.fromJson(response);
  }


// ==================== MÉTHODES RP : LISTES & GESTION ====================

// Récupérer la liste des étudiants d'un groupe spécifique
  Future<List<Map<String, dynamic>>> getEtudiantsParGroupe(String site, String groupe) async {
    final response = await _client
        .from('etudiants')
        .select()
        .eq('site', site)
        .eq('groupe', groupe)
        .eq('statut', 'Actif')
        .order('nom');
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getCategoriesExamens() async {
    final response = await _client
        .from('categories_examens')
        .select()
        .order('libelle');
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Semestre>> getSemestresActifs() async {
    final anneeResponse = await _client
        .from('annees_academiques')
        .select()
        .eq('is_active', true)
        .maybeSingle(); // Utiliser maybeSingle pour éviter le crash si vide

    if (anneeResponse == null) return [];

    final anneeId = anneeResponse['id'];
    final response = await _client
        .from('semestres')
        .select()
        .eq('annee_id', anneeId)
        .order('numero');
    return (response as List).map((e) => Semestre.fromJson(e)).toList();
  }

  Future<void> saveNotesBatch(List<Map<String, dynamic>> notesData) async {
    await _client.from('notes').insert(notesData);
  }

  Future<void> saveAbsencesBatch(List<Map<String, dynamic>> absencesData) async {
    await _client.from('absences').insert(absencesData);
  }

  // CORRECTION : Méthodes Admin
  Future<List<Map<String, dynamic>>> getAllProfiles() async {
    final response = await _client
        .from('profiles')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> createStaffUser({
    required String email,
    required String password,
    required String nomComplet,
    required String role,
    required String site,
  }) async {
    // Note: create_staff_user est une RPC Postgres définie dans vos migrations
    await _client.rpc('create_staff_user', params: {
      'email': email,
      'password': password,
      'nom_complet': nomComplet,
      'role': role,
      'site': site,
    });
  }

  Future<void> deleteUser(String userId) async {
    await _client.rpc('delete_staff_user', params: {'user_id': userId});
  }

  Future<List<Map<String, dynamic>>> getAuditLogs() async {
    final response = await _client
        .from('audit_log')
        .select()
        .order('timestamp', ascending: false)
        .limit(100);
    return List<Map<String, dynamic>>.from(response);
  }

  // ==================== COMMUN : MESSAGERIE ====================
  // Utilisé par Admin pour envoyer messages privés
  Future<void> sendMessage(String destinataireId, String objet, String contenu) async {
    await _client.from('messages_prives').insert({
      'expediteur_id': _client.auth.currentUser!.id,
      'destinataire_id': destinataireId,
      'objet': objet,
      'contenu': contenu,
    });
  }
}