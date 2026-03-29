import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

class EmailService {
  static final EmailService _instance = EmailService._internal();
  factory EmailService() => _instance;
  EmailService._internal();

  final _functions = FirebaseFunctions.instanceFor(region: 'europe-west1');

  Future<void> sendConfirmationEmail({
    required String firstName,
    required String email,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Utilisateur non connecté');

    await _functions.httpsCallable('sendWelcomeEmail').call({
      'firstName': firstName,
      'email': email,
    });
  }
}