import ExcelJS from "exceljs";
import { UserGroup, CheckoutResult } from "./types";
import admin from "./firebase-admin";

const db = admin.firestore();

const BLUE_DARK = "FF2D5478";
const BLUE_MID = "FF4A90B8";
const BLUE_LIGHT = "FFE8F4FB";
const WHITE = "FFFFFFFF";
const RED_LIGHT = "FFFFF0F0";
const RED_DARK = "FFC0392B";

function styleHeader(row: ExcelJS.Row): void {
  row.eachCell((cell) => {
    cell.font = { bold: true, color: { argb: WHITE } };
    cell.fill = {
      type: "pattern",
      pattern: "solid",
      fgColor: { argb: BLUE_MID },
    };
    cell.alignment = { horizontal: "center", vertical: "middle" };
  });
}

function styleTitle(cell: ExcelJS.Cell, text: string, color = BLUE_DARK): void {
  cell.value = text;
  cell.font = { bold: true, size: 15, color: { argb: WHITE } };
  cell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: color } };
  cell.alignment = { horizontal: "center", vertical: "middle" };
}

function formatMonthKey(monthKey: string): string {
  const fullMonths = [
    "",
    "janvier",
    "février",
    "mars",
    "avril",
    "mai",
    "juin",
    "juillet",
    "août",
    "septembre",
    "octobre",
    "novembre",
    "décembre",
  ];
  const [year, month] = monthKey.split("-").map(Number);
  return `${fullMonths[month]} ${year}`;
}

