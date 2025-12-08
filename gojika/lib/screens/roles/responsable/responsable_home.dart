import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/theme.dart';
import '../../auth/login_page.dart';
import '../../common/publication_create_page.dart';
import '../rp/rp_dashboard.dart'; // On réutilise le dashboard du RP car identique par site

class ResponsableHomePage extends StatefulWidget {
  const ResponsableHomePage({Key? key}) : super(key: key);

  @override
  State<ResponsableHomePage> createState() => _ResponsableHomePageState();
}

class _ResponsableHomePageState extends State<ResponsableHomePage> {
  int _selectedIndex = 0;
  String? _site;

  @override
  void initState() {
    super.initState();
    _loadSite();
  }

  Future<void> _loadSite() async {
    final user = Supabase.instance.client.auth.currentUser!;
    final profile = await Supabase.instance.client.from('profiles').select('site_rattache').eq('id', user.id).single();
    setState(() => _site = profile['site_rattache']);
  }

  @override
  Widget build(BuildContext context) {
    if (_site == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final pages = [
      RPDashboard(site: _site!), // Réutilisation intelligente
      const Center(child: Text("Rapports Financiers & Pédagogiques")),
      const Center(child: Text("Profil")),
    ];

    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Iconsax.home), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Iconsax.chart_1), label: 'Rapports'),
          BottomNavigationBarItem(icon: Icon(Iconsax.user), label: 'Profil'),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => PublicationCreatePage(site: _site!)));
        },
        backgroundColor: GojikaTheme.primaryBlue,
        child: const Icon(Iconsax.edit, color: Colors.white),
      )
          : null,
    );
  }
}