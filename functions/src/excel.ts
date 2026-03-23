import ExcelJS from "exceljs";
import { UserGroup, CheckoutResult } from "./types";

const BLUE_DARK  = "FF2D5478";
const BLUE_MID   = "FF4A90B8";
const BLUE_LIGHT = "FFE8F4FB";
const WHITE      = "FFFFFFFF";

function styleHeader(row: ExcelJS.Row): void {
  row.eachCell((cell) => {
    cell.font  = { bold: true, color: { argb: WHITE } };
    cell.fill  = { type: "pattern", pattern: "solid", fgColor: { argb: BLUE_MID } };
    cell.alignment = { horizontal: "center", vertical: "middle" };
  });
}

function styleTitle(cell: ExcelJS.Cell, text: string): void {
  cell.value = text;
  cell.font  = { bold: true, size: 15, color: { argb: WHITE } };
  cell.fill  = { type: "pattern", pattern: "solid", fgColor: { argb: BLUE_DARK } };
  cell.alignment = { horizontal: "center", vertical: "middle" };
}

export async function generateExcel(
  byUser: Record<string, UserGroup>,
  checkoutResults: CheckoutResult[],
  monthLabel: string
): Promise<Buffer> {
  const workbook = new ExcelJS.Workbook();

  // ── Onglet 1 : Détail ──────────────────────────────────────────
  const detailSheet = workbook.addWorksheet("Détail");
  detailSheet.columns = [
    { key: "firstName", width: 14 },
    { key: "lastName",  width: 14 },
    { key: "date",      width: 14 },
    { key: "product",   width: 26 },
    { key: "quantity",  width: 12 },
    { key: "unitPrice", width: 16 },
    { key: "subtotal",  width: 16 },
  ];
  detailSheet.mergeCells("A1:F1");
  styleTitle(detailSheet.getCell("A1"), `Détail des commandes – ${monthLabel}`);
  detailSheet.getRow(1).height = 34;
  detailSheet.addRow([]);
  styleHeader(detailSheet.addRow([
    "Nom", "Date", "Produit", "Quantité", "Prix unitaire", "Sous-total",
  ]));

  let rowIndex = 4;
  for (const user of Object.values(byUser)) {
    for (const order of user.orders) {
      const date = new Date(order.createdAt).toLocaleDateString("fr-FR");
      for (const item of order.items) {
        const row = detailSheet.addRow([
          user.firstName || user.lastName, date,
          item.productName, item.quantity,
          item.price, item.price * item.quantity,
        ]);
        const bg = rowIndex % 2 === 0 ? BLUE_LIGHT : WHITE;
        row.eachCell((cell) => {
          cell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: bg } };
          cell.alignment = { horizontal: "center" };
        });
        row.getCell(5).numFmt = '#,##0.00 "€"';
        row.getCell(6).numFmt = '#,##0.00 "€"';
        rowIndex++;
      }
    }
  }

  // ── Onglet 2 : Totaux ──────────────────────────────────────────
  const summarySheet = workbook.addWorksheet("Totaux");
  summarySheet.columns = [
    { key: "firstName",  width: 14 },
    { key: "lastName",  width: 14 },
    { key: "total", width: 18 },
  ];
  summarySheet.mergeCells("A1:B1");
  styleTitle(summarySheet.getCell("A1"), `Totaux par personne – ${monthLabel}`);
  summarySheet.getRow(1).height = 34;
  summarySheet.addRow([]);
  styleHeader(summarySheet.addRow(["Nom", "Total du mois"]));

  let grandTotal = 0;
  let summaryRowIndex = 4;
  for (const user of Object.values(byUser)) {
    const row = summarySheet.addRow([user.firstName || user.lastName, user.total]);
    const bg  = summaryRowIndex % 2 === 0 ? BLUE_LIGHT : WHITE;
    row.eachCell((cell) => {
      cell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: bg } };
      cell.alignment = { horizontal: "center" };
    });
    row.getCell(2).numFmt = '#,##0.00 "€"';
    grandTotal += user.total;
    summaryRowIndex++;
  }
  summarySheet.addRow([]);
  const grandTotalRow = summarySheet.addRow(["TOTAL GÉNÉRAL", grandTotal]);
  grandTotalRow.eachCell((cell) => {
    cell.font  = { bold: true, color: { argb: WHITE } };
    cell.fill  = { type: "pattern", pattern: "solid", fgColor: { argb: BLUE_DARK } };
    cell.alignment = { horizontal: "center" };
  });
  grandTotalRow.getCell(2).numFmt = '#,##0.00 "€"';

  // ── Onglet 3 : Liens HelloAsso ─────────────────────────────────
  const haSheet = workbook.addWorksheet("Liens HelloAsso");
  haSheet.columns = [
    { key: "firstName",   width: 28 },
    { key: "lastName",  width: 34 },
    { key: "email",  width: 32 },
    { key: "total",  width: 16 },
    { key: "status", width: 12 },
    { key: "url",    width: 60 },
  ];
  haSheet.mergeCells("A1:E1");
  styleTitle(haSheet.getCell("A1"), `Liens de paiement HelloAsso – ${monthLabel}`);
  haSheet.getRow(1).height = 34;
  haSheet.addRow([]);
  styleHeader(haSheet.addRow(["Nom", "Email", "Montant", "Statut", "Lien de paiement"]));

  let haRowIndex = 4;
  for (const result of checkoutResults) {
    const row = haSheet.addRow([
      result.firstName || result.lastName,
      result.email,
      result.status === "ok" ? result.total : "—",
      result.status === "ok" ? "✅ Envoyé" : "❌ Erreur",
      result.status === "ok" ? result.checkoutUrl : result.error ?? "",
    ]);
    const bg = haRowIndex % 2 === 0 ? BLUE_LIGHT : WHITE;
    row.eachCell((cell) => {
      cell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: bg } };
      cell.alignment = { horizontal: "center" };
    });
    if (result.status === "ok") {
      row.getCell(3).numFmt = '#,##0.00 "€"';
      const urlCell   = row.getCell(5);
      urlCell.value   = { text: "Ouvrir", hyperlink: result.checkoutUrl } as ExcelJS.CellHyperlinkValue;
      urlCell.font    = { color: { argb: "FF0070C0" }, underline: true };
    }
    haRowIndex++;
  }

  return Buffer.from(await workbook.xlsx.writeBuffer());
}