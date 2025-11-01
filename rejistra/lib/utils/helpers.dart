// rejistra/lib/utils/helpers.dart
import 'package:flutter/material.dart';

// Widget pour les champs non modifiables
class ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const ReadOnlyField({
    Key? key,
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color ?? Colors.grey.shade700, size: 20),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              Text(value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: color, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}

// Helper pour afficher les snackbars d'erreur
void showErrorSnackBar(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Theme.of(context).colorScheme.error,
    ),
  );
}

// Helper pour afficher les snackbars de succès
void showSuccessSnackBar(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.green,
    ),
  );
}