import 'package:bar_app/auth_gate.dart';
import 'package:bar_app/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/styled_text_field.dart';
import '../widgets/styled_button.dart';
import '../widgets/section_title.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bar_app/services/email_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _displayFirstNameController = TextEditingController();
  final _displayLastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _loading = false;

  @override
  void dispose() {
    _displayFirstNameController.dispose();
    _displayLastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        elevation: 0,
        title: const Text(
          "Inscription",
          style: TextStyle(
            color: Color(0xFF2D5478),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF2D5478)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Center(
                child: CircleAvatar(
                  radius: 45,
                  backgroundColor: const Color.fromARGB(255, 150, 201, 222),
                  child: const Icon(
                    Icons.person,
                    size: 40,
                    color: Color(0xFF2D5478),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              SectionTitle(title: "Informations"),
              const SizedBox(height: 10),
              StyledTextField(
                controller: _displayFirstNameController,
                label: "Prénom",
                icon: Icons.person,
              ),
              const SizedBox(height: 10),
              StyledTextField(
                controller: _displayLastNameController,
                label: "Nom",
                icon: Icons.person,
              ),
              const SizedBox(height: 10),
              StyledTextField(
                controller: _emailController,
                label: "E-mail",
                icon: Icons.email,
                keyboardType: TextInputType.emailAddress,
              ),

              const SizedBox(height: 30),

              SectionTitle(title: "Mot de passe"),
              const SizedBox(height: 10),
              StyledTextField(
                controller: _passwordController,
                label: "Mot de passe",
                icon: Icons.lock,
                obscure: _obscurePassword,
                onToggleObscure: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              const SizedBox(height: 10),
              StyledTextField(
                controller: _confirmPasswordController,
                label: "Confirmer le mot de passe",
                icon: Icons.lock_outline,
                obscure: _obscureConfirm,
                onToggleObscure: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),

              const SizedBox(height: 30),

              StyledButton(
                label: "M'inscrire",
                loading: _loading,
                onPressed: register,
              ),
            ],
          ),
        ),
      ),
    );
  }

Future<void> register() async {
  if (_passwordController.text != _confirmPasswordController.text) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Les mots de passe ne correspondent pas")),
    );
    return;
  }

  setState(() => _loading = true);

  try {
    final credential = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

    final user = credential.user!;
    await user.updateDisplayName(_displayFirstNameController.text.trim());

    await EmailService().sendConfirmationEmail(
      firstName: _displayFirstNameController.text.trim(),
      email: _emailController.text.trim(),
    );

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'firstName': _displayFirstNameController.text.trim(),
      'lastName': _displayLastNameController.text.trim(),
      'email': _emailController.text.trim(),
    });

    await FirebaseAuth.instance.signOut();

    if (context.mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.mark_email_unread_outlined, color: Color(0xFF2D5478)),
              SizedBox(width: 8),
              Text(
                "Vérifiez votre email",
                style: TextStyle(
                  color: Color(0xFF2D5478),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Un email de confirmation a été envoyé à :",
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 6),
              Text(
                _emailController.text.trim(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D5478),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Cliquez sur le lien dans l'email pour activer votre compte, puis connectez-vous.",
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D5478),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("Compris"),
            ),
          ],
        ),
      );

      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  } on FirebaseAuthException catch (e) {
    final msg = switch (e.code) {
      'weak-password'        => "Le mot de passe est trop faible.",
      'invalid-email'        => "E-mail invalide.",
      'email-already-in-use' => "Un compte avec cet e-mail existe déjà.",
      _                      => "Erreur d'inscription : ${e.message}",
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      setState(() => _loading = false);
    }
  }
}
