const admin = require("firebase-admin");
const { Resend } = require("resend");

const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();
const resend = new Resend(process.env.RESEND_API_KEY);

async function main() {
  const now = new Date();
  const firstDayThisMonth = new Date(now.getFullYear(), now.getMonth() + 1, 1);
  const firstDayLastMonth = new Date(now.getFullYear(), now.getMonth(), 1);
  const monthLabel = firstDayLastMonth.toLocaleString("fr-FR", {
    month: "long",
    year: "numeric",
  });

  console.log(`Génération du récapitulatif pour : ${monthLabel}`);

  const ordersSnap = await db
    .collection("orders")
    .where("createdAt", ">=", firstDayLastMonth.toISOString())
    .where("createdAt", "<", firstDayThisMonth.toISOString())
    .get();

  if (ordersSnap.empty) {
    console.log("Aucune commande ce mois-ci.");
    process.exit(0);
  }

  // Grouper par email
  const ordersByEmail = {};
  ordersSnap.forEach((doc) => {
    const data = doc.data();
    const email = data.email;
    if (!email) return; // ignorer les commandes sans email
    if (!ordersByEmail[email]) ordersByEmail[email] = [];
    ordersByEmail[email].push(data);
  });

  // Générer le CSV
  const csvContent = generateCSV(ordersByEmail, monthLabel);
  const base64 = Buffer.from(csvContent, "utf-8").toString("base64");

  // Envoyer à toi-même
  await resend.emails.send({
    from: process.env.MAIL_FROM,
    to: process.env.MAIL_FROM,
    subject: `Récapitulatif des commandes – ${monthLabel}`,
    html: `
      <p>Bonjour,</p>
      <p>Veuillez trouver ci-joint le récapitulatif des commandes de <strong>${monthLabel}</strong>.</p>
      <p>${Object.keys(ordersByEmail).length} compte(s) ont passé des commandes ce mois-ci.</p>
    `,
    attachments: [
      {
        filename: `recap_${monthLabel.replace(" ", "_")}.csv`,
        content: base64,
      },
    ],
  });

  console.log(`✅ Récapitulatif envoyé à tresor@voile-evian.fr`);
  process.exit(0);
}

function generateCSV(ordersByEmail, monthLabel) {
  const lines = [];

  // En-tête du fichier
  lines.push(`Récapitulatif des commandes - ${monthLabel}`);
  lines.push("");
  lines.push("Email,Produit,Quantité,Prix unitaire,Sous-total,Date");

  const totauxParPersonne = {};

  for (const [email, orders] of Object.entries(ordersByEmail)) {
    let totalPersonne = 0;

    for (const order of orders) {
      const date = new Date(order.createdAt).toLocaleDateString("fr-FR");
      for (const item of order.items) {
        const lineTotal = item.price * item.quantity;
        totalPersonne += lineTotal;
        lines.push(
          `${email},${item.productName},${item.quantity},${item.price.toFixed(2)} €,${lineTotal.toFixed(2)} €,${date}`
        );
      }
    }

    totauxParPersonne[email] = totalPersonne;
  }

  // Séparateur
  lines.push("");
  lines.push("--- TOTAUX PAR PERSONNE ---");
  lines.push("");
  lines.push("Email,Total du mois");

  for (const [email, total] of Object.entries(totauxParPersonne)) {
    lines.push(`${email},${total.toFixed(2)} €`);
  }

  return lines.join("\n");
}

main().catch((err) => {
  console.error("Erreur fatale :", err);
  process.exit(1);
});