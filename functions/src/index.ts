import admin from "./firebase-admin";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { onRequest } from "firebase-functions/https";
import { runMonthlyBilling } from "./billing";
export { generateInvoiceCheckout } from "./generateInvoiceCheckout";
export { sendWelcomeEmail } from "./sendWelcomeEmail";

if (!admin.apps.length) admin.initializeApp();

export { getEvents, createEventCheckout } from "./events";
export { helloassoWebhook } from "./webhook";

// ── Facturation mensuelle — 1er du mois à 8h ─────────────────────
export const monthlyBilling = onSchedule(
  {
    schedule:       "0 8 1 * *",
    timeZone:       "Europe/Paris",
    region:         "europe-west1",
    timeoutSeconds: 300,
    memory:         "512MiB",
  },
  async () => { await runMonthlyBilling(); }
);

// ── Fonction de test (HTTP protégé) ──────────────────────────────
export const monthlyBillingTest = onRequest(
  { region: "europe-west1" },
  async (req, res) => {
    if (req.headers["x-test-secret"] !== process.env.TEST_SECRET) {
      res.status(403).send("Forbidden");
      return;
    }
    try {
      await runMonthlyBilling();
      res.status(200).send("Test terminé avec succès");
    } catch (err: any) {
      console.error("[Test] Erreur fatale:", err?.message, err?.stack);
      res.status(500).send("Erreur : " + err?.message);
    }
  }
);