export async function generateExcel(
  byUser: Record<string, UserGroup>,
  checkoutResults: CheckoutResult[],
  monthLabel: string,
  orgSlug: string,
): Promise<Buffer> {
  const workbook = new ExcelJS.Workbook();

  // ── Onglet 1 : Détail ──────────────────────────────────────────
  const detailSheet = workbook.addWorksheet(`Détail ${monthLabel}`);
  detailSheet.columns = [
    { key: "firstName", width: 14 },
    { key: "lastName", width: 14 },
    { key: "date", width: 14 },
    { key: "product", width: 26 },
    { key: "quantity", width: 12 },
    { key: "unitPrice", width: 16 },
    { key: "subtotal", width: 16 },
  ];
  detailSheet.mergeCells("A1:G1");
  styleTitle(detailSheet.getCell("A1"), `Détail des commandes – ${monthLabel}`);
  detailSheet.getRow(1).height = 34;
  detailSheet.addRow([]);
  styleHeader(
    detailSheet.addRow([
      "Prénom",
      "Nom",
      "Date",
      "Produit",
      "Quantité",
      "Prix unitaire",
      "Sous-total",
    ]),
  );

  let rowIndex = 4;
  for (const user of Object.values(byUser)) {
    for (const order of user.orders) {
      const date = new Date(order.createdAt).toLocaleDateString("fr-FR");
      for (const item of order.items) {
        const row = detailSheet.addRow([
          user.firstName,
          user.lastName,
          date,
          item.productName,
          item.quantity,
          item.price,
          item.price * item.quantity,
        ]);
        const bg = rowIndex % 2 === 0 ? BLUE_LIGHT : WHITE;
        row.eachCell((cell) => {
          cell.fill = {
            type: "pattern",
            pattern: "solid",
            fgColor: { argb: bg },
          };
          cell.alignment = { horizontal: "center" };
        });
        row.getCell(6).numFmt = '#,##0.00 "€"';
        row.getCell(7).numFmt = '#,##0.00 "€"';
        rowIndex++;
      }
    }
  }

  // ── Onglet 2 : Totaux + lien de paiement ───────────────────────
  const summarySheet = workbook.addWorksheet(`Totaux ${monthLabel}`);
  summarySheet.columns = [
    { key: "firstName", width: 14 },
    { key: "lastName", width: 14 },
    { key: "email", width: 32 },
    { key: "total", width: 16 },
    { key: "status", width: 12 },
    { key: "url", width: 60 },
  ];
  summarySheet.mergeCells("A1:F1");
  styleTitle(summarySheet.getCell("A1"), `Totaux & paiements – ${monthLabel}`);
  summarySheet.getRow(1).height = 34;
  summarySheet.addRow([]);
  styleHeader(
    summarySheet.addRow([
      "Prénom",
      "Nom",
      "Email",
      "Total du mois",
      "Statut",
      "Lien de paiement",
    ]),
  );

  let grandTotal = 0;
  let summaryRowIndex = 4;

  for (const result of checkoutResults) {
    const invoiceSnap = await db
      .collection("monthly_invoices")
      .where("email", "==", result.email)
      .where("checkoutId", "==", result.checkoutId)
      .limit(1)
      .get();

    const invoiceId = !invoiceSnap.empty ? invoiceSnap.docs[0].id : null;
    const deepLink = invoiceId
      ? `https://cve-bar.web.app/pay?invoiceId=${invoiceId}`
      : result.checkoutUrl;

    const row = summarySheet.addRow([
      result.firstName,
      result.lastName,
      result.email,
      result.status === "ok" ? result.total : "—",
      result.status === "ok" ? "✅ Envoyé" : "❌ Erreur",
      "",
    ]);

    const bg = summaryRowIndex % 2 === 0 ? BLUE_LIGHT : WHITE;
    row.eachCell((cell) => {
      cell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: bg } };
      cell.alignment = { horizontal: "center" };
    });

    if (result.status === "ok") {
      row.getCell(4).numFmt = '#,##0.00 "€"';
      const urlCell = row.getCell(6);
      urlCell.value = {
        text: "Ouvrir le lien",
        hyperlink: deepLink,
      } as ExcelJS.CellHyperlinkValue;
      urlCell.font = { color: { argb: "FF0070C0" }, underline: true };
      grandTotal += result.total;
    } else {
      row.getCell(6).value = result.error ?? "Erreur inconnue";
      row.getCell(6).font = { color: { argb: RED_DARK } };
    }

    summaryRowIndex++;
  }

  summarySheet.addRow([]);
  const grandTotalRow = summarySheet.addRow([
    "TOTAL GÉNÉRAL",
    "",
    "",
    grandTotal,
    "",
    "",
  ]);
  grandTotalRow.eachCell((cell) => {
    cell.font = { bold: true, color: { argb: WHITE } };
    cell.fill = {
      type: "pattern",
      pattern: "solid",
      fgColor: { argb: BLUE_DARK },
    };
    cell.alignment = { horizontal: "center" };
  });
  grandTotalRow.getCell(4).numFmt = '#,##0.00 "€"';

  // ── Onglet 3 : Impayés historiques ────────────────────────────
  const unpaidSheet = workbook.addWorksheet("⚠️ Impayés");
  unpaidSheet.columns = [
    { key: "firstName", width: 16 },
    { key: "lastName", width: 16 },
    { key: "email", width: 32 },
    { key: "month", width: 18 },
    { key: "total", width: 16 },
    { key: "createdAt", width: 20 },
    { key: "url", width: 60 },
  ];
  unpaidSheet.mergeCells("A1:G1");
  styleTitle(
    unpaidSheet.getCell("A1"),
    "Factures impayées — tous mois confondus",
    RED_DARK,
  );
  unpaidSheet.getRow(1).height = 34;
  unpaidSheet.addRow([]);
  styleHeader(
    unpaidSheet.addRow([
      "Prénom",
      "Nom",
      "Email",
      "Mois",
      "Montant",
      "Créée le",
      "Lien de paiement",
    ]),
  );

  const pendingSnap = await db
    .collection("monthly_invoices")
    .where("status", "==", "pending")
    .get();

  const docs = pendingSnap.docs.sort(
    (a, b) => (b.data().createdAt ?? 0) - (a.data().createdAt ?? 0),
  );

  // Regrouper les factures impayées par email
  type UnpaidGroup = {
    firstName: string;
    lastName: string;
    email: string;
    totalAmount: number;
    invoices: Array<{
      month: string;
      total: number;
      createdAt: number;
      deepLink: string;
    }>;
  };

  const unpaidByUser: Record<string, UnpaidGroup> = {};
  for (const doc of docs) {
    const inv = doc.data();
    const email = inv.email ?? "";
    const deepLink = `https://cve-bar.web.app/pay?invoiceId=${doc.id}`;

    if (!unpaidByUser[email]) {
      unpaidByUser[email] = {
        firstName: inv.firstName ?? "",
        lastName: inv.lastName ?? "",
        email,
        totalAmount: 0,
        invoices: [],
      };
    }
    unpaidByUser[email].totalAmount += inv.total ?? 0;
    unpaidByUser[email].invoices.push({
      month: formatMonthKey(inv.month ?? ""),
      total: inv.total ?? 0,
      createdAt: inv.createdAt ?? 0,
      deepLink,
    });
  }

  let unpaidTotal = 0;
  let unpaidRowIdx = 4;

  if (docs.length === 0) {
    const emptyRow = unpaidSheet.addRow([
      "Aucune facture impayée",
      "",
      "",
      "",
      "",
      "",
      "",
    ]);
    emptyRow.getCell(1).font = { italic: true, color: { argb: "FF888888" } };
    emptyRow.getCell(1).alignment = { horizontal: "center" };
    unpaidSheet.mergeCells("A4:G4");
  } else {
    for (const group of Object.values(unpaidByUser)) {
      const bg = unpaidRowIdx % 2 === 0 ? RED_LIGHT : WHITE;

      // Ligne de sous-total par utilisateur (en gras)
      const userRow = unpaidSheet.addRow([
        group.firstName,
        group.lastName,
        group.email,
        `${group.invoices.length} facture(s)`,
        group.totalAmount,
        "",
        `${group.invoices[0].deepLink}`,
      ]);
      userRow.eachCell((cell) => {
        cell.fill = {
          type: "pattern",
          pattern: "solid",
          fgColor: { argb: bg },
        };
        cell.alignment = { horizontal: "center" };
        cell.font = { bold: true };
      });
      userRow.getCell(5).numFmt = '#,##0.00 "€"';

      const urlCell = userRow.getCell(7);
      urlCell.value = {
        text: "Lien de paiement",
        hyperlink: group.invoices[0].deepLink,
      } as ExcelJS.CellHyperlinkValue;
      urlCell.font = { color: { argb: "FF0070C0" }, underline: true };
      unpaidRowIdx++;

      unpaidTotal += group.totalAmount;
    }

    unpaidSheet.addRow([]);
    const totalRow = unpaidSheet.addRow([
      "TOTAL IMPAYÉ",
      "",
      "",
      "",
      unpaidTotal,
      "",
      "",
    ]);
    totalRow.eachCell((cell) => {
      cell.font = { bold: true, color: { argb: WHITE } };
      cell.fill = {
        type: "pattern",
        pattern: "solid",
        fgColor: { argb: RED_DARK },
      };
      cell.alignment = { horizontal: "center" };
    });
    totalRow.getCell(5).numFmt = '#,##0.00 "€"';
  }

  return Buffer.from(await workbook.xlsx.writeBuffer());
}
