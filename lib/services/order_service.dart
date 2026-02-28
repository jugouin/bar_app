import 'package:cloud_firestore/cloud_firestore.dart' as firebase;
import '../models/order.dart';

class OrderService {
  final _db = firebase.FirebaseFirestore.instance;

  Future<void> saveOrder(Order order) async {
    await _db.collection('orders').add(order.toMap());
  }
}