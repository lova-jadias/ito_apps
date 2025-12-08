// gojika/lib/screens/roles/student/student_finance_page.dart

import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/theme.dart';
import '../../auth/widgets/common_widgets.dart';

class StudentFinancePage extends StatefulWidget {
  final Map<String, dynamic> etudiantData;

  const StudentFinancePage({Key? key, required this.etudiantData}) : super(key: key);

  @override
  State<StudentFinancePage> createState() => _StudentFinancePageState();
}

class _StudentFinancePageState extends State<StudentFinancePage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _paiements = [];
  double _solde = 0.0;
  double _totalPaye = 0.0;
  double _totalDu = 0.0;

  @override
  void initState() {
    super.initState();
    _loadFinanceData();
  }

  Future<void> _loadFinanceData() async {
    try {
      // Récupérer les paiements de l'étudiant
      final response = await Supabase.instance.client
          .from('paiement_items')
          .select('*, recus!inner(n_recu_principal, date_paiement, mode_paiement, ref_transaction)')
          .eq('id_etudiant', widget.etudiantData['id'])
          .order('recus.date_paiement', ascending: false);

      setState(() {
        _paiements = List<Map<String, dynamic>>.from(response);

        // Calculer le total payé
        _totalPaye = _paiements
            .where((p) => !(p['motif'] as String).startsWith('ANNULÉ'))
            .map((p) => (p['montant'] as num).toDouble())
            .fold(0.0, (a, b) => a + b);

        // TODO: Calculer le total dû (à implémenter)
        _totalDu = 5000000.0; // Exemple

        _solde = _totalDu - _totalPaye;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Finances'),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadFinanceData();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadFinanceData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Carte solde
              _SoldeCard(
                solde: _solde,
                totalPaye: _totalPaye,
                totalDu: _totalDu,
              ),

              const SizedBox(height: 24),

              // Historique paiements
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Historique des Paiements', style: GojikaTheme.titleMedium),
                  Text(
                    '${_paiements.length} paiements',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (_paiements.isEmpty)
                const EmptyState(
                  message: 'Aucun paiement enregistré',
                  icon: Iconsax.wallet,
                )
              else
                ..._paiements.map((paiement) => _PaiementCard(paiement: paiement)).toList(),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== CARTE SOLDE ====================
class _SoldeCard extends StatelessWidget {
  final double solde;
  final double totalPaye;
  final double totalDu;

  const _SoldeCard({
    required this.solde,
    required this.totalPaye,
    required this.totalDu,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(locale: 'fr_FR', symbol: 'Ar', decimalDigits: 0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            solde > 0 ? GojikaTheme.riskRed : GojikaTheme.riskGreen,
            (solde > 0 ? GojikaTheme.riskRed : GojikaTheme.riskGreen).withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (solde > 0 ? GojikaTheme.riskRed : GojikaTheme.riskGreen).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Solde Restant',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Iconsax.wallet, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            formatter.format(solde),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white24),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _InfoColumn(
                label: 'Total Dû',
                value: formatter.format(totalDu),
              ),
              _InfoColumn(
                label: 'Total Payé',
                value: formatter.format(totalPaye),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoColumn extends StatelessWidget {
  final String label;
  final String value;

  const _InfoColumn({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// ==================== CARTE PAIEMENT ====================
class _PaiementCard extends StatelessWidget {
  final Map<String, dynamic> paiement;

  const _PaiementCard({required this.paiement});

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(locale: 'fr_FR', symbol: 'Ar', decimalDigits: 0);
    final recus = paiement['recus'] as Map<String, dynamic>;
    final date = DateTime.parse(recus['date_paiement']);
    final isAnnule = (paiement['motif'] as String).startsWith('ANNULÉ');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isAnnule
                ? Colors.grey.withOpacity(0.1)
                : GojikaTheme.riskGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isAnnule ? Iconsax.close_circle : Iconsax.tick_circle,
            color: isAnnule ? Colors.grey : GojikaTheme.riskGreen,
          ),
        ),
        title: Text(
          paiement['motif'],
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: isAnnule ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text(
          '${DateFormat('dd/MM/yyyy').format(date)} • ${recus['mode_paiement'] ?? 'N/A'}',
        ),
        trailing: Text(
          formatter.format(paiement['montant']),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isAnnule ? Colors.grey : GojikaTheme.riskGreen,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailRow(label: 'N° Reçu', value: recus['n_recu_principal']),
                if (recus['ref_transaction'] != null)
                  _DetailRow(label: 'Référence', value: recus['ref_transaction']),
                if (paiement['mois_de'] != null)
                  _DetailRow(label: 'Mois concerné', value: paiement['mois_de']),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ],
      ),
    );
  }
}