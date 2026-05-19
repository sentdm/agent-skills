---
name: waba-embedded-signup
description: Implements Meta's WhatsApp Business Embedded Signup flow end-to-end — Facebook Login for Business, the JS SDK launch, the `WA_EMBEDDED_SIGNUP` postMessage event that returns `waba_id` + `phone_number_id` + auth code, the code-for-token exchange, debug-token introspection (fallback path), phone-number registration, and post-signup webhook subscription. Use when adding Embedded Signup to a multi-tenant app on Sent, integrating Meta's OAuth as a Tech Provider or Solution Partner, onboarding new tenants via Meta, or debugging a stuck or failed signup. Use when the user mentions "embedded signup", "FBL", "Facebook Login for Business", "Meta onboarding", "BSP partner flow", `config_id`, or `WA_EMBEDDED_SIGNUP` sessionInfo.
---

# WABA Embedded Signup

## Overview

Embedded Signup is Meta's flow for letting a tenant connect their WhatsApp Business Account to your platform without leaving your app. Done right, it takes ~2 minutes and links the WhatsApp half of a Sender Profile end-to-end. Done wrong, tenants drop off, support tickets pile up, and you end up debugging opaque Graph API errors in production. This skill walks the full end-to-end: prerequisites, the JS launch + `WA_EMBEDDED_SIGNUP` event handling, the backend exchange, phone-number registration, app subscription, and the most common ways the flow gets stuck.

## When to Use

Use when:
- Adding Embedded Signup to an app for the first time
- A tenant signup is stuck at a specific step
- Migrating from the legacy WhatsApp signup to Embedded Signup
- Migrating from the older `debug_token` extraction pattern to the current `sessionInfo` event pattern
- A Meta app is being reviewed and you need to verify the flow

Do **not** use for:
- Designing the tenant data model around the WABA — use `sender-profile-architect`
- The SMS or RCS halves of a Sender Profile — use `sms-10dlc-registration` or `rcs-agent-onboarding`
- Sending the first message after signup completes — that's regular Cloud API work

## Prerequisites (don't skip)

Signup will silently fail if any of these are missing. Verify each before touching code:

1. **Tech Provider / Solution Partner status** with Meta — apply via the Meta Business Suite. Required for revenue-share or hosted billing.
2. **A Meta app** in App Dashboard with these products added:
   - WhatsApp
   - Facebook Login for Business
3. **A `config_id`** from Meta — created in your app's *Facebook Login for Business → Configurations*. The config defines which permissions and assets are requested; you cannot use a generic FBL config.
4. **Allowlisted redirect URIs** in the FBL config — every signup environment (`https://app.example.com`, `https://staging.example.com`, `http://localhost:3000`) must be listed.
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
       │ 3. window listens for            │                            │
       │    WA_EMBEDDED_SIGNUP message    │                            │
       │─── opens Meta dialog ─────────────────────────────────────────▶
       │                                  │                            │
       │ 4a. WA_EMBEDDED_SIGNUP event:    │                            │
       │     phone_number_id, waba_id,    │                            │
       │     business_id                  │                            │
       │ 4b. FB.login callback: { code }  │                            │
       │─── POST /signup/callback ───────▶│                            │
       │     { code, phone_number_id,     │                            │
       │       waba_id, business_id }     │                            │
       │                                  │ 5. exchange code → token   │
       │                                  │───────────────────────────▶│
       │                                  │◀────── access_token ───────│
       │                                  │ 6. register phone number   │
       │                                  │───────────────────────────▶│
       │                                  │ 7. subscribe app to WABA   │
       │                                  │───────────────────────────▶│
       │                                  │ 8. verify subscription     │
       │                                  │───────────────────────────▶│
       │ 9. show Sender Profile connected │                            │
       │ ◀────────────────────────────────│                            │
