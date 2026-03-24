import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../models/helloasso_event.dart';

class HelloAssoService {
  static const _baseUrl = 'https://europe-west1-cve-bar.cloudfunctions.net';
  static const _ttlMinutes = 60;

  final _firestore = FirebaseFirestore.instance;

  // ── Récupérer les événements (cache Firestore en priorité) ─────
  Future<List<HelloAssoEvent>> fetchEvents() async {
    try {
      final cacheDoc = await _firestore
          .collection('events_cache')
          .doc('latest')
          .get();

      if (cacheDoc.exists) {
        final data     = cacheDoc.data()!;
        final cachedAt = DateTime.parse(data['cachedAt'] as String);
        final age      = DateTime.now().difference(cachedAt).inMinutes;

        if (age < _ttlMinutes) {
          // Cache valide
          final items = data['events'] as List<dynamic>;
          return items
              .map((e) => HelloAssoEvent.fromJson(e as Map<String, dynamic>))
              .toList();
        }

        // Cache expiré → essayer l'API
        try {
          return await _fetchFromApi();
        } catch (_) {
          // Pas de réseau → retourner le cache expiré plutôt que rien
          final items = data['events'] as List<dynamic>;
          return items
              .map((e) => HelloAssoEvent.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }

      return await _fetchFromApi();
    } catch (e) {
      throw Exception('Impossible de charger les événements : $e');
    }
  }
  // ── Forcer un rafraîchissement (bouton refresh) ────────────────
  Future<List<HelloAssoEvent>> refreshEvents() => _fetchFromApi();

  // ── Appel API → met à jour le cache via la Cloud Function ──────
  Future<List<HelloAssoEvent>> _fetchFromApi() async {
    final res = await http.get(Uri.parse('$_baseUrl/getEvents'));

    if (res.statusCode != 200) {
      throw Exception('Erreur API : ${res.statusCode}');
    }

    final body  = jsonDecode(res.body) as Map<String, dynamic>;
    final items = body['data'] as List<dynamic>? ?? [];

    return items
        .map((e) => HelloAssoEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Créer un checkout HelloAsso ────────────────────────────────
  Future<String> createCheckout(HelloAssoEvent event) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/createEventCheckout'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'formSlug': event.slug,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('Erreur checkout : ${res.body}');
    }

    return (jsonDecode(res.body) as Map<String, dynamic>)['checkoutUrl']
        as String;
  }

  // ── Créer un checkout "frais" pour une facture mensuelle (bar) ─────────
  Future<String> generateInvoiceCheckout(String invoiceId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Non connecté');

    final idToken = await user.getIdToken();

    final res = await http.get(
      Uri.parse('$_baseUrl/generateInvoiceCheckout?invoiceId=$invoiceId'),
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
    );

    if (res.statusCode != 200) {
      throw Exception('Erreur génération checkout : ${res.body}');
    }

    return (jsonDecode(res.body) as Map<String, dynamic>)['checkoutUrl'] as String;
  }
}