import * as functions from "firebase-functions/v2/https"; 
import { Request, Response } from "express";
import admin from "./firebase-admin";
import { getHelloAssoToken, createCheckout } from "./helloasso";

const db = admin.firestore();

export const generateInvoiceCheckout = functions.onRequest(
  { region: "europe-west1" },
  async (req: Request, res: Response) => {
    res.set("Access-Control-Allow-Origin", "*");

    if (req.method === "OPTIONS") {
      res.set("Access-Control-Allow-Methods", "GET");
      res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
      res.status(204).send("");
      return;
    }

    // Vérification Firebase Auth token
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith("Bearer ")) {
      res.status(401).json({ error: "Non autorisé" });
      return;
    }

    try {
      const idToken = authHeader.split("Bearer ")[1];
      const decoded = await admin.auth().verifyIdToken(idToken);
      const uid = decoded.uid;

      const invoiceId = req.query.invoiceId as string;
      if (!invoiceId) {
        res.status(400).json({ error: "invoiceId manquant" });
        return;
      }

      // Récupérer la facture
      const invoiceDoc = await db
        .collection("monthly_invoices")
        .doc(invoiceId)
        .get();

      if (!invoiceDoc.exists) {
        res.status(404).json({ error: "Facture introuvable" });
        return;
      }

      const invoice = invoiceDoc.data()!;

      // Vérifier que la facture appartient bien à cet utilisateur
      if (invoice.uid !== uid) {
        res.status(403).json({ error: "Accès refusé" });
        return;
      }

      // Facture déjà payée ?
      if (invoice.status === "paid") {
        res.status(400).json({ error: "Facture déjà réglée" });
        return;
      }

      const orgSlug = process.env.HELLOASSO_ORG_SLUG!;
      const token = await getHelloAssoToken();

      const monthKey = invoice.month as string;
      const label = `Facture ${monthKey} — ${invoice.firstName} ${invoice.lastName || invoice.email}`;

      const checkout = await createCheckout(token, orgSlug, {
        totalCents: Math.round(invoice.total * 100),
        label,
        email: invoice.email,
        firstName: invoice.firstName,
        lastName: invoice.lastName,
        month: monthKey,
        invoiceId: invoiceId,
      });

      // Mettre à jour l'URL dans Firestore (optionnel, pour l'admin)
      await invoiceDoc.ref.update({
        checkoutUrl: checkout.redirectUrl,
        checkoutIntentId: checkout.id,
        checkoutRefreshedAt: new Date().toISOString(),
      });

      res.status(200).json({ checkoutUrl: checkout.redirectUrl });
    } catch (err: any) {
      console.error("[generateInvoiceCheckout] Erreur:", err);
      res.status(500).json({ error: err.message ?? "Erreur interne" });
    }
  });