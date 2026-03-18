import admin from "firebase-admin";
import ExcelJS from "exceljs";
import { Resend } from "resend";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { onRequest } from "firebase-functions/https";

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

// ════════════════════════════════════════════════════════════════
// TYPES
// ════════════════════════════════════════════════════════════════

interface OrderItem {
  productName: string;
  price: number;
  quantity: number;
}

interface Order {
  uid: string;
  email: string;
  name?: string;
  total: number;
  createdAt: string;
  items: OrderItem[];
}

interface UserGroup {
  uid: string;
  email: string;
  name: string;
  total: number;
  orders: Order[];
  orderIds: string[];
}

interface CheckoutResult {
  uid: string;
  email: string;
  name: string;
  total: number;
  checkoutId: string;
  checkoutUrl: string;
  status: "ok" | "error";
  error?: string;
}

// ════════════════════════════════════════════════════════════════
// HELLOASSO
// ════════════════════════════════════════════════════════════════

async function getHelloAssoToken(): Promise<string> {
  const res = await fetch("https://api.helloasso.com/oauth2/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "client_credentials",
      client_id: process.env.HELLOASSO_CLIENT_ID!,
      client_secret: process.env.HELLOASSO_CLIENT_SECRET!,
    }),
  });
  const data = await res.json();
  if (!data.access_token)
    throw new Error("HelloAsso token failed: " + JSON.stringify(data));
  return data.access_token;
}

async function createCheckout(
  token: string,
  orgSlug: string,
  params: {
    totalCents: number;
    label: string;
    email: string;
    firstName: string;
    lastName: string;
    month: string;
  }
): Promise<{ id: string; redirectUrl: string }> {
  const res = await fetch(
    `https://api.helloasso.com/v5/organizations/${orgSlug}/checkouts`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        backUrl:   process.env.HELLOASSO_BACK_URL!,
        errorUrl:  process.env.HELLOASSO_ERROR_URL!,
        returnUrl: process.env.HELLOASSO_RETURN_URL!,
        totalAmount: params.totalCents,
        initialAmount: params.totalCents,
        itemName: params.label,
        containsDonation: false,
        payer: {
          email: params.email,
          firstName: params.firstName,
          lastName: params.lastName,
        },
        metadata: { month: params.month },
      }),
    }
  );
  const data = await res.json();
  if (!data.redirectUrl)
    throw new Error("Checkout failed: " + JSON.stringify(data));
  return { id: data.id, redirectUrl: data.redirectUrl };
}

// ════════════════════════════════════════════════════════════════
// EXCEL
// ════════════════════════════════════════════════════════════════

