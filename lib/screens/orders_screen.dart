import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/section_title.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('orders')
              .where('uid', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
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

            final orders = snapshot.data!.docs;

            orders.sort((a, b) {
              final aDate = DateTime.parse((a.data() as Map<String, dynamic>)['createdAt']);
              final bDate = DateTime.parse((b.data() as Map<String, dynamic>)['createdAt']);
              return bDate.compareTo(aDate);
            });

            return ListView.builder(
              padding: const EdgeInsets.symmetric(
                horizontal: 30.0,
                vertical: 20.0,
              ),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final data = orders[index].data() as Map<String, dynamic>;
                final items = data['items'] as List<dynamic>;
                final total = data['total'] as double;
                final date = DateTime.parse(data['createdAt']);

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 150, 201, 222),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ExpansionTile(
                    iconColor: const Color(0xFF2D5478),
                    collapsedIconColor: const Color(0xFF2D5478),
                    title: Text(
                      "Commande du ${_formatDate(date)}",
                      style: const TextStyle(
                        color: Color(0xFF2D5478),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      "Total : ${total.toStringAsFixed(2)} €",
                      style: const TextStyle(color: Color(0xFF2D5478)),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Divider(color: Color(0xFF2D5478)),
                            ...items.map((item) {
                              final i = item as Map<String, dynamic>;
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "${i['productName']} x${i['quantity']}",
                                      style: const TextStyle(
                                        color: Color(0xFF2D5478),
                                      ),
                                    ),
                                    Text(
                                      "${(i['price'] * i['quantity']).toStringAsFixed(2)} €",
                                      style: const TextStyle(
                                        color: Color(0xFF2D5478),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
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
}
