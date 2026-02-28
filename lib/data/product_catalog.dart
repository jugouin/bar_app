import 'package:flutter/material.dart';
import '../models/product.dart';

const Map<String, Product> productCatalog = {
  'beer': Product(name: 'Bière', price: 2.5, icon: Icons.sports_bar),
  'wine_glass': Product(name: 'Vin au verre', price: 2.5, icon: Icons.wine_bar),
  'wine_bottle': Product(name: 'Vin bouteille', price: 10.0, icon: Icons.liquor),
  'chips': Product(name: 'Chips', price: 2.0, icon: Icons.cookie),
  'soft': Product(name: 'Soft', price: 1.5, icon: Icons.local_drink),
};
