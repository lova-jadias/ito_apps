// rejistra/lib/main.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared/services/supabase_service.dart';
import 'package:rejistra/providers/auth_provider.dart';
import 'package:rejistra/screens/auth/login_page.dart';
import 'package:google_fonts/google_fonts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialiser Supabase
  await SupabaseService.initialize();

  runApp(
    ChangeNotifierProvider(
      create: (context) => AuthProvider(),
      child: const RejistraApp(),
    ),
  );
}

// --- Placeholders (seront remplacés en Phase 1.1) ---

// Placeholder pour le Layout Principal
class MainLayout extends StatelessWidget {
  final Widget child;
  const MainLayout({required this.child, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Le vrai layout sera implémenté au Bloc 1.1
    return Scaffold(
      appBar: AppBar(
        title: Text("REJISTRA (Phase 0)"),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => context.read<AuthProvider>().logout(),
          )
        ],
      ),
      body: child,
    );
  }
}

// Placeholder pour le Dashboard
class DashboardPage extends StatelessWidget {
  const DashboardPage({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("Dashboard (À venir - Phase 1.1)"),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => context.read<AuthProvider>().logout(),
            child: Text("Déconnexion"),
          )
        ],
      ),
    );
  }
}
// --- Fin des Placeholders ---

// Configuration de l'App (adapté de )
class RejistraApp extends StatelessWidget {
  const RejistraApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.latoTextTheme(Theme.of(context).textTheme);

    // Initialisation du routeur ici
    final _router = GoRouter(
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => LoginPage(),
        ),
        // <-- CORRECTION : Route de chargement déplacée ici
        GoRoute(
          path: '/loading',
          builder: (context, state) => Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
        ),
        ShellRoute(
          builder: (context, state, child) {
            return MainLayout(child: child);
          },
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => DashboardPage(),
            ),
            // Les autres routes (inscription, paiements...)
            // seront ajoutées dans la Phase 1
          ],
        ),
      ],
      // Logique de redirection
      redirect: (BuildContext context, GoRouterState state) {
        final authProvider = Provider.of<AuthProvider>(context, listen: true);

        // Si l'app est en cours de chargement (vérification du login)
        if (authProvider.isLoading) {
          // Affiche un écran de chargement simple pendant la vérification
          return '/loading';
        }

        final isLoggedIn = authProvider.isLoggedIn;
        final isLoggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/loading';

        if (!isLoggedIn && !isLoggingIn) {
          return '/login';
        }
        if (isLoggedIn && isLoggingIn) {
          return '/';
        }
        return null; // Pas de redirection nécessaire
      },
      // <-- CORRECTION : Simplification du refreshListenable
      refreshListenable: Provider.of<AuthProvider>(context),
    );

    return MaterialApp.router(
      title: 'iTo REJISTRA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blueGrey,
        brightness: Brightness.light,
        textTheme: textTheme,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
          fillColor: Colors.grey.shade100,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      routerConfig: _router,
    );
  }
}