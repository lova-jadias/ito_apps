// rejistra/lib/screens/inscription/inscription_page.dart
// ignore_for_file: use_build_context_synchronously, prefer_const_constructors

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:rejistra/providers/data_provider.dart';
import 'package:rejistra/utils/helpers.dart';
import 'package:rejistra/services/admin_service.dart';
import 'package:rejistra/widgets/photo_uploader.dart';

class InscriptionPage extends StatefulWidget {
  const InscriptionPage({Key? key}) : super(key: key);

  @override
  State<InscriptionPage> createState() => _InscriptionPageState();
}

class _InscriptionPageState extends State<InscriptionPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  final _nomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _emailController = TextEditingController();
  final _telController = TextEditingController();
  DateTime? _dateNaissance;
  String? _selectedMention;
  String? _selectedNiveau;
  String? _selectedGroupe;
  String? _selectedDepartement;
  String? _photoUrl;
  bool _gojikaActive = false;

  final String _paymentDate = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
  final String _statut = "Actif";

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _emailController.dispose();
    _telController.dispose();
    super.dispose();
  }

  String _generateTempPassword() {
    final random = Random.secure();
    String a = random.nextInt(999999).toString().padLeft(6, '0');
    String prefix = _prenomController.text.trim().toLowerCase().replaceAll(' ', '');
    if (prefix.isEmpty) {
      prefix = "gojika";
    }
    return "$prefix-$a";
  }

  Future<void> _inscrire() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final String tempPassword = _generateTempPassword();

    final studentData = {
      'nom': _nomController.text.trim(),
      'prenom': _prenomController.text.trim(),
      'date_naissance': _dateNaissance?.toIso8601String(),
      'email_contact': _emailController.text.trim(),
      'telephone': _telController.text.trim(),
      'mention_module': _selectedMention,
      'niveau': _selectedNiveau,
      'groupe': _selectedGroupe,
      'departement': _selectedDepartement,
      'photo_url': _photoUrl,
    };

    try {
      final result = await AdminService().createStudent(
        studentData: studentData,
        tempPassword: tempPassword,
        activateGojika: _gojikaActive,
      );

      final String generatedId = result['id_etudiant_genere'];

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text("✅ Succès ! Compte Étudiant Créé"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("L'étudiant a été inscrit avec succès.\n"),
              Text("ID Étudiant:",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text(generatedId),
              SizedBox(height: 16),
              Text("Mot de passe GOJIKA:",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SelectableText(tempPassword,
                  style: TextStyle(fontSize: 18, color: Colors.blue)),
              SizedBox(height: 16),
              Text(
                "⚠️ ATTENTION : Veuillez copier et remettre ce mot de passe à l'étudiant. Il ne sera plus jamais affiché.",
                style: TextStyle(color: Colors.red.shade700),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _resetForm();
              },
              child: Text("Terminé"),
            ),
          ],
        ),
      );
    } catch (e) {
      showErrorSnackBar(context, "Erreur d'inscription: $e");
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _resetForm() {
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
      _photoUrl = null;
      _gojikaActive = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dataProvider = Provider.of<DataProvider>(context);
    final config = dataProvider.configOptions;

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
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Formulaire d'inscription",
                      style: Theme.of(context).textTheme.headlineSmall),
                  Text(
                      "Remplissez les champs pour enregistrer un étudiant et créer son compte GOJIKA."),
                  SizedBox(height: 24),
                  _buildReadOnlyInfoSection(),
                  SizedBox(height: 16),
                  Center(
                    child: PhotoUploader(
                      initialPhotoUrl: _photoUrl,
                      onPhotoUploaded: (url) {
                        setState(() {
                          _photoUrl = url;
                        });
                      },
                    ),
                  ),
                  SizedBox(height: 16),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _buildTextField("Nom *", _nomController),
                      _buildTextField("Prénom", _prenomController,
                          isRequired: false),
                      _buildDateField(context, "Date de Naissance"),
                      _buildTextField(
                          "Email de contact (pour GOJIKA) *", _emailController,
                          keyboardType: TextInputType.emailAddress),
                      _buildTextField("Téléphone", _telController,
                          isRequired: false,
                          keyboardType: TextInputType.phone),
                      _buildDropdown("Mention/Module *", config['MentionModule'],
                              (val) => setState(() => _selectedMention = val)),
                      _buildDropdown("Niveau *", config['Niveau'],
                              (val) => setState(() => _selectedNiveau = val)),
                      _buildDropdown("Groupe *", config['Groupe'],
                              (val) => setState(() => _selectedGroupe = val)),
                      _buildDropdown("Département *", config['Département'],
                              (val) => setState(() => _selectedDepartement = val)),
                    ],
                  ),
                  SizedBox(height: 24),
                  SwitchListTile(
                    title: Text("Activer le compte GOJIKA immédiatement ?"),
                    subtitle: Text(
                        "L'étudiant pourra se connecter dès maintenant avec le mot de passe temporaire."),
                    value: _gojikaActive,
                    onChanged: (val) => setState(() => _gojikaActive = val),
                  ),
                  SizedBox(height: 32),
                  _isLoading
                      ? Center(child: CircularProgressIndicator())
                      : ElevatedButton.icon(
                    onPressed: _inscrire,
                    icon: Icon(Icons.save),
                    label: Text('Enregistrer l\'étudiant'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                      Theme.of(context).colorScheme.primary,
                      foregroundColor:
                      Theme.of(context).colorScheme.onPrimary,
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

  Widget _buildReadOnlyInfoSection() {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        ReadOnlyField(
            label: "ID Étudiant",
            value: "Généré à la validation",
            icon: Icons.vpn_key),
        ReadOnlyField(
            label: "Date Opération", value: _paymentDate, icon: Icons.today),
        ReadOnlyField(
            label: "Statut Initial",
            value: _statut,
            icon: Icons.check_circle_outline,
            color: Colors.green),
      ],
    );
  }

  Widget _buildDropdown(
      String label, List<String>? items, ValueChanged<String?> onChanged) {
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: 280),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(labelText: label),
        items: (items ?? [])
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
        onChanged: onChanged,
        validator: (value) => value == null ? 'Champ requis' : null,
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {bool isRequired = true, TextInputType? keyboardType}) {
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: 280),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        keyboardType: keyboardType,
        validator: (value) {
          if (isRequired && (value == null || value.isEmpty)) {
            return 'Champ requis';
          }
          if (keyboardType == TextInputType.emailAddress &&
              value!.isNotEmpty &&
              !value.contains('@')) {
            return 'Email invalide';
          }
          return null;
        },
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
            setState(() {
              _dateNaissance = pickedDate;
            });
          }
        },
        child: InputDecorator(
          decoration: InputDecoration(
              labelText: label, suffixIcon: Icon(Icons.calendar_month)),
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