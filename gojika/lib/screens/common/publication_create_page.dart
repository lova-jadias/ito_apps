import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:iconsax/iconsax.dart';
import '../../config/theme.dart';
import '../../providers/gojika_provider.dart';

class PublicationCreatePage extends StatefulWidget {
  final String site;
  const PublicationCreatePage({Key? key, required this.site}) : super(key: key);

  @override
  State<PublicationCreatePage> createState() => _PublicationCreatePageState();
}

class _PublicationCreatePageState extends State<PublicationCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _titreCtrl = TextEditingController();
  final _contenuCtrl = TextEditingController();
  String _type = 'communique';
  String? _groupeCible; // Null = tout le site
  bool _isSaving = false;

  final List<String> _groupes = ['GL1', 'GL2', 'GM1', 'DL1', 'AS1', 'IG1'];

  Future<void> _publier() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final user = Supabase.instance.client.auth.currentUser!;
      final profile = await Supabase.instance.client.from('profiles').select('role').eq('id', user.id).single();
      final role = profile['role'];

      // Auto-validation si Admin ou RP, sinon brouillon
      final status = (role == 'admin' || role == 'rp') ? 'publiee' : 'en_attente_validation';

      await context.read<GojikaProvider>().service.createPublication({
        'titre': _titreCtrl.text,
        'contenu': _contenuCtrl.text,
        'auteur_id': user.id,
        'site_cible': widget.site,
        'groupe_cible': _groupeCible,
        'type_publication': _type,
        'status': status,
        'date_publication': DateTime.now().toIso8601String(),
        'approuve_par_rp': (status == 'publiee'),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(status == 'publiee' ? 'Publié avec succès' : 'Soumis pour validation'),
          backgroundColor: GojikaTheme.riskGreen,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle Publication')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _titreCtrl,
                decoration: const InputDecoration(labelText: 'Titre', prefixIcon: Icon(Iconsax.text)),
                validator: (v) => v!.isEmpty ? 'Requis' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(value: 'communique', child: Text('Communiqué (Info)')),
                  DropdownMenuItem(value: 'urgent', child: Text('Urgent (Alerte)')),
                  DropdownMenuItem(value: 'rappel', child: Text('Rappel')),
                ],
                onChanged: (v) => setState(() => _type = v!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _groupeCible,
                decoration: const InputDecoration(labelText: 'Cible (Groupe)'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Tout le site (Tous les étudiants)')),
                  ..._groupes.map((g) => DropdownMenuItem(value: g, child: Text(g))),
                ],
                onChanged: (v) => setState(() => _groupeCible = v),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contenuCtrl,
                maxLines: 6,
                decoration: const InputDecoration(labelText: 'Contenu', alignLabelWithHint: true),
                validator: (v) => v!.isEmpty ? 'Requis' : null,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _publier,
                  icon: const Icon(Iconsax.send_1),
                  label: Text(_isSaving ? 'Envoi...' : 'Publier'),
                  style: ElevatedButton.styleFrom(backgroundColor: GojikaTheme.primaryBlue, foregroundColor: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}