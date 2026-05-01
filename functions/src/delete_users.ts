// import admin from "./firebase-admin";

// const EMAILS_A_GARDER = [
//   "juliegouin@outlook.com",
//   "patferaco@hotmail.com"
// ];

// async function deleteUsersExcept() {
//   let nextPageToken: string | undefined;
//   let totalSupprimes = 0;

//   do {
//     const result = await admin.auth().listUsers(1000, nextPageToken);

//     const uidsASupprimer = result.users
//       .filter(u => !EMAILS_A_GARDER.includes(u.email ?? ""))
//       .map(u => u.uid);

//     if (uidsASupprimer.length > 0) {
//       await admin.auth().deleteUsers(uidsASupprimer);
//       totalSupprimes += uidsASupprimer.length;
//       console.log(`${uidsASupprimer.length} utilisateur(s) supprimé(s)`);
//     }

//     nextPageToken = result.pageToken;
//   } while (nextPageToken);

//   console.log(`Terminé — ${totalSupprimes} utilisateur(s) supprimé(s) au total`);
// }

// deleteUsersExcept();