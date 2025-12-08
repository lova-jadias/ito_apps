import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/theme.dart';
import '../../../models/models.dart';
import '../../../providers/gojika_provider.dart';

class AdminMotSemainePage extends StatefulWidget {
  const AdminMotSemainePage({Key? key}) : super(key: key);

  @override
  State<AdminMotSemainePage> createState() => _AdminMotSemainePageState();
}

class _AdminMotSemainePageState extends State<AdminMotSemainePage> {
  final _texteCtrl = TextEditingController();
  final _auteurCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Charger le mot actuel
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<GojikaProvider>();
      await provider.loadMotSemaine();
      if (provider.motSemaine != null) {
        _texteCtrl.text = provider.motSemaine!.texte;
        _auteurCtrl.text = provider.motSemaine!.auteur ?? '';
      }
    });
  }

  Future<void> _saveMot() async {
    if (_texteCtrl.text.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      final mot = MotSemaine(
        id: 0, // Ignoré à l'insert
        texte: _texteCtrl.text,
        auteur: _auteurCtrl.text.isEmpty ? null : _auteurCtrl.text,
        dateDebut: DateTime.now(),
        dateFin: DateTime.now().add(const Duration(days: 7)),
        isActive: true,
      );

      // Désactiver les anciens
      await Supabase.instance.client.from('mot_semaine').update({'is_active': false}).neq('id', -1);

      // Créer le nouveau via Service
      await context.read<GojikaProvider>().service.createMotSemaine(mot);

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mot de la semaine mis à jour')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mot de la Semaine')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: GojikaTheme.accentGold.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: const Row(
                children: [
                  Icon(Iconsax.info_circle, color: GojikaTheme.accentGold),
                  SizedBox(width: 12),
                  Expanded(child: Text("Ce message sera visible par tous les étudiants sur leur écran d'accueil.")),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _texteCtrl,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Citation / Message', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _auteurCtrl,
              decoration: const InputDecoration(labelText: 'Auteur (Optionnel)', prefixIcon: Icon(Iconsax.user)),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveMot,
                icon: const Icon(Iconsax.save_2),
                label: Text(_isSaving ? 'Enregistrement...' : 'Publier'),
                style: ElevatedButton.styleFrom(backgroundColor: GojikaTheme.primaryBlue, foregroundColor: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}