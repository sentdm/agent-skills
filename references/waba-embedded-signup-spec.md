# WABA Embedded Signup — Implementation Reference

Supporting reference for `waba-embedded-signup`. Captures the exact field names,
example payloads, and Graph API endpoints used in a current (v20.0) integration.
Authoritative source:
[Embedded Signup](https://developers.facebook.com/docs/whatsapp/embedded-signup).

## Prerequisites Checklist

- [ ] Tech Provider or Solution Partner approval from Meta
- [ ] Meta App with products: **WhatsApp**, **Facebook Login for Business**
- [ ] FBL Configuration created in App Dashboard with the WhatsApp Embedded Signup
      permission selected
- [ ] `config_id` captured from the FBL config (string, treat as semi-public)
- [ ] Redirect URIs allowlisted in the FBL config for every environment
- [ ] App secret stored server-side; never expose to the browser
- [ ] System User in your Meta Business with admin role on the app
- [ ] Webhook URL configured under the WhatsApp product with a verify token
- [ ] App signing secret stored server-side, used to verify `X-Hub-Signature-256`

## Frontend — Launch the Dialog

```html
<button onclick="launchSignup()">Connect WhatsApp</button>

<script async src="https://connect.facebook.net/en_US/sdk.js"></script>
<script>
  window.fbAsyncInit = function () {
    FB.init({
      appId: 'YOUR_APP_ID',
      cookie: true,
      xfbml: false,
      version: 'v20.0'
    });
  };

  function launchSignup() {
    FB.login(
      function (response) {
        if (response.authResponse && response.authResponse.code) {
          // POST the code to your backend; include CSRF / session
          fetch('/signup/whatsapp/callback', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ code: response.authResponse.code })
          });
        } else {
          // User dismissed the dialog or did not grant permissions
        }
      },
      {
        config_id: 'YOUR_CONFIG_ID',
        response_type: 'code',
        override_default_response_type: true,
        extras: { feature: 'whatsapp_embedded_signup' }
      }
    );
  }
</script>
```

**Required `extras`:** `feature: 'whatsapp_embedded_signup'`. Without it the
dialog runs the legacy FBL flow and you'll get back a user token without
WABA scopes.

**Optional `extras`:** `setup` for pre-fill (business name, email). Useful for
existing tenants who already have data on file.

## Backend — Step 4: Exchange Code for Token

```http
GET https://graph.facebook.com/v20.0/oauth/access_token
  ?client_id={APP_ID}
  &client_secret={APP_SECRET}
  &redirect_uri={ALLOWLISTED_URI}
  &code={CODE_FROM_FRONTEND}
```

Response:
```json
{
  "access_token": "EAAB...",
  "token_type": "bearer",
  "expires_in": 5184000
}
```

This is a user token. For production, exchange to a System User token (long-lived)
before persisting.

## Backend — Step 5: Inspect with debug_token

```http
GET https://graph.facebook.com/debug_token
  ?input_token={USER_TOKEN}
  &access_token={APP_ID}|{APP_SECRET}
```

Response (abbreviated):
```json
{
  "data": {
    "app_id": "...",
    "type": "USER",
    "application": "...",
    "expires_at": 1700000000,
    "is_valid": true,
    "scopes": [
      "whatsapp_business_management",
      "whatsapp_business_messaging",
      "business_management"
    ],
    "granular_scopes": [
      {
        "scope": "whatsapp_business_management",
        "target_ids": ["WABA_ID_1"]
      },
      {
        "scope": "whatsapp_business_messaging",
        "target_ids": ["WABA_ID_1"]
      }
    ],
    "user_id": "..."
  }
}
```

The `granular_scopes` is the authoritative source of which WABA(s) the user
granted access to. Do not trust the token alone — always cross-check.

## Backend — Get the Business and Phone Numbers

```http
GET https://graph.facebook.com/v20.0/{WABA_ID}?fields=id,name,owner_business_info
```

```http
GET https://graph.facebook.com/v20.0/{WABA_ID}/phone_numbers
```

Phone-numbers response:
```json
{
  "data": [
    {
      "id": "PHONE_NUMBER_ID",
      "display_phone_number": "+1 555-555-0123",
      "verified_name": "Sent Demo",
      "code_verification_status": "VERIFIED",
      "quality_rating": "GREEN"
    }
  ]
}
```

## Backend — Step 7: Register the Phone Number

```http
POST https://graph.facebook.com/v20.0/{PHONE_NUMBER_ID}/register
Content-Type: application/json
Authorization: Bearer {SYSTEM_USER_TOKEN}

{
  "messaging_product": "whatsapp",
  "pin": "123456"
}
```

The `pin` is a 6-digit numeric PIN. Generate one per phone number, store it
encrypted on the SPS, and reuse for any future re-registration.

Response: `{ "success": true }`.

## Backend — Step 8: Subscribe Your App to the WABA

```http
POST https://graph.facebook.com/v20.0/{WABA_ID}/subscribed_apps
Authorization: Bearer {SYSTEM_USER_TOKEN}
```

Response: `{ "success": true }`.

Verify by reading back:
```http
GET https://graph.facebook.com/v20.0/{WABA_ID}/subscribed_apps
```
Response should include your app in the `data[]`. If not, webhooks will never
fire for this WABA.

## Webhook Verification (one-time, for the URL itself)

Meta calls your webhook URL with a verification request:
```
GET /webhook?hub.mode=subscribe&hub.verify_token=YOUR_TOKEN&hub.challenge=12345
```
Respond with the challenge value as the body when `verify_token` matches.

## Webhook Signature Verification (every request)

Header:
```
X-Hub-Signature-256: sha256=<hex>
```

Compute `HMAC-SHA256(request.raw_body, APP_SECRET)` and compare in constant time.
**Reject the request if the signature doesn't match.** This is the only thing
preventing spoofed webhooks.

## State Transition Persistence

After each Graph API call, persist the SPS state:

| Step | New state |
|---|---|
| Code received from frontend | `connecting` |
| Token exchanged + debug_token success | `connected` |
| Phone number registered | `registered` |
| App subscribed to WABA + verified read-back | `active` |
| Any of the above fails | `failed` (with `error_code` and `error_message`) |

Never declare `active` until Step 8 read-back succeeds. Otherwise the tenant
sees "Connected!" but no webhooks arrive.

## Common Error Responses (and what to do)

| HTTP / code | Body excerpt | Action |
|---|---|---|
| 400 / `code: 100` | `Invalid OAuth access token` | Token expired or revoked; ask tenant to reconnect |
| 400 / `code: 190` | `OAuthException` | Same as 100 |
| 403 / `code: 200` | `Permissions error` | Granular scope missing; re-launch with the right `config_id` |
| 500 | Empty body | Meta transient; retry with exponential backoff |
| 4XX on `/register` | `code: 133005` or `133006` | PIN wrong, or phone number not eligible — surface to tenant |
