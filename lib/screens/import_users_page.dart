// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:file_picker/file_picker.dart';
// import 'package:csv/csv.dart';

// Future<List<List<dynamic>>> readCSV() async {
//   FilePickerResult? resultat = await FilePicker.platform.pickFiles();
//   if (resultat != null) {
//     PlatformFile fichier = resultat.files.first;
//     String contenu = String.fromCharCodes(fichier.bytes!);
//     return CsvCodec().decoder.convert(contenu);
//   } else {
//     throw Exception("Aucun fichier sélectionné");
//   }
// }

// class ImportUsersPage extends StatelessWidget {
//   const ImportUsersPage({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("Importer des users")),
//       body: Center(
//         child: ElevatedButton(
//           onPressed: () async {
//             await createUsersFromCSV(context);
//           },
//           child: const Text("Importer les users"),
//         ),
//       ),
//     );
//   }

//   Future<void> createUsersFromCSV(BuildContext context) async {
//     try {
//       List<List<dynamic>> lignesCSV = await readCSV();
//       FirebaseAuth auth = FirebaseAuth.instance;
//       FirebaseFirestore firestore = FirebaseFirestore.instance;

//       for (var i = 1; i < lignesCSV.length; i++) {
//         String name = lignesCSV[i][0];
//         String email = lignesCSV[i][1];
//         String password = lignesCSV[i][2];

//         UserCredential users = await auth.createUserWithEmailAndPassword(
//           email: email,
//           password: password,
//         );

//         await firestore.collection('users').doc(users.user!.uid).set({
//           'name': name,
//           'email': email,
//           'password': password,
//         });

//       }

//     //   ScaffoldMessenger.of(context).showSnackBar(
//     //     const SnackBar(content: Text("Import terminé avec succès !")),
//     //   );
//     // } catch (e) {
//     //   ScaffoldMessenger.of(context).showSnackBar(
//     //     SnackBar(content: Text("Erreur lors de l'import : $e")),
//     //   );
//     }
//   }

// }
