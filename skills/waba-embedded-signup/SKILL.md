---
name: waba-embedded-signup
description: Implements Meta's WhatsApp Business Embedded Signup flow — Facebook Login for Business, the JS SDK launch, the code-for-token exchange, debug-token introspection, phone-number registration, and post-signup webhook subscription. Use when adding Embedded Signup to a multi-tenant app, integrating Meta's OAuth as a Tech Provider or Solution Partner, onboarding new tenants via Meta, or debugging a stuck or failed signup. Use when the user mentions "embedded signup", "FBL", "Facebook Login for Business", "Meta onboarding", "BSP partner flow", or "config_id".
---

# WABA Embedded Signup

## Overview

Embedded Signup is Meta's flow for letting a tenant connect their WhatsApp Business Account to your platform without leaving your app. Done right, it takes ~2 minutes and creates a fully-provisioned SPS. Done wrong, tenants drop off, support tickets pile up, and you end up debugging opaque Graph API errors in production. This skill walks the full end-to-end: prerequisites, the JS launch, the backend exchange, phone-number registration, and the most common ways the flow gets stuck.

## When to Use

Use when:
- Adding Embedded Signup to an app for the first time
- A tenant signup is stuck at a specific step
- Migrating from the legacy WhatsApp signup to Embedded Signup
- A Meta app is being reviewed and you need to verify the flow

Do **not** use for:
- Designing the tenant data model around the WABA — use `sender-profile-architect`
- Sending the first message after signup completes — that's regular Cloud API work

## Prerequisites (don't skip)

Signup will silently fail if any of these are missing. Verify each before touching code:

1. **Tech Provider / Solution Partner status** with Meta — apply via the Meta Business Suite. Required for revenue-share or hosted billing.
2. **A Meta app** in App Dashboard with these products added:
   - WhatsApp
   - Facebook Login for Business
3. **A `config_id`** from Meta — created in your app's *Facebook Login for Business → Configurations*. The config defines which permissions and assets are requested; you cannot use a generic FBL config.
4. **Allowlisted redirect URIs** in the FBL config — every signup environment (`https://app.sent.example`, `https://staging.sent.example`, `http://localhost:3000`) must be listed.
5. **A System User** in your Meta Business with admin access to your app. The auth code exchanges into a System User token that owns the new WABA.
6. **Webhook URL** registered on the WhatsApp product, with signing secret stored.

Capture all of these in `.env` (or your secrets manager) and *fail-fast in CI* if any are missing.

For the exact field names, scopes, and example payloads, see `references/waba-embedded-signup-spec.md`.

## The Flow End-to-End

```
[Tenant browser]                    [Your backend]              [Meta Graph API]
       │                                  │                            │
       │ 1. user clicks "Connect WhatsApp"│                            │
       │ 2. FB.login({config_id, extras}) │                            │
       │─── opens Meta dialog ─────────────────────────────────────────▶
       │                                  │                            │
       │ 3. callback with { code, state } │                            │
       │─── POST /signup/callback ───────▶│                            │
       │                                  │ 4. exchange code → token   │
       │                                  │───────────────────────────▶│
       │                                  │◀────── access_token ───────│
       │                                  │ 5. debug_token             │
       │                                  │───────────────────────────▶│
       │                                  │◀── business_id, waba_id ───│
       │                                  │ 6. list phone numbers      │
       │                                  │───────────────────────────▶│
       │                                  │ 7. register pin            │
       │                                  │───────────────────────────▶│
       │                                  │ 8. subscribe app to WABA   │
       │                                  │───────────────────────────▶│
       │ 9. show SPS as connected ◀───────│                            │
```

### Step 2 — Launch from the frontend

```html
<script async src="https://connect.facebook.net/en_US/sdk.js"></script>
<script>
  FB.init({ appId: 'YOUR_APP_ID', version: 'v20.0' });
  function launchSignup() {
    FB.login(function (response) {
      // response.authResponse.code → POST to your backend
    }, {
      config_id: 'YOUR_CONFIG_ID',
      response_type: 'code',
      override_default_response_type: true,
      extras: { feature: 'whatsapp_embedded_signup' }
    });
  }
</script>
```

`config_id` is required. `extras.feature: 'whatsapp_embedded_signup'` is what activates the WABA-specific UI inside the Meta dialog. Without it, the dialog falls back to a generic FBL flow that won't give you a `waba_id`.

### Step 4 — Code exchange

```
GET https://graph.facebook.com/v20.0/oauth/access_token
  ?client_id=APP_ID
  &client_secret=APP_SECRET
  &redirect_uri=ALLOWLISTED_URI
  &code=CODE
```

