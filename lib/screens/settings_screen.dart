import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});


  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;

  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _loadingName = false;
  bool _loadingEmail = false;
  bool _loadingPassword = false;

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _displayNameController.text = _user?.displayName ?? '';
    _emailController.text = _user?.email ?? '';
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showSnack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.redAccent : const Color(0xFF2D5478),
      ),
    );
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  // Ré-authentifie l'utilisateur avant une action sensible
  Future<bool> _reauthenticate(String password) async {
    try {
      final credential = EmailAuthProvider.credential(
        email: _user!.email!,
        password: password,
      );
      await _user.reauthenticateWithCredential(credential);
      return true;
    } catch (e) {
      _showSnack("Mot de passe actuel incorrect", error: true);
      return false;
    }
  }

  Future<void> _updateDisplayName() async {
    if (_displayNameController.text.trim().isEmpty) {
      _showSnack("Le nom ne peut pas être vide", error: true);
      return;
    }
    setState(() => _loadingName = true);
    try {
      await _user!.updateDisplayName(_displayNameController.text.trim());
      _showSnack("Nom mis à jour avec succès !");
    } catch (e) {
      _showSnack("Erreur : ${e.toString()}", error: true);
    } finally {
      setState(() => _loadingName = false);
    }
  }

  Future<void> _updateEmail() async {
    if (_emailController.text.trim().isEmpty) {
      _showSnack("L'email ne peut pas être vide", error: true);
      return;
    }
    if (_currentPasswordController.text.isEmpty) {
      _showSnack("Entrez votre mot de passe actuel pour changer l'email", error: true);
      return;
    }
    setState(() => _loadingEmail = true);
    final ok = await _reauthenticate(_currentPasswordController.text);
    if (!ok) {
      setState(() => _loadingEmail = false);
      return;
    }
    try {
      await _user!.verifyBeforeUpdateEmail(_emailController.text.trim());
      _showSnack("Email de vérification envoyé à ${_emailController.text.trim()}");
    } catch (e) {
      _showSnack("Erreur : ${e.toString()}", error: true);
    } finally {
      setState(() => _loadingEmail = false);
    }
  }

  Future<void> _updatePassword() async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showSnack("Les mots de passe ne correspondent pas", error: true);
      return;
    }
    if (_newPasswordController.text.length < 6) {
      _showSnack("Le mot de passe doit contenir au moins 6 caractères", error: true);
      return;
    }
    setState(() => _loadingPassword = true);
    final ok = await _reauthenticate(_currentPasswordController.text);
    if (!ok) {
      setState(() => _loadingPassword = false);
      return;
    }
    try {
      await _user!.updatePassword(_newPasswordController.text);
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      _showSnack("Mot de passe mis à jour avec succès !");
    } catch (e) {
      _showSnack("Erreur : ${e.toString()}", error: true);
    } finally {
      setState(() => _loadingPassword = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        elevation: 0,
        title: const Text(
          "Réglages",
          style: TextStyle(color: Color(0xFF2D5478), fontWeight: FontWeight.bold),
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
                  child: Icon(Icons.sailing, size: 40)
                ),
              ),

              const SizedBox(height: 30),

              // Section Nom
              _SectionTitle(title: "Nom"),
              const SizedBox(height: 10),
              _StyledTextField(
                controller: _displayNameController,
                icon: Icons.person, label: '',
              ),
              const SizedBox(height: 10),
              _StyledButton(
                label: "Mettre à jour le nom",
                loading: _loadingName,
                onPressed: _updateDisplayName,
              ),

              const SizedBox(height: 30),

              // Section Email
              _SectionTitle(title: "Adresse email"),
              const SizedBox(height: 10),
              _StyledTextField(
                controller: _emailController,
                icon: Icons.email,
                keyboardType: TextInputType.emailAddress, label: '',
              ),
              const SizedBox(height: 10),
              _StyledTextField(
                controller: _currentPasswordController,
                label: "Mot de passe actuel (requis)",
                icon: Icons.lock,
                obscure: _obscureCurrent,
                onToggleObscure: () =>
                    setState(() => _obscureCurrent = !_obscureCurrent),
              ),
              const SizedBox(height: 10),
              _StyledButton(
                label: "Mettre à jour l'email",
                loading: _loadingEmail,
                onPressed: _updateEmail,
              ),

              const SizedBox(height: 30),

              // Section Mot de passe
              _SectionTitle(title: "Mot de passe"),
              const SizedBox(height: 10),
              _StyledTextField(
                controller: _currentPasswordController,
                label: "Mot de passe actuel",
                icon: Icons.lock_outline,
                obscure: _obscureCurrent,
                onToggleObscure: () =>
                    setState(() => _obscureCurrent = !_obscureCurrent),
              ),
              const SizedBox(height: 10),
              _StyledTextField(
                controller: _newPasswordController,
                label: "Nouveau mot de passe",
                icon: Icons.lock,
                obscure: _obscureNew,
                onToggleObscure: () =>
                    setState(() => _obscureNew = !_obscureNew),
              ),
              const SizedBox(height: 10),
              _StyledTextField(
                controller: _confirmPasswordController,
                label: "Confirmer le mot de passe",
                icon: Icons.lock,
                obscure: _obscureConfirm,
                onToggleObscure: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
              const SizedBox(height: 10),
              _StyledButton(
                label: "Mettre à jour le mot de passe",
                loading: _loadingPassword,
                onPressed: _updatePassword,
              ),

              const SizedBox(height: 60),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: _logout,
                child: const Text("Déconnexion"),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// Widgets utilitaires

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF2D5478),
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _StyledTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final TextInputType keyboardType;

  const _StyledTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.onToggleObscure,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(color: Color(0xFF2D5478)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF2D5478)),
        prefixIcon: Icon(icon, color: const Color(0xFF2D5478)),
        suffixIcon: onToggleObscure != null
            ? IconButton(
                icon: Icon(
                  obscure ? Icons.visibility : Icons.visibility_off,
                  color: const Color(0xFF2D5478),
                ),
                onPressed: onToggleObscure,
              )
            : null,
        filled: true,
        fillColor: const Color.fromARGB(255, 150, 201, 222),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _StyledButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onPressed;

  const _StyledButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromARGB(255, 150, 201, 222),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF2D5478),
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF2D5478),
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
      ),
    );
  }
}