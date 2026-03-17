import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

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
          style: TextStyle(
            color: Color(0xFF2D5478),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF2D5478)),
      ),
      body: SafeArea(
        // ── Stream 1 : commandes ─────────────────────────────────────
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('orders')
              .where('uid', isEqualTo: uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF2D5478)),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Text(
                  "Aucune commande pour le moment",
                  style: TextStyle(color: Color(0xFF2D5478), fontSize: 14),
                ),
              );
            }

            // ── Grouper les commandes par mois "2026-02" ──────────────
            final ordersByMonth =
                <String, List<Map<String, dynamic>>>{};

            for (final doc in snapshot.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              final date = DateTime.parse(data['createdAt']);
              final monthKey =
                  '${date.year}-${date.month.toString().padLeft(2, '0')}';
              ordersByMonth.putIfAbsent(monthKey, () => []).add(data);
            }

            // Trier les mois du plus récent au plus ancien
            final sortedMonths = ordersByMonth.keys.toList()
              ..sort((a, b) => b.compareTo(a));

            // ── Stream 2 : factures mensuelles (pour le statut) ───────
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('monthly_invoices')
                  .where('uid', isEqualTo: uid)
                  .snapshots(),
              builder: (context, invoicesSnapshot) {
                // Map "2026-02" -> données de la facture la plus récente
                final invoiceByMonth = <String, Map<String, dynamic>>{};
                if (invoicesSnapshot.hasData) {
                  for (final doc in invoicesSnapshot.data!.docs) {
                    final inv = doc.data() as Map<String, dynamic>;
                    final month = inv['month'] as String? ?? '';
                    if (!invoiceByMonth.containsKey(month) ||
                        (inv['createdAt'] as String).compareTo(
                                invoiceByMonth[month]!['createdAt']) >
                            0) {
                      invoiceByMonth[month] = inv;
                    }
                  }
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30.0,
                    vertical: 20.0,
                  ),
                  itemCount: sortedMonths.length,
                  itemBuilder: (context, index) {
                    final monthKey = sortedMonths[index];
                    final monthOrders = ordersByMonth[monthKey]!;

                    // Total du mois = somme de toutes les commandes
                    final monthTotal = monthOrders.fold<double>(
                      0,
                      (sum, o) => sum + (o['total'] as num).toDouble(),
                    );

                    // Statut de la facture associée à ce mois
                    final invoice = invoiceByMonth[monthKey];
                    final isPaid = invoice?['status'] == 'paid';
                    final isPending = invoice != null && !isPaid;
                    final checkoutUrl =
                        invoice?['checkoutUrl'] as String?;

                    // Label lisible du mois
                    final parts = monthKey.split('-');
                    final monthLabel = _formatMonthFromParts(
                        int.parse(parts[1]), int.parse(parts[0]));

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 150, 201, 222),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ExpansionTile(
                        iconColor: const Color(0xFF2D5478),
                        collapsedIconColor: const Color(0xFF2D5478),

                        // ── Titre du mois + badge statut ──────────────
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _capitalize(monthLabel),
                                style: const TextStyle(
                                  color: Color(0xFF2D5478),
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
                                color: Color(0xFF2D5478),
                                icon: Icons.schedule,
                              ),
                          ],
                        ),

                        subtitle: Text(
                          "Total : ${monthTotal.toStringAsFixed(2)} €"
                          "  ·  ${monthOrders.length} commande${monthOrders.length > 1 ? 's' : ''}",
                          style: const TextStyle(color: Color(0xFF2D5478)),
                        ),

                        children: [
                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Divider(color: Color(0xFF2D5478)),

                                // ── Détail de chaque commande du mois ─────
                                ...monthOrders.map((order) {
                                  final date = DateTime.parse(
                                      order['createdAt']);
                                  final items =
                                      order['items'] as List<dynamic>;
                                  final orderTotal =
                                      (order['total'] as num).toDouble();

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Date de la commande
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            top: 8, bottom: 4),
                                        child: Text(
                                          "Commande du ${_formatDate(date)}",
                                          style: const TextStyle(
                                            color: Color(0xFF2D5478),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      // Lignes produits
                                      ...items.map((item) {
                                        final i = item
                                            as Map<String, dynamic>;
                                        return Padding(
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  vertical: 3),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment
                                                    .spaceBetween,
                                            children: [
                                              Text(
                                                "${i['productName']} x${i['quantity']}",
                                                style: const TextStyle(
                                                    color:
                                                        Color(0xFF2D5478),
                                                    fontSize: 13),
                                              ),
                                              Text(
                                                "${(i['price'] * i['quantity']).toStringAsFixed(2)} €",
                                                style: const TextStyle(
                                                  color: Color(0xFF2D5478),
                                                  fontWeight:
                                                      FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                      // Sous-total commande
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            top: 4, bottom: 8),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            Text(
                                              "Sous-total : ${orderTotal.toStringAsFixed(2)} €",
                                              style: const TextStyle(
                                                color: Color(0xFF2D5478),
                                                fontSize: 12,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (order != monthOrders.last)
                                        const Divider(
                                            color: Color(0xFF2D5478),
                                            thickness: 0.3),
                                    ],
                                  );
                                }),

                                // ── Bouton payer (si facture en attente) ──
                                if (isPending && checkoutUrl != null) ...[
                                  const SizedBox(height: 10),
                                  const Divider(color: Color(0xFF2D5478)),
                                  const SizedBox(height: 6),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () => launchUrl(
                                        Uri.parse(checkoutUrl),
                                        mode: LaunchMode
                                            .externalApplication,
                                      ),
                                      icon: const Icon(Icons.payment,
                                          size: 16),
                                      label: Text(
                                          "Payer la facture $monthLabel"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF2D5478),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 10),
                                      ),
                                    ),
                                  ),
                                ],

                                // ── Confirmation payée ─────────────────────
                                if (isPaid) ...[
                                  const SizedBox(height: 10),
                                  const Divider(color: Color(0xFF2D5478)),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(Icons.check_circle,
                                          size: 14,
                                          color: Colors.green.shade600),
                                      const SizedBox(width: 6),
                                      Text(
                                        "Facture $monthLabel réglée",
                                        style: TextStyle(
                                          color: Colors.green.shade600,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
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

  String _formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/"
        "${date.month.toString().padLeft(2, '0')}/"
        "${date.year}";
  }

  String _formatMonthFromParts(int month, int year) {
    const months = [
      '',
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
    ];
    return "${months[month]} $year";
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ── Badge statut ────────────────────────────────────────────────────
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