// rejistra/lib/widgets/main_layout.dart
// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:rejistra/providers/auth_provider.dart';

class MainLayout extends StatefulWidget {
  final Widget child;
  const MainLayout({required this.child, Key? key}) : super(key: key);

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _getSelectedIndex(String location) {
    if (location == '/') return 0;
    if (location.startsWith('/inscription')) return 1;
    if (location.startsWith('/paiements')) return 2;
    if (location.startsWith('/etat')) return 3;
    if (location.startsWith('/admin')) return 4;
    return 0; // Par défaut sur Dashboard
  }

  void _onDestinationSelected(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/inscription');
        break;
      case 2:
        context.go('/paiements-etudiants');
        break;
      case 3:
        context.go('/etat-individuel');
        break;
      case 4:
        context.go('/admin/users');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final userRole = auth.currentUser?.role;
    final location = GoRouterState.of(context).matchedLocation;
    final selectedIndex = _getSelectedIndex(location);

    // Liste des destinations de la barre de navigation
    List<NavigationRailDestination> destinations = [
      // Le Dashboard n'est visible que pour 'admin' et 'controleur'
      if (userRole == 'admin' || userRole == 'controleur')
        NavigationRailDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: Text('Dashboard'),
        ),
      // L'inscription est visible pour tout le monde (sauf l'étudiant, etc. plus tard)
      NavigationRailDestination(
        icon: Icon(Icons.person_add_alt_1_outlined),
        selectedIcon: Icon(Icons.person_add_alt_1),
        label: Text('Inscription'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.payment_outlined),
        selectedIcon: Icon(Icons.payment),
        label: Text('Paiements'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.bar_chart_outlined),
        selectedIcon: Icon(Icons.bar_chart),
        label: Text('État'),
      ),
      // Le menu Admin n'est visible que pour le rôle 'admin'
      if (userRole == 'admin')
        NavigationRailDestination(
          icon: Icon(Icons.admin_panel_settings_outlined),
          selectedIcon: Icon(Icons.admin_panel_settings),
          label: Text('Admin'),
        ),
    ];

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) => _onDestinationSelected(context, index),
            labelType: NavigationRailLabelType.all,
            extended: false,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: Column(
                children: [
                  Icon(Icons.school, size: 40, color: Theme.of(context).colorScheme.primary),
                  Text("iTo", style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            trailing: Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: Icon(Icons.info_outline),
                      tooltip: 'À propos',
                      onPressed: () => context.go('/a-propos'),
                    ),
                    SizedBox(height: 10),
                    // ✅ Le bouton de déconnexion est ici
                    IconButton(
                      icon: Icon(Icons.logout, color: Colors.red.shade700),
                      tooltip: 'Déconnexion',
                      onPressed: () {
                        context.read<AuthProvider>().logout();
                        // Le routeur redirigera automatiquement vers /login
                      },
                    ),
                  ],
                ),
              ),
            ),
            destinations: destinations,
          ),
          VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: Column(
              children: [
                _buildSecondaryHeader(context, location, userRole),
                Expanded(
                  child: widget.child,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Barre de sous-menu
  Widget _buildSecondaryHeader(BuildContext context, String location, String? userRole) {
    List<Widget> tabs = [];

    if (location.startsWith('/paiements')) {
      tabs = [
        _SecondaryNavButton(
            label: 'Paiements Étudiants',
            icon: Icons.person_search,
            isActive: location == '/paiements-etudiants',
            onPressed: () => context.go('/paiements-etudiants')),
        _SecondaryNavButton(
            label: 'Autres Paiements',
            icon: Icons.add_shopping_cart,
            isActive: location == '/paiements-autres',
            onPressed: () => context.go('/paiements-autres')),
      ];
    } else if (location.startsWith('/etat')) {
      tabs = [
        _SecondaryNavButton(
            label: 'État Individuel',
            icon: Icons.person,
            isActive: location == '/etat-individuel',
            onPressed: () => context.go('/etat-individuel')),
        _SecondaryNavButton(
            label: 'État par Groupe (BAG)',
            icon: Icons.group,
            isActive: location == '/etat-groupe',
            onPressed: () => context.go('/etat-groupe')),
      ];
    } else if (location.startsWith('/admin') && userRole == 'admin') {
      tabs = [
        _SecondaryNavButton(
            label: 'Gérer les Utilisateurs',
            icon: Icons.manage_accounts,
            isActive: location == '/admin/users',
            onPressed: () => context.go('/admin/users')),
        _SecondaryNavButton(
            label: 'Édition (Admin Edit)',
            icon: Icons.edit_note,
            isActive: location == '/admin/edit',
            onPressed: () => context.go('/admin/edit')),
        _SecondaryNavButton(
            label: 'Audit Log',
            icon: Icons.history_toggle_off,
            isActive: location == '/admin/audit',
            onPressed: () => context.go('/admin/audit')),
      ];
    }

    if (tabs.isEmpty) return SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 1)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: tabs),
      ),
    );
  }
}

// Widget pour les boutons de sous-navigation
class _SecondaryNavButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onPressed;

  const _SecondaryNavButton({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12.0),
      child: isActive
          ? FilledButton.icon(
        icon: Icon(icon, size: 18),
        label: Text(label),
        onPressed: onPressed,
      )
          : OutlinedButton.icon(
        icon: Icon(icon, size: 18),
        label: Text(label),
        onPressed: onPressed,
      ),
    );
  }
}