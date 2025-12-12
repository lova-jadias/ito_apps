import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared/services/supabase_service.dart';

import 'config/theme.dart';
import 'config/router.dart'; // ✅ Import du router
import 'providers/gojika_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialiser Supabase
  await SupabaseService.initialize();

  // Initialiser la localisation
  await initializeDateFormatting('fr_FR', null);

  runApp(const GojikaApp());
}

class GojikaApp extends StatelessWidget {
  const GojikaApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => GojikaProvider()..initialize(),
        ),
      ],
      child: MaterialApp.router( // ✅ Utiliser MaterialApp.router
        title: 'GOJIKA - Suivi Pédagogique',
        debugShowCheckedModeBanner: false,
        theme: GojikaTheme.lightTheme,
        darkTheme: GojikaTheme.darkTheme,
        themeMode: ThemeMode.system,
        routerConfig: goRouter, // ✅ Injecter le router
        locale: const Locale('fr', 'FR'),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('fr', 'FR'),
        ],
      ),
    );
  }
}