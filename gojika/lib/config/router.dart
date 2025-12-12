// 📁 NOUVEAU FICHIER : gojika/lib/config/router.dart
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import '../screens/splash_screen.dart';
import '../screens/auth/login_page.dart';
import '../screens/auth/force_password_reset_page.dart';
import '../screens/roles/student/student_home.dart';
import '../screens/roles/rp/rp_home.dart';
import '../screens/roles/admin/admin_home.dart';
import '../screens/roles/responsable/responsable_home.dart';

final GoRouter goRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/force-reset',
      builder: (context, state) => const ForcePasswordResetPage(),
    ),
    GoRoute(
      path: '/student-home',
      builder: (context, state) => const StudentHomePage(),
    ),
    GoRoute(
      path: '/rp-home',
      builder: (context, state) => const RPHomePage(),
    ),
    GoRoute(
      path: '/admin-home',
      builder: (context, state) => const AdminHomePage(),
    ),
    GoRoute(
      path: '/responsable-home',
      builder: (context, state) => const ResponsableHomePage(),
    ),
  ],
  errorBuilder: (context, state) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 80, color: Colors.red),
            const SizedBox(height: 20),
            Text('Route non trouvée: ${state.uri}'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('Retour à l\'accueil'),
            ),
          ],
        ),
      ),
    );
  },
);