async function generateExcel(
  byUser: Record<string, UserGroup>,
  checkoutResults: CheckoutResult[],
  monthLabel: string
): Promise<Buffer> {
  const workbook = new ExcelJS.Workbook();

  const BLUE_DARK  = "FF2D5478";
  const BLUE_MID   = "FF4A90B8";
  const BLUE_LIGHT = "FFE8F4FB";
  const WHITE      = "FFFFFFFF";

  const styleHeader = (row: ExcelJS.Row) => {
    row.eachCell((cell) => {
      cell.font = { bold: true, color: { argb: WHITE } };
      cell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: BLUE_MID } };
      cell.alignment = { horizontal: "center", vertical: "middle" };
    });
  };

  const styleTitle = (cell: ExcelJS.Cell, text: string) => {
    cell.value = text;
    cell.font = { bold: true, size: 15, color: { argb: WHITE } };
    cell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: BLUE_DARK } };
    cell.alignment = { horizontal: "center", vertical: "middle" };
  };

  // ── Onglet 1 : Détail des commandes ─────────────────────────────
  const detailSheet = workbook.addWorksheet("Détail");
  detailSheet.columns = [
    { key: "name",      width: 28 },
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

  const detailHeaderRow = detailSheet.addRow([
    "Nom", "Date", "Produit", "Quantité", "Prix unitaire", "Sous-total",
  ]);
  styleHeader(detailHeaderRow);

  let rowIndex = 4;
  for (const user of Object.values(byUser)) {
    for (const order of user.orders) {
      const date = new Date(order.createdAt).toLocaleDateString("fr-FR");
      for (const item of order.items) {
        const row = detailSheet.addRow([
          user.name || user.email,
          date,
          item.productName,
          item.quantity,
          item.price,
          item.price * item.quantity,
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

  // ── Onglet 2 : Totaux par personne ───────────────────────────────
  const summarySheet = workbook.addWorksheet("Totaux");
  summarySheet.columns = [
    { key: "name",  width: 34 },
    { key: "total", width: 18 },
  ];

  summarySheet.mergeCells("A1:B1");
  styleTitle(summarySheet.getCell("A1"), `Totaux par personne – ${monthLabel}`);
  summarySheet.getRow(1).height = 34;
  summarySheet.addRow([]);

  const summaryHeaderRow = summarySheet.addRow(["Nom", "Total du mois"]);
  styleHeader(summaryHeaderRow);

  let grandTotal = 0;
  let summaryRowIndex = 4;
  for (const user of Object.values(byUser)) {
    const row = summarySheet.addRow([user.name || user.email, user.total]);
    const bg = summaryRowIndex % 2 === 0 ? BLUE_LIGHT : WHITE;
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
    cell.font = { bold: true, color: { argb: WHITE } };
    cell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: BLUE_DARK } };
    cell.alignment = { horizontal: "center" };
  });
  grandTotalRow.getCell(2).numFmt = '#,##0.00 "€"';

  // ── Onglet 3 : Liens HelloAsso générés ──────────────────────────
  const helloassoSheet = workbook.addWorksheet("Liens HelloAsso");
  helloassoSheet.columns = [
    { key: "name",   width: 28 },
    { key: "email",  width: 32 },
    { key: "total",  width: 16 },
    { key: "status", width: 12 },
    { key: "url",    width: 60 },
  ];

  helloassoSheet.mergeCells("A1:E1");
  styleTitle(
    helloassoSheet.getCell("A1"),
    `Liens de paiement HelloAsso – ${monthLabel}`
  );
  helloassoSheet.getRow(1).height = 34;
  helloassoSheet.addRow([]);

  const haHeaderRow = helloassoSheet.addRow([
    "Nom", "Email", "Montant", "Statut", "Lien de paiement",
  ]);
  styleHeader(haHeaderRow);

  let haRowIndex = 4;
  for (const result of checkoutResults) {
    const row = helloassoSheet.addRow([
      result.name || result.email,
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
      // Lien cliquable
      const urlCell = row.getCell(5);
      urlCell.value = { text: "Ouvrir", hyperlink: result.checkoutUrl } as ExcelJS.CellHyperlinkValue;
      urlCell.font = { color: { argb: "FF0070C0" }, underline: true };
    }
    haRowIndex++;
  }

  const buffer = await workbook.xlsx.writeBuffer();
  return Buffer.from(buffer);
}

// ════════════════════════════════════════════════════════════════
// EMAIL CLIENT (HelloAsso)
// ════════════════════════════════════════════════════════════════

async function sendClientEmail(
  resend: Resend,
  fromEmail: string,
  params: {
    to: string;
    firstName: string;
    month: string;
    monthLabel: string;
    total: number;
    checkoutUrl: string;
    year: string;
  }
): Promise<void> {
  const { to, firstName, monthLabel, total, checkoutUrl, year } = params;

  await resend.emails.send({
    from: fromEmail,
    to,
    subject: `Votre facture ${monthLabel} — ${total.toFixed(2)} €`,
    html: `
      <!DOCTYPE html>
      <html lang="fr">
      <head><meta charset="UTF-8"></head>
      <body style="margin:0;padding:0;background:#f0f7fb;font-family:Georgia,serif;">
        <table width="100%" cellpadding="0" cellspacing="0">
          <tr><td align="center" style="padding:40px 20px;">
            <table width="560" cellpadding="0" cellspacing="0"
                   style="background:#fff;border-radius:16px;overflow:hidden;
                          box-shadow:0 4px 24px rgba(45,84,120,0.10);">
              <tr>
                <td style="background:#2D5478;padding:32px 40px;">
                  <p style="margin:0;color:#fff;font-size:22px;font-weight:bold;">
                    Votre facture mensuelle
                  </p>
                  <p style="margin:6px 0 0;color:#96c9de;font-size:14px;">
                    ${monthLabel}
                  </p>
                </td>
              </tr>
              <tr>
                <td style="padding:36px 40px;">
                  <p style="margin:0 0 16px;color:#2D5478;font-size:16px;">
                    Bonjour <strong>${firstName}</strong>,
                  </p>
                  <p style="margin:0 0 28px;color:#4a6a82;font-size:15px;line-height:1.6;">
                    Votre facture pour <strong>${monthLabel}</strong> est disponible.
                  </p>
                  <table width="100%" cellpadding="0" cellspacing="0"
                         style="background:#f0f7fb;border-radius:12px;margin-bottom:32px;">
                    <tr><td style="padding:20px 24px;">
                      <p style="margin:0;color:#4a6a82;font-size:13px;
                                 text-transform:uppercase;letter-spacing:1px;">
                        Montant total
                      </p>
                      <p style="margin:6px 0 0;color:#2D5478;font-size:32px;font-weight:bold;">
                        ${total.toFixed(2)} €
                      </p>
                    </td></tr>
                  </table>
                  <table cellpadding="0" cellspacing="0">
                    <tr>
                      <td style="border-radius:10px;background:#2D5478;">
                        <a href="${checkoutUrl}"
                           style="display:inline-block;padding:14px 32px;color:#fff;
                                  font-size:15px;font-weight:bold;text-decoration:none;">
                          Payer ma facture →
                        </a>
                      </td>
                    </tr>
                  </table>
                  <p style="margin:28px 0 0;color:#8aacbf;font-size:12px;line-height:1.5;">
                    Ce lien est personnel et sécurisé.
                  </p>
                </td>
              </tr>
              <tr>
                <td style="background:#f0f7fb;padding:20px 40px;
                            border-top:1px solid #ddedf5;">
                  <p style="margin:0;color:#8aacbf;font-size:12px;">
                    Envoyé automatiquement. © ${year}
                  </p>
                </td>
              </tr>
            </table>
          </td></tr>
        </table>
      </body>
      </html>
    `,
  });
}

// ════════════════════════════════════════════════════════════════
// EMAIL ADMIN (récap Excel)
// ════════════════════════════════════════════════════════════════

async function sendAdminEmail(
  resend: Resend,
  fromEmail: string,
  adminEmail: string,
  monthLabel: string,
  byUser: Record<string, UserGroup>,
  checkoutResults: CheckoutResult[],
  excelBuffer: Buffer
): Promise<void> {
  const nbOk    = checkoutResults.filter((r) => r.status === "ok").length;
  const nbError = checkoutResults.filter((r) => r.status === "error").length;
  const grandTotal = Object.values(byUser).reduce((s, u) => s + u.total, 0);

  const checkoutRows = checkoutResults
    .map((r) =>
      r.status === "ok"
        ? `<tr>
             <td style="padding:6px 12px;color:#2D5478;">${r.name || r.email}</td>
             <td style="padding:6px 12px;color:#2D5478;">${r.total.toFixed(2)} €</td>
             <td style="padding:6px 12px;">
               <a href="${r.checkoutUrl}" style="color:#2D5478;font-weight:bold;">
                 Lien HelloAsso
               </a>
             </td>
             <td style="padding:6px 12px;color:green;">✅ Envoyé</td>
           </tr>`
        : `<tr>
             <td style="padding:6px 12px;color:#2D5478;">${r.name || r.email}</td>
             <td style="padding:6px 12px;color:#2D5478;">—</td>
             <td style="padding:6px 12px;color:#c0392b;">${r.error ?? "Erreur inconnue"}</td>
             <td style="padding:6px 12px;color:red;">❌ Erreur</td>
           </tr>`
    )
    .join("");

  const filename = `recap_${monthLabel.replace(" ", "_")}.xlsx`;
  const base64   = excelBuffer.toString("base64");

  await resend.emails.send({
    from: fromEmail,
    to: adminEmail,
    subject: `[Admin] Facturation ${monthLabel} — ${nbOk}/${checkoutResults.length} envoyés`,
    html: `
      <!DOCTYPE html>
      <html lang="fr">
      <head><meta charset="UTF-8"></head>
      <body style="margin:0;padding:0;background:#f0f7fb;font-family:Georgia,serif;">
        <table width="100%" cellpadding="0" cellspacing="0">
          <tr><td align="center" style="padding:40px 20px;">
            <table width="640" cellpadding="0" cellspacing="0"
                   style="background:#fff;border-radius:16px;overflow:hidden;
                          box-shadow:0 4px 24px rgba(45,84,120,0.10);">

              <!-- Header -->
              <tr>
                <td style="background:#2D5478;padding:28px 40px;">
                  <p style="margin:0;color:#fff;font-size:20px;font-weight:bold;">
                    Récapitulatif facturation
                  </p>
                  <p style="margin:6px 0 0;color:#96c9de;font-size:14px;">
                    ${monthLabel}
                  </p>
                </td>
              </tr>

              <!-- KPIs -->
              <tr>
                <td style="padding:28px 40px 0;">
                  <table width="100%" cellpadding="0" cellspacing="0">
                    <tr>
                      <td width="33%" align="center"
                          style="background:#f0f7fb;border-radius:12px;padding:16px;">
                        <p style="margin:0;color:#4a6a82;font-size:12px;
                                   text-transform:uppercase;letter-spacing:1px;">
                          Comptes facturés
                        </p>
                        <p style="margin:4px 0 0;color:#2D5478;font-size:28px;
                                   font-weight:bold;">
                          ${Object.keys(byUser).length}
                        </p>
                      </td>
                      <td width="4%"></td>
                      <td width="33%" align="center"
                          style="background:#f0f7fb;border-radius:12px;padding:16px;">
                        <p style="margin:0;color:#4a6a82;font-size:12px;
                                   text-transform:uppercase;letter-spacing:1px;">
                          Total général
                        </p>
                        <p style="margin:4px 0 0;color:#2D5478;font-size:28px;
                                   font-weight:bold;">
                          ${grandTotal.toFixed(2)} €
                        </p>
                      </td>
                      <td width="4%"></td>
                      <td width="26%" align="center"
                          style="background:${nbError > 0 ? "#fff5f5" : "#f0fff4"};
                                 border-radius:12px;padding:16px;">
                        <p style="margin:0;color:#4a6a82;font-size:12px;
                                   text-transform:uppercase;letter-spacing:1px;">
                          HelloAsso
                        </p>
                        <p style="margin:4px 0 0;font-size:22px;font-weight:bold;
                                   color:${nbError > 0 ? "#c0392b" : "#27ae60"};">
                          ${nbOk} ✅ ${nbError > 0 ? `/ ${nbError} ❌` : ""}
                        </p>
                      </td>
                    </tr>
                  </table>
                </td>
              </tr>

              <!-- Tableau checkouts -->
              <tr>
                <td style="padding:28px 40px 0;">
                  <p style="margin:0 0 12px;color:#2D5478;font-weight:bold;font-size:15px;">
                    Liens HelloAsso générés
                  </p>
                  <table width="100%" cellpadding="0" cellspacing="0"
                         style="border-collapse:collapse;font-size:13px;">
                    <tr style="background:#2D5478;">
                      <th style="padding:8px 12px;color:#fff;text-align:left;">Nom</th>
                      <th style="padding:8px 12px;color:#fff;text-align:left;">Montant</th>
                      <th style="padding:8px 12px;color:#fff;text-align:left;">Lien</th>
                      <th style="padding:8px 12px;color:#fff;text-align:left;">Statut</th>
                    </tr>
                    ${checkoutRows}
                  </table>
                </td>
              </tr>

              <!-- Footer -->
              <tr>
                <td style="padding:24px 40px;border-top:1px solid #ddedf5;margin-top:28px;">
                  <p style="margin:0;color:#8aacbf;font-size:12px;">
                    Le fichier Excel détaillé est joint à cet email.
                  </p>
                </td>
              </tr>

            </table>
          </td></tr>
        </table>
      </body>
      </html>
    `,
    attachments: [{ filename, content: base64 }],
  });
}

// ════════════════════════════════════════════════════════════════
// CLOUD FUNCTION PRINCIPALE — 1er du mois à 8h
// ════════════════════════════════════════════════════════════════

async function runMonthlyBilling(): Promise<void> {
    const resend     = new Resend(process.env.RESEND_API_KEY!);
    const fromEmail  = process.env.MAIL_FROM!;
    const adminEmail = process.env.MAIL_ADMIN!;
    const orgSlug    = process.env.HELLOASSO_ORG_SLUG!;

    // Période : mois précédent
    const now       = new Date();
    const prevMonth = new Date(now.getFullYear(), now.getMonth() - 1, 1);
    const start     = new Date(prevMonth.getFullYear(), prevMonth.getMonth(), 1);
    const end       = new Date(prevMonth.getFullYear(), prevMonth.getMonth() + 1, 1);
    const monthKey  = `${prevMonth.getFullYear()}-${String(prevMonth.getMonth() + 1).padStart(2, "0")}`;
    const monthLabel = prevMonth.toLocaleString("fr-FR", { month: "long", year: "numeric" });
    const year       = String(prevMonth.getFullYear());

    console.log(`[monthlyBilling] Démarrage — ${monthLabel}`);

    // ── 1. Lire les commandes ──────────────────────────────────────
    const ordersSnap = await db.collection("orders")
      .where("createdAt", ">=", start.toISOString())
      .where("createdAt", "<",  end.toISOString())
      .get();

    if (ordersSnap.empty) {
      console.log("Aucune commande ce mois-ci.");
      return;
    }

    // ── 2. Grouper par uid ────────────────────────────────────────
    const byUser: Record<string, UserGroup> = {};

    for (const doc of ordersSnap.docs) {
      const o = doc.data() as Order;
      if (!o.uid) continue;

      if (!byUser[o.uid]) {
        byUser[o.uid] = {
          uid:      o.uid,
          email:    o.email,
          name:     o.name ?? "",
          total:    0,
          orders:   [],
          orderIds: [],
        };
      }
      byUser[o.uid].total += o.total;
      byUser[o.uid].orders.push(o);
      byUser[o.uid].orderIds.push(doc.id);
    }

    // ── 3. Token HelloAsso ─────────────────────────────────────────
    const token = await getHelloAssoToken();

    // ── 4. Créer un checkout + envoyer l'email client par user ─────
    const checkoutResults: CheckoutResult[] = [];

    for (const user of Object.values(byUser)) {
      const nameParts  = user.name.trim().split(" ");
      const firstName  = nameParts[0] ?? "";
      const lastName   = nameParts.slice(1).join(" ") || firstName;
      const totalCents = Math.round(user.total * 100);
      const label      = `Facture ${monthKey} — ${user.name || user.email}`;

      try {
        // Checkout HelloAsso
        const checkout = await createCheckout(token, orgSlug, {
          totalCents,
          label,
          email:     user.email,
          firstName,
          lastName,
          month:     monthKey,
        });

        // Sauvegarde Firestore
        await db.collection("monthly_invoices").add({
          uid:         user.uid,
          email:       user.email,
          name:        user.name,
          month:       monthKey,
          total:       user.total,
          orderIds:    user.orderIds,
          checkoutId:  checkout.id,
          checkoutUrl: checkout.redirectUrl,
          status:      "pending",
          createdAt:   new Date().toISOString(),
        });

        // Email client
        await sendClientEmail(resend, fromEmail, {
          to:          user.email,
          firstName,
          month:       monthKey,
          monthLabel,
          total:       user.total,
          checkoutUrl: checkout.redirectUrl,
          year,
        });

        checkoutResults.push({
          uid:         user.uid,
          email:       user.email,
          name:        user.name,
          total:       user.total,
          checkoutId:  checkout.id,
          checkoutUrl: checkout.redirectUrl,
          status:      "ok",
        });

        console.log(`[OK] ${user.email} — ${user.total.toFixed(2)} €`);

      } catch (err: any) {
        console.error(`[ERREUR] ${user.email}:`, err?.message ?? err);
        checkoutResults.push({
          uid:   user.uid,
          email: user.email,
          name:  user.name,
          total: user.total,
          checkoutId:  "",
          checkoutUrl: "",
          status: "error",
          error:  err?.message ?? String(err),
        });
      }
    }

    // ── 5. Générer l'Excel et envoyer l'email admin ────────────────
    const excelBuffer = await generateExcel(byUser, checkoutResults, monthLabel);
    await sendAdminEmail(
      resend, fromEmail, adminEmail,
      monthLabel, byUser, checkoutResults, excelBuffer
    );

    const nbOk = checkoutResults.filter((r) => r.status === "ok").length;
    console.log(
      `[monthlyBilling] Terminé — ${nbOk}/${checkoutResults.length} checkouts OK`
    );
    return;
}

// ════════════════════════════════════════════════════════════════
// WEBHOOK HelloAsso → marquer facture comme payée
// ════════════════════════════════════════════════════════════════

export const helloassoWebhook = onRequest(
  { region: "europe-west1" },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }

    const event = req.body;

    if (event.eventType === "Payment" && event.data?.state === "Authorized") {
      const checkoutId: string =
        event.data?.checkoutIntentId ?? event.data?.order?.id ?? "";

      if (checkoutId) {
        const snap = await db.collection("monthly_invoices")
          .where("checkoutId", "==", checkoutId)
          .get();

        if (!snap.empty) {
          const batch = db.batch();
          snap.docs.forEach((doc) =>
            batch.update(doc.ref, {
              status: "paid",
              paidAt: new Date().toISOString(),
            })
          );
          await batch.commit();
          console.log(`${snap.size} facture(s) payée(s) — checkoutId=${checkoutId}`);
        }
      }
    }

    res.status(200).send("OK");
  });

// ════════════════════════════════════════════════════════════════
// GET /events → liste les formulaires HelloAsso de l'orga
// ════════════════════════════════════════════════════════════════

export const getEvents = onRequest(
  { region: "europe-west1" },
  async (req, res) => {
    // CORS pour Flutter
    res.set("Access-Control-Allow-Origin", "*");
    if (req.method === "OPTIONS") { res.status(204).send(""); return; }

    try {
      const token = await getHelloAssoToken();
      const orgSlug = process.env.HELLOASSO_ORG_SLUG!;

      // Récupère tous les formulaires de l'organisation
      // (events, adhesions, don, crowdfunding...)
      const response = await fetch(
        `https://api.helloasso.com/v5/organizations/${orgSlug}/forms?states=Public&pageSize=50`,
        {
          headers: { Authorization: `Bearer ${token}` },
        }
      );

      const data = await response.json();
      res.status(200).json(data);
    } catch (err: any) {
      res.status(500).json({ error: err.message });
    }
  }
);

// ════════════════════════════════════════════════════════════════
// POST /createEventCheckout → crée un checkout pour un événement
// ════════════════════════════════════════════════════════════════

export const createEventCheckout = onRequest(
  { region: "europe-west1" },
  async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    if (req.method === "OPTIONS") { res.status(204).send(""); return; }
    if (req.method !== "POST") { res.status(405).send("Method Not Allowed"); return; }

    try {
      const { formSlug, totalCents, email, firstName, lastName, eventTitle } = req.body;

      if (!formSlug || !totalCents || !email) {
        res.status(400).json({ error: "Paramètres manquants" });
        return;
      }

      const token = await getHelloAssoToken();
      const orgSlug = process.env.HELLOASSO_ORG_SLUG!;

      const response = await fetch(
        `https://api.helloasso.com/v5/organizations/${orgSlug}/checkouts`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${token}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            totalAmount: totalCents,
            initialAmount: totalCents,
            itemName: eventTitle ?? "Inscription événement",
            containsDonation: false,
            backUrl:    process.env.HELLOASSO_BACK_URL!,
            returnUrl:  process.env.HELLOASSO_RETURN_URL!,
            errorUrl:   process.env.HELLOASSO_ERROR_URL!,
            payer: { email, firstName, lastName },
            metadata: { formSlug },
          }),
        }
      );

      const data = await response.json();

      if (!data.redirectUrl) {
        res.status(500).json({ error: "Checkout échoué", detail: data });
        return;
      }

      res.status(200).json({ checkoutUrl: data.redirectUrl });
    } catch (err: any) {
      res.status(500).json({ error: err.message });
    }
  }
);

// ════════════════════════════════════════════════════════════════
// FONCTION DE TEST (HTTP protégé)
// ════════════════════════════════════════════════════════════════
export const monthlyBilling = onSchedule(
  {
    schedule: "0 8 1 * *",
    timeZone: "Europe/Paris",
    region: "europe-west1",
    timeoutSeconds: 300,
    memory: "512MiB",
  },
  async (event) => {
    await runMonthlyBilling();
  }
);

export const monthlyBillingTest = onRequest(
  { region: "europe-west1" },
  async (req, res) => {
    if (req.headers["x-test-secret"] !== process.env.TEST_SECRET) {
      res.status(403).send("Forbidden");
      return;
    }
    try {
      await runMonthlyBilling(); // ✅ appelle directement la logique
      res.status(200).send("Test terminé avec succès");
    } catch (err: any) {
      res.status(500).send("Erreur : " + err?.message);
    }
  }
);