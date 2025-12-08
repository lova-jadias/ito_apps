//import "package:flutter/material.dart";

import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/auth/login_page.dart';
import '../screens/splash_screen.dart';
import '../screens/roles/student/student_home.dart';
import '../screens/roles/rp/rp_home.dart';
import '../screens/roles/admin/admin_home.dart';
import '../screens/roles/responsable/responsable_home.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final goRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
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
      path: '/student',
      builder: (context, state) => const StudentHomePage(),
    ),
    GoRoute(
      path: '/rp',
      builder: (context, state) => const RPHomePage(),
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminHomePage(),
    ),
    GoRoute(
      path: '/responsable',
      builder: (context, state) => const ResponsableHomePage(),
    ),
  ],
  redirect: (context, state) async {
    final session = Supabase.instance.client.auth.currentSession;
    final isLoggingIn = state.uri.toString() == '/login';
    final isSplash = state.uri.toString() == '/';

    // Si pas connecté et n'est pas sur login ou splash -> Login
    if (session == null && !isLoggingIn && !isSplash) {
      return '/login';
    }

    // Si connecté et sur login -> Rediriger vers rôle (géré par SplashScreen ou logique ici)
    // Pour simplifier, on laisse le SplashScreen dispatcher
    return null;
  },
);