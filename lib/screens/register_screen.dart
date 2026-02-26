import 'package:bar_app/auth_gate.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Inscription")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _displayNameController,
              decoration: const InputDecoration(labelText: "Nom prénom"),
            ),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "E-mail"),
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: "Mot de passe"),
              obscureText: true,
            ),
            TextField(
              controller: _confirmPasswordController,
              decoration: const InputDecoration(labelText: "Confirmer le mot de passe"),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await register();
              },
              child: const Text("M'inscrire"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> register() async {

    try {
      await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text, password: _passwordController.text);

      await FirebaseAuth.instance.currentUser?.updateDisplayName(_displayNameController.text);
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Inscription réussie!")),
      );
      if (context.mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => AuthGate()));
      }    
    } on FirebaseAuthException catch (e) {
      final msg = switch (e.code) {
        'weak-password' => "Le mot de passe est trop faible.",
        'invalid-email' => "E-mail invalide.",
        'email-already-in-use' => "Un compte avec cet e-mail existe déjà.",
        _ => "Erreur d'inscription : ${e.message}",
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    }
  }
}
