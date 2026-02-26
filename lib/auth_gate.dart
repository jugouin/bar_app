import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bar_app/screens/login_screen.dart';
import 'package:bar_app/screens/home_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          User? user = snapshot.data;
          if (user == null) {
            return LoginScreen();
          } else {
            return HomeScreen();
          }
        } else {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
      },
    );
  }
}