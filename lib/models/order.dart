import 'package:firebase_auth/firebase_auth.dart';

class OrderItem {
  final String productKey;
  final String productName;
  final double price;
  final int quantity;

  OrderItem({
    required this.productKey,
    required this.productName,
    required this.price,
    required this.quantity,
  });

  Map<String, dynamic> toMap() => {
    'productKey': productKey,
    'productName': productName,
    'price': price,
    'quantity': quantity,
  };
}

class Order {
  final String uid; 
  final String email;
  final String firstName;
  final String lastName;
  final List<OrderItem> items;
  final double total;
  final DateTime createdAt;
  
  Order({
    required this.uid,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.items,
    required this.total,
    required this.createdAt
  });

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'email': email,
    'firstName': firstName,
    'lastName': lastName,
    'items': items.map((i) => i.toMap()).toList(),
    'total': total,
    'createdAt': createdAt.toIso8601String(),
  };
}