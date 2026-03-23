import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bar_app/auth_gate.dart'; 
import '../widgets/section_title.dart';
import '../widgets/styled_text_field.dart';
import '../widgets/styled_button.dart';

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

  bool _loadingEmail = false;
  bool _loadingPassword = false;

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _emailController.text = _user?.email ?? '';
    _loadNameFromFirestore();
  }

  Future<void> _loadNameFromFirestore() async {
    if (_user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_user.uid)
        .get();
    if (mounted) {
      _displayNameController.text = doc.data()?['firstName'] ?? '';
    }
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
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AuthGate()),
        (route) => false,
      );
    }
  }

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
      final newEmail = _emailController.text.trim();

      await _user!.verifyBeforeUpdateEmail(newEmail);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_user.uid)
          .update({'email': newEmail});

      final orders = await FirebaseFirestore.instance
          .collection('orders')
          .where('uid', isEqualTo: _user.uid)
          .get();
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in orders.docs) {
        batch.update(doc.reference, {'email': newEmail});
      }
      await batch.commit();

      _showSnack("Email de vérification envoyé à $newEmail");
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

  Future<void> _deleteAccount() async {
    final passwordController = TextEditingController();
    bool obscureDeletePassword = true;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: const [
                  Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                  SizedBox(width: 8),
                  Text(
                    "Supprimer mon compte",
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Cette action est irréversible. Toutes vos données personnelles seront supprimées définitivement :",
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    _rgpdBullet("Votre profil (nom, email)"),
                    _rgpdBullet("Votre historique de commandes"),
                    _rgpdBullet("Votre compte d'authentification"),
                    const SizedBox(height: 16),
                    const Text(
                      "Confirmez avec votre mot de passe :",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: passwordController,
                      obscureText: obscureDeletePassword,
                      decoration: InputDecoration(
                        hintText: "Mot de passe actuel",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureDeletePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () => setDialogState(
                            () => obscureDeletePassword = !obscureDeletePassword,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text("Annuler"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text("Supprimer définitivement"),
                ),
              ],
            );
          },
        );
      },
    );

    final password = passwordController.text;

    if (confirmed != true) return;

    if (password.isEmpty) {
      _showSnack("Mot de passe requis pour supprimer le compte", error: true);
      return;
    }

    final ok = await _reauthenticate(password);
    if (!ok) return;

    try {
      final uid = _user!.uid;
      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      batch.delete(db.collection('users').doc(uid));

      final orders = await db
          .collection('orders')
          .where('uid', isEqualTo: uid)
          .get();
      for (final doc in orders.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      await _user.delete();

      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthGate()),
          (route) => false,
        );
        passwordController.dispose();
      }
    } catch (e) {
      _showSnack(
        "Erreur lors de la suppression : ${e.toString()}",
        error: true,
      );
    }
  }

  /// Widget helper pour les puces RGPD dans la boîte de dialogue
  Widget _rgpdBullet(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("• ", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
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
                  child: const Icon(Icons.sailing, size: 40),
                ),
              ),

              const SizedBox(height: 30),

              // Section Email
              SectionTitle(title: "Adresse email"),
              const SizedBox(height: 10),
              StyledTextField(
                controller: _emailController,
                icon: Icons.email,
                keyboardType: TextInputType.emailAddress,
                label: '',
              ),
              const SizedBox(height: 10),
              StyledTextField(
                controller: _currentPasswordController,
                label: "Mot de passe actuel (requis)",
                icon: Icons.lock,
                obscure: _obscureCurrent,
                onToggleObscure: () =>
                    setState(() => _obscureCurrent = !_obscureCurrent),
              ),
              const SizedBox(height: 10),
              StyledButton(
                label: "Mettre à jour l'email",
                loading: _loadingEmail,
                onPressed: _updateEmail,
              ),

              const SizedBox(height: 30),

              // Section Mot de passe
              SectionTitle(title: "Mot de passe"),
              const SizedBox(height: 10),
              StyledTextField(
                controller: _currentPasswordController,
                label: "Mot de passe actuel",
                icon: Icons.lock_outline,
                obscure: _obscureCurrent,
                onToggleObscure: () =>
                    setState(() => _obscureCurrent = !_obscureCurrent),
              ),
              const SizedBox(height: 10),
              StyledTextField(
                controller: _newPasswordController,
                label: "Nouveau mot de passe",
                icon: Icons.lock,
                obscure: _obscureNew,
                onToggleObscure: () =>
                    setState(() => _obscureNew = !_obscureNew),
              ),
              const SizedBox(height: 10),
              StyledTextField(
                controller: _confirmPasswordController,
                label: "Confirmer le mot de passe",
                icon: Icons.lock,
                obscure: _obscureConfirm,
                onToggleObscure: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
              const SizedBox(height: 10),
              StyledButton(
                label: "Mettre à jour le mot de passe",
                loading: _loadingPassword,
                onPressed: _updatePassword,
              ),

              const SizedBox(height: 60),

              // Bouton Déconnexion
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

              const SizedBox(height: 16),

              // Bouton Suppression de compte (RGPD)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: _deleteAccount,
                icon: const Icon(Icons.delete_forever),
                label: const Text(
                  "Supprimer mon compte",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),

              const SizedBox(height: 8),

              // Mention RGPD discrète
              Center(
                child: Text(
                  "Droit à l'effacement – Art. 17 RGPD",
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}