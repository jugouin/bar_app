import admin from "firebase-admin";
import { onRequest } from "firebase-functions/https";
import { getHelloAssoToken } from "./helloasso";

const db = admin.firestore();

export const getEvents = onRequest(
  { region: "europe-west1" },
  async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }

    try {
      const token = await getHelloAssoToken();
      const orgSlug = process.env.HELLOASSO_ORG_SLUG!;

      const listRes = await fetch(
        `https://api.helloasso.com/v5/organizations/${orgSlug}/forms?formType=Event&states=Public&pageSize=50`,
        { headers: { Authorization: `Bearer ${token}` } },
      );
      const listData = await listRes.json();
      const forms = listData.data ?? [];

      await db.collection("events_cache").doc("latest").set({
        events: forms,
        cachedAt: new Date().toISOString(),
        ttlMinutes: 60,
      });

      res.status(200).json({ data: forms, source: "api" });
    } catch (err: any) {
      console.error("[getEvents] Erreur:", err?.message);
      res.status(500).json({ error: err.message });
    }
  },
);

// ── POST /createEventCheckout ─────────────────────────────────────
export const createEventCheckout = onRequest(
  { region: "europe-west1" },
  async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }

    const formSlug = req.body?.formSlug;
    if (!formSlug) {
      res
        .status(400)
        .json({ error: "Paramètres manquants", received: req.body });
      return;
    }

    const orgSlug = process.env.HELLOASSO_ORG_SLUG!;
    const checkoutUrl = `https://www.helloasso.com/associations/${orgSlug}/evenements/${formSlug}`;

    res.status(200).json({ checkoutUrl });
  },
);
