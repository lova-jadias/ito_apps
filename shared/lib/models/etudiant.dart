// Créez ce fichier s'il n'existe pas
import 'package:flutter/foundation.dart';

// Basé sur le schéma 'etudiants' (Source: 1052-1054)
class Etudiant {
  final int id; // L'ID auto-incrémenté (PK)
  final String? idEtudiantGenere; // "1-25-T"
  final String nom;
  final String? prenom;
  final DateTime? dateNaissance;
  final String? emailContact;
  final String? telephone;
  final String? photoUrl;
  final String site; // 'T', 'TO', etc.
  final String? mentionModule;
  final String? niveau;
  final String? groupe;
  final String? departement;
  final String statut; // 'Actif', 'Abandon'...
  final DateTime? statutMajLe;
  final DateTime? dateInscription;

  Etudiant({
    required this.id,
    this.idEtudiantGenere,
    required this.nom,
    this.prenom,
    this.dateNaissance,
    this.emailContact,
    this.telephone,
    this.photoUrl,
    required this.site,
    this.mentionModule,
    this.niveau,
    this.groupe,
    this.departement,
    required this.statut,
    this.statutMajLe,
    this.dateInscription,
  });

  // Factory pour créer un Etudiant depuis un JSON (Réponse Supabase)
  factory Etudiant.fromJson(Map<String, dynamic> json) {
    return Etudiant(
      id: json['id'],
      idEtudiantGenere: json['id_etudiant_genere'],
      nom: json['nom'],
      prenom: json['prenom'],
      dateNaissance: json['date_naissance'] != null
          ? DateTime.parse(json['date_naissance'])
          : null,
      emailContact: json['email_contact'],
      telephone: json['telephone'],
      photoUrl: json['photo_url'],
      site: json['site'],
      mentionModule: json['mention_module'],
      niveau: json['niveau'],
      groupe: json['groupe'],
      departement: json['departement'],
      statut: json['statut'],
      statutMajLe: json['statut_maj_le'] != null
          ? DateTime.parse(json['statut_maj_le'])
          : null,
      dateInscription: json['date_inscription'] != null
          ? DateTime.parse(json['date_inscription'])
          : null,
    );
  }

  // Méthode pour convertir un Etudiant en Map pour l'insertion Supabase
  // Note: On n'inclut pas les champs auto-générés (id, id_etudiant_genere, site, etc.)
  Map<String, dynamic> toJsonForInsert() {
    return {
      'nom': nom,
      'prenom': prenom,
      'date_naissance': dateNaissance?.toIso8601String(),
      'email_contact': emailContact,
      'telephone': telephone,
      'mention_module': mentionModule,
      'niveau': niveau,
      'groupe': groupe,
      'departement': departement,
      // 'statut' a une valeur par défaut 'Actif' dans la DB (Source: 1053)
      // 'site' sera rempli par le trigger (Source: 1081)
    };
  }
}