```

### Step 2-4 — Launch + capture the session

The current SDK gives you the WABA ID and phone-number ID directly via a `postMessage` event. You no longer have to introspect the token to discover them (that path still works as a fallback for older `config_id`s — see below).

```html
<script async src="https://connect.facebook.net/en_US/sdk.js"></script>
<script>
  // Always install the message listener BEFORE launching, or you'll miss the event.
  window.addEventListener('message', (event) => {
    if (!event.origin.endsWith('facebook.com')) return;
    try {
      const data = typeof event.data === 'string' ? JSON.parse(event.data) : event.data;
      if (data.type === 'WA_EMBEDDED_SIGNUP') {
        if (data.event === 'FINISH') {
          // data.data has { phone_number_id, waba_id, business_id }
          window.__waSessionInfo = data.data;
        } else if (data.event === 'CANCEL') {
          // user dismissed at step `data.data.current_step`
        } else if (data.event === 'ERROR') {
          // surface data.data.error_message to the tenant
        }
      }
    } catch (_) { /* ignore */ }
  });

  FB.init({ appId: 'YOUR_APP_ID', version: 'v23.0' });

  function launchSignup() {
    FB.login(function (response) {
      const session = window.__waSessionInfo || null;
      if (response.authResponse && response.authResponse.code) {
        fetch('/signup/whatsapp/callback', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ code: response.authResponse.code, session })
        });
      }
    }, {
      config_id: 'YOUR_CONFIG_ID',
      response_type: 'code',
      override_default_response_type: true,
      extras: { feature: 'whatsapp_embedded_signup', version: 3 }
    });
  }
</script>
```

`config_id` is required. `extras.feature: 'whatsapp_embedded_signup'` is what activates the WABA-specific UI inside the Meta dialog. Without it, the dialog falls back to a generic FBL flow that won't fire the `WA_EMBEDDED_SIGNUP` event.

### Step 5 — Code exchange

```
GET https://graph.facebook.com/v23.0/oauth/access_token
  ?client_id=APP_ID
  &client_secret=APP_SECRET
  &redirect_uri=ALLOWLISTED_URI
  &code=CODE
```

Returns `{ access_token, token_type, expires_in }`. Store this token associated with the *tentative* WhatsApp sender record (state = `connecting`).

For production, exchange to a System User token (long-lived) before persisting.

### Step 5b — Fallback: extract IDs from `debug_token` (legacy config IDs)

If the SDK did not deliver a `WA_EMBEDDED_SIGNUP` event (older `config_id`, browser blocked the `postMessage`, or a tenant on a non-default flow), introspect the token to recover the IDs:

```
GET https://graph.facebook.com/debug_token
  ?input_token=USER_TOKEN
  &access_token=APP_ID|APP_SECRET
```

The response's `granular_scopes` array contains `whatsapp_business_management` and `whatsapp_business_messaging`, each with a `target_ids` list. To recover the `waba_id` cleanly, list owned WABAs:

```
GET https://graph.facebook.com/v23.0/{business_id}/owned_whatsapp_business_accounts
```

Treat this path as a fallback, not the primary. The `WA_EMBEDDED_SIGNUP` event is the supported flow now.

### Step 6 — Register the phone number

The phone number you got in Step 4 is *not* registered for Cloud API until you call:

```
POST https://graph.facebook.com/v23.0/{phone_number_id}/register
  body: { messaging_product: 'whatsapp', pin: '<6-digit pin>' }
