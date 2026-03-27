import admin from "./firebase-admin";
import { Resend } from "resend";
import { Order, UserGroup, CheckoutResult } from "./types";
import { getHelloAssoToken, createCheckout } from "./helloasso";
import { generateExcel } from "./excel";
import { sendAdminEmail } from "./emails/admin_email";
import { sendClientEmail } from "./emails/client_email";

const db = admin.firestore();

export async function runMonthlyBilling(): Promise<void> {
  const resend = new Resend(process.env.RESEND_API_KEY!);
  const fromEmail = process.env.MAIL_FROM!;
  const adminEmail = process.env.MAIL_ADMIN!;
  const orgSlug = process.env.HELLOASSO_ORG_SLUG!;

  console.log("[Config] fromEmail:", fromEmail);
  console.log("[Config] adminEmail:", adminEmail);
  console.log("[Config] orgSlug:", orgSlug);

  // Période : mois précédent
  const now = new Date();
  const prevMonth = new Date(now.getFullYear(), now.getMonth() - 1, 1);
  const start = new Date(prevMonth.getFullYear(), prevMonth.getMonth(), 1);
  const end = new Date(prevMonth.getFullYear(), prevMonth.getMonth() + 1, 1);
  const monthKey = `${prevMonth.getFullYear()}-${String(prevMonth.getMonth() + 1).padStart(2, "0")}`;
  const monthLabel = prevMonth.toLocaleString("fr-FR", {
    month: "long",
    year: "numeric",
  });
  const year = String(prevMonth.getFullYear());

  console.log(`[monthlyBilling] Démarrage — ${monthLabel}`);
  console.log(
    `[monthlyBilling] Période: ${start.toISOString()} → ${end.toISOString()}`,
  );

  // ── 1. Commandes du mois précédent ────────────────────────────
  const ordersSnap = await db
    .collection("orders")
    .where("createdAt", ">=", start.toISOString())
    .where("createdAt", "<", end.toISOString())
    .get();

  console.log(`[monthlyBilling] ${ordersSnap.size} commande(s) trouvée(s)`);

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
        uid: o.uid,
        email: o.email,
        firstName: o.firstName,
        lastName: o.lastName,
        total: 0,
        orders: [],
        orderIds: [],
      };
    }
    byUser[o.uid].total += o.total;
    byUser[o.uid].orders.push(o);
    byUser[o.uid].orderIds.push(doc.id);
  }

  console.log(`[monthlyBilling] ${Object.keys(byUser).length} utilisateur(s)`);

  // ── 3. Token HelloAsso ────────────────────────────────────────
  console.log("[HelloAsso] Récupération du token...");
  const token = await getHelloAssoToken();
  console.log("[HelloAsso] Token OK");

  // ── 4. Checkout + email par utilisateur ──────────────────────
  const checkoutResults: CheckoutResult[] = [];

  for (const user of Object.values(byUser)) {
    const totalCents = Math.round(user.total * 100);
    const label = `Facture ${monthKey} — ${user.firstName} ${user.lastName || user.email}`;

    console.log(
      `[Checkout] Création pour ${user.email} — ${totalCents} centimes`,
    );

    try {
      const checkout = await createCheckout(token, orgSlug, {
        totalCents,
        label,
        email: user.email,
        firstName: user.firstName,
        lastName: user.lastName,
        month: monthKey,
      });

      console.log(`[Checkout] OK pour ${user.email} — ${checkout.redirectUrl}`);
      const existingInvoice = await db
        .collection("monthly_invoices")
        .where("uid", "==", user.uid)
        .where("month", "==", monthKey)
        .where("status", "==", "pending")
        .limit(1)
        .get();

      if (!existingInvoice.empty) {
        console.log(
          `[Checkout] Facture déjà existante pour ${user.email} — ${monthKey}, on skip`,
        );
        const existing = existingInvoice.docs[0].data();
        checkoutResults.push({
          uid: user.uid,
          email: user.email,
          firstName: user.firstName,
          lastName: user.lastName,
          total: user.total,
          checkoutId: existing.checkoutId,
          checkoutUrl: existing.checkoutUrl,
          status: "ok",
        });
        continue;
      }

      // Sauvegarder dans Firestore
      const invoiceRef = await db.collection("monthly_invoices").add({
        uid: user.uid,
        email: user.email,
        firstName: user.firstName,
        lastName: user.lastName,
        month: monthKey,
        total: user.total,
        orderIds: user.orderIds,
        checkoutId: checkout.id,
        checkoutUrl: checkout.redirectUrl,
        status: "pending",
        createdAt: new Date().toISOString(),
      });

      const deepLink = `https://cve-bar.web.app/pay?invoiceId=${invoiceRef.id}`;
      await sendClientEmail(resend, fromEmail, {
        to: user.email,
        firstName: user.firstName,
        monthLabel,
        total: user.total,
        checkoutUrl: deepLink,
        year,
      });
      console.log(`[Email] OK pour ${user.email}`);

      checkoutResults.push({
        uid: user.uid,
        email: user.email,
        firstName: user.firstName,
        lastName: user.lastName,
        total: user.total,
        checkoutId: checkout.id,
        checkoutUrl: checkout.redirectUrl,
        status: "ok",
      });
    } catch (err: any) {
      console.error(
        `[ERREUR] ${user.email}:`,
        err?.message,
        "\nStack:",
        err?.stack,
      );
      checkoutResults.push({
        uid: user.uid,
        email: user.email,
        firstName: user.firstName,
        lastName: user.lastName,
        total: user.total,
        checkoutId: "",
        checkoutUrl: "",
        status: "error",
        error: err?.message ?? String(err),
      });
    }
  }

  // ── 5. Excel + email admin ────────────────────────────────────
  console.log("[Excel] Génération...");
  const excelBuffer = await generateExcel(
    byUser,
    checkoutResults,
    monthLabel,
    orgSlug,
  );
  console.log("[Excel] OK");

  console.log("[Email Admin] Envoi...");
  await sendAdminEmail(
    resend,
    fromEmail,
    adminEmail,
    monthLabel,
    byUser,
    checkoutResults,
    excelBuffer,
  );

  const nbOk = checkoutResults.filter((r) => r.status === "ok").length;
  console.log(
    `[monthlyBilling] Terminé — ${nbOk}/${checkoutResults.length} OK`,
  );
}
