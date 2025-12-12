import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/theme.dart';
import 'auth/login_page.dart';
import 'roles/student/student_home.dart';
import 'roles/rp/rp_home.dart';
import 'roles/admin/admin_home.dart';
import 'roles/responsable/responsable_home.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) {
      context.go('/login');
      return;
    }

    // Récupérer le profil utilisateur
    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('role, site_rattache')
          .eq('id', session.user.id)
          .single();

      final role = profile['role'] as String;

      String routePath;
      switch (role) {
        case 'admin':
          routePath = '/admin-home';
          break;
        case 'rp':
          routePath = '/rp-home';
          break;
        case 'responsable':
          routePath = '/responsable-home';
          break;
        case 'etudiant':
          routePath = '/student-home';
          break;
        default:
          routePath = '/login';
      }

      if (mounted) {
        context.go(routePath);
      }
    } catch (e) {
      debugPrint('Erreur profil: $e');
      if (mounted) {
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: GojikaTheme.primaryGradient,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: Image.asset(
                    'assets/images/logo/iToLogo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              )
                  .animate()
                  .scale(
                duration: 600.ms,
                curve: Curves.elasticOut,
              )
                  .fadeIn(duration: 400.ms),

              const SizedBox(height: 40),

              // Titre
              Text(
                'GOJIKA',
                style: GojikaTheme.titleLarge.copyWith(
                  fontSize: 42,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              )
                  .animate()
                  .fadeIn(delay: 300.ms, duration: 600.ms)
                  .slideY(begin: 0.3, end: 0),

              const SizedBox(height: 10),

              // Slogan
              Text(
                'Chaque étudiant mérite de réussir\nensemble nous y veillons',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  height: 1.5,
                ),
              )
                  .animate()
                  .fadeIn(delay: 500.ms, duration: 600.ms)
                  .slideY(begin: 0.3, end: 0),

              const SizedBox(height: 60),

              // Loading indicator
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              )
                  .animate(onPlay: (controller) => controller.repeat())
                  .fadeIn(delay: 700.ms),
            ],
          ),
        ),
      ),
    );
  }
}