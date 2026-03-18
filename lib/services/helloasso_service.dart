import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/helloasso_event.dart';

class HelloAssoService {
  // URL de vos Cloud Functions
  static const _baseUrl =
      'https://europe-west1-cve-bar.cloudfunctions.net';

  // ── Récupérer les événements depuis HelloAsso ──────────────────
  Future<List<HelloAssoEvent>> fetchEvents() async {
    final res = await http.get(Uri.parse('$_baseUrl/getEvents'));

    if (res.statusCode != 200) {
      throw Exception('Erreur API : ${res.statusCode}');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final items = body['data'] as List<dynamic>? ?? [];

    return items
        .map((e) => HelloAssoEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Créer un checkout pour inscrire l'utilisateur ──────────────
  Future<String> createCheckout(HelloAssoEvent event) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Non connecté');

    // Récupérer le nom depuis Firestore
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final name = doc.data()?['name'] as String? ?? '';
    final nameParts = name.trim().split(' ');
    final firstName = nameParts.first;
    final lastName = nameParts.length > 1
        ? nameParts.sublist(1).join(' ')
        : firstName;

    final res = await http.post(
      Uri.parse('$_baseUrl/createEventCheckout'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'formSlug':   event.slug,
        'totalCents': (event.prix * 100).round(),
        'email':      user.email,
        'firstName':  firstName,
        'lastName':   lastName,
        'eventTitle': event.title,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('Erreur checkout : ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['checkoutUrl'] as String;
  }
}