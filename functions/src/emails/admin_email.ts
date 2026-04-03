import { Resend } from "resend";
import { UserGroup, CheckoutResult } from ".././types";

export async function sendAdminEmail(
  resend: Resend,
  fromEmail: string,
  adminEmail: string,
  monthLabel: string,
  byUser: Record<string, UserGroup>,
  checkoutResults: CheckoutResult[],
  excelBuffer: Buffer,
): Promise<void> {
  const nbOk = checkoutResults.filter((r) => r.status === "ok").length;
  const nbError = checkoutResults.filter((r) => r.status === "error").length;
  const grandTotal = Object.values(byUser).reduce((s, u) => s + u.total, 0);

  const checkoutRows = checkoutResults
    .map((r) =>
      r.status === "ok"
        ? `<tr>
           <td style="padding:6px 12px;color:#2D5478;">${r.firstName} ${r.lastName || ""}</td>
           <td style="padding:6px 12px;color:#2D5478;">${r.total.toFixed(2)} €</td>
           <td style="padding:6px 12px;">
             <a href="${r.checkoutUrl}" style="color:#2D5478;font-weight:bold;">
               Lien HelloAsso
             </a>
           </td>
           <td style="padding:6px 12px;color:green;">✅ Envoyé</td>
         </tr>`
        : `<tr>
           <td style="padding:6px 12px;color:#2D5478;">${r.firstName} ${r.lastName || ""}</td>
           <td style="padding:6px 12px;color:#2D5478;">—</td>
           <td style="padding:6px 12px;color:#c0392b;">${r.error ?? "Erreur inconnue"}</td>
           <td style="padding:6px 12px;color:red;">❌ Erreur</td>
         </tr>`,
    )
    .join("");

  const result = await resend.emails.send({
    from: fromEmail,
    to: adminEmail,
    subject: `[Admin] Facturation ${monthLabel} — ${nbOk}/${checkoutResults.length} envoyés`,
    html: `
      <!DOCTYPE html><html lang="fr"><head><meta charset="UTF-8"></head>
      <body style="margin:0;padding:0;background:#f0f7fb;font-family:Georgia,serif;">
        <table width="100%" cellpadding="0" cellspacing="0">
          <tr><td align="center" style="padding:40px 20px;">
            <table width="640" cellpadding="0" cellspacing="0"
                   style="background:#fff;border-radius:16px;overflow:hidden;
                          box-shadow:0 4px 24px rgba(45,84,120,0.10);">
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
              <tr>
                <td style="padding:28px 40px 0;">
                  <table width="100%" cellpadding="0" cellspacing="0">
                    <tr>
                      <td width="33%" align="center"
                          style="background:#f0f7fb;border-radius:12px;padding:16px;">
                        <p style="margin:0;color:#4a6a82;font-size:12px;
                                   text-transform:uppercase;letter-spacing:1px;">
                          Clients facturés
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
              <tr>
                <td style="padding:24px 40px;border-top:1px solid #ddedf5;">
                  <p style="margin:0;color:#8aacbf;font-size:12px;">
                    Le fichier Excel détaillé est joint à cet email.
                  </p>
                </td>
              </tr>
            </table>
          </td></tr>
        </table>
      </body></html>
    `,
    attachments: [
      {
        filename: `recap_${monthLabel.replace(" ", "_")}.xlsx`,
        content: excelBuffer.toString("base64"),
      },
    ],
  });

  console.log(
    `[Email Admin] Résultat envoi à ${adminEmail}:`,
    JSON.stringify(result),
  );
}
