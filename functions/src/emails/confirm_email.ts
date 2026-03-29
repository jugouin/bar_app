import { Resend } from "resend";

export async function sendConfirmEmail(
  resend: Resend,
  fromEmail: string,
  params: {
    to: string;
    firstName: string;
    confirmEmail: string;
  },
): Promise<void> {
  const { to, firstName, confirmEmail } = params;

  const result = await resend.emails.send({
    from: fromEmail,
    to,
    subject: "Confirmez votre adresse email",
    html: `
      <!DOCTYPE html>
      <html lang="fr">
      <head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
      <body style="margin:0;padding:0;background:#f0f7fb;font-family:Georgia,serif;">
        <table width="100%" cellpadding="0" cellspacing="0">
          <tr><td align="center" style="padding:48px 20px;">
            <table width="560" cellpadding="0" cellspacing="0"
                   style="background:#ffffff;border-radius:16px;overflow:hidden;
                          box-shadow:0 4px 24px rgba(45,84,120,0.10);">

              <!-- En-tête -->
              <tr>
                <td style="background:#2D5478;padding:32px 40px;">
                  <p style="margin:0;color:#ffffff;font-size:20px;font-weight:bold;letter-spacing:0.3px;">
                    Confirmation d'adresse email
                  </p>
                </td>
              </tr>

              <!-- Corps -->
              <tr>
                <td style="padding:40px 40px 32px;">
                  <p style="margin:0 0 12px;color:#2D5478;font-size:16px;font-weight:bold;">
                    Bonjour ${firstName},
                  </p>
                  <p style="margin:0 0 8px;color:#4a6a82;font-size:15px;line-height:1.7;">
                    Votre compte CVE a bien été créé.
                  </p>
                  <p style="margin:0 0 32px;color:#4a6a82;font-size:15px;line-height:1.7;">
                    Cliquez sur le bouton ci-dessous pour confirmer votre adresse
                    et activer votre accès à l'application.
                  </p>

                  <!-- Bouton CTA -->
                  <table cellpadding="0" cellspacing="0">
                    <tr>
                      <td style="border-radius:10px;background:#2D5478;">
                        <a href="${confirmEmail}"
                           style="display:inline-block;padding:14px 36px;color:#ffffff;
                                  font-size:15px;font-weight:bold;text-decoration:none;
                                  letter-spacing:0.2px;">
                          Confirmer mon adresse email →
                        </a>
                      </td>
                    </tr>
                  </table>

                  <!-- Lien texte de secours -->
                  <p style="margin:24px 0 0;color:#8aacbf;font-size:12px;line-height:1.6;">
                    Si le bouton ne fonctionne pas, copiez ce lien dans votre navigateur :<br>
                    <a href="${confirmEmail}" style="color:#2D5478;word-break:break-all;">${confirmEmail}</a>
                  </p>

                  <p style="margin:24px 0 0;color:#8aacbf;font-size:12px;line-height:1.5;">
                    Ce lien est personnel, sécurisé et à usage unique.
                  </p>
                </td>
              </tr>

              <!-- Signature -->
              <tr>
                <td style="padding:0 40px 32px;">
                  <p style="margin:0;color:#4a6a82;font-size:14px;">
                    À bientôt,<br>
                    <strong>L'équipe du CVE</strong>
                  </p>
                </td>
              </tr>

              <!-- Pied de page -->
              <tr>
                <td style="background:#f0f7fb;padding:20px 40px;border-top:1px solid #ddedf5;">
                  <p style="margin:0;color:#8aacbf;font-size:11px;line-height:1.5;">
                    Vous recevez cet email car une inscription a été effectuée avec cette adresse.<br>
                    Si ce n'est pas vous, ignorez simplement ce message. © CVE
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

  if (result.error) {
    throw new Error(`[Resend] Échec envoi à ${to}: ${result.error.message}`);
  }

  console.log(`[Email] Envoyé à ${to} — id: ${result.data?.id}`);
}