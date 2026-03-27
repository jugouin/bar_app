import { Resend } from "resend";

export async function sendClientEmail(
  resend: Resend,
  fromEmail: string,
  params: {
    to: string;
    firstName: string;
    monthLabel: string;
    total: number;
    checkoutUrl: string;
    year: string;
  },
): Promise<void> {
  const { to, firstName, monthLabel, total, checkoutUrl, year } = params;

  const result = await resend.emails.send({
    from: fromEmail,
    to,
    subject: `Facture mensuelle du bar du CVE`,
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
                    Votre facture mensuelle du bar
                  </p>
                  <p style="margin:6px 0 0;color:#96c9de;font-size:16px;">
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
                    Votre facture de <strong>${monthLabel}</strong> est disponible.
                  </p>
                  <table width="100%" cellpadding="0" cellspacing="0"
                         style="background:#f0f7fb;border-radius:12px;margin-bottom:32px;">
                    <tr><td style="padding:20px 24px;">
                      <p style="margin:0;color:#4a6a82;font-size:13px;
                                 text-transform:uppercase;letter-spacing:1px;">
                        Montant total
                      </p>
                      <p style="margin:6px 0 0;color:#2D5478;font-size:32px;
                                 font-weight:bold;">
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
                  <p style="margin:28px 0 0;color:#4a6a82;font-size:15px;line-height:1.6;">
                  HelloAsso ajoute automatiquement une contribution pour soutenir leur projet, si vous ne souhaitez pas participer vous pouvez modifier la contribution automatique.
                  </p>
                  <p style="margin:28px 0 0;color:#8aacbf;font-size:12px;line-height:1.5;">
                    Ce lien est personnel et sécurisé.
                  </p>
                  <p style="margin:28px 0 0;color:#8aacbf;font-size:12px;line-height:1.5;">
                    L'équipe du CVE.
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

  console.log(`[Email] Résultat envoi à ${to}:`, JSON.stringify(result));
}
