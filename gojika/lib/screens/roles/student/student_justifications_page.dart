// gojika/lib/screens/roles/student/student_justifications_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import '../../../config/theme.dart';
import '../../../providers/gojika_provider.dart';
import '../../../models/models.dart';
import '../../../services/storage_service.dart';
import '../../auth/widgets/common_widgets.dart';

class StudentJustificationsPage extends StatefulWidget {
  final Map<String, dynamic> etudiantData;

  const StudentJustificationsPage({Key? key, required this.etudiantData}) : super(key: key);

  @override
  State<StudentJustificationsPage> createState() => _StudentJustificationsPageState();
}

class _StudentJustificationsPageState extends State<StudentJustificationsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _storageService = StorageService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadJustifications();
  }

  Future<void> _loadJustifications() async {
    final provider = context.read<GojikaProvider>();
    await provider.loadJustificationsEtudiant(widget.etudiantData['id']);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Justificatifs d\'Absence'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Soumettre', icon: Icon(Iconsax.document_upload)),
            Tab(text: 'Historique', icon: Icon(Iconsax.archive_book)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _SoumettreTab(
            etudiantId: widget.etudiantData['id'],
            onSubmitted: () {
              _loadJustifications();
              _tabController.animateTo(1);
            },
          ),
          _HistoriqueTab(etudiantId: widget.etudiantData['id']),
        ],
      ),
    );
  }
}

// ==================== ONGLET SOUMETTRE ====================
class _SoumettreTab extends StatefulWidget {
  final int etudiantId;
  final VoidCallback onSubmitted;

  const _SoumettreTab({required this.etudiantId, required this.onSubmitted});

  @override
  State<_SoumettreTab> createState() => _SoumettreTabState();
}

class _SoumettreTabState extends State<_SoumettreTab> {
  final _formKey = GlobalKey<FormState>();
  final _motifController = TextEditingController();
  final _storageService = StorageService();

