import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/theme.dart';
import '../../auth/login_page.dart';
import 'admin_dashboard.dart';
import 'admin_users_page.dart';
import 'admin_audit_page.dart';
import 'admin_mot_semaine_page.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({Key? key}) : super(key: key);

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const AdminDashboard(),
    const AdminUsersPage(),
    const AdminMotSemainePage(), // Page Mot de la semaine
    const AdminAuditPage(),
    const Center(child: Text("Paramètres Admin (Config)")),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) => setState(() => _selectedIndex = index),
            labelType: NavigationRailLabelType.all,
            backgroundColor: GojikaTheme.primaryBlue.withOpacity(0.05),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: CircleAvatar(
                backgroundColor: Colors.black,
                child: Image.asset('assets/images/logo/iToLogo.png', width: 24),
              ),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: IconButton(
                    icon: const Icon(Iconsax.logout, color: GojikaTheme.riskRed),
                    onPressed: () async {
                      await Supabase.instance.client.auth.signOut();
                      if (context.mounted) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                        );
                      }
                    },
                  ),
                ),
              ),
            ),
            destinations: const [
              NavigationRailDestination(icon: Icon(Iconsax.element_4), label: Text('Dash')),
              NavigationRailDestination(icon: Icon(Iconsax.people), label: Text('Users')),
              NavigationRailDestination(icon: Icon(Iconsax.quote_up), label: Text('Mot Sem.')),
              NavigationRailDestination(icon: Icon(Iconsax.security_safe), label: Text('Audit')),
              NavigationRailDestination(icon: Icon(Iconsax.setting), label: Text('Config')),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: _pages[_selectedIndex]),
        ],
      ),
    );
  }
}