```

The PIN is the two-factor PIN for Cloud API. Generate one server-side, store it (encrypted) on the WhatsApp sender record, and re-use it for any future re-registration. Without registration the phone number cannot send.

### Step 7 — Subscribe your app to the WABA

```
POST https://graph.facebook.com/v23.0/{waba_id}/subscribed_apps
```

This is **easy to forget**, and without it your webhook silently never fires. Always do this in the same transaction as the rest of the signup.

### Step 8 — Verify subscription

```
GET https://graph.facebook.com/v23.0/{waba_id}/subscribed_apps
```

Your app should appear in `data[]`. Until you've read this back, do not declare the WhatsApp sender `active`.

## Common Stuck States and Fixes

| Symptom | Likely cause | Fix |
|---|---|---|
| Dialog opens, closes immediately, no event or code returned | Redirect URI not allowlisted, or `config_id` mismatched between init and login | Verify both in App Dashboard |
| Got the auth code but no `WA_EMBEDDED_SIGNUP` event | Older `config_id` lacking the embedded-signup feature, or message listener installed too late | Update the `config_id` to enable `whatsapp_embedded_signup`; install listener before `FB.login()`; or fall back to `debug_token` extraction |
| Code exchange returns `OAuthException` 100 | App not approved for FBL, or wrong `client_secret` | Check app status; rotate secret if leaked |
| `debug_token` shows no `whatsapp_business_management` scope | Tenant unchecked the WhatsApp permission in the dialog | Re-launch and emphasize the permission is required |
| Phone numbers list is empty | Tenant didn't link a number in the dialog | Re-launch; some tenants need to create a WABA from scratch inside the dialog |
| Webhooks never fire after signup | Forgot Step 7 (subscribe app to WABA) | Hit `/subscribed_apps` and verify the app is in the list |
| Token expires unexpectedly | Used a short-lived user token instead of a System User token | Always exchange to a System User token for production |
| `register` returns `133005` or `133006` | PIN wrong, or phone-number eligibility issue | Reset the PIN in WhatsApp Manager and retry |

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll skip the System User token — the user token works." | User tokens expire in 60 days and revoke on password change. Production must use System User. |
| "I'll subscribe to webhooks once globally, not per-WABA." | App-level webhook config picks the URL; per-WABA subscription is what actually opens the firehose for that account. Both are required. |
| "Embedded Signup auto-registers the phone number." | It does not. Step 6 (register with PIN) is your responsibility. |
| "The `config_id` is just an ID — any FBL config works." | Only configs created with the WhatsApp Embedded Signup feature produce the right flow and the `WA_EMBEDDED_SIGNUP` event. Generic FBL configs silently downgrade. |
| "I'll do this synchronously inside the OAuth callback." | Steps 5-8 take 2-10s and call multiple Meta endpoints. Run async with a job queue; show progress to the tenant. |
| "I'll still use `debug_token` since that's what the old docs say." | That path still works, but the SDK now gives you the IDs directly via the `WA_EMBEDDED_SIGNUP` event. Use it as primary and `debug_token` as fallback. |

## Red Flags

- No `message` event listener installed before `FB.login()` — you'll miss the `WA_EMBEDDED_SIGNUP` event
- Listener doesn't validate `event.origin` against `facebook.com` — accepting any origin is an XSS vector
- The `config_id` is hardcoded in client JS but never validated server-side
- Tokens stored as plaintext, not encrypted at rest
- No retry logic on Steps 5-8 — any transient Meta failure leaves the WhatsApp sender half-provisioned
- Phone-number registration PIN reused across Sender Profiles
- No verification step that `subscribed_apps` actually contains your app post-signup
- Signup completion is declared on Step 5 (code received) instead of Step 8 (webhook subscription verified)

## Verification

A complete Embedded Signup integration should:
- [ ] Fail fast in CI if any prerequisite env var is missing
- [ ] Install a `message` listener that validates `event.origin` *before* calling `FB.login()`
- [ ] Use a System User token, not a user access token, in production
- [ ] Persist WhatsApp-sender state transitions explicitly (`provisioned` → `connecting` → `connected` → `active`)
- [ ] Register the phone number and verify the registration succeeded
- [ ] Subscribe the app to the WABA and read it back to confirm
- [ ] Send a test message (or check `phone_number_status`) before declaring the WhatsApp sender active
- [ ] Surface a useful error to the tenant for each known stuck state above
- [ ] Use a current Graph API version (the spec doc tracks the version Sent currently targets)

## Related Skills

- `sender-profile-architect` — what to do with the WABA and phone numbers once signup succeeds
- `waba-template-author` — the first thing tenants do after connecting is submit templates
