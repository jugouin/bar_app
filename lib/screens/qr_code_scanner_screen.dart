import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

// Modèle produit
class Product {
  final String name;
  final double price;
  final IconData icon;

  const Product({required this.name, required this.price, required this.icon});
}

// Catalogue des produits associés aux QR codes
const Map<String, Product> productCatalog = {
  'biere': Product(name: 'Bière', price: 2.5, icon: Icons.sports_bar),
  'vin_verre': Product(name: 'Vin au verre', price: 2.5, icon: Icons.wine_bar),
  'vin_bouteille': Product(name: 'Vin bouteille', price: 10.0, icon: Icons.liquor),
  'chips': Product(name: 'Chips', price: 2.0, icon: Icons.cookie),
  'soft': Product(name: 'Soft', price: 1.5, icon: Icons.local_drink),
};

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  final List<Product> _scannedProducts = [];
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

    final Product? product = productCatalog[code.toLowerCase()];
    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Produit inconnu")),
      );
      return;
    }

    // Pause le scanner brièvement pour éviter les doublons
    setState(() => _isScanning = false);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isScanning = true);
    });

    setState(() => _scannedProducts.add(product));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("${product.name} ajouté !")),
    );
  }

  double get _total =>
      _scannedProducts.fold(0, (sum, p) => sum + p.price);

  void _removeProduct(int index) {
    setState(() => _scannedProducts.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        elevation: 0,
        title: const Text(
          "Scanner un QR Code",
          style: TextStyle(
            color: Color(0xFF2D5478),
            fontWeight: FontWeight.bold,
          ),
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
                    // Viseur
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

            // Label
            const Text(
              "Placez le QR code dans le cadre",
              style: TextStyle(
                color: Color(0xFF2D5478),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 10),

            // Liste des produits scannés
            Expanded(
              child: _scannedProducts.isEmpty
                  ? const Center(
                      child: Text(
                        "Aucun produit scanné",
                        style: TextStyle(
                          color: Color(0xFF2D5478),
                          fontSize: 14,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 30.0),
                      itemCount: _scannedProducts.length,
                      itemBuilder: (context, index) {
                        final product = _scannedProducts[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(255, 150, 201, 222),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: Icon(product.icon, color: const Color(0xFF2D5478), size: 30),
                            title: Text(
                              product.name,
                              style: const TextStyle(
                                color: Color(0xFF2D5478),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "${product.price.toStringAsFixed(2)} €",
                                  style: const TextStyle(
                                    color: Color(0xFF2D5478),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => _removeProduct(index),
                                  child: const Icon(Icons.close, color: Color(0xFF2D5478), size: 20),
                                ),
                              ],
                            ),
                          ),
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