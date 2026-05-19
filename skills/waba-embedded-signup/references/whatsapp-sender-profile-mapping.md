# WhatsApp ↔ Sent Sender Profile Mapping

How Meta-side entities created during Embedded Signup map onto Sent's Sender Profile model. Read this before deciding how many profiles to create per tenant, or when debugging why a webhook landed on the wrong profile.

## The entities

**Meta side:**
- **Business Manager** — the tenant's legal/operational umbrella in Meta Business Suite.
- **WABA (WhatsApp Business Account)** — owns templates and phone numbers; the unit Meta bills.
- **Phone Number** — a single E.164 number registered for Cloud API on a WABA.
- **System User** — the long-lived identity that holds the access token used to call Graph API on behalf of the tenant.

**Sent side:**
- **Sender Profile** — the tenant's unified sending identity across SMS / WhatsApp / RCS. Owns one API key. (See top-level `references/sent-glossary.md`.)
- **Channel config** — the per-channel block on a profile. The WhatsApp channel config holds `waba_id`, `phone_number_id`, vault-refs for the access token and registration PIN.
- **Webhook routing** — Sent uses `phone_number_id` from inbound Meta payloads to route events back to the right profile's MDR stream.

## ASCII map

```
Tenant
  │
  ├── Business Manager (1)
  │     │
  │     ├── WABA #A ────────────────────────► Sender Profile P1
  │     │     ├── Phone +1 555 0100  ◄────────┤  channels.whatsapp
  │     │     ├── Phone +1 555 0101  ◄──┐     │  { waba_id: A,
  │     │     └── Templates              │    │    phone_number_id: ...100,
  │     │                                │    │    token_ref, pin_ref }
  │     │                                │    │
  │     │                                └────► Sender Profile P2
  │     │                                     │  channels.whatsapp
  │     │                                     │  { waba_id: A,
  │     │                                     │    phone_number_id: ...101 }
  │     │
  │     └── WABA #B ────────────────────────► Sender Profile P3
  │           └── Phone +44 20 7946 0000 ◄────┤  channels.whatsapp
  │                                            │  { waba_id: B,
  │                                            │    phone_number_id: ... }
  │
  └── System User (1) ──► token held in vault, referenced by all of P1/P2/P3
```

## Cardinality rules

| Relationship | Cardinality | Notes |
|---|---|---|
| Business Manager → WABA | 1 : N | A tenant may operate multiple WABAs (e.g. per region or brand) under one Business Manager. |
| WABA → Phone Number | 1 : N | Up to 25 per WABA per Meta's current limits. |
| Phone Number → Sender Profile | 1 : 1 | **Hard rule.** Each phone number routes to exactly one profile. Sharing a number across profiles breaks webhook routing. |
| WABA → Sender Profile | 1 : N | Multiple profiles may reference the same WABA, each pinning a different `phone_number_id`. Useful when one tenant runs separate brands off the same WABA. |
| System User → WABA | 1 : N | One System User token can hold scopes for many WABAs. |
| Sender Profile → WhatsApp channel | 0 : 1 | A profile has at most one WhatsApp half. SMS / RCS halves are independent. |

## What `POST /v3/profiles/{id}/complete` actually does

Profile completion is the Sent-side commit that takes a profile from `draft` to `active` for a given channel. For WhatsApp:

1. Validates that `(waba_id, phone_number_id)` is not already claimed by another profile in this tenant.
2. Persists `phone_number_id` into the profile's routing index — this is what lets Sent's webhook ingest find the right profile when Meta delivers an inbound event.
3. Stores `token_ref` and `pin_ref` as opaque vault references; the values themselves never enter the profile record.
4. Subscribes Sent's app to the WABA (idempotent — safe to re-call).
5. Returns the profile with `channels.whatsapp.state = active`.

Idempotent on `(profile_id, channel)`: calling again with corrected fields updates in place. See [docs.sent.dm](https://docs.sent.dm) for the live request/response schema.

## How webhook events flow back

```
Meta Cloud API ──signed POST──► Sent webhook ingest
                                     │
                                     │ verify X-Hub-Signature-256
                                     │ extract entry[].changes[].value.metadata.phone_number_id
                                     │
                                     ▼
                              Phone-number-id → Sender Profile lookup
                                     │
                                     ▼
                              Tenant MDR stream + webhook to tenant URL
```

The routing key is `phone_number_id`, not `waba_id`. This is why the "Phone Number → Sender Profile" relation must stay 1:1 — there's nowhere else in the payload to disambiguate.

## Detaching a WABA without losing message history

You will eventually need to remove a WABA from a profile (tenant churns, swaps providers, etc.) **without** wiping the historical MDRs for compliance.

1. Set `channels.whatsapp.state = detaching` on the profile (blocks new sends).
2. Wait for in-flight messages to settle (delivery webhooks drain within 24h for normal traffic, 48h for slower carriers).
3. `DELETE /v3/profiles/{id}/channels/whatsapp` — soft-deletes the channel config, keeps MDR history searchable by `wamid` and `phone_number_id`.
4. Unsubscribe Sent's app from the WABA: `DELETE /v23.0/{waba_id}/subscribed_apps` (Graph API).
5. Optionally archive the System User token if no other profile references it.

The MDR history stays queryable; only the *send* path is removed. Re-attaching later goes through the normal Embedded Signup flow and produces a fresh channel config.

## Migrating a phone number between WABAs

Tenants sometimes need to move a phone number from one WABA to another (consolidating, separating brands, or switching from a self-served WABA to a Tech-Provider-managed one). Meta supports this; Sent treats it as a profile re-mapping.

1. **In Meta:** initiate "Migrate phone number" in WhatsApp Manager on the *destination* WABA, target the source WABA + number. Meta sends an OTP to the registered number to confirm.
2. **Post-migration:** the *same* `phone_number_id` now belongs to the new WABA. The number, display name, quality rating, and existing `wamid` history all survive. Templates do **not** transfer — they live on the WABA.
3. **In Sent:** update the affected profile's channel config: `PATCH /v3/profiles/{id}/channels/whatsapp { waba_id: <new> }`. The `phone_number_id` is unchanged, so webhook routing is unaffected.
4. **Subscribe Sent's app to the new WABA** (`POST /{new_waba_id}/subscribed_apps`) — the old subscription does not follow the number.
5. **Re-author or re-clone any templates** the tenant used; their old approvals do not migrate.

The `phone_number_id` stability is what makes this clean for Sent — webhook routing and MDR history are keyed on it, so message history pre- and post-migration sits in one searchable timeline.
