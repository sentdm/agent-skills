---
name: sender-profile-architect
description: Plans multi-tenant application architecture around Sent's Sender Profile — the per-tenant abstraction that unifies SMS (10DLC/TCR brand+campaign), WhatsApp (WABA + phone numbers + access tokens), and RCS (RBM agent) into one sending identity. Use when designing tenant isolation, sender provisioning, channel routing, webhook fan-out, or rate-limit accounting for a multi-tenant messaging app on Sent. Use when a user asks "how do I model tenants and sender profiles", "how should I route an inbound webhook to the right tenant", or "how do I scope rate limits per profile across SMS/WhatsApp/RCS". Covers pooled vs siloed trade-offs, the profile lifecycle, and per-channel rate accounting.
---

# Sender Profile Architect

## Overview

In a multi-tenant messaging app on Sent, the question that breaks naive designs is: *which tenant does this inbound event belong to, and which channel's quirks does it carry?* Sent's **Sender Profile** is the abstraction that solves both — a stable, tenant-scoped record that unifies the SMS brand+campaign registration with TCR, the WhatsApp Business Account (WABA), and the RCS Business Messaging (RBM) agent under one sending identity, with one API key. This skill helps design the Sender Profile data model, lifecycle, and the surrounding multi-tenant patterns so the architecture survives 10x growth without re-platforming.

A Sender Profile is the unit of:
- **Tenant isolation** — billing meters, quotas, and access scoping all anchor here
- **Channel routing** — one profile owns the SMS, WhatsApp, *and* RCS sending identities a tenant uses
- **Webhook attribution** — inbound delivery events from carriers, Meta, and Google route back via the profile

## When to Use

Use when:
- Designing the data model for tenants, sender profiles, and per-channel sender records (TCR campaigns, WABAs, RBM agents)
- Routing inbound delivery events from any of the three channels to the right tenant
- Scoping rate limits, billing, or quotas per tenant across channels
- Choosing between pooled and isolated tenancy
- Planning the profile lifecycle (provisioning → channel-by-channel verification → suspension)

Do **not** use for:
- The Embedded Signup flow that *creates* the WhatsApp half of a profile → use `waba-embedded-signup`
- TCR brand + campaign submission for SMS → use `sms-10dlc-registration`
- RBM agent creation + verification for RCS → use `rcs-agent-onboarding`
- Template authoring or analysis — use `waba-template-author` / `messaging-performance-analyzer`

## Sender Profile as the Tenancy Primitive

```
Tenant (your customer)
   └── Sender Profile (1..N)                    ← the unit of isolation
        ├── API key (one per profile)
        │
        ├── SMS sender:
        │   ├── Phone number(s) / short code(s)
        │   ├── TCR Brand ID
        │   └── TCR Campaign ID(s)              ← carrier filtering keys
        │
        ├── WhatsApp sender:
        │   ├── WABA ID (Meta)
        │   ├── System User access token
        │   └── Phone Number(s)                 ← phone_number_id is the WA webhook key
        │
        └── RCS sender:
            ├── RBM Agent ID (Google)
            └── Verified domains, capabilities, fallback policy
```

Why "Sender Profile" — not "Tenant", not "WABA", not "TCR Brand" — is the right granularity:
- A tenant may run multiple brands (multiple profiles)
- A profile may host any combination of the three channels — some profiles are SMS-only, some span all three
- Inbound webhooks arrive from three different carriers/platforms and must converge on one tenant view

Every channel-specific resource you store should reference the **Sender Profile ID**, not the tenant ID directly. Tenant ID is one foreign key on the profile.

For the conceptual data model (display name, brand description, `x-sender-id`, channel configuration status, how brands/campaigns/webhooks/API keys hang off the profile), see `references/sender-profile-data-model.md`.

## Pooled vs Siloed Decision

The basics of pooled-vs-siloed multi-tenancy are well-covered elsewhere; what matters for a messaging platform on Sent is the constraints unique to messaging:

| Concern | Pooled (one shared store, tenant scoped) | Siloed (per-tenant store) |
|---|---|---|
| Cost at small scale | Low | High |
| Onboarding a new profile | Instant; the work is the per-channel registration, not infra | Requires infra provisioning *plus* per-channel registration |
| Message-content storage (PHI / residency) | Hard to claim isolation | Easy |
| Cross-channel funnel analytics | Single query | Pipeline per silo |
| TCR campaign sharing across tenants | Trivial (each tenant owns its own campaign) | Same; tenancy doesn't change TCR |

**Default to pooled** for the Sender Profile and message-event metadata. Silo only when a tenant pays for it or a regulator requires it. Hybrid pattern: pooled compute, pooled profile metadata, but **siloed message-content storage** for tenants with PHI or strict residency requirements.

For decision criteria and the messaging-specific reconciliation / offboarding patterns, see `references/multi-tenancy-patterns.md`. For worked examples of where to draw the profile boundary (per legal entity, per channel, per department, per tenant in a B2B2C platform, per region), see `references/profile-boundary-examples.md`.

## Sender Profile Lifecycle (state machine)

A profile's overall state is the *minimum* state across its enabled channels. Track per-channel state independently and surface the rollup.

