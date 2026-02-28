const admin = require("firebase-admin");
const ExcelJS = require("exceljs");
const { Resend } = require("resend");

// Init Firebase avec le service account stocké dans les secrets GitHub
const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();
const resend = new Resend(process.env.RESEND_API_KEY);

async function main() {
  const now = new Date();
  const firstDayThisMonth = new Date(now.getFullYear(), now.getMonth(), 1);
  const firstDayLastMonth = new Date(now.getFullYear(), now.getMonth() - 1, 1);
  const monthLabel = firstDayLastMonth.toLocaleString("fr-FR", {
    month: "long",
    year: "numeric",
  });

  console.log(`Génération des factures pour : ${monthLabel}`);

  // Récupérer les commandes du mois précédent
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
    if (!ordersByEmail[data.email]) ordersByEmail[data.email] = [];
    ordersByEmail[data.email].push(data);
  });

  // Générer et envoyer une facture par utilisateur
  for (const [email, orders] of Object.entries(ordersByEmail)) {
    try {
      const excelBuffer = await generateExcel(email, orders, monthLabel);
      await sendInvoiceEmail(email, excelBuffer, monthLabel);
      console.log(`✅ Facture envoyée à ${email}`);
    } catch (err) {
      console.error(`❌ Erreur pour ${email} :`, err);
    }
  }

  process.exit(0);
}

async function generateExcel(email, orders, monthLabel) {
  const workbook = new ExcelJS.Workbook();
  const sheet = workbook.addWorksheet("Facture");

  // En-tête
  sheet.mergeCells("A1:D1");
  sheet.getCell("A1").value = `Facture – ${monthLabel}`;
  sheet.getCell("A1").font = { bold: true, size: 16 };
  sheet.getCell("A1").alignment = { horizontal: "center" };

  sheet.mergeCells("A2:D2");
  sheet.getCell("A2").value = email;
  sheet.getCell("A2").alignment = { horizontal: "center" };

  sheet.addRow([]);

  sheet.columns = [
    { key: "date", width: 20 },
    { key: "product", width: 25 },
    { key: "quantity", width: 12 },
    { key: "price", width: 12 },
  ];

  const headerRow = sheet.addRow(["Date", "Produit", "Quantité", "Prix"]);
  headerRow.eachCell((cell) => {
    cell.font = { bold: true, color: { argb: "FFFFFFFF" } };
    cell.fill = {
      type: "pattern",
      pattern: "solid",
      fgColor: { argb: "FF2D5478" },
    };
    cell.alignment = { horizontal: "center" };
  });

  let grandTotal = 0;

  for (const order of orders) {
    const date = new Date(order.createdAt).toLocaleDateString("fr-FR");
    for (const item of order.items) {
      const lineTotal = item.price * item.quantity;
      grandTotal += lineTotal;
      const row = sheet.addRow([
        date,
        item.productName,
        item.quantity,
        `${lineTotal.toFixed(2)} €`,
      ]);
      row.getCell(4).alignment = { horizontal: "right" };
    }
  }

  sheet.addRow([]);
  const totalRow = sheet.addRow(["", "", "TOTAL", `${grandTotal.toFixed(2)} €`]);
  totalRow.eachCell((cell) => { cell.font = { bold: true }; });
  totalRow.getCell(3).alignment = { horizontal: "right" };
  totalRow.getCell(4).alignment = { horizontal: "right" };

  return await workbook.xlsx.writeBuffer();
}

async function sendInvoiceEmail(email, excelBuffer, monthLabel) {
  const base64 = Buffer.from(excelBuffer).toString("base64");

  await resend.emails.send({
    from: process.env.MAIL_FROM,
    to: email,
    subject: `Votre facture de consommation – ${monthLabel}`,
    html: `
      <p>Bonjour,</p>
      <p>Veuillez trouver ci-joint votre facture de consommation pour <strong>${monthLabel}</strong>.</p>
      <p>Cordialement</p>
    `,
    attachments: [
      {
        filename: `facture_${monthLabel.replace(" ", "_")}.xlsx`,
        content: base64,
      },
    ],
  });
}

main().catch((err) => {
  console.error("Erreur fatale :", err);
  process.exit(1);
});