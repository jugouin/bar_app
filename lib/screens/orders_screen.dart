import 'package:bar_app/utils/date.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'pay_invoice_screen.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});
  static const _blue = Color(0xFF2D5478);

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        elevation: 0,
        title: const Text(
          "Mes commandes",
          style: TextStyle(color: _blue, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: _blue),
      ),
      body: SafeArea(
        // ── Stream 1 : commandes ───────────────────────────────────
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('orders')
              .where('uid', isEqualTo: uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: _blue),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Text(
                  "Aucune commande pour le moment",
                  style: TextStyle(color: _blue, fontSize: 14),
                ),
              );
            }

            // Grouper par mois
            final ordersByMonth = <String, List<Map<String, dynamic>>>{};
            for (final doc in snapshot.data!.docs) {
              final data     = doc.data() as Map<String, dynamic>;
              final date     = DateTime.parse(data['createdAt']);
              final monthKey =
                  '${date.year}-${date.month.toString().padLeft(2, '0')}';
              ordersByMonth.putIfAbsent(monthKey, () => []).add(data);
            }

            final sortedMonths = ordersByMonth.keys.toList()
              ..sort((a, b) => b.compareTo(a));

            // ── Stream 2 : factures mensuelles ─────────────────────
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('monthly_invoices')
                  .where('uid', isEqualTo: uid)
                  .snapshots(),
              builder: (context, invoicesSnapshot) {
                // Map "2026-02" -> facture la plus récente
                final invoiceByMonth = <String, Map<String, dynamic>>{};
                if (invoicesSnapshot.hasData) {
                  for (final doc in invoicesSnapshot.data!.docs) {
                    final inv   = doc.data() as Map<String, dynamic>;
                    final month = inv['month'] as String? ?? '';
                    if (!invoiceByMonth.containsKey(month) ||
                        (inv['createdAt'] as String).compareTo(
                                invoiceByMonth[month]!['createdAt']) > 0) {
                      invoiceByMonth[month] = inv;
                    }
                  }
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 30.0, vertical: 20.0),
                  itemCount: sortedMonths.length,
                  itemBuilder: (context, index) {
                    final monthKey    = sortedMonths[index];
                    final monthOrders = ordersByMonth[monthKey]!;

                    final monthTotal = monthOrders.fold<double>(
                      0, (sum, o) => sum + (o['total'] as num).toDouble());

                    final invoice    = invoiceByMonth[monthKey];
                    final isPaid     = invoice?['status'] == 'paid';
                    final isPending  = invoice != null && !isPaid;
                    final paidAt     = invoice?['paidAt'] as String?;

                    final parts      = monthKey.split('-');
                    final monthLabel = formatMonthYear(int.parse(parts[1]), int.parse(parts[0]));

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 150, 201, 222),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ExpansionTile(
                        iconColor:          _blue,
                        collapsedIconColor: _blue,

                        // ── Titre + badge ────────────────────────────
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _capitalize(monthLabel),
                                style: const TextStyle(
                                  color: _blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (isPaid)
                              _StatusBadge(
                                label: "Payée",
                                color: Colors.green.shade600,
                                icon: Icons.check_circle_outline,
                              )
                            else if (isPending)
                              const _StatusBadge(
                                label: "En attente",
                                color: Color.fromARGB(255, 235, 130, 1),  
                                icon: Icons.schedule,
                              ),
                          ],
                        ),

                        subtitle: Text(
                          "Total : ${monthTotal.toStringAsFixed(2)} €"
                          "  ·  ${monthOrders.length} commande${monthOrders.length > 1 ? 's' : ''}",
                          style: const TextStyle(color: _blue),
                        ),

                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Divider(color: _blue),

                                // ── Détail commandes ─────────────────
                                ...monthOrders.map((order) {
                                  final date  = DateTime.parse(order['createdAt']);
                                  final items = order['items'] as List<dynamic>;
                                  final orderTotal = (order['total'] as num).toDouble();

                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            top: 8, bottom: 4),
                                        child: Text(
                                          "Commande du ${formatDate(date)}",
                                          style: const TextStyle(
                                            color: _blue,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      ...items.map((item) {
                                        final i = item as Map<String, dynamic>;
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 3),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                "${i['productName']} x${i['quantity']}",
                                                style: const TextStyle(
                                                    color: _blue, fontSize: 13),
                                              ),
                                              Text(
                                                "${(i['price'] * i['quantity']).toStringAsFixed(2)} €",
                                                style: const TextStyle(
                                                  color: _blue,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            top: 4, bottom: 8),
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: Text(
                                            "Sous-total : ${orderTotal.toStringAsFixed(2)} €",
                                            style: const TextStyle(
                                              color: _blue,
                                              fontSize: 12,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (order != monthOrders.last)
                                        const Divider(
                                            color: _blue, thickness: 0.3),
                                    ],
                                  );
                                }),

                                // ── Statut de la facture ──────────────
                                const Divider(color: _blue),
                                const SizedBox(height: 6),

                                if (invoice == null)
                                  // Pas encore de facture générée
                                  _InvoiceStatusRow(
                                    icon: Icons.hourglass_empty,
                                    iconColor: _blue.withOpacity(0.4),
                                    label: "Facture pas encore générée",
                                    labelColor: _blue.withOpacity(0.5),
                                  )
                                else if (isPaid)
                                  // Facture payée
                                  _InvoiceStatusRow(
                                    icon: Icons.check_circle,
                                    iconColor: Colors.green.shade600,
                                    label: paidAt != null
                                        ? "Payée le ${formatDate(DateTime.parse(paidAt))}"
                                        : "Facture $monthLabel réglée",
                                    labelColor: Colors.green.shade600,
                                  )
                                else
                                  // Facture en attente
                                  _InvoiceStatusRow(
                                    icon: Icons.schedule,
                                    iconColor: Colors.orange.shade600,
                                    label:
                                        "En attente de paiement — ${monthTotal.toStringAsFixed(2)} €",
                                    labelColor: Colors.orange.shade600,
                                  ),

                                // ── Bouton payer ──────────────────────
                                if (isPending) ...[
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        final invoiceId = invoicesSnapshot.data!.docs
                                            .firstWhere((d) =>
                                                (d.data() as Map<String, dynamic>)['month'] == monthKey)
                                            .id;

                                        Navigator.of(context).push(MaterialPageRoute(
                                          builder: (_) => PayInvoiceScreen(invoiceId: invoiceId),
                                        ));
                                      },
                                      icon: const Icon(Icons.payment, size: 16),
                                      label: Text('Payer la facture $monthLabel'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _blue,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 4),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ── Ligne de statut facture ──────────────────────────────────────────
class _InvoiceStatusRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Color labelColor;

  const _InvoiceStatusRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: labelColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Badge statut (titre) ─────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _StatusBadge({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}