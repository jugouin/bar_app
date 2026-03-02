import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import '../models/product.dart';
import '../models/order.dart';
import '../data/product_catalog.dart';
import '../widgets/product_list_tile.dart';
import '../services/order_service.dart';
import '../widgets/styled_button.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  final Map<String, ({Product product, int quantity})> _scannedProducts = {};
  final OrderService _orderService = OrderService();
  bool _isScanning = true;
  bool _loadingOrder = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (!_isScanning) return;

    final String? code = capture.barcodes.first.rawValue;
    if (code == null) return;

    final String key = code.toLowerCase();
    final Product? product = productCatalog[key];
    if (product == null) return;

    setState(() => _isScanning = false);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isScanning = true);
    });

    setState(() {
      if (_scannedProducts.containsKey(key)) {
        _scannedProducts[key] = (
          product: product,
          quantity: _scannedProducts[key]!.quantity + 1,
        );
      } else {
        _scannedProducts[key] = (product: product, quantity: 1);
      }
    });
  }

  void _increment(String key) {
    setState(() {
      _scannedProducts[key] = (
        product: _scannedProducts[key]!.product,
        quantity: _scannedProducts[key]!.quantity + 1,
      );
    });
  }

  void _decrement(String key) {
    setState(() {
      if (_scannedProducts[key]!.quantity <= 1) {
        _scannedProducts.remove(key);
      } else {
        _scannedProducts[key] = (
          product: _scannedProducts[key]!.product,
          quantity: _scannedProducts[key]!.quantity - 1,
        );
      }
    });
  }

  double get _total => _scannedProducts.values
      .fold(0, (sum, e) => sum + e.product.price * e.quantity);

Future<void> _validateOrder() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Confirmer la commande",
          style: TextStyle(color: Color(0xFF2D5478), fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Total : ${_total.toStringAsFixed(2)} €\n\nValider cette commande ?",
          style: const TextStyle(color: Color(0xFF2D5478)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Annuler", style: TextStyle(color: Color(0xFF2D5478))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Valider",
              style: TextStyle(color: Color(0xFF2D5478), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _loadingOrder = true);

    try {
      // Récupérer le name depuis Firestore
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final name = doc.data()?['name'] ?? '';

      final order = Order(
        email: user.email!,
        name: name,
        total: _total,
        createdAt: DateTime.now(),
        items: _scannedProducts.entries.map((e) => OrderItem(
          productKey: e.key,
          productName: e.value.product.name,
          price: e.value.product.price,
          quantity: e.value.quantity,
        )).toList(),
      );

      await _orderService.saveOrder(order);
      setState(() => _scannedProducts.clear());

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Commande validée avec succès !")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur : ${e.toString()}")),
      );
    } finally {
      setState(() => _loadingOrder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = _scannedProducts.entries.toList();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        elevation: 0,
        title: const Text(
          "Scanner un QR Code",
          style: TextStyle(color: Color(0xFF2D5478), fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_scannedProducts.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Color(0xFF2D5478)),
              onPressed: () => setState(() => _scannedProducts.clear()),
              tooltip: "Vider la liste",
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Caméra
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 10.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      height: 250,
                      child: MobileScanner(
                        controller: _controller,
                        onDetect: _onDetect,
                      ),
                    ),
                    Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF2D5478), width: 3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Text(
              "Placez le QR code dans le cadre",
              style: TextStyle(
                color: Color(0xFF2D5478),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 10),

            // Liste
            Expanded(
              child: _scannedProducts.isEmpty
                  ? const Center(
                      child: Text(
                        "Aucun produit scanné",
                        style: TextStyle(color: Color(0xFF2D5478), fontSize: 14),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 30.0),
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final key = entries[index].key;
                        final entry = entries[index].value;
                        return ProductListTile(
                          productKey: key,
                          product: entry.product,
                          quantity: entry.quantity,
                          onIncrement: () => _increment(key),
                          onDecrement: () => _decrement(key),
                        );
                      },
                    ),
            ),

            // Total + Bouton valider
            if (_scannedProducts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 150, 201, 222),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Total",
                            style: TextStyle(
                              color: Color(0xFF2D5478),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "${_total.toStringAsFixed(2)} €",
                            style: const TextStyle(
                              color: Color(0xFF2D5478),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    StyledButton(
                      label: "Valider la commande",
                      loading: _loadingOrder,
                      onPressed: _validateOrder,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
