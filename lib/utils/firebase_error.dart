class FirebaseErrors {
  static String getMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return "Aucun compte associé à cet e-mail.";
      case 'wrong-password':
        return "Mot de passe incorrect.";
      case 'invalid-email':
        return "Adresse e-mail invalide.";
      case 'user-disabled':
        return "Ce compte a été désactivé.";
      case 'too-many-requests':
        return "Trop de tentatives. Réessayez plus tard.";
      case 'invalid-credential':
        return "E-mail ou mot de passe incorrect.";
      default:
        return "Erreur inconnue.";
    }
  }
}
