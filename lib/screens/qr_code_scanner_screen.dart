import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/product.dart';
import '../data/product_catalog.dart';
import '../widgets/product_list_tile.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  final Map<String, ({Product product, int quantity})> _scannedProducts = {};
  bool _isScanning = true;

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

            // Total
            if (_scannedProducts.isNotEmpty)
              Container(
                margin: const EdgeInsets.all(20),
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
          ],
        ),
      ),
    );
  }
}