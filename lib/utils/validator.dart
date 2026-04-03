class Validators {
  static String? required(String? value, {String field = "Ce champ"}) {
    if (value == null || value.trim().isEmpty) {
      return "$field est requis";
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.isEmpty) {
      return "Veuillez entrer un e-mail";
    }
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
      return "Veuillez entrer un e-mail valide";
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return "Veuillez entrer un mot de passe";
    }
    if (value.trim().length < 6) {
      return "Veuillez entrer un mot de passe d'au moins 6 caractères";
    }
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return "Veuillez confirmer votre mot de passe";
    }
    if (value != password) {
      return "Les mots de passe ne correspondent pas";
    }
    return null;
  }
}