```
provisioned ──► connecting ──► partially_active ──► active
     │              │                  │                │
     ▼              ▼                  ▼                ▼
  failed       disconnected        suspended       restricted
                                       │
                                       └──► restoring ──► active
```

States and what owns them:

- **provisioned** — Profile exists; no channel linked yet.
- **connecting** — Tenant has started at least one channel onboarding (Embedded Signup, TCR submission, RBM agent creation).
- **partially_active** — At least one channel is sending, but others are still pending verification. Common steady state during onboarding.
- **active** — All enabled channels are sending. Quality / vetting scores tracked.
- **suspended** — Carrier or platform has restricted *one* channel (e.g. WABA quality drop, TCR campaign paused, RBM agent suspended). Other channels may still be sending.
- **restricted** — All channels blocked.
- **disconnected** — Token expired or revoked on at least one channel; needs re-auth via the channel-specific onboarding skill.

Each channel carries its own sub-state alongside the rollup. Persist that explicitly — don't infer it by hitting upstream APIs on every request. Track when each channel was last reconciled so you know how stale each is.

## Webhook Routing

Each channel pushes its own webhook stream with its own routing key. The job is to converge them on the Sender Profile.

| Channel | Inbound source | Routing key in payload |
|---|---|---|
| SMS | Carrier (via Sent) | Sender phone / short code + TCR campaign ID |
| WhatsApp | Meta | WABA ID + `phone_number_id` |
| RCS | Google RBM (via Sent) | `agentId` |

For each event, the handler should:

1. Verify the signature against the *channel's* secret (Meta `X-Hub-Signature-256` with app secret; carrier-specific HMAC for SMS; RBM service-account JWT for RCS).
2. Resolve the routing key to a Sender Profile.
3. Enqueue per-profile (or per-tenant) so a noisy tenant doesn't block another.
4. ACK fast — every platform retries on 5xx and times out (Meta ~15s, Google ~10s, carriers vary).

Never put per-webhook business logic in the webhook handler — enqueue and return 200 immediately.

## Rate Limits & Quotas

You account for limits at three layers on every channel. Track per-channel; bill at the profile.

| Channel | Carrier / platform limit |
|---|---|
| SMS | TCR campaign throughput (TPS), assigned after vetting; per-carrier filtering |
| WhatsApp | Phone-number tier (1K / 10K / 100K / unlimited business-initiated conversations per 24h); Cloud API CPS cap |
| RCS | Agent QPS imposed by Google; per-carrier delivery throttling |

Plus **your per-profile quota** — whatever you sell. Enforce at the Sender Profile layer.

Bill against the Sender Profile, not the tenant — a tenant with three brands gets three meters.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll just key everything by WABA." | Plenty of Sent customers don't have a WABA — they're SMS-only or RCS-only. Sender Profile is the only key that works across channels. |
| "Tenant is enough — I don't need Sender Profile." | The moment a tenant runs two brands (or mixes SMS-only and WhatsApp-only brands), the model breaks. Profile is a five-minute decision today and a six-month migration in two years. |
| "Pooled is too risky for an enterprise tenant." | Pooled with strict access boundaries is what every messaging platform does. Silo as an upsell, not a default. |
| "I'll process the webhook synchronously — it's just a status update." | At scale, a single WhatsApp phone number or SMS campaign can push hundreds of events per second. Synchronous processing kills throughput. Always enqueue. |
| "I can share one Meta System User token across profiles." | One revoked token now disables every profile. One System User per WABA. |

## Red Flags

- A message attributed to a tenant but with no Sender Profile or per-channel routing key behind it
- Webhook handlers doing real work before ACKing
- No per-channel state — sender state is recomputed from upstream API calls on demand
- Rate limits enforced at the HTTP-request layer, not at the Sender Profile / per-channel-sender layer
- No staleness tracking per channel
- The same Meta access token, TCR API key, or RBM service account shared across multiple Sender Profiles
- "SMS-only" customers force-fitted into a WhatsApp-shaped model

## Verification

A sound Sender Profile architecture has:
- [ ] Sender Profile sits between Tenant and every channel-specific sender; nothing channel-specific attaches directly to Tenant
- [ ] A documented state machine with explicit transitions — per channel and at the profile rollup
- [ ] Webhook routing that resolves each channel's routing key to a Sender Profile fast and enqueues per profile
- [ ] Workers that can be scaled per tenant or per profile (no single global queue)
- [ ] Rate-limit accounting at the Sender Profile *and* per-channel-sender layer, not at request time
- [ ] A documented escalation path for `suspended`, `restricted`, and `disconnected` states per channel (re-auth flow, ops alert)

## Related Skills

- `waba-embedded-signup` — the flow that links the WhatsApp half of a Sender Profile
- `sms-10dlc-registration` — the flow that registers a TCR brand + campaign on a Sender Profile
- `rcs-agent-onboarding` — the flow that creates and verifies an RBM agent on a Sender Profile
- `messaging-performance-analyzer` — if profile state seems to correlate with delivery problems
- See the top-level `references/` directory — `sent-glossary.md` — for shared Sent terminology.
