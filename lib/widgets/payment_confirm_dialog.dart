import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PaymentConfirmDialog extends StatefulWidget {
  final String invoiceId;
  const PaymentConfirmDialog({super.key, required this.invoiceId });

  @override
  State<PaymentConfirmDialog> createState() => PaymentConfirmDialogState();
}

class PaymentConfirmDialogState extends State<PaymentConfirmDialog> {
  static const _blue = Color(0xFF2D5478);
  bool _timedOut = false;

  @override
  void initState() {
    super.initState();
    // Si après 15s le statut n'est pas "paid", on affiche un message d'attente
    Future.delayed(const Duration(seconds: 15), () {
      if (mounted && !_timedOut) {
        setState(() => _timedOut = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('monthly_invoices')
          .doc(widget.invoiceId)
          .snapshots(),
      builder: (context, snapshot) {
        final isPaid = snapshot.hasData &&
            (snapshot.data!.data() as Map<String, dynamic>?)?['status'] == 'paid';

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isPaid) ...[
                const Icon(Icons.check_circle, color: Colors.green, size: 56),
                const SizedBox(height: 16),
                const Text(
                  'Paiement confirmé !',
                  style: TextStyle(color: _blue, fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Votre facture a bien été réglée.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
              ] else if (_timedOut) ...[
                const Icon(Icons.schedule, color: Colors.orange, size: 56),
                const SizedBox(height: 16),
                const Text(
                  'Confirmation en cours…',
                  style: TextStyle(color: _blue, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Le paiement est bien reçu mais la confirmation peut prendre quelques minutes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54, fontSize: 13),
                ),
              ] else ...[
                const CircularProgressIndicator(color: _blue),
                const SizedBox(height: 16),
                const Text(
                  'Confirmation du paiement…',
                  style: TextStyle(color: _blue, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Merci de patienter quelques secondes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54, fontSize: 13),
                ),
              ],
            ],
          ),
          actions: (isPaid || _timedOut)
              ? [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Retour', style: TextStyle(color: _blue)),
                  ),
                ]
              : null,
        );
      },
    );
  }
}