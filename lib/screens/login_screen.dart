import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:bar_app/screens/register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey();

  final FocusNode _focusNodePassword = FocusNode();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();


  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            children: [
              const SizedBox(height: 150),
              Image(image: AssetImage('lib/assets/logo_cve.png'), height: 150),
              const SizedBox(height: 10),
              Text("Connexion à votre compte", style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 60),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: "E-mail",
                  prefixIcon: const Icon(Icons.mail),
                  border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onEditingComplete: () => _focusNodePassword.requestFocus(),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer votre e-mail';
                  }
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                    return 'Veuillez entrer un e-mail valide';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _passwordController,
                focusNode: _focusNodePassword,
                obscureText: _obscurePassword,
                keyboardType: TextInputType.visiblePassword,
                decoration: InputDecoration(
                  labelText: "Mot de passe",
                  prefixIcon: const Icon(Icons.password_outlined),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                    icon: _obscurePassword
                      ? const Icon(Icons.visibility_outlined)
                      : const Icon(Icons.visibility_off_outlined)
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer votre mot de passe';
                  }
                  if (value.length < 6) {
                    return 'Le mot de passe doit contenir au moins 6 caractères';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: "Pas de compte ? ",
                      style: const TextStyle(color: Colors.black),
                    ),
                    TextSpan(
                      text: "Inscrivez-vous !",
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => RegisterScreen()));
                        },
                      style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 60),
              ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  await login();
                }
            },
              child: const Text("Me connecter"),
            ),
          ],
          ),
        )
      )
    );
  }

  Future<void> login() async {
    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
              email: _emailController.text, password: _passwordController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Bonjour ${userCredential.user!.displayName ?? ''}!")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Échec de connexion: $e")),
      );
    }
  }

  @override
  void dispose() {
    _focusNodePassword.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