Returns `{ access_token, token_type, expires_in }`. Store this token associated with the *tentative* SPS record (state = `connecting`).

### Step 5 — Debug the token to extract IDs

```
GET https://graph.facebook.com/debug_token
  ?input_token=USER_TOKEN
  &access_token=APP_TOKEN
```

The response contains the granular scopes and the `granular_scopes[]` array. Pull `whatsapp_business_management` and `whatsapp_business_messaging`. The `target_ids` and `business_id` are inside the granular-scope objects.

To get the `waba_id` cleanly, list the user's owned/client WABAs:
```
GET https://graph.facebook.com/v20.0/{business_id}/owned_whatsapp_business_accounts
```

### Step 6 — Phone numbers

```
GET https://graph.facebook.com/v20.0/{waba_id}/phone_numbers
```

Each phone number has an `id` (the all-important `phone_number_id`), `display_phone_number`, `verified_name`, and `code_verification_status`. You may have multiple — let the tenant pick one in the UI.

### Step 7 — Register the phone number

```
POST https://graph.facebook.com/v20.0/{phone_number_id}/register
  body: { messaging_product: 'whatsapp', pin: '<6-digit pin>' }
```

The PIN is the two-factor PIN for Cloud API. Generate one server-side, store it (encrypted) on the SPS, and re-use it for any future re-registration. Without registration the phone number cannot send.

### Step 8 — Subscribe your app to the WABA

```
POST https://graph.facebook.com/v20.0/{waba_id}/subscribed_apps
```

This is **easy to forget**, and without it your webhook silently never fires. Always do this in the same transaction as the rest of the signup, and verify it by reading `subscribed_apps` back.

## Common Stuck States and Fixes

| Symptom | Likely cause | Fix |
|---|---|---|
| Dialog opens, closes immediately, no code returned | Redirect URI not allowlisted, or `config_id` mismatched between init and login | Verify both in App Dashboard |
| Code exchange returns `OAuthException` 100 | App not approved for FBL, or wrong `client_secret` | Check app status; rotate secret if leaked |
| `debug_token` shows no `whatsapp_business_management` scope | Tenant unchecked the WhatsApp permission in the dialog | Re-launch and emphasize the permission is required |
| Phone numbers list is empty | Tenant didn't link a number in the dialog | Re-launch; some tenants need to create a WABA from scratch inside the dialog |
| Webhooks never fire after signup | Forgot Step 8 (subscribe app to WABA) | Hit `/subscribed_apps` and verify the app is in the list |
| Token expires unexpectedly | Used a short-lived token instead of System User token | Always exchange to a System User token for production |

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll skip the System User token — the user token works." | User tokens expire in 60 days and revoke on password change. Production must use System User. |
| "I'll subscribe to webhooks once globally, not per-WABA." | App-level webhook config picks the URL; per-WABA subscription is what actually opens the firehose for that account. Both are required. |
| "Embedded Signup auto-registers the phone number." | It does not. Step 7 (register with PIN) is your responsibility. |
| "The config_id is just an ID — any FBL config works." | Only configs created with the WhatsApp Embedded Signup permission produce the right flow. Generic FBL configs silently downgrade. |
| "I'll do this synchronously inside the OAuth callback." | Steps 4-8 take 2-10s and call multiple Meta endpoints. Run async with a job queue; show progress to the tenant. |

## Red Flags

- The `config_id` is hardcoded in client JS but never validated server-side
- Tokens stored as plaintext, not encrypted at rest
- No retry logic on Steps 4-8 — any transient Meta failure leaves the SPS half-provisioned
- Phone-number registration PIN reused across SPSes
- No verification step that `subscribed_apps` actually contains your app post-signup
- Signup completion is declared on Step 4 (code received) instead of Step 8 (webhook subscription)

## Verification

A complete Embedded Signup integration should:
- [ ] Fail fast in CI if any prerequisite env var is missing
- [ ] Use a System User token, not a user access token, in production
- [ ] Persist SPS state transitions explicitly (`provisioned` → `connecting` → `connected`)
- [ ] Register the phone number and verify the registration succeeded
- [ ] Subscribe the app to the WABA and read it back to confirm
- [ ] Send a test message (or check `phone_number_status`) before declaring the SPS active
- [ ] Surface a useful error to the tenant for each known stuck state above

## Related Skills

- `sender-profile-architect` — what to do with the WABA and phone numbers once signup succeeds
- `waba-template-author` — the first thing tenants do after connecting is submit templates
