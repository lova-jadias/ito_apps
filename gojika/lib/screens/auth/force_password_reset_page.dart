import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../config/theme.dart';
import 'package:go_router/go_router.dart';

class ForcePasswordResetPage extends StatefulWidget {
  const ForcePasswordResetPage({Key? key}) : super(key: key);

  @override
  State<ForcePasswordResetPage> createState() => _ForcePasswordResetPageState();
}

class _ForcePasswordResetPageState extends State<ForcePasswordResetPage> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 1. Mettre à jour le mot de passe
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _newPasswordController.text.trim()),
      );

      // 2. Marquer le flag gojika_must_reset_password à false
      await Supabase.instance.client.rpc('mark_password_changed');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Mot de passe changé avec succès'),
            backgroundColor: GojikaTheme.riskGreen,
            duration: Duration(seconds: 2),
          ),
        );

        // ✅ Attendre un court instant pour que l'utilisateur voie le message
        await Future.delayed(const Duration(milliseconds: 1500));

        // ✅ Utiliser GoRouter au lieu de pushReplacementNamed
        if (mounted) {
          context.go('/student-home');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: GojikaTheme.lightGradient,
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: GojikaTheme.riskOrange.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Iconsax.lock,
                          size: 60,
                          color: GojikaTheme.riskOrange,
                        ),
                      ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),

                      const SizedBox(height: 32),

                      Text(
                        'Première Connexion',
                        style: GojikaTheme.titleLarge.copyWith(fontSize: 28),
                        textAlign: TextAlign.center,
                      ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.3, end: 0),

                      const SizedBox(height: 12),

                      Text(
                        'Pour des raisons de sécurité, vous devez changer votre mot de passe temporaire avant de continuer.',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 14,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.3, end: 0),

                      const SizedBox(height: 40),

                      Card(
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _newPasswordController,
                                obscureText: _obscureNew,
                                decoration: InputDecoration(
                                  labelText: 'Nouveau mot de passe',
                                  prefixIcon: const Icon(Iconsax.lock_1),
                                  suffixIcon: IconButton(
                                    icon: Icon(_obscureNew ? Iconsax.eye_slash : Iconsax.eye),
                                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                                  ),
                                  helperText: 'Minimum 8 caractères',
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Veuillez entrer un mot de passe';
                                  }
                                  if (value.length < 8) {
                                    return 'Minimum 8 caractères requis';
                                  }
                                  if (!RegExp(r'[A-Z]').hasMatch(value)) {
                                    return 'Au moins une majuscule requise';
                                  }
                                  if (!RegExp(r'[0-9]').hasMatch(value)) {
                                    return 'Au moins un chiffre requis';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 20),

                              TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: _obscureConfirm,
                                decoration: InputDecoration(
                                  labelText: 'Confirmer le mot de passe',
                                  prefixIcon: const Icon(Iconsax.lock_1),
                                  suffixIcon: IconButton(
                                    icon: Icon(_obscureConfirm ? Iconsax.eye_slash : Iconsax.eye),
                                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Veuillez confirmer le mot de passe';
                                  }
                                  if (value != _newPasswordController.text) {
                                    return 'Les mots de passe ne correspondent pas';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 32),

                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _resetPassword,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: GojikaTheme.primaryBlue,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                      : const Text(
                                    'Changer le mot de passe',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.3, end: 0),

                      const SizedBox(height: 24),

                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Iconsax.info_circle, color: Colors.blue[700], size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Conseil: Utilisez un mot de passe fort que vous seul connaissez.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue[900],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}