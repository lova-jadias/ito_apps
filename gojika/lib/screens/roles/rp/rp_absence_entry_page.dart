import 'package:flutter/material.dart';
import 'package:gojika/providers/gojika_provider.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/theme.dart';
import '../../../providers/gojika_provider.dart';



class RPAbsenceEntryPage extends StatefulWidget {
  final String site;
  const RPAbsenceEntryPage({Key? key, required this.site}) : super(key: key);

  @override
  State<RPAbsenceEntryPage> createState() => _RPAbsenceEntryPageState();
}

class _RPAbsenceEntryPageState extends State<RPAbsenceEntryPage> {
  String? _selectedGroupe;
  int? _selectedMatiereId; // Optionnel si absence générale
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _heureDebut = const TimeOfDay(hour: 8, minute: 0);

  // Set des IDs étudiants absents
  final Set<int> _absentIds = {};

  bool _isLoadingList = false;
  bool _isSaving = false;
  final List<String> _groupes = ['GL1', 'GL2', 'GM1', 'DL1', 'AS1', 'IG1'];

  Future<void> _chargerEtudiants() async {
    if (_selectedGroupe == null) return;
    await context.read<GojikaProvider>().loadDonneesSaisie(widget.site, _selectedGroupe!);
    setState(() => _absentIds.clear());
  }

  Future<void> _sauvegarderAbsences() async {
    if (_selectedGroupe == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez sélectionner un groupe')));
      return;
    }

    if (_absentIds.isEmpty) {
      // Confirmation si personne n'est absent ? Ou juste retour.
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucun étudiant marqué absent.')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final List<Map<String, dynamic>> absencesASauvegarder = [];
      final currentUser = Supabase.instance.client.auth.currentUser!.id;

      // Combiner Date et Heure
      // Note: La table 'absences' a 'date_absence'. Si on veut l'heure précise, il faudrait 'seance_id'
      // Pour simplifier selon le schéma[cite: 112], on utilise date_absence.

      for (var etudiantId in _absentIds) {
        absencesASauvegarder.add({
          'etudiant_id': etudiantId,
          'date_absence': _selectedDate.toIso8601String().split('T')[0],
          'matiere_id': _selectedMatiereId, // Peut être null
          'saisie_par_user_id': currentUser,
          // 'seance_id': ... // Si on gérait les séances strictement
          'est_retard': false, // Checkbox retard possible future amélioration
        });
      }

      await context.read<GojikaProvider>().soumettreAbsencesGroupe(absencesASauvegarder);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${absencesASauvegarder.length} absences enregistrées'),
          backgroundColor: GojikaTheme.riskGreen,
        ));
        Navigator.pop(context);
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
      appBar: AppBar(title: const Text('Saisie des Absences')),
      body: Column(
        children: [
          // --- FILTRES ---
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[50],
            child: Column(
              children: [
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
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final d = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now()
                          );
                          if (d != null) setState(() => _selectedDate = d);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Date'),
                          child: Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'Matière concernée (Optionnel)'),
                  value: _selectedMatiereId,
                  items: [
                    const DropdownMenuItem<int>(value: null, child: Text('Toute la journée / Non spécifié')),
                    ...provider.matieresSite.map((m) => DropdownMenuItem(value: m.id, child: Text(m.nom, overflow: TextOverflow.ellipsis))),
                  ],
                  onChanged: (val) => setState(() => _selectedMatiereId = val),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // --- INFO HEADER ---
          if (_selectedGroupe != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: GojikaTheme.riskRed.withOpacity(0.1),
              width: double.infinity,
              child: Text(
                'Cochez les étudiants ABSENTS (${_absentIds.length} sélectionnés)',
                style: const TextStyle(color: GojikaTheme.riskRed, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),

          // --- LISTE ---
          Expanded(
            child: _isLoadingList || provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : _selectedGroupe == null
                ? const Center(child: Text('Sélectionnez un groupe'))
                : ListView.separated(
              itemCount: provider.etudiantsGroupeActuel.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final etudiant = provider.etudiantsGroupeActuel[index];
                final isAbsent = _absentIds.contains(etudiant['id']);

                return CheckboxListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  activeColor: GojikaTheme.riskRed,
                  title: Text(
                      '${etudiant['nom']} ${etudiant['prenom'] ?? ''}',
                      style: TextStyle(
                        fontWeight: isAbsent ? FontWeight.bold : FontWeight.normal,
                        color: isAbsent ? GojikaTheme.riskRed : Colors.black,
                      )
                  ),
                  subtitle: Text(etudiant['id_etudiant_genere'] ?? ''),
                  secondary: CircleAvatar(
                    child: Text(etudiant['nom'][0]),
                  ),
                  value: isAbsent,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _absentIds.add(etudiant['id']);
                      } else {
                        _absentIds.remove(etudiant['id']);
                      }
                    });
                  },
                );
              },
            ),
          ),

          // --- BOUTON ---
          Container(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _sauvegarderAbsences,
                icon: const Icon(Iconsax.tick_circle),
                label: Text(_isSaving ? 'Enregistrement...' : 'Valider les absences'),
                style: ElevatedButton.styleFrom(backgroundColor: GojikaTheme.riskRed, foregroundColor: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}