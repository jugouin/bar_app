import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';


class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Accueil")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Bienvenue sur la page d'accueil !"),
            ElevatedButton(
              onPressed: _logout,
              child: Text("Déconnection"),
            ),
          ],
        ),
      ),
    );
  }
}