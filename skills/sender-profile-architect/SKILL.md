---
name: sender-profile-architect
description: Plans multi-tenant application architecture around Sent's Sender Profiles (SPS) — the per-tenant abstraction over a WABA phone number, WhatsApp Business Account, and webhook subscription. Use when designing tenant isolation, sender provisioning, per-tenant phone-number routing, webhook fan-out, or rate-limit accounting for a multi-tenant WhatsApp app. Use when a user asks "how do I model tenants and senders", "how should I handle multi-tenancy with WABA", or "how do I scope rate limits per tenant". Covers pooled vs siloed trade-offs, the sender lifecycle, and webhook routing.
---

# Sender Profile Architect

## Overview

In a multi-tenant WhatsApp app, the question that breaks naive designs is: *which tenant does this incoming webhook belong to?* Meta sends a single webhook stream to your app per **WABA** (WhatsApp Business Account); the routing back to the right tenant is your problem. **Sent's Sender Profile (SPS)** is the abstraction that solves this — a stable, tenant-scoped record that owns the WABA, the phone numbers, the access token, and the routing rules. This skill helps design the SPS data model, lifecycle, and the surrounding multi-tenant patterns so the architecture survives 10x growth without re-platforming.

## When to Use

Use when:
- Designing the data model for tenants, senders, and WABAs
- Routing incoming WhatsApp webhooks to the right tenant
- Scoping rate limits, billing, or quotas per tenant
- Choosing between pooled and isolated tenancy
- Planning the sender lifecycle (provisioning → verification → suspension)

Do **not** use for:
- The actual Embedded Signup flow that *creates* a sender → use `waba-embedded-signup`
- Template authoring or analysis — use `waba-template-author` / `messaging-performance-analyzer`

## SPS as the Tenancy Primitive

```
Tenant (your customer)
   └── SPS (1..N)                    ← the unit of isolation
        ├── WABA ID (Meta)
        ├── System User access token (Meta)
        ├── Phone Number (1..N)      ← phone_number_id is the webhook key
        └── Webhook subscriptions
```

Why SPS, not "tenant", is the right granularity:
- A tenant may run multiple brands (multiple WABAs)
- A WABA may host multiple phone numbers, each with its own messaging tier
- Webhooks are scoped to (WABA, phone_number_id), not to the tenant

Every Meta object you store should reference the **SPS ID**, not the tenant ID directly. Tenant ID is one foreign key on the SPS.

## Pooled vs Siloed Decision

| Concern | Pooled (shared DB, tenant_id column) | Siloed (per-tenant DB or schema) |
|---|---|---|
| Cost at small scale | Low | High |
| Onboarding new tenants | Instant | Requires provisioning |
| Blast radius of a bad query | All tenants | One tenant |
| Compliance (data residency, BAA) | Hard | Easy |
| Operational complexity | Low | High |

**Default to pooled** for the SPS and message data. Silo only when a tenant pays for it or a regulator requires it. Hybrid pattern: pooled compute, pooled SPS metadata, but **siloed message-content storage** for tenants with PHI or strict residency requirements.

For decision criteria and migration paths, see `references/multi-tenancy-patterns.md`.

## Sender Lifecycle (state machine)

```
provisioned → connecting → connected → verifying → verified → active
                  │             │           │           │
                  ↓             ↓           ↓           ↓
              failed       disconnected  rejected   suspended
                                            │           │
                                            └──→ restoring ──→ active
```

States and what owns them:

- **provisioned** — Row exists in your DB; no Meta link yet. Tenant has not finished Embedded Signup.
- **connecting** — Embedded Signup completed; you're exchanging the auth code, fetching `business_id`, `waba_id`, debug-token-validating.
- **connected** — Tokens stored, WABA linked, but phone number not yet registered.
- **verifying** — Business verification submitted to Meta; waiting for review.
- **verified** — Meta has approved the business; messaging tier assignable.
- **active** — Sending allowed. Quality rating tracked.
- **suspended** — Meta has restricted the account (quality, tier downgrade). No sending; templates frozen.
- **disconnected** — Token expired or revoked; needs re-auth via Embedded Signup.

Persist the state machine — don't infer state from Meta API responses on every request. Persist `last_meta_sync_at` so you know how stale the state is.

## Webhook Routing

Incoming webhook payload contains `entry[0].id` (the WABA ID) and inside the change, `value.metadata.phone_number_id`. The routing key is **`phone_number_id`**:

```
phone_number_id → SPS ID → tenant_id → tenant-scoped queue
```

Store the `phone_number_id ↔ SPS` mapping in a fast lookup (Redis, or a B-tree index in Postgres). Webhook handlers should:
1. Verify the X-Hub signature against the **app-level** secret (one secret, all WABAs)
2. Resolve `phone_number_id` to SPS
3. Enqueue per-SPS (or per-tenant) so a noisy tenant doesn't block another
4. ACK fast (Meta retries on 5xx and times out at ~15s)

Never put per-webhook business logic in the webhook handler — enqueue and return 200 immediately.

## Rate Limits & Quotas

Three layers, all of which you must account for:

1. **Meta phone-number tier** — Tier 1k / 10k / 100k / unlimited business-initiated conversations per 24h. Track via Meta's quality-rating API per SPS.
2. **Meta messaging rate** — Throughput cap per phone number (CPS). Burst beyond this gets 429s.
3. **Your per-tenant quota** — Whatever you sell. Enforce at the SPS layer with a token bucket, not the request layer.

Bill against the SPS, not the tenant — a tenant with three brands gets three meters.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll just key everything by `waba_id`." | A WABA can have multiple phone numbers with different tiers. You'll need per-phone-number scoping eventually. |
| "Tenant ID is enough — I don't need SPS." | The moment a tenant runs two brands, your schema breaks. SPS is a five-minute decision today and a six-month migration in two years. |
| "Pooled is too risky for an enterprise tenant." | Pooled with strict row-level access (Postgres RLS, app-layer enforcement) is what every messaging platform does. Silo as an upsell, not a default. |
| "I'll process the webhook synchronously — it's just a status update." | At scale, a single phone number can push hundreds of webhooks/sec. Synchronous processing kills throughput. Always enqueue. |
| "I'll cache phone_number_id → tenant in memory and skip the DB." | Fine until you scale to N pods; then a webhook hits a pod without the mapping and gets dropped. Use a shared cache or DB. |

## Red Flags

- The data model has `tenant_id` on a message row but no `sps_id` or `phone_number_id`
- Webhook handlers do DB writes before ACKing
- No state machine — sender state is derived from Meta API calls on demand
- Rate limits enforced at the HTTP-request layer, not at the SPS layer
- No `last_meta_sync_at` or equivalent staleness tracking
- The same access token is shared across multiple SPS records (it shouldn't be — one System User per WABA)

## Verification

A sound SPS architecture has:
- [ ] An SPS table with a clear FK to `tenant`, and `phone_number_id` indexed for webhook lookup
- [ ] A documented state machine with explicit transitions and persisted state
- [ ] Webhook routing that resolves `phone_number_id` → SPS in O(1) and enqueues per-SPS
- [ ] A worker pool that can be scaled per-tenant or per-SPS (no global queue)
- [ ] Rate-limit accounting at the SPS layer using token buckets, not request-time checks
- [ ] A documented escalation path for `suspended` and `disconnected` states (re-auth flow, ops alert)

## Related Skills

- `waba-embedded-signup` — the flow that takes an SPS from `provisioned` to `connected`
- `messaging-performance-analyzer` — if SPS state seems to correlate with delivery problems
