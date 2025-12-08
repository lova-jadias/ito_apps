import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/theme.dart';
import '../../../models/models.dart';
import '../../../providers/gojika_provider.dart';
import 'package:iconsax/iconsax.dart';

class RPNotesEntryPage extends StatefulWidget {
  final String site;
  const RPNotesEntryPage({Key? key, required this.site}) : super(key: key);

  @override
  State<RPNotesEntryPage> createState() => _RPNotesEntryPageState();
}

class _RPNotesEntryPageState extends State<RPNotesEntryPage> {
  // Sélecteurs
  String? _selectedGroupe;
  int? _selectedMatiereId;
  int? _selectedCategorieId;
  int? _selectedSemestreId;

  // Contrôleurs pour les champs de notes : Map<EtudiantID, Controller>
  final Map<int, TextEditingController> _controllers = {};

  bool _isLoadingList = false;
  bool _isSaving = false;

  // Liste des groupes (Statique pour l'instant ou via config)
  final List<String> _groupes = ['GL1', 'GL2', 'GM1', 'DL1', 'AS1', 'IG1'];

  Future<void> _chargerEtudiants() async {
    if (_selectedGroupe == null) return;

    // Charger les données nécessaires via le provider
    await context.read<GojikaProvider>().loadDonneesSaisie(widget.site, _selectedGroupe!);

    // Initialiser les contrôleurs pour chaque étudiant chargé
    final etudiants = context.read<GojikaProvider>().etudiantsGroupeActuel;
    _controllers.clear();
    for (var e in etudiants) {
      _controllers[e['id']] = TextEditingController();
    }
  }

  Future<void> _sauvegarderNotes() async {
    if (_selectedMatiereId == null || _selectedCategorieId == null || _selectedSemestreId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez sélectionner Matière, Catégorie et Semestre')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final List<Map<String, dynamic>> notesASauvegarder = [];
      final currentUser = Supabase.instance.client.auth.currentUser!.id;

      // Parcourir les contrôleurs
      _controllers.forEach((etudiantId, controller) {
        final text = controller.text.trim();
        if (text.isNotEmpty) {
          final noteVal = double.tryParse(text.replaceAll(',', '.'));
          if (noteVal != null) {
            notesASauvegarder.add({
              'etudiant_id': etudiantId,
              'matiere_id': _selectedMatiereId,
              'categorie_examen_id': _selectedCategorieId,
              'semestre_id': _selectedSemestreId,
              'note': noteVal,
              'type': 'Saisie RP', // Ou libellé catégorie
              'saisie_par_user_id': currentUser, // Important pour Audit
              'approuve_par_rp': true, // Auto-approuvé car saisi par RP
              'approuve_le': DateTime.now().toIso8601String(),
            });
          }
        }
      });

      if (notesASauvegarder.isNotEmpty) {
        await context.read<GojikaProvider>().soumettreNotesGroupe(notesASauvegarder);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${notesASauvegarder.length} notes enregistrées avec succès'),
            backgroundColor: GojikaTheme.riskGreen,
          ));
          Navigator.pop(context); // Retour
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucune note saisie')));
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GojikaProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Saisie des Notes')),
      body: Column(
        children: [
          // --- ZONE DE FILTRES ---
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[50],
            child: Column(
              children: [
                // Ligne 1: Groupe & Semestre
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Groupe'),
                        value: _selectedGroupe,
                        items: _groupes.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedGroupe = val;
                            _isLoadingList = true;
                          });
                          _chargerEtudiants().then((_) => setState(() => _isLoadingList = false));
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Semestre (chargé depuis provider)
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        decoration: const InputDecoration(labelText: 'Semestre'),
                        value: _selectedSemestreId,
                        items: provider.semestresActifs.map((s) => DropdownMenuItem(value: s.id, child: Text('Semestre ${s.numero}'))).toList(),
                        onChanged: (val) => setState(() => _selectedSemestreId = val),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Ligne 2: Matière & Catégorie
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<int>(
                        decoration: const InputDecoration(labelText: 'Matière'),
                        value: _selectedMatiereId,
                        isExpanded: true, // Pour éviter l'overflow texte long
                        items: provider.matieresSite.map((m) => DropdownMenuItem(value: m.id, child: Text(m.nom, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (val) => setState(() => _selectedMatiereId = val),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<int>(
                        decoration: const InputDecoration(labelText: 'Type'),
                        value: _selectedCategorieId,
                        items: provider.categoriesExamens.map((c) => DropdownMenuItem<int>(value: c['id'], child: Text(c['libelle']))).toList(),
                        onChanged: (val) => setState(() => _selectedCategorieId = val),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // --- LISTE DES ÉTUDIANTS ---
          Expanded(
            child: _isLoadingList || provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : _selectedGroupe == null
                ? const Center(child: Text('Sélectionnez un groupe pour commencer'))
                : provider.etudiantsGroupeActuel.isEmpty
                ? const Center(child: Text('Aucun étudiant trouvé dans ce groupe'))
                : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: provider.etudiantsGroupeActuel.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final etudiant = provider.etudiantsGroupeActuel[index];
                return Row(
                  children: [
                    // Photo et Nom
                    CircleAvatar(
                      backgroundColor: GojikaTheme.primaryBlue.withOpacity(0.1),
                      child: Text(etudiant['nom'][0], style: const TextStyle(color: GojikaTheme.primaryBlue)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${etudiant['nom']} ${etudiant['prenom'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text(etudiant['id_etudiant_genere'] ?? 'N/A', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        ],
                      ),
                    ),
                    // Champ Note
                    SizedBox(
                      width: 80,
                      child: TextFormField(
                        controller: _controllers[etudiant['id']],
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          hintText: '/ 20',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) return null;
                          final n = double.tryParse(val.replaceAll(',', '.'));
                          if (n == null || n < 0 || n > 20) return '!';
                          return null;
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // --- BOUTON SAUVEGARDER ---
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _sauvegarderNotes,
                icon: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Iconsax.save_2),
                label: Text(_isSaving ? 'Enregistrement...' : 'Enregistrer les notes'),
                style: ElevatedButton.styleFrom(backgroundColor: GojikaTheme.primaryBlue, foregroundColor: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}