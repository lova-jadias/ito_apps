import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:rejistra/providers/data_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// Assurez-vous d'importer votre modèle depuis le package partagé
import 'package:shared/models/etudiant.dart';

class InscriptionPage extends StatefulWidget {
  const InscriptionPage({Key? key}) : super(key: key);

  @override
  State<InscriptionPage> createState() => _InscriptionPageState();
}

class _InscriptionPageState extends State<InscriptionPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Contrôleurs pour les champs
  final _nomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _emailController = TextEditingController();
  final _telController = TextEditingController();
  DateTime? _dateNaissance;
  String? _selectedMention;
  String? _selectedNiveau;
  String? _selectedGroupe;
  String? _selectedDepartement;

  // Champs non modifiables (Source: 304)
  final String _paymentDate =
  DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
  final String _statut = "Actif"; // (Source: 289)

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _emailController.dispose();
    _telController.dispose();
    super.dispose();
  }

  // Fonction d'inscription (connectée à Supabase)
  Future<void> _inscrire() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() { _isLoading = true; });

    try {
      // 1. Créer l'objet Etudiant à partir du formulaire
      // (Nous n'utilisons pas le constructeur complet, seulement la map pour l'insertion)
      final etudiantData = {
        'nom': _nomController.text.trim(),
        'prenom': _prenomController.text.trim(),
        'date_naissance': _dateNaissance?.toIso8601String(),
        'email_contact': _emailController.text.trim(),
        'telephone': _telController.text.trim(),
        'mention_module': _selectedMention,
        'niveau': _selectedNiveau,
        'groupe': _selectedGroupe,
        'departement': _selectedDepartement,
        // 'site' est géré par le trigger (Source: 1081)
        // 'id_etudiant_genere' est géré par le trigger (Source: 1081)
        // 'statut' a une valeur par défaut dans la DB (Source: 1053)
      };

      // 2. Insérer dans Supabase (Source: 1240)
      final response = await Supabase.instance.client
          .from('etudiants')
          .insert(etudiantData)
          .select() // Demande à Supabase de retourner la ligne insérée
          .single(); // S'assure qu'une seule ligne est retournée

      // 3. Gérer le succès
      final newIdGenere = response['id_etudiant_genere'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Étudiant ${_nomController.text} inscrit (ID: $newIdGenere)'),
          backgroundColor: Colors.green,
        ),
      );

      // 4. Réinitialiser le formulaire
      _formKey.currentState?.reset();
      _nomController.clear();
      _prenomController.clear();
      _emailController.clear();
      _telController.clear();
      setState(() {
        _dateNaissance = null;
        _selectedMention = null;
        _selectedNiveau = null;
        _selectedGroupe = null;
        _selectedDepartement = null;
      });

    } on PostgrestException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur d'inscription: ${e.message}"),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Une erreur inattendue est survenue: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() { _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    // Récupère le provider de config
    final dataProvider = Provider.of<DataProvider>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Enregistrer un nouvel Étudiant'),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: 900),
          padding: EdgeInsets.all(24),
          // SingleChildScrollView pour éviter les overflows sur petits écrans
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Formulaire d'inscription",
                      style: Theme.of(context).textTheme.headlineSmall),
                  Text(
                      "Remplissez les champs pour enregistrer un étudiant."),
                  SizedBox(height: 24),

                  // Champs de statut (non modifiables) (Source: 304)
                  _buildReadOnlyInfoSection(),
                  SizedBox(height: 16),

                  // Formulaire
                  // Wrap permet aux champs de passer à la ligne sur mobile
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      // Champs d'identité
                      _buildTextField("Nom *", _nomController),
                      _buildTextField("Prénom", _prenomController, isRequired: false),
                      _buildDateField(context, "Date de Naissance"),

                      // Champs de contact
                      _buildTextField("Email de contact", _emailController, isRequired: false, keyboardType: TextInputType.emailAddress),
                      _buildTextField("Téléphone", _telController, isRequired: false, keyboardType: TextInputType.phone),

                      // Champs académiques (chargés depuis le provider)
                      _buildDropdown("Mention/Module *", dataProvider.configOptions['MentionModule'], (val) => setState(() => _selectedMention = val)),
                      _buildDropdown("Niveau *", dataProvider.configOptions['Niveau'], (val) => setState(() => _selectedNiveau = val)),
                      _buildDropdown("Groupe *", dataProvider.configOptions['Groupe'], (val) => setState(() => _selectedGroupe = val)),
                      _buildDropdown("Département *", dataProvider.configOptions['Département'], (val) => setState(() => _selectedDepartement = val)),
                    ],
                  ),
                  SizedBox(height: 32),

                  _isLoading
                      ? Center(child: CircularProgressIndicator())
                      : ElevatedButton.icon(
                    onPressed: _inscrire,
                    icon: Icon(Icons.save),
                    label: Text('Enregistrer l\'étudiant'),
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

  // --- Widgets Helpers (basés sur le prototype) ---

  Widget _buildReadOnlyInfoSection() {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        // L'ID est maintenant généré par la DB (Source: 1081)
        _ReadOnlyField(
            label: "ID Étudiant",
            value: "Généré à la validation",
            icon: Icons.vpn_key),
        _ReadOnlyField(
            label: "Date Opération", value: _paymentDate, icon: Icons.today),
        _ReadOnlyField(
            label: "Statut Initial",
            value: _statut,
            icon: Icons.check_circle_outline,
            color: Colors.green),
      ],
    );
  }

  Widget _buildDropdown(String label, List<String>? items, ValueChanged<String?> onChanged) {
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: 280),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(labelText: label),
        // Si items est null (chargement), on affiche une liste vide
        items: (items ?? [])
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
        onChanged: onChanged,
        validator: (value) => value == null ? 'Champ requis' : null,
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool isRequired = true, TextInputType? keyboardType}) {
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: 280),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        keyboardType: keyboardType,
        validator: (value) => (isRequired && (value == null || value.isEmpty))
            ? 'Champ requis'
            : null,
      ),
    );
  }

  Widget _buildDateField(BuildContext context, String label) {
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: 280),
      child: InkWell(
        onTap: () async {
          final pickedDate = await showDatePicker(
            context: context,
            initialDate: _dateNaissance ?? DateTime(2005, 1, 1),
            firstDate: DateTime(1950),
            lastDate: DateTime.now().subtract(Duration(days: 365 * 10)),
          );
          if (pickedDate != null) {
            setState(() { _dateNaissance = pickedDate; });
          }
        },
        child: InputDecorator(
          decoration:
          InputDecoration(labelText: label, suffixIcon: Icon(Icons.calendar_month)),
          child: Text(
            _dateNaissance == null
                ? 'Sélectionner une date'
                : DateFormat('dd/MM/yyyy').format(_dateNaissance!),
          ),
        ),
      ),
    );
  }
}

// Widget pour les champs non modifiables (Source: 311-315)
// (Copiez-collez ce widget au bas de votre fichier inscription_page.dart)
class _ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const _ReadOnlyField(
      {required this.label,
        required this.value,
        required this.icon,
        this.color});

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
              Text(value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: color, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}