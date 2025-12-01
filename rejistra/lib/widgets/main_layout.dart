// rejistra/lib/widgets/main_layout.dart
// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

//import 'package://flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:rejistra/providers/auth_provider.dart';
import 'package:rejistra/widgets/sync_status_indicator.dart';

// Enum pour les pages, pour clarifier la logique
enum AppPage { dashboard, inscription, paiements, etat, admin, apropos }

// Classe pour définir un item de menu
class NavItem {
  final AppPage page;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String route;

  NavItem({
    required this.page,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.route,
  });
}

class MainLayout extends StatefulWidget {
  final Widget child;
  const MainLayout({required this.child, Key? key}) : super(key: key);

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  // Définition de tous les items de menu possibles
  final Map<AppPage, NavItem> _allNavItems = {
    AppPage.dashboard: NavItem(
      page: AppPage.dashboard,
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      route: '/',
    ),
    AppPage.inscription: NavItem(
      page: AppPage.inscription,
      label: 'Inscription',
      icon: Icons.person_add_alt_1_outlined,
      selectedIcon: Icons.person_add_alt_1,
      route: '/inscription',
    ),
    AppPage.paiements: NavItem(
      page: AppPage.paiements,
      label: 'Paiements',
      icon: Icons.payment_outlined,
      selectedIcon: Icons.payment,
      route: '/paiements-etudiants',
    ),
    AppPage.etat: NavItem(
      page: AppPage.etat,
      label: 'État',
      icon: Icons.bar_chart_outlined,
      selectedIcon: Icons.bar_chart,
      route: '/etat-individuel',
    ),
    AppPage.admin: NavItem(
      page: AppPage.admin,
      label: 'Admin',
      icon: Icons.admin_panel_settings_outlined,
      selectedIcon: Icons.admin_panel_settings,
      route: '/admin/users',
    ),
  };

  /// Construit la liste des items de menu VISIBLES pour le rôle actuel
  List<NavItem> _getVisibleNavItems(String? userRole) {
    switch (userRole) {
      case 'admin':
        return [
          _allNavItems[AppPage.dashboard]!,
          _allNavItems[AppPage.inscription]!,
          _allNavItems[AppPage.paiements]!,
          _allNavItems[AppPage.etat]!,
          _allNavItems[AppPage.admin]!,
        ];
      case 'controleur':
        return [
          _allNavItems[AppPage.dashboard]!,
          _allNavItems[AppPage.etat]!,
          _allNavItems[AppPage.admin]!, // Le Contrôleur peut voir Admin
        ];
      case 'responsable':
        return [
          _allNavItems[AppPage.dashboard]!,
          _allNavItems[AppPage.etat]!,
        ];
      case 'accueil':
        return [
          _allNavItems[AppPage.inscription]!,
          _allNavItems[AppPage.paiements]!,
          _allNavItems[AppPage.etat]!,
        ];
      default:
        return [];
    }
  }

  /// Trouve l'index sélectionné basé sur la route ET la liste visible
  int _getSelectedIndex(String location, List<NavItem> visibleItems) {
    // Cas spécial pour 'À Propos' (pas dans la barre principale)
    if (location.startsWith('/a-propos')) return -1; // -1 pour "rien n'est sélectionné"

    // Trouve l'item dont la route commence par la location
    // ex: /paiements-etudiants commence par /paiements
    final int index = visibleItems.indexWhere((item) {
      if (item.page == AppPage.dashboard) return location == '/';
      return location.startsWith(item.route.substring(0, 6)); // ex: /admin, /paiem
    });

    return (index == -1) ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final userRole = auth.currentUser?.role;
    final location = GoRouterState.of(context).matchedLocation;

    // 1. Obtenir les items visibles pour ce rôle
    final List<NavItem> visibleItems = _getVisibleNavItems(userRole);

    // 2. Calculer l'index sélectionné basé sur les items visibles
    final int selectedIndex = _getSelectedIndex(location, visibleItems);

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            // S'il n'y a rien de sélectionné (ex: À Propos), on passe null
            selectedIndex: selectedIndex == -1 ? null : selectedIndex,
            onDestinationSelected: (index) {
              // Naviguer vers la route de l'item cliqué
              context.go(visibleItems[index].route);
            },
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

            // --- CORRECTION OVERFLOW (Point 1) ---
            // Le widget `Expanded` a été supprimé.
            // Le `NavigationRail` place `trailing` en bas par défaut.
            // `Expanded` causait un overflow lorsque la hauteur de la fenêtre était réduite.
            trailing: Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SyncStatusIndicator(), // ⬅️ Synchronisation de status
                  SizedBox(height: 10),
                  IconButton(
                    icon: Icon(Icons.info_outline,
                      // Mettre en surbrillance si la page 'À Propos' est active
                      color: location == '/a-propos' ? Theme.of(context).colorScheme.primary : null,
                    ),
                    tooltip: 'À propos',
                    onPressed: () => context.go('/a-propos'),
                  ),
                  SizedBox(height: 10),
                  IconButton(
                    icon: Icon(Icons.logout, color: Colors.red.shade700),
                    tooltip: 'Déconnexion',
                    onPressed: () {
                      context.read<AuthProvider>().logout();
                    },
                  ),
                ],
              ),
            ),
            // --- FIN CORRECTION ---

            // 3. Construire les destinations à partir des items visibles
            destinations: visibleItems.map((item) {
              return NavigationRailDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.selectedIcon),
                label: Text(item.label),
              );
            }).toList(),
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
    final bool canAccessAdmin = userRole == 'admin' || userRole == 'controleur';
    final bool canAccessAdminEdit = userRole == 'admin' || userRole == 'controleur';

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
    } else if (location.startsWith('/admin') && canAccessAdmin) {
      // Le 'Controleur' voit le menu Admin
      tabs = [
        // Seul l'Admin peut gérer les utilisateurs
        if (userRole == 'admin')
          _SecondaryNavButton(
              label: 'Gérer les Utilisateurs',
              icon: Icons.manage_accounts,
              isActive: location == '/admin/users',
              onPressed: () => context.go('/admin/users')),

        // Admin ET Controleur peuvent voir l'édition
        if (canAccessAdminEdit)
          _SecondaryNavButton(
              label: 'Édition (Admin Edit)',
              icon: Icons.edit_note,
              isActive: location == '/admin/edit',
              onPressed: () => context.go('/admin/edit')),

        // Seul l'Admin voit l'Audit
        if (userRole == 'admin')
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