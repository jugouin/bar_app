export async function getHelloAssoToken(): Promise<string> {
  const res = await fetch("https://api.helloasso.com/oauth2/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "client_credentials",
      client_id: process.env.HELLOASSO_CLIENT_ID!,
      client_secret: process.env.HELLOASSO_CLIENT_SECRET!,
    }),
  });

  const text = await res.text();
  console.log(`[HelloAsso] Token response [${res.status}]:`, text);

  if (!res.ok) throw new Error(`Token HTTP ${res.status}: ${text}`);

  let data: any;
  try {
    data = JSON.parse(text);
  } catch {
    throw new Error(`Token JSON invalide: ${text}`);
  }

  if (!data.access_token) throw new Error(`Token manquant dans: ${text}`);
  return data.access_token;
}

export async function createCheckout(
  token: string,
  orgSlug: string,
  params: {
    totalCents: number;
    label: string;
    email: string;
    firstName: string;
    lastName: string;
    month: string;
    invoiceId: string;
  },
): Promise<{ id: string; redirectUrl: string }> {
  const body = JSON.stringify({
    backUrl: process.env.HELLOASSO_BACK_URL!,
    errorUrl: process.env.HELLOASSO_ERROR_URL!,
    returnUrl: process.env.HELLOASSO_RETURN_URL!,
    totalAmount: params.totalCents,
    initialAmount: params.totalCents,
    itemName: params.label,
    containsDonation: false,
    payer: {
      email: params.email,
      firstName: params.firstName,
      lastName: params.lastName,
    },
    metadata: { month: params.month, invoiceId: params.invoiceId },
  });

  console.log(`[Checkout] Requête pour ${params.email}:`, body);

  const res = await fetch(
    `https://api.helloasso.com/v5/organizations/${orgSlug}/checkout-intents`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body,
    },
  );

  const text = await res.text();
  console.log(`[Checkout] Réponse [${res.status}] pour ${params.email}:`, text);

  // Fallback si checkout non activé (404)
  if (res.status === 404) {
    console.warn(`[Checkout] API non disponible (404), fallback lien direct`);
    return {
      id: "",
      redirectUrl: `https://www.helloasso.com/associations/${orgSlug}`,
    };
  }

  if (!res.ok) throw new Error(`Checkout HTTP ${res.status}: ${text}`);
  if (!text || text.trim() === "") throw new Error(`Checkout réponse vide`);

  let data: any;
  try {
    data = JSON.parse(text);
  } catch {
    throw new Error(`Checkout JSON invalide: ${text}`);
  }

  if (!data.redirectUrl) throw new Error(`redirectUrl manquant: ${text}`);
  return { id: data.id ?? "", redirectUrl: data.redirectUrl };
}
