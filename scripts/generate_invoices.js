const admin = require("firebase-admin");
const ExcelJS = require("exceljs");
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

  // Grouper par name
  const ordersByName = {};
  ordersSnap.forEach((doc) => {
    const data = doc.data();
    const name = data.name;
    if (!name) return;
    if (!ordersByName[name]) ordersByName[name] = [];
    ordersByName[name].push(data);
  });

  const excelBuffer = await generateExcel(ordersByName, monthLabel);
  const base64 = Buffer.from(excelBuffer).toString("base64");

  await resend.emails.send({
    from: process.env.MAIL_FROM,
    to: process.env.MAIL_FROM,
    subject: `Récapitulatif des commandes – ${monthLabel}`,
    html: `
      <p>Bonjour,</p>
      <p>Veuillez trouver ci-joint le récapitulatif des commandes de <strong>${monthLabel}</strong>.</p>
      <p>${Object.keys(ordersByName).length} compte(s) ont passé des commandes ce mois-ci.</p>
    `,
    attachments: [
      {
        filename: `recap_${monthLabel.replace(" ", "_")}.xlsx`,
        content: base64,
      },
    ],
  });

  console.log(`✅ Récapitulatif envoyé à ${process.env.MAIL_FROM}`);
  process.exit(0);
}

async function generateExcel(ordersByName, monthLabel) {
  const workbook = new ExcelJS.Workbook();

  // ── Onglet 1 : Détail des commandes ──────────────────────────────
  const detailSheet = workbook.addWorksheet("Détail");

  // Titre
  detailSheet.mergeCells("A1:F1");
  const titleCell = detailSheet.getCell("A1");
  titleCell.value = `Récapitulatif des commandes – ${monthLabel}`;
  titleCell.font = { bold: true, size: 16, color: { argb: "FFFFFFFF" } };
  titleCell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: "FF2D5478" } };
  titleCell.alignment = { horizontal: "center", vertical: "middle" };
  detailSheet.getRow(1).height = 35;

  detailSheet.addRow([]);

  // En-têtes colonnes
  const detailHeaders = detailSheet.addRow([
    "Name", "Date", "Produit", "Quantité", "Prix unitaire", "Sous-total"
  ]);
  detailSheet.columns = [
    { key: "name",    width: 30 },
    { key: "date",     width: 15 },
    { key: "product",  width: 25 },
    { key: "quantity", width: 12 },
    { key: "unitPrice",width: 15 },
    { key: "subtotal", width: 15 },
  ];
  detailHeaders.eachCell((cell) => {
    cell.font = { bold: true, color: { argb: "FFFFFFFF" } };
    cell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: "FF4A90B8" } };
    cell.alignment = { horizontal: "center" };
    cell.border = { bottom: { style: "thin", color: { argb: "FF2D5478" } } };
  });

  // Données
  let rowIndex = 4;
  for (const [name, orders] of Object.entries(ordersByName)) {
    for (const order of orders) {
      const date = new Date(order.createdAt).toLocaleDateString("fr-FR");
      for (const item of order.items) {
        const lineTotal = item.price * item.quantity;
        const row = detailSheet.addRow([
          name,
          date,
          item.productName,
          item.quantity,
          item.price,
          lineTotal,
        ]);
        // Alterner les couleurs de lignes
        const bgColor = rowIndex % 2 === 0 ? "FFE8F4FB" : "FFFFFFFF";
        row.eachCell((cell) => {
          cell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: bgColor } };
          cell.alignment = { horizontal: "center" };
        });
        // Format euro
        row.getCell(5).numFmt = '#,##0.00 "€"';
        row.getCell(6).numFmt = '#,##0.00 "€"';
        rowIndex++;
      }
    }
  }

  // ── Onglet 2 : Totaux par personne ───────────────────────────────
  const summarySheet = workbook.addWorksheet("Totaux");

  summarySheet.mergeCells("A1:B1");
  const summaryTitle = summarySheet.getCell("A1");
  summaryTitle.value = `Totaux par personne – ${monthLabel}`;
  summaryTitle.font = { bold: true, size: 16, color: { argb: "FFFFFFFF" } };
  summaryTitle.fill = { type: "pattern", pattern: "solid", fgColor: { argb: "FF2D5478" } };
  summaryTitle.alignment = { horizontal: "center", vertical: "middle" };
  summarySheet.getRow(1).height = 35;

  summarySheet.addRow([]);

  summarySheet.columns = [
    { key: "email", width: 35 },
    { key: "total", width: 18 },
  ];

  const summaryHeaders = summarySheet.addRow(["Email", "Total du mois"]);
  summaryHeaders.eachCell((cell) => {
    cell.font = { bold: true, color: { argb: "FFFFFFFF" } };
    cell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: "FF4A90B8" } };
    cell.alignment = { horizontal: "center" };
  });

  let grandTotal = 0;
  let summaryRowIndex = 4;

  for (const [email, orders] of Object.entries(ordersByEmail)) {
    let totalPersonne = 0;
    for (const order of orders) {
      for (const item of order.items) {
        totalPersonne += item.price * item.quantity;
      }
    }
    grandTotal += totalPersonne;

    const row = summarySheet.addRow([email, totalPersonne]);
    const bgColor = summaryRowIndex % 2 === 0 ? "FFE8F4FB" : "FFFFFFFF";
    row.eachCell((cell) => {
      cell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: bgColor } };
      cell.alignment = { horizontal: "center" };
    });
    row.getCell(2).numFmt = '#,##0.00 "€"';
    summaryRowIndex++;
  }

  // Ligne grand total
  summarySheet.addRow([]);
  const grandTotalRow = summarySheet.addRow(["TOTAL GÉNÉRAL", grandTotal]);
  grandTotalRow.eachCell((cell) => {
    cell.font = { bold: true, color: { argb: "FFFFFFFF" } };
    cell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: "FF2D5478" } };
    cell.alignment = { horizontal: "center" };
  });
  grandTotalRow.getCell(2).numFmt = '#,##0.00 "€"';

  return await workbook.xlsx.writeBuffer();
}

main().catch((err) => {
  console.error("Erreur fatale :", err);
  process.exit(1);
});