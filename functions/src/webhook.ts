import admin from "firebase-admin";
import { onRequest } from "firebase-functions/https";

const db = admin.firestore();

export const helloassoWebhook = onRequest(
  { region: "europe-west1" },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }

    const event = req.body;
    console.log("[Webhook] eventType:", event?.eventType);

    if (event.eventType === "Order") {
      const invoiceId: string = event.metadata?.invoiceId ?? "";
      const checkoutIntentId: string = String(event.data?.checkoutIntentId ?? "");

      console.log("[Webhook] invoiceId:", invoiceId);
      console.log("[Webhook] checkoutIntentId:", checkoutIntentId);

      if (!invoiceId) {
        console.warn("[Webhook] Pas d'invoiceId dans les metadata, on skip");
        res.status(200).send("OK");
        return;
      }

      await db.collection("monthly_invoices").doc(invoiceId).update({
        status: "paid",
        paidAt: new Date().toISOString(),
        checkoutIntentId,
      });

      console.log(`[Webhook] Facture ${invoiceId} marquée payée`);
    }

    res.status(200).send("OK");
  }
);