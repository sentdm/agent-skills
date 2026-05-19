# WABA Onboarding Runbook

Operator-facing companion to `waba-embedded-signup`. Walks the flow in time order and tells you, for each step, what success looks like, the failure modes you should expect, and how to recover **without** restarting the whole signup.

Use this when shepherding a real tenant through Embedded Signup on Sent, or when a stuck WhatsApp Sender Profile lands on your desk and you need to pinpoint where it broke.

## 0. Pre-flight (do once per Meta app, not per tenant)

Verify all of these in [Meta Business Suite](https://business.facebook.com) and the App Dashboard before *any* tenant sees the button:

- [ ] **Tech Provider status approved.** Business Settings → Requests → Tech Provider tab shows "Approved". If it shows "Pending" or "More info needed", finish that first — signup will technically run without it, but you cannot bill or manage tenant WABAs on their behalf.
- [ ] **App is Live** (not "In Development") in App Dashboard → App Review. In Development apps only signal-test with admin/dev/tester accounts.
- [ ] **Required products added:** WhatsApp + Facebook Login for Business.
- [ ] **Permissions approved in App Review:** `whatsapp_business_management`, `whatsapp_business_messaging`, `business_management`.
- [ ] **System User created** in Business Settings → Users → System Users. Role: Admin. Generate a never-expiring token scoped to the app and store in your secrets manager.
- [ ] **FBL Configuration** with the WhatsApp Embedded Signup feature selected, `config_id` captured.
- [ ] **Redirect URIs allowlisted** for every environment that launches the dialog.
- [ ] **Webhook URL + verify token** configured on the WhatsApp product. URL must respond to Meta's GET verification handshake before save will succeed.

**Success looks like:** A green Tech Provider badge, app status "Live", a System User token that introspects via `debug_token` with all three WhatsApp scopes.

**Common failure:** Tech Provider in "More info needed" because the legal entity uploaded doesn't match what's on your Meta Business. Re-upload with the exact registered business name and EIN — Meta matches strings, not entities.

**Recovery without restarting:** None — pre-flight blocks everything. If you discover a gap mid-tenant-flow, pause signup at the UI level and finish pre-flight before re-launching.

## 1. Launch the Embedded Signup dialog (frontend)

The tenant clicks "Connect WhatsApp". Your code calls `FB.login()` with the `config_id` and `extras: { feature: 'whatsapp_embedded_signup', version: 3 }`.

**Success looks like:** The Meta dialog opens to "Continue as <tenant>" and lists the assets the tenant will grant. The `message` listener (installed *before* `FB.login`) fires with `type: 'WA_EMBEDDED_SIGNUP'` and `event: 'FINISH'` containing `{ phone_number_id, waba_id, business_id }`.

**Common failure modes:**
- Dialog opens then closes immediately → `redirect_uri` not allowlisted or `config_id` belongs to a different app.
- No `WA_EMBEDDED_SIGNUP` event ever fires → listener installed *after* `FB.login` (race), or the `config_id` predates the embedded-signup feature.
- Tenant chose "Create a new WhatsApp Business Account" inside the dialog and got stuck on business verification → not your bug; surface a clear "finish business verification in Meta Business Suite" link and resume later.

**Recovery without restarting:** Capture the auth code regardless. If `sessionInfo` is missing, fall back to Step 5b (`debug_token`) — you can still recover `waba_id` from `granular_scopes` + `/owned_whatsapp_business_accounts`.

## 2. Backend OAuth code → token exchange

`POST /signup/whatsapp/callback` arrives with `{ code, session }`. Exchange the code at `GET /oauth/access_token` to receive a short-lived user token, then **immediately** swap it for a System User token so it survives the tenant changing their password.

**Success looks like:** `debug_token` on the resulting token shows `is_valid: true`, `expires_at: 0` (never), and `granular_scopes` containing the WABA the tenant granted.

**Common failure modes:**
- `OAuthException 100` → wrong `client_secret`, or `redirect_uri` doesn't *exactly* match what was used to mint the code.
- `expires_in: 5184000` instead of never-expiring → you forgot the System User swap and persisted the user token.
- `granular_scopes` empty → tenant unchecked WhatsApp permissions in the dialog.

**Recovery without restarting:** Token-exchange failures are recoverable in place — fix secrets / redirect URI and replay the same `code` (codes are valid for 1 hour and one use). If the code is already consumed, re-launch the dialog from Step 1; the tenant only re-confirms permissions.

## 3. Phone number registration with Meta

`POST /{phone_number_id}/register` with `{ messaging_product: 'whatsapp', pin }`. The PIN is a 6-digit code you generate; persist it encrypted on the WhatsApp sender record so re-registration is possible later.

**Success looks like:** `{ "success": true }`. A follow-up `GET /{phone_number_id}` shows `code_verification_status: VERIFIED`.

**Common failure modes:**
- `133005` (PIN mismatch) → previously registered with a different PIN. Reset in WhatsApp Manager → Phone Numbers → ⋮ → Two-step verification, then retry.
- `133006` (number not eligible) → number is on hold (quality drop) or owned by a different WABA. Check WhatsApp Manager.
- Silent 200 with no register response → wrong endpoint version. Confirm you are on the same Graph API version as the rest of the flow.

**Recovery without restarting:** All register errors are step-local. Fix the PIN / number eligibility and re-POST `/register`. Do *not* re-launch the dialog.

## 4. WABA subscription

`POST /{waba_id}/subscribed_apps`. This subscribes **your app** to **this WABA's** webhook firehose. App-level webhook URL config is necessary but not sufficient — without per-WABA subscription, no events flow.

**Success looks like:** `{ "success": true }`, then `GET /{waba_id}/subscribed_apps` returns `data[]` containing your `{ whatsapp_business_api_data: { id: <YOUR_APP_ID> } }`.

**Common failure modes:**
- 200 but read-back is empty → token used for the POST didn't have `whatsapp_business_management` on this WABA. Use the System User token, not a user token.
- 403 on POST → app not approved for WhatsApp permissions in App Review.

**Recovery without restarting:** Always do the read-back. If subscription is missing, fix the token / app review and re-POST. Never mark the sender `active` based only on the POST response.

## 5. Mapping into a Sent Sender Profile

Persist the new WhatsApp half on the tenant's [Sender Profile](https://docs.sent.dm) by calling Sent's profile-completion endpoint:

```
POST /v3/profiles/{profile_id}/complete
{
  "channel": "whatsapp",
  "waba_id": "...",
  "phone_number_id": "...",
  "business_id": "...",
  "access_token_ref": "vault://wa/tokens/<id>",
  "pin_ref": "vault://wa/pins/<id>"
}
```

Store tokens and PINs by *reference* (vault path), never by value, in the Sender Profile record.

**Success looks like:** Sender Profile `channels.whatsapp.state` transitions to `active`. The Sent dashboard shows the verified business name and `display_phone_number`.

**Common failure modes:**
- Profile already had a WhatsApp half on a different WABA → reject the completion request; force tenant to either detach the old WABA or create a new profile.
- Token-ref persisted but no `access_token` actually written to the vault → broken vault wiring on your side. The profile will show "Connected" and silently fail on first send.

**Recovery without restarting:** Profile completion is idempotent on `(profile_id, channel)` — re-POST with corrected fields.

## 6. Webhook subscription verification

Send a synthetic event through the loop to prove the wiring works end-to-end:

1. Mark the new WhatsApp number as your own (admin-side) and from a personal WhatsApp, message it.
2. Expect Sent to receive a `messages` webhook from Meta and re-emit it on the tenant's MDR stream.

**Success looks like:** A Sent MDR with `channel: whatsapp`, `direction: inbound`, and a `wamid` that matches what your personal device sees in the chat.

**Common failure modes:**
- No webhook → Step 4 (per-WABA subscription) wasn't actually verified.
- Webhook arrives at Meta-side but not at Sent → app-level webhook URL is wrong, or the signature check is rejecting requests. Check Sent's webhook-ingest logs.
- Webhook arrives at Sent but not on the tenant's MDR → Sender Profile mapping in Step 5 didn't actually persist `phone_number_id` (routing key).

**Recovery without restarting:** All are repair-in-place. Re-verify subscription read-back; check the app-level webhook URL; re-POST `/complete` with the correct `phone_number_id`.

## 7. First test send

`POST` an approved template (the simplest utility template you have) to the phone number you control.

**Success looks like:** `200` with a `messages[0].id` (the outbound `wamid`); within seconds, a `sent` → `delivered` → `read` sequence on the MDR stream.

**Common failure modes:**
- `131047` (re-engagement required) → expected; means you're outside the 24-hour window and used a non-template message. Use a template.
- `132000` (template not approved) → tenant hasn't authored or had a template approved yet. Direct them to the template builder.
- Outbound succeeds, no MDR follow-up → Step 6 (webhook end-to-end) wasn't actually verified.

**Recovery without restarting:** Send errors are tenant-content issues, not signup issues. The Sender Profile is `active` — leave it that way and surface a clear next-step ("approve a template") in the tenant UI.

## Stuck-state triage cheat-sheet

| Symptom in production | Step | First thing to check |
|---|---|---|
| "Connect WhatsApp" does nothing | 1 | Browser console for FBL init errors; `config_id` matches app |
| Dialog closes immediately | 1 | Redirect URI allowlist for *this* environment |
| Backend got code, missing `waba_id` | 1–2 | Listener race; fall back to `debug_token` |
| Token works, register fails 133005 | 3 | PIN was set elsewhere; reset in WhatsApp Manager |
| Subscribed but no webhooks | 4–6 | Read back `/subscribed_apps`; verify app-level webhook URL |
| Sender Profile `active` but no MDR | 6 | `phone_number_id` mapping in Sent |
| Test send 132000 | 7 | Not a signup bug; tenant needs an approved template |
