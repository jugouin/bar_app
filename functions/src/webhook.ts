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
  }
);