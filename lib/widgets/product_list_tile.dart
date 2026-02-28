import 'package:flutter/material.dart';
import '../models/product.dart';

class ProductListTile extends StatelessWidget {
  final String productKey;
  final Product product;
  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const ProductListTile({
    super.key,
    required this.productKey,
    required this.product,
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
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
              "${(product.price * quantity).toStringAsFixed(2)} €",
              style: const TextStyle(
                color: Color(0xFF2D5478),
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onDecrement,
              child: const Icon(Icons.remove_circle_outline,
                  color: Color(0xFF2D5478), size: 30),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                "$quantity",
                style: const TextStyle(
                  color: Color(0xFF2D5478),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            GestureDetector(
              onTap: onIncrement,
              child: const Icon(Icons.add_circle_outline,
                  color: Color(0xFF2D5478), size: 30),
            ),
          ],
        ),
      ),
    );
  }
}