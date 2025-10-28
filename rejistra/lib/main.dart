// rejistra/lib/main.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:rejistra/providers/data_provider.dart'; // <-- Ajoutez ceci
import 'package:rejistra/screens/dashboard/dashboard_page.dart'; // <-- Ajoutez ceci
import 'package:rejistra/screens/inscription/inscription_page.dart'; // <-- Ajoutez ceci
import 'package:shared/services/supabase_service.dart';
import 'package:rejistra/providers/auth_provider.dart';
import 'package:rejistra/screens/auth/login_page.dart';
import 'package:google_fonts/google_fonts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialiser Supabase
  await SupabaseService.initialize();

  runApp(
    // Enveloppez l'application avec les providers
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AuthProvider()),
        ChangeNotifierProvider(create: (context) => DataProvider()), // <-- Ajoutez ceci
      ],
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
    return Scaffold(
      body: Row(
        children: [
          // Menu latéral simple
          NavigationRail(
            selectedIndex: 0,
            onDestinationSelected: (index) {
              if (index == 0) context.go('/');
              if (index == 1) context.go('/inscription');
            },
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard),
                label: Text('Dashboard'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.person_add),
                label: Text('Inscription'),
              ),
            ],
          ),
          // Zone principale
          Expanded(child: child),
        ],
      ),
    );
  }
}


/*
Placeholder pour le Dashboard
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
 --- Fin des Placeholders ---
*/
// Configuration de l'App (adapté de )
class RejistraApp extends StatelessWidget {
  const RejistraApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.latoTextTheme(Theme.of(context).textTheme);

    // Récupérer l'instance unique du AuthProvider (sans écouter)
    final authProvider = context.read<AuthProvider>();

    // Initialisation du router ici
    final _router = GoRouter(
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
        ShellRoute(
          builder: (context, state, child) => MainLayout(child: child),
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => DashboardPage(),
            ),
            GoRoute(
              path: '/inscription',
              builder: (context, state) => InscriptionPage(),
            ),
          ],
        ),
      ],

      // ✅ Correction ici : listen: false
      redirect: (BuildContext context, GoRouterState state) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);

        if (authProvider.isLoading) {
          return '/loading';
        }

        final isLoggedIn = authProvider.isLoggedIn;
        final isLoggingIn = state.matchedLocation == '/login' ||
            state.matchedLocation == '/loading';

        if (!isLoggedIn && !isLoggingIn) return '/login';
        if (isLoggedIn && isLoggingIn) return '/';
        return null;
      },

      // ✅ Correction ici : utiliser le ChangeNotifier existant
      refreshListenable: authProvider,
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
