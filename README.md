# CVE Bar App 🥂

A Firebase-powered bar management app for the **Club de Voile d’Évian**, handling monthly billing, HelloAsso payment checkouts, automated email notifications, and club event registration.

-----

## Overview

This app automates the monthly billing cycle for club members:

1. At the start of each month, all orders from the previous month are fetched from Firestore
2. A HelloAsso payment checkout is created for each member
3. Each member receives an email with their invoice and payment link
4. The club treasurer receives a summary email with an Excel export

-----

## Tech Stack

- **Runtime**: Node.js 22 (TypeScript)
- **Backend**: Firebase Cloud Functions v2 (Gen 2)
- **Database**: Firestore
- **Payments**: HelloAsso API
- **Emails**: Resend
- **Region**: `europe-west1`

-----

## Project Structure

```
functions/
├── src/
│   ├── index.ts                  # Cloud Functions entry point
│   ├── billing.ts                # Monthly billing logic
│   ├── firebase-admin.ts         # Firebase Admin SDK init
│   ├── helloasso.ts              # HelloAsso API client
│   ├── excel.ts                  # Excel export generation
│   ├── generateInvoiceCheckout.ts
│   ├── sendWelcomeEmail.ts
│   ├── webhook.ts                # HelloAsso webhook handler
│   ├── events.ts                 # Events management
│   ├── types.ts
│   └── emails/
│       ├── admin_email.ts
│       └── client_email.ts
├── scripts/
│   └── seed-test-orders.ts       # Seed Firestore with test data
└── .env                          # Environment variables (not committed)
```

-----

## Cloud Functions

|Function                 |Trigger                                           |Description                                                                             |
|-------------------------|--------------------------------------------------|----------------------------------------------------------------------------------------|
|`monthlyBilling`         |Scheduler — 1st of month at 8:00 AM (Europe/Paris)|Runs the full monthly billing cycle                                                     |
|`monthlyBillingTest`     |HTTP POST                                         |Manually trigger billing (protected by secret header)                                   |
|`helloassoWebhook`       |HTTP POST                                         |Handles HelloAsso payment webhooks                                                      |
|`generateInvoiceCheckout`|HTTP                                              |Generates a checkout for a specific invoice                                             |
|`sendWelcomeEmail`       |HTTP                                              |Sends welcome email to new members                                                      |
|`getEvents`              |HTTP GET                                          |Fetches public club events from HelloAsso API and caches them in Firestore (TTL: 60 min)|
|`createEventCheckout`    |HTTP POST                                         |Returns the HelloAsso registration URL for a given event `formSlug`                     |

-----

## Environment Variables

Create a `functions/.env` file with the following:

```env
RESEND_API_KEY=your_resend_api_key
MAIL_FROM=tresor@voile-evian.fr
MAIL_ADMIN=tresor@voile-evian.fr
HELLOASSO_ORG_SLUG=club-de-voile-d-evian
HELLOASSO_CLIENT_ID=your_helloasso_client_id
HELLOASSO_CLIENT_SECRET=your_helloasso_client_secret
TEST_SECRET=your_test_secret
```

-----

## Monthly Billing Logic

The `runMonthlyBilling()` function in `billing.ts`:

- Queries all `orders` where `createdAt` falls in the **previous calendar month**
- Groups orders by `uid` (one invoice per member)
- Checks for existing `monthly_invoices` to avoid duplicates (idempotent)
- Creates a HelloAsso checkout for each member
- Sends a payment email to each member via Resend
- Generates an Excel summary and emails it to the admin

### Firestore Collections

|Collection        |Description                                                    |
|------------------|---------------------------------------------------------------|
|`orders`          |Individual bar orders with `uid`, `email`, `total`, `createdAt`|
|`monthly_invoices`|Generated invoices with checkout URLs and status               |


> ⚠️ The `createdAt` field in `orders` must be stored as an **ISO 8601 string** (e.g. `"2026-03-15T14:30:00.000Z"`), not as a Firestore Timestamp, for the billing query to work correctly.

-----

## Club Events

The app integrates with HelloAsso to display and manage club events.

### How it works

1. **`getEvents`** calls the HelloAsso API to fetch all public events (`formType=Event`, `states=Public`) for the organization
1. The result is cached in Firestore under `events_cache/latest` for **60 minutes** to avoid unnecessary API calls
1. **`createEventCheckout`** receives a `formSlug` and returns the direct HelloAsso registration URL for that event — members are redirected to HelloAsso to complete their registration

### API Usage

**Fetch club events:**

```bash
GET https://europe-west1-cve-bar.cloudfunctions.net/getEvents
```

Response:

```json
{
  "data": [ ...events from HelloAsso... ],
  "source": "api"
}
```

**Get registration URL for an event:**

```bash
POST https://europe-west1-cve-bar.cloudfunctions.net/createEventCheckout
Content-Type: application/json

{ "formSlug": "nom-de-levenement" }
```

Response:

```json
{
  "checkoutUrl": "https://www.helloasso.com/associations/club-de-voile-d-evian/evenements/nom-de-levenement"
}
```

### Firestore Cache

|Collection    |Document|Description                                                         |
|--------------|--------|--------------------------------------------------------------------|
|`events_cache`|`latest`|Latest fetched events with `cachedAt` timestamp and `ttlMinutes: 60`|

-----

## Local Development

### Prerequisites

- Node.js 22+
- Java 21+ (required for Firebase emulators)
- Firebase CLI: `npm install -g firebase-tools`

### Install dependencies

```bash
cd functions
npm install
```

### Start emulators

```bash
# Kill any processes already using emulator ports
lsof -ti:5001 | xargs kill -9
lsof -ti:8080 | xargs kill -9

# Start emulators
firebase emulators:start --only functions,firestore
```

Emulator UI is available at: `http://localhost:2000`

### Seed test data

```bash
FIRESTORE_EMULATOR_HOST=localhost:8080 npx ts-node scripts/seed-test-orders.ts
```

### Trigger billing manually (local)

```bash
curl -X POST "http://localhost:5001/cve-bar/europe-west1/monthlyBillingTest" \
  -H "x-test-secret: YOUR_TEST_SECRET" \
  -H "Content-Type: application/json"
```

### Trigger billing manually (production)

```bash
curl -X POST "https://europe-west1-cve-bar.cloudfunctions.net/monthlyBillingTest" \
  -H "x-test-secret: YOUR_TEST_SECRET" \
  -H "Content-Type: application/json"
```

-----

## Deployment

```bash
firebase deploy --only functions
```

-----

## Expected Billing Logs

A successful run should produce:

```
[monthlyBilling] Démarrage — mars 2026
[monthlyBilling] Période: 2026-03-01T... → 2026-04-01T...
[monthlyBilling] N commande(s) trouvée(s)
[monthlyBilling] N utilisateur(s)
[HelloAsso] Token OK
[Checkout] OK pour user@example.com
[Email] OK pour user@example.com
[Excel] OK
[Email Admin] Envoi...
[monthlyBilling] Terminé — N/N OK
```