  DateTime? _dateAbsence;
  File? _fichierJoint;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _motifController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _fichierJoint = File(pickedFile.path);
        });
      }
    } catch (e) {
      _showError('Erreur lors de la sélection de l\'image: $e');
    }
  }

  Future<void> _submitJustification() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dateAbsence == null) {
      _showError('Veuillez sélectionner une date');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      String? fichierUrl;

      // Upload fichier si présent
      if (_fichierJoint != null) {
        fichierUrl = await _storageService.uploadJustificatif(
          _fichierJoint!,
          widget.etudiantId,
        );
      }

      // Créer la justification
      final provider = context.read<GojikaProvider>();
      await provider.createJustification({
        'etudiant_id': widget.etudiantId,
        'soumis_par_user_id': Supabase.instance.client.auth.currentUser!.id,
        'motif': _motifController.text.trim(),
        'date_absence': _dateAbsence!.toIso8601String().split('T')[0],
        'fichier_url': fichierUrl,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Justificatif soumis avec succès'),
            backgroundColor: GojikaTheme.riskGreen,
          ),
        );

        // Réinitialiser le formulaire
        _formKey.currentState!.reset();
        _motifController.clear();
        setState(() {
          _dateAbsence = null;
          _fichierJoint = null;
        });

        widget.onSubmitted();
      }
    } catch (e) {
      _showError('Erreur lors de la soumission: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Instructions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: GojikaTheme.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: GojikaTheme.primaryBlue.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Iconsax.info_circle, color: GojikaTheme.primaryBlue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Soumettez votre justificatif d\'absence avec une pièce jointe (certificat médical, convocation, etc.)',
                      style: TextStyle(color: Colors.grey[700], height: 1.5),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Date d'absence
            Text('Date de l\'absence', style: GojikaTheme.titleMedium),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                  lastDate: DateTime.now(),
                  locale: const Locale('fr', 'FR'),
                );
                if (date != null) {
                  setState(() => _dateAbsence = date);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    const Icon(Iconsax.calendar, color: GojikaTheme.primaryBlue),
                    const SizedBox(width: 12),
                    Text(
                      _dateAbsence != null
                          ? DateFormat('dd/MM/yyyy').format(_dateAbsence!)
                          : 'Sélectionner une date',
                      style: TextStyle(
                        fontSize: 16,
                        color: _dateAbsence != null ? Colors.black : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Motif
            Text('Motif de l\'absence', style: GojikaTheme.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _motifController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Décrivez la raison de votre absence...',
                alignLabelWithHint: true,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Veuillez entrer un motif';
                }
                if (value.trim().length < 10) {
                  return 'Le motif doit contenir au moins 10 caractères';
                }
                return null;
              },
            ),

            const SizedBox(height: 24),

            // Pièce jointe
            Text('Pièce justificative', style: GojikaTheme.titleMedium),
            const SizedBox(height: 8),

            if (_fichierJoint == null)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: const Icon(Iconsax.camera),
                      label: const Text('Prendre une photo'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Iconsax.gallery),
                      label: const Text('Depuis la galerie'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                ],
              )
            else
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _fichierJoint!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      onPressed: () => setState(() => _fichierJoint = null),
                      icon: const Icon(Iconsax.close_circle),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 32),

            // Bouton soumettre
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitJustification,
                icon: _isSubmitting
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
                    : const Icon(Iconsax.document_upload),
                label: Text(_isSubmitting ? 'Envoi en cours...' : 'Soumettre le justificatif'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: GojikaTheme.primaryBlue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== ONGLET HISTORIQUE ====================
class _HistoriqueTab extends StatelessWidget {
  final int etudiantId;

  const _HistoriqueTab({required this.etudiantId});

  @override
  Widget build(BuildContext context) {
    return Consumer<GojikaProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final justifications = provider.justifications;
        final absences = provider.absences;

        if (justifications.isEmpty && absences.isEmpty) {
          return const EmptyState(
            message: 'Aucun historique d\'absence',
            icon: Iconsax.document,
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            await provider.loadJustificationsEtudiant(etudiantId);
            await provider.loadAbsencesEtudiant(etudiantId);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Justifications soumises
              if (justifications.isNotEmpty) ...[
                Text('Justificatifs Soumis', style: GojikaTheme.titleMedium),
                const SizedBox(height: 12),
                ...justifications.map((j) => _JustificationCard(justification: j)),
                const SizedBox(height: 24),
              ],

              // Absences non justifiées
              if (absences.where((a) => a.justificationId == null).isNotEmpty) ...[
                Text('Absences Non Justifiées', style: GojikaTheme.titleMedium),
                const SizedBox(height: 12),
                ...absences
                    .where((a) => a.justificationId == null)
                    .map((a) => _AbsenceCard(absence: a)),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ==================== WIDGETS ====================
class _JustificationCard extends StatelessWidget {
  final Justification justification;

  const _JustificationCard({required this.justification});

  Color _getStatusColor() {
    switch (justification.status) {
      case JustificationStatus.validee:
        return GojikaTheme.riskGreen;
      case JustificationStatus.refusee:
        return GojikaTheme.riskRed;
      default:
        return GojikaTheme.riskOrange;
    }
  }

  String _getStatusText() {
    switch (justification.status) {
      case JustificationStatus.validee:
        return '✅ Validée';
      case JustificationStatus.refusee:
        return '❌ Refusée';
      default:
        return '⏳ En attente';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('dd/MM/yyyy').format(justification.dateSoumission),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Text(
                    _getStatusText(),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              justification.motif,
              style: TextStyle(color: Colors.grey[700], height: 1.5),
            ),
            if (justification.fichierUrl != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Iconsax.document_text, size: 16, color: GojikaTheme.primaryBlue),
                  const SizedBox(width: 8),
                  Text(
                    'Pièce jointe disponible',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AbsenceCard extends StatelessWidget {
  final Absence absence;

  const _AbsenceCard({required this.absence});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Iconsax.close_circle, color: GojikaTheme.riskRed),
        title: Text(
          DateFormat('dd/MM/yyyy').format(absence.dateAbsence),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: const Text('Absence non justifiée'),
        trailing: TextButton(
          onPressed: () {
            // TODO: Ouvrir formulaire de justification pré-rempli
          },
          child: const Text('Justifier'),
        ),
      ),
    );
  }
}