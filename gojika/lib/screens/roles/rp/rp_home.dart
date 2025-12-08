import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/theme.dart';
import '../../../providers/gojika_provider.dart';
import 'rp_dashboard.dart';

import 'rp_pedagogy_page.dart';
import 'rp_entry_menu_page.dart';

class RPHomePage extends StatefulWidget {
  const RPHomePage({Key? key}) : super(key: key);

  @override
  State<RPHomePage> createState() => _RPHomePageState();
}

class _RPHomePageState extends State<RPHomePage> {
  int _selectedIndex = 0;
  bool _isLoading = true;
  String? _siteRattache;

  @override
  void initState() {
    super.initState();
    _initRP();
  }

  Future<void> _initRP() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('site_rattache')
          .eq('id', userId)
          .single();

      _siteRattache = profile['site_rattache'];

      if (mounted) {
        // Charger le dashboard pour le site du RP
        await context.read<GojikaProvider>().loadDashboard(_siteRattache);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur init RP: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Liste des pages
    final pages = [
      RPDashboard(site: _siteRattache!),
      const RPPedagogyPage(), // Page Pédagogie créée à l'étape 2
      RPEntryMenuPage(site: _siteRattache!), // Nouveau menu pour choisir entre Notes et Absences
      const Center(child: Text("Publications (Voir suite)")),
      const Center(child: Text("Paramètres (Voir suite)")),
    ];

    // Layout Adaptatif
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 800) {
          // Mode Tablette/Desktop : NavigationRail
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (int index) {
                    setState(() => _selectedIndex = index);
                  },
                  labelType: NavigationRailLabelType.all,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: CircleAvatar(
                      backgroundColor: GojikaTheme.primaryBlue,
                      child: const Text('RP', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  destinations: const [
                    NavigationRailDestination(icon: Icon(Iconsax.home), label: Text('Dashboard')),
                    NavigationRailDestination(icon: Icon(Iconsax.teacher), label: Text('Pédagogie')),
                    NavigationRailDestination(icon: Icon(Iconsax.edit), label: Text('Saisie')),
                    NavigationRailDestination(icon: Icon(Iconsax.message), label: Text('Comms')),
                    NavigationRailDestination(icon: Icon(Iconsax.setting), label: Text('Param')),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(child: pages[_selectedIndex]),
              ],
            ),
          );
        } else {
          // Mode Mobile : BottomNavigationBar
          return Scaffold(
            body: pages[_selectedIndex],
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (index) => setState(() => _selectedIndex = index),
              type: BottomNavigationBarType.fixed,
              items: const [
                BottomNavigationBarItem(icon: Icon(Iconsax.home), label: 'Dash'),
                BottomNavigationBarItem(icon: Icon(Iconsax.teacher), label: 'Péda'),
                BottomNavigationBarItem(icon: Icon(Iconsax.edit), label: 'Saisie'),
                BottomNavigationBarItem(icon: Icon(Iconsax.message), label: 'Comms'),
                BottomNavigationBarItem(icon: Icon(Iconsax.setting), label: 'Param'),
              ],
            ),
          );
        }
      },
    );
  }
}