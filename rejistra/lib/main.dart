// rejistra/lib/main.dart
// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

// --- CORRECTION DE L'IMPORTATION ---
import 'package:shared/services/supabase_service.dart';
// --- FIN DE LA CORRECTION ---
import 'package:rejistra/providers/data_provider.dart';
import 'package:rejistra/providers/auth_provider.dart';

import 'package:rejistra/widgets/main_layout.dart';

import 'package:rejistra/screens/auth/login_page.dart';
import 'package:rejistra/screens/dashboard/dashboard_page.dart';
import 'package:rejistra/screens/inscription/inscription_page.dart';

import 'package:rejistra/screens/paiement/autre_paiement_page.dart';
import 'package:rejistra/screens/paiement/paiement_etudiant_page.dart';
import 'package:rejistra/screens/etat/etat_individuel_page.dart';
import 'package:rejistra/screens/etat/etat_groupe_bag_page.dart';
import 'package:rejistra/screens/admin/user_management_page.dart';
import 'package:rejistra/screens/admin/admin_edit_page.dart';
import 'package:rejistra/screens/admin/audit_log_page.dart';
import 'package:rejistra/screens/about_page.dart';

import 'package:rejistra/services/sync_service.dart';
import 'package:rejistra/services/offline_cache_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 1. Initialiser Supabase
    await SupabaseService.initialize();

    // 2. Initialiser le service de synchronisation
    final syncService = SyncService(Supabase.instance.client);
    await syncService.initialize();

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (context) => AuthProvider()),
          ChangeNotifierProvider(create: (context) => DataProvider(syncService)),
        ],
        child: const RejistraApp(),
      ),
    );
  } catch (e) {
    print("Erreur critique d'initialisation: $e");
    runApp(
      ErrorApp(
        errorMessage: "Erreur de démarrage de l'application: $e",
      ),
    );
  }
}

// Ajoutez cette classe simple en bas de main.dart
class ErrorApp extends StatelessWidget {
  final String errorMessage;
  const ErrorApp({super.key, required this.errorMessage});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 60),
              const SizedBox(height: 16),
              const Text("Erreur Critique", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              // Afficher le message pour un diagnostic (à retirer en production)
              Text(errorMessage, textAlign: TextAlign.center, style: TextStyle(color: Colors.red.shade700)),
              const SizedBox(height: 24),
              const Text("Veuillez contacter le support technique."),
            ],
          ),
        ),
      ),
    );
  }
}

class RejistraApp extends StatelessWidget {
  const RejistraApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authProvider = context.read<AuthProvider>();

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => LoginPage(),
        ),
        GoRoute(
          path: '/loading',
          builder: (context, state) => Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
        ),
        // Le ShellRoute englobe toutes les pages après connexion
        ShellRoute(
          builder: (context, state, child) {
            final userRole = context.read<AuthProvider>().currentUser?.role;

            // Redirection pour 'Accueil' vers l'inscription si sur la racine
            if (userRole == 'accueil' && state.matchedLocation == '/') {
              Future.microtask(() => context.go('/inscription'));
              return Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            // Redirection pour 'Responsable' et 'Controleur' vers le dashboard
            if ((userRole == 'responsable' || userRole == 'controleur') && state.matchedLocation == '/inscription') {
              Future.microtask(() => context.go('/'));
              return Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            return MainLayout(child: child);
          },
          routes: [
            GoRoute(path: '/', builder: (context, state) => DashboardPage()),
            GoRoute(path: '/inscription', builder: (context, state) => InscriptionPage()),
            GoRoute(path: '/paiements-etudiants', builder: (context, state) => PaiementEtudiantPage()),
            GoRoute(path: '/paiements-autres', builder: (context, state) => AutrePaiementPage()),
            GoRoute(path: '/etat-individuel', builder: (context, state) => EtatIndividuelPage()),
            GoRoute(path: '/etat-groupe', builder: (context, state) => EtatGroupeBagPage()),
            GoRoute(path: '/admin/users', builder: (context, state) => UserManagementPage()),
            GoRoute(path: '/admin/edit', builder: (context, state) => AdminEditPage()),
            GoRoute(path: '/admin/audit', builder: (context, state) => AuditLogPage()),
            GoRoute(path: '/a-propos', builder: (context, state) => AboutPage()),
          ],
        ),
      ],
      redirect: (BuildContext context, GoRouterState state) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (authProvider.isLoading) return '/loading';

        final isLoggedIn = authProvider.isLoggedIn;
        final isLoggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/loading';

        if (!isLoggedIn && !isLoggingIn) return '/login';

        if (isLoggedIn && isLoggingIn) {
          // Logique de redirection post-connexion
          final userRole = authProvider.currentUser?.role;
          if(userRole == 'accueil') {
            return '/inscription'; // Accueil va vers l'inscription
          }
          return '/'; // Les autres vont au Dashboard
        }

        return null;
      },
      refreshListenable: authProvider,
    );

    return MaterialApp.router(
      title: 'iTo REJISTRA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blueGrey,
        brightness: Brightness.light,
        textTheme: GoogleFonts.latoTextTheme(Theme.of(context).textTheme),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade300, width: 1),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: Colors.grey.shade100,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
      routerConfig: router,
    );
  }
}