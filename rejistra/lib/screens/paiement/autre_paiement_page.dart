// rejistra/lib/screens/paiement/autre_paiement_page.dart
// ignore_for_file: prefer_const_constructors, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:rejistra/providers/auth_provider.dart';
import 'package:rejistra/providers/data_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AutrePaiementPage extends StatefulWidget {
  const AutrePaiementPage({Key? key}) : super(key: key);

  @override
  State<AutrePaiementPage> createState() => _AutrePaiementPageState();
}

class _AutrePaiementPageState extends State<AutrePaiementPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  String? _selectedMotif;
  final _montantController = TextEditingController();
  String? _selectedModePaiement;
  final _recuController = TextEditingController();

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final user = context.read<AuthProvider>().currentUser!;
      final total = double.parse(_montantController.text);

      // Insérer le reçu principal SANS id_etudiant
      await Supabase.instance.client.from('recus').insert({
        'id_etudiant': null,
        'site': user.site,
        'created_by_user_id': user.id,
        'n_recu_principal': _recuController.text,
        'montant_total': total,
        'mode_paiement': _selectedModePaiement,
        'ref_transaction': _selectedMotif, // On utilise ref pour le motif
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Autre paiement enregistré avec succès.'),
        backgroundColor: Colors.green,
      ));

      _formKey.currentState?.reset();
      _montantController.clear();
      _recuController.clear();
      setState(() {
        _selectedMotif = null;
        _selectedModePaiement = null;
      });

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString()),
        backgroundColor: Colors.red,
      ));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<DataProvider>().configOptions;
    final user = context.read<AuthProvider>().currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Enregistrer un "Autre Paiement"'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: 900),
          padding: EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Opérations non liées à un étudiant", style: Theme.of(context).textTheme.headlineSmall),
                  Text("Exemple: Dépôt de dossiers, achat de fournitures, etc."),
                  SizedBox(height: 24),
                  Wrap(
                    spacing: 16, runSpacing: 16,
                    children: [
                      _ReadOnlyField(label: "Date Opération", value: DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()), icon: Icons.today),
                      _ReadOnlyField(label: "Opérateur", value: user?.nomComplet ?? 'N/A', icon: Icons.person_pin),
                    ],
                  ),
                  SizedBox(height: 16),
                  Wrap(
                    spacing: 16, runSpacing: 16,
                    children: [
                      _buildDropdown("Motif *", config['MotifsAutres'], (val) => setState(() => _selectedMotif = val)),
                      _buildDropdown("Mode de Paiement *", config['ModePaiement'], (val) => setState(() => _selectedModePaiement = val)),
                      _buildTextField("Nº Reçu *", _recuController),
                      ConstrainedBox(
                        constraints: BoxConstraints(minWidth: 280),
                        child: TextFormField(
                          controller: _montantController,
                          decoration: InputDecoration(labelText: "Montant (Ar) *", prefixText: "Ar "),
                          keyboardType: TextInputType.number,
                          validator: (value) => (value == null || value.isEmpty || double.tryParse(value) == null) ? 'Montant invalide' : null,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 32),
                  if (_isSaving) CircularProgressIndicator() else ElevatedButton.icon(
                    onPressed: _enregistrer,
                    icon: Icon(Icons.save),
                    label: Text('Enregistrer l\'opération'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // -- Widgets Helpers --
  Widget _buildDropdown(String label, List<String>? items, ValueChanged<String?> onChanged) {
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: 280),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(labelText: label),
        items: (items ?? []).map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
        onChanged: onChanged,
        validator: (value) => value == null ? 'Champ requis' : null,
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: 280),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        validator: (value) => (value == null || value.isEmpty) ? 'Champ requis' : null,
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  const _ReadOnlyField({required this.label, required this.value, required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color ?? Colors.grey.shade700, size: 20),
          SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}