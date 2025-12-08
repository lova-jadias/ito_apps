import 'package:shared/models/etudiant.dart';

// Énumérations
enum RiskLevel { vert, jaune, orange, rouge }
enum JustificationStatus { enAttente, validee, refusee }
enum PublicationStatus { brouillon, enAttenteValidation, publiee }
enum NotificationType { info, alerte, rappel, urgent }

// Année académique
class AnneeAcademique {
  final int id;
  final String libelle;
  final DateTime dateDebut;
  final DateTime dateFin;
  final bool isActive;

  AnneeAcademique({
    required this.id,
    required this.libelle,
    required this.dateDebut,
    required this.dateFin,
    this.isActive = false,
  });

  factory AnneeAcademique.fromJson(Map<String, dynamic> json) {
    return AnneeAcademique(
      id: json['id'],
      libelle: json['libelle'],
      dateDebut: DateTime.parse(json['date_debut']),
      dateFin: DateTime.parse(json['date_fin']),
      isActive: json['is_active'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'libelle': libelle,
      'date_debut': dateDebut.toIso8601String().split('T')[0],
      'date_fin': dateFin.toIso8601String().split('T')[0],
      'is_active': isActive,
    };
  }
}

// Semestre
class Semestre {
  final int id;
  final int anneeId;
  final int numero;
  final DateTime dateDebut;
  final DateTime dateFin;

  Semestre({
    required this.id,
    required this.anneeId,
    required this.numero,
    required this.dateDebut,
    required this.dateFin,
  });

  factory Semestre.fromJson(Map<String, dynamic> json) {
    return Semestre(
      id: json['id'],
      anneeId: json['annee_id'],
      numero: json['numero'],
      dateDebut: DateTime.parse(json['date_debut']),
      dateFin: DateTime.parse(json['date_fin']),
    );
  }
}

// Événement académique
class EvenementAcademique {
  final int id;
  final int anneeId;
  final String titre;
  final String? description;
  final DateTime dateDebut;
  final DateTime? dateFin;
  final String typeEvenement;
  final String? groupeCible;
  final String site;

  EvenementAcademique({
    required this.id,
    required this.anneeId,
    required this.titre,
    this.description,
    required this.dateDebut,
    this.dateFin,
    required this.typeEvenement,
    this.groupeCible,
    required this.site,
  });

  factory EvenementAcademique.fromJson(Map<String, dynamic> json) {
    return EvenementAcademique(
      id: json['id'],
      anneeId: json['annee_id'],
      titre: json['titre'],
      description: json['description'],
      dateDebut: DateTime.parse(json['date_debut']),
      dateFin: json['date_fin'] != null ? DateTime.parse(json['date_fin']) : null,
      typeEvenement: json['type_evenement'],
      groupeCible: json['groupe_cible'],
      site: json['site'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'annee_id': anneeId,
      'titre': titre,
      'description': description,
      'date_debut': dateDebut.toIso8601String().split('T')[0],
      'date_fin': dateFin?.toIso8601String().split('T')[0],
      'type_evenement': typeEvenement,
      'groupe_cible': groupeCible,
      'site': site,
    };
  }
}

// Matière
class Matiere {
  final int id;
  final String nom;
  final String site;
  final String? enseignantId;

  Matiere({
    required this.id,
    required this.nom,
    required this.site,
    this.enseignantId,
  });

  factory Matiere.fromJson(Map<String, dynamic> json) {
    return Matiere(
      id: json['id'],
      nom: json['nom'],
      site: json['site'],
      enseignantId: json['enseignant_id'],
    );
  }
}

// Note
class Note {
  final int id;
  final int etudiantId;
  final int matiereId;
  final double note;
  final double coefficient;
  final String type;
  final int? categorieExamenId;
  final int? semestreId;
  final bool approuveParRp;

  Note({
    required this.id,
    required this.etudiantId,
    required this.matiereId,
    required this.note,
    this.coefficient = 1.0,
    required this.type,
    this.categorieExamenId,
    this.semestreId,
    this.approuveParRp = false,
  });

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'],
      etudiantId: json['etudiant_id'],
      matiereId: json['matiere_id'],
      note: (json['note'] as num).toDouble(),
      coefficient: json['coefficient'] != null ? (json['coefficient'] as num).toDouble() : 1.0,
      type: json['type'],
      categorieExamenId: json['categorie_examen_id'],
      semestreId: json['semestre_id'],
      approuveParRp: json['approuve_par_rp'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'etudiant_id': etudiantId,
      'matiere_id': matiereId,
      'note': note,
      'coefficient': coefficient,
      'type': type,
      'categorie_examen_id': categorieExamenId,
      'semestre_id': semestreId,
    };
  }
}

// Absence
class Absence {
  final int id;
  final int etudiantId;
  final DateTime dateAbsence;
  final int? matiereId;
  final int? seanceId;
  final bool estRetard;
  final int? justificationId;
  final bool enregistreParDelegue;
  final bool approuveParRp;

  Absence({
    required this.id,
    required this.etudiantId,
    required this.dateAbsence,
    this.matiereId,
    this.seanceId,
    this.estRetard = false,
    this.justificationId,
    this.enregistreParDelegue = false,
    this.approuveParRp = false,
  });

  factory Absence.fromJson(Map<String, dynamic> json) {
    return Absence(
      id: json['id'],
      etudiantId: json['etudiant_id'],
      dateAbsence: DateTime.parse(json['date_absence']),
      matiereId: json['matiere_id'],
      seanceId: json['seance_id'],
      estRetard: json['est_retard'] ?? false,
      justificationId: json['justification_id'],
      enregistreParDelegue: json['enregistre_par_delegue'] ?? false,
      approuveParRp: json['approuve_par_rp'] ?? false,
    );
  }
}

// Justification
class Justification {
  final int id;
  final int etudiantId;
  final String soumisParUserId;
  final String motif;
  final String? fichierUrl;
  final JustificationStatus status;
  final DateTime dateSoumission;
  final String? valideParUserId;
  final List<int>? absenceIds;

  Justification({
    required this.id,
    required this.etudiantId,
    required this.soumisParUserId,
    required this.motif,
    this.fichierUrl,
    this.status = JustificationStatus.enAttente,
    required this.dateSoumission,
    this.valideParUserId,
    this.absenceIds,
  });

  factory Justification.fromJson(Map<String, dynamic> json) {
    return Justification(
      id: json['id'],
      etudiantId: json['etudiant_id'],
      soumisParUserId: json['soumis_par_user_id'],
      motif: json['motif'],
      fichierUrl: json['fichier_url'],
      status: _statusFromString(json['status']),
      dateSoumission: DateTime.parse(json['date_soumission']),
      valideParUserId: json['valide_par_user_id'],
      absenceIds: json['absence_ids'] != null ? List<int>.from(json['absence_ids']) : null,
    );
  }

  static JustificationStatus _statusFromString(String status) {
    switch (status) {
      case 'validee': return JustificationStatus.validee;
      case 'refusee': return JustificationStatus.refusee;
      default: return JustificationStatus.enAttente;
    }
  }
}

// Publication
class Publication {
  final int id;
  final String titre;
  final String contenu;
  final String auteurId;
  final PublicationStatus status;
  final String siteCible;
  final String? groupeCible;
  final String typePublication;
  final String? lienVideo;
  final String? imageUrl;
  final DateTime datePublication;
  final bool approuveParRp;

  Publication({
    required this.id,
    required this.titre,
    required this.contenu,
    required this.auteurId,
    this.status = PublicationStatus.publiee,
    required this.siteCible,
    this.groupeCible,
    this.typePublication = 'communique',
    this.lienVideo,
    this.imageUrl,
    required this.datePublication,
    this.approuveParRp = false,
  });

  factory Publication.fromJson(Map<String, dynamic> json) {
    return Publication(
      id: json['id'],
      titre: json['titre'],
      contenu: json['contenu'],
      auteurId: json['auteur_id'],
      status: _statusFromString(json['status']),
      siteCible: json['site_cible'],
      groupeCible: json['groupe_cible'],
      typePublication: json['type_publication'] ?? 'communique',
      lienVideo: json['lien_video'],
      imageUrl: json['image_url'],
      datePublication: DateTime.parse(json['date_publication']),
      approuveParRp: json['approuve_par_rp'] ?? false,
    );
  }

  static PublicationStatus _statusFromString(String status) {
    switch (status) {
      case 'publiee': return PublicationStatus.publiee;
      case 'en_attente_validation': return PublicationStatus.enAttenteValidation;
      default: return PublicationStatus.brouillon;
    }
  }
}

// Notification
class NotificationModel {
  final int id;
  final String userId;
  final String titre;
  final String message;
  final NotificationType type;
  final String? lien;
  final bool lu;
  final DateTime? luLe;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.titre,
    required this.message,
    required this.type,
    this.lien,
    this.lu = false,
    this.luLe,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      userId: json['user_id'],
      titre: json['titre'],
      message: json['message'],
      type: _typeFromString(json['type_notification']),
      lien: json['lien'],
      lu: json['lu'] ?? false,
      luLe: json['lu_le'] != null ? DateTime.parse(json['lu_le']) : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  static NotificationType _typeFromString(String type) {
    switch (type) {
      case 'alerte': return NotificationType.alerte;
      case 'rappel': return NotificationType.rappel;
      case 'urgent': return NotificationType.urgent;
      default: return NotificationType.info;
    }
  }
}

// Emploi du temps
class EmploiDuTemps {
  final int id;
  final int matiereId;
  final String groupe;
  final String? salle;
  final int jourSemaine;
  final String heureDebut;
  final String heureFin;
  final String site;

  EmploiDuTemps({
    required this.id,
    required this.matiereId,
    required this.groupe,
    this.salle,
    required this.jourSemaine,
    required this.heureDebut,
    required this.heureFin,
    required this.site,
  });

  factory EmploiDuTemps.fromJson(Map<String, dynamic> json) {
    return EmploiDuTemps(
      id: json['id'],
      matiereId: json['matiere_id'],
      groupe: json['groupe'],
      salle: json['salle'],
      jourSemaine: json['jour_semaine'],
      heureDebut: json['heure_debut'],
      heureFin: json['heure_fin'],
      site: json['site'],
    );
  }
}

// Mot de la semaine
class MotSemaine {
  final int id;
  final String texte;
  final String? auteur;
  final DateTime dateDebut;
  final DateTime dateFin;
  final bool isActive;

  MotSemaine({
    required this.id,
    required this.texte,
    this.auteur,
    required this.dateDebut,
    required this.dateFin,
    this.isActive = true,
  });

  factory MotSemaine.fromJson(Map<String, dynamic> json) {
    return MotSemaine(
      id: json['id'],
      texte: json['texte'],
      auteur: json['auteur'],
      dateDebut: DateTime.parse(json['date_debut']),
      dateFin: DateTime.parse(json['date_fin']),
      isActive: json['is_active'] ?? true,
    );
  }
}