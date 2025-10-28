// rejistra/lib/screens/paiement/paiement_etudiant_page.dart
// ignore_for_file: prefer_const_constructors, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:rejistra/providers/auth_provider.dart';
import 'package:rejistra/providers/data_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PaiementEtudiantPage extends StatefulWidget {
  const PaiementEtudiantPage({Key? key}) : super(key: key);

  @override
  State<PaiementEtudiantPage> createState() => _PaiementEtudiantPageState();
}

class _PaiementEtudiantPageState extends State<PaiementEtudiantPage> {
  Map<String, dynamic>? _selectedStudent;
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // Champs du formulaire
  String? _selectedMotif;
  final _montantController = TextEditingController();
  String? _selectedModePaiement;
  final _recuController = TextEditingController();
  String? _selectedMois;
  bool _moisDeActif = false;

  void _updateMoisDeField(String? newMotif) {
    setState(() {
      _selectedMotif = newMotif;
      _moisDeActif = (newMotif == "Écolage mensuel");
      if (!_moisDeActif) {
        _selectedMois = null;
      }
    });
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _montantController.clear();
    _recuController.clear();
    setState(() {
      _selectedMotif = null;
      _selectedModePaiement = null;
      _selectedMois = null;
      _moisDeActif = false;
    });
  }

  // Dans rejistra/lib/screens/paiement/paiement_etudiant_page.dart

  // ... (le début de la classe _PaiementEtudiantPageState reste le même)

  // REMPLACEZ CETTE MÉTHODE
  Future<void> _validerPaiement() async {
    if (_selectedStudent == null || !_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // CORRECTION: On construit la requête de base
      var query = Supabase.instance.client
          .from('paiement_items')
          .select('id')
          .eq('id_etudiant', _selectedStudent!['id'])
          .eq('motif', _selectedMotif!);

      // CORRECTION: On ajoute le filtre 'mois_de' SEULEMENT s'il n'est pas null
      if (_selectedMois != null) {
        query = query.eq('mois_de', _selectedMois!);
      }

      // On exécute la requête pour vérifier les doublons
      final existingPayment = await query.maybeSingle();

      if (existingPayment != null) {
        throw 'Un paiement pour ce motif (ou ce mois) existe déjà pour cet étudiant.';
      }

      final user = context.read<AuthProvider>().currentUser!;
      final total = double.parse(_montantController.text);

      // Insérer le reçu principal
      final recuData = await Supabase.instance.client.from('recus').insert({
        'id_etudiant': _selectedStudent!['id'],
        'site': user.site,
        'created_by_user_id': user.id,
        'n_recu_principal': _recuController.text,
        'montant_total': total,
        'mode_paiement': _selectedModePaiement,
      }).select().single();

      // Insérer la ligne de détail
      await Supabase.instance.client.from('paiement_items').insert({
        'id_recu': recuData['id'],
        'id_etudiant': _selectedStudent!['id'],
        'motif': _selectedMotif!,
        'montant': total,
        'mois_de': _selectedMois,
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Paiement enregistré avec succès pour ${_selectedStudent!['nom']}.'),
        backgroundColor: Colors.green,
      ));

      setState(() {
        _selectedStudent = null;
        // La fonction _resetForm() est appelée depuis votre code original
        _resetForm();
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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Enregistrer un Paiement Étudiant'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: 900),
          padding: EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("1. Rechercher l'étudiant", style: Theme.of(context).textTheme.headlineSmall),
                SizedBox(height: 12),
                Autocomplete<Map<String, dynamic>>(
                  displayStringForOption: (option) => '${option['id_etudiant_genere']} - ${option['nom']} ${option['prenom'] ?? ''}',
                  optionsBuilder: (TextEditingValue textEditingValue) async {
                    if (textEditingValue.text.isEmpty) {
                      return const Iterable<Map<String, dynamic>>.empty();
                    }
                    final response = await Supabase.instance.client
                        .from('etudiants')
                        .select('id, id_etudiant_genere, nom, prenom, groupe, statut')
                        .or('nom.ilike.%${textEditingValue.text}%,prenom.ilike.%${textEditingValue.text}%,id_etudiant_genere.ilike.%${textEditingValue.text}%')
                        .limit(10);
                    return response;
                  },
                  onSelected: (selection) {
                    setState(() {
                      _selectedStudent = selection;
                      _resetForm();
                    });
                  },
                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                          labelText: 'Rechercher par ID, Nom ou Prénom',
                          prefixIcon: Icon(Icons.search),
                          suffixIcon: IconButton(
                            icon: Icon(Icons.clear),
                            onPressed: () {
                              controller.clear();
                              setState(() => _selectedStudent = null);
                            },
                          )
                      ),
                    );
                  },
                ),
                SizedBox(height: 24),
                if (_selectedStudent != null) _buildPaymentForm(config),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentForm(Map<String, List<String>> config) {
    final user = context.read<AuthProvider>().currentUser;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("2. Saisir le paiement", style: Theme.of(context).textTheme.headlineSmall),
          SizedBox(height: 12),
          Card(
            color: Colors.blue.shade50,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.blue.shade200)),
            child: ListTile(
              leading: CircleAvatar(child: Icon(Icons.person)),
              title: Text('${_selectedStudent!['nom']} ${_selectedStudent!['prenom'] ?? ''}', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('ID: ${_selectedStudent!['id_etudiant_genere']} | Groupe: ${_selectedStudent!['groupe']} | Statut: ${_selectedStudent!['statut']}'),
            ),
          ),
          SizedBox(height: 16),
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
              _buildDropdown("Motif de Paiement *", config['Motifs'], _updateMoisDeField),
              _buildDropdown("Mode de Paiement *", config['ModePaiement'], (val) => setState(() => _selectedModePaiement = val)),
              ConstrainedBox(
                constraints: BoxConstraints(minWidth: 280),
                child: DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: "Mois de (si écolage)",
                    filled: !_moisDeActif,
                    fillColor: Colors.grey.shade200,
                  ),
                  items: (config['Mois de'] ?? []).map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
                  onChanged: _moisDeActif ? (val) => setState(() => _selectedMois = val) : null,
                  validator: (value) => (_moisDeActif && value == null) ? 'Mois requis pour écolage' : null,
                ),
              ),
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
          SizedBox(height: 16),
          Text("Note: Pour les paiements groupés sur un seul reçu, enregistrez le premier motif, puis recommencez avec le même Nº Reçu.", style: Theme.of(context).textTheme.bodySmall),
          SizedBox(height: 24),
          if (_isSaving) CircularProgressIndicator() else ElevatedButton.icon(
            onPressed: _validerPaiement,
            icon: Icon(Icons.check_circle),
            label: Text('Valider le Paiement'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
          ),
        ],
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

// Widget copié depuis inscription_page.dart
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