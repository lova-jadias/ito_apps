// rejistra/lib/screens/about_page.dart
import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('À propos de iTo REJISTRA'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 700),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('iTo REJISTRA',
                      style: Theme.of(context).textTheme.headlineMedium),
                  Text('Version 1.1.0',
                      style: Theme.of(context).textTheme.titleSmall),
                  const Divider(height: 32),
                  Text(
                    "iTo REJISTRA est une plateforme de gestion intégrée, moderne et performante, conçue spécifiquement pour les établissements d'enseignement.",
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Elle remplace les systèmes de suivi manuels par un écosystème applicatif unifié, sécurisé et accessible en temps réel.",
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Développée avec Flutter et propulsée par Supabase, iTo REJISTRA est la tour de contrôle de votre établissement.",
                  ),
                  const SizedBox(height: 24),
                  Text("Concepteur: iTo_ 2025",
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}