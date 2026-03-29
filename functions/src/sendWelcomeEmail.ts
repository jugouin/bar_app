import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { Resend } from "resend";
import { sendConfirmEmail } from "./emails/confirm_email";

admin.initializeApp();

export const sendWelcomeEmail = onCall(
  { region: "europe-west1" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Non authentifié");
    }

    const { firstName, email } = request.data as {
      firstName: string;
      email: string;
    };

    if (!firstName || !email) {
      throw new HttpsError("invalid-argument", "Paramètres manquants");
    }

    const resend = new Resend(process.env.RESEND_API_KEY);
    const FROM_EMAIL = process.env.RESEND_FROM_EMAIL || "noreply@example.com";

    const confirmLink = await admin.auth().generateEmailVerificationLink(email);

    await sendConfirmEmail(resend, FROM_EMAIL, {
      to: email,
      firstName,
      confirmEmail: confirmLink,
    });

    return { success: true };
  }
);