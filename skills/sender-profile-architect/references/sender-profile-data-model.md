# Sender Profile Data Model — Reference

Supporting reference for `sender-profile-architect`. Captures the conceptual model Sent exposes for a Sender Profile and the resources that attach to it. Names are drawn from the Sent v3 OpenAPI and the dashboard documentation at https://docs.sent.dm — when in doubt, the live spec is the source of truth.

This doc is **conceptual**, not a schema dump. Resource shapes evolve; the relationships below are what stabilize them.

## Top-level shape

A Sender Profile carries metadata that Sent uses for routing, billing, and dashboard display, plus per-channel attachments that carry the regulator-facing identity for each channel.

```
SenderProfile
├── id                          (Sent-issued, stable)
├── displayName                 (shown in dashboard + as default sender name)
├── brandDescription            (human-readable; surfaces in TCR + WABA flows)
├── x-sender-id                 (header value tenants use on /messages calls)
├── completionStatus            (rollup across enabled channels)
├── channelConfigurationStatus  (per-channel: enabled? verified? throttled?)
├── webhooks[]                  (scoped to this profile)
├── apiKeys[]                   (scoped to this profile)
└── senders
    ├── sms?       → SmsSender (TCR brand + campaign + phone/short code)
    ├── whatsapp?  → WhatsAppSender (WABA + phone numbers + System User token)
    └── rcs?       → RcsSender (RBM agent + verified domains + fallback policy)
```

Verified via OpenAPI / docs:

- `displayName`, `brandDescription`, and an `x-sender-id` header are first-class on a Sender Profile.
- `completionStatus` exists as a rollup field surfaced in the dashboard.
- Per-channel configuration is tracked separately from the rollup status.
- Webhooks and API keys both scope to a Sender Profile, not directly to a tenant.

Likely but unverified inference (treat as design intent, confirm against the live OpenAPI before coding against it):

- Exact field names like `channelConfigurationStatus` and the substructure of each channel sender may differ slightly. The shape — one profile, three optional channel attachments — is stable.
- The exact set of completion statuses (`provisioned`, `partially_active`, `active`, …) is described in the SKILL.md state machine and may not map 1:1 to API enum values.

## How channels attach

Each channel is an *optional* sub-resource of the profile. A profile may have zero, one, or all three. The channel attachment carries the regulator-facing identity for that channel:

| Channel | Attached identity | Key external IDs |
|---|---|---|
| SMS | A TCR-registered brand + at least one campaign, plus one or more phone numbers / short codes | TCR Brand ID, TCR Campaign ID, sender phone |
| WhatsApp | A Meta WABA, one or more WABA phone numbers, a System User access token | WABA ID, `phone_number_id`, System User ID |
| RCS | A Google RBM agent, verified domains, fallback policy | `agentId` |

Two consequences fall out of this model:

1. **Provisioning is per-channel**. A profile can be `partially_active` — sending on SMS but still pending WABA verification, or RCS-verified but with no SMS sender yet.
2. **Channel identifiers are the webhook routing keys** (see `references/multi-tenancy-patterns.md`). The data model is what makes "look up the Sender Profile from a `phone_number_id`" cheap.

## How brands and campaigns relate

The word *brand* shows up in two layers and the overload is a frequent source of bugs:

- **Sent brand context** — the `brandDescription` and `displayName` on the Sender Profile. Used for display and surfaced as the default sender identity in some channels.
- **TCR Brand** — the legal-entity record registered with The Campaign Registry, mandatory for US 10DLC SMS. One Sent Sender Profile typically maps to one TCR Brand, which in turn owns one or more TCR Campaigns (each campaign is a registered use case with its own throughput and filtering).

```
SenderProfile (Sent)
  └── SmsSender
       └── TCR Brand (1)
            └── TCR Campaign (1..N) ─── carrier filtering happens here
```

A profile that needs to send for multiple distinct use cases (e.g. transactional + marketing) typically registers multiple TCR Campaigns under the same TCR Brand, all attached to the same SMS sender.

WhatsApp has no direct analogue of TCR Campaigns — WABA + per-template approval plays a similar role. RCS uses one RBM agent per profile per region.

## Webhooks scope to the profile

Webhook subscriptions in Sent are per-Sender-Profile. The implication for architecture:

- The webhook secret used to verify Sent → tenant signatures is per-profile. Rotating a secret affects only that profile.
- Inbound events that arrive on a profile's webhook are guaranteed to be about that profile's senders — the routing fan-in is solved before the tenant ever sees it.
- One tenant with multiple Sender Profiles will typically configure one webhook per profile.

Caveat: this assumes the tenant chose per-profile webhooks. Some tenants intentionally point all their profiles at the same URL and route on the payload contents; that works but the secret-rotation blast radius widens.

## API keys scope to the profile

API keys authenticate as a Sender Profile, not as a tenant. This is the property that lets:

- Per-profile rate-limit accounting (the rate limiter has the profile ID before any database lookup).
- Per-profile audit logging.
- Per-profile credential rotation that doesn't take other profiles down.

A tenant that wants a single key for all its profiles has to build that abstraction itself (e.g. an internal proxy that maps an internal tenant key to the right Sent profile key). Sent does not provide a "tenant-level" key today.

## ER summary

```
Tenant (your customer)
  │  1..N
  ▼
SenderProfile ── apiKey(s) ── webhook(s)
  │
  ├── (0..1) SmsSender ─── TCR Brand ─── TCR Campaign(s) ─── PhoneNumber(s)
  ├── (0..1) WhatsAppSender ─── WABA ─── PhoneNumber(s) + SystemUserToken
  └── (0..1) RcsSender ─── RBM Agent ─── VerifiedDomain(s)
```

The single architectural rule that follows: every channel-specific resource references the Sender Profile ID, never the Tenant ID directly. Tenant is a foreign key on Sender Profile.

## What to confirm against the live OpenAPI

Before writing application code, confirm with the Sent v3 OpenAPI at https://docs.sent.dm:

- Exact field names on the Sender Profile resource (`displayName`, `brandDescription`, `completionStatus`, etc.).
- The exact enum values for completion / configuration status.
- The webhook subscription resource shape and which events scope to which profile.
- API-key creation + scope semantics.

The relationships in this doc are stable; the field names are not guaranteed to be byte-perfect.
