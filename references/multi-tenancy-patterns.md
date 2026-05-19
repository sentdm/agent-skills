# Multi-Tenancy Patterns for Messaging Apps on Sent — Reference

Supporting reference for `sender-profile-architect`. Patterns that are *specific to messaging workloads* on Sent — high write volume, webhook fan-in from three channels, and carrier / Meta / Google compliance constraints. Generic multi-tenant SaaS theory is covered exhaustively elsewhere; this doc only captures what changes when SMS, WhatsApp, and RCS are involved.

## What a Sender Profile owns

A Sender Profile is *one tenant's sending identity* across every channel that tenant uses. At minimum:

- One API key (the tenant authenticates as the profile)
- Zero or one SMS sender — phone number(s) or short code, plus a TCR brand + campaign registration
- Zero or one WhatsApp sender — a WABA, one or more phone numbers, a System User token
- Zero or one RCS sender — an RBM agent with verified domains and a fallback policy

Each tenant may have multiple profiles (one per brand, region, or use case). The profile is the routing key everything else attaches to.

## Webhook Routing (the hot path)

Each channel pushes inbound events on its own stream with its own routing key. The job is to converge them on the right Sender Profile:

| Channel | Inbound from | Routing key in the payload | Used to find |
|---|---|---|---|
| SMS | Carrier (via Sent) | Sender phone / short code + TCR campaign ID | the profile's SMS sender |
| WhatsApp | Meta | WABA ID + `phone_number_id` | the profile's WhatsApp sender |
| RCS | Google RBM (via Sent) | `agentId` | the profile's RCS sender |

Whatever you use to look these up — cache, store, or service — the contract is the same: resolve the routing key, find the Sender Profile, enqueue per profile, ACK the webhook fast. Synchronous business logic in the webhook handler kills throughput because all three platforms retry on slow / 5xx responses (Meta times out around 15s, Google around 10s, carriers vary).

Two failure modes to design out:

- **Cold routing key.** A webhook arrives for a phone number, `phone_number_id`, or `agentId` that doesn't map to a known profile yet (the tenant added a number in Meta Business Manager out-of-band, or a TCR campaign moved between brands). Log, return 200, alert ops — don't drop the event.
- **Slow routing-key lookup.** If lookups go to cold storage every time, they'll be the bottleneck under spike load. Cache aggressively, but back the cache with a durable store — pods that don't have the cache primed must still resolve correctly.

## Per-Channel Rate-Limit Accounting

Limits exist at three layers on every channel. Track per-channel; bill at the profile.

| Channel | Carrier / platform limit you must respect | Where it comes from |
|---|---|---|
| **SMS** | Campaign TPS per carrier (assigned after TCR vetting) | TCR + carrier reconciliation; periodic re-fetch |
| **SMS** | Daily volume caps imposed by carriers | Carrier-specific; surfaced by Sent |
| **WhatsApp** | Phone-number tier (1K / 10K / 100K / unlimited business-initiated conversations per 24h) | Meta — readable from the phone-number record |
| **WhatsApp** | Cloud API throughput (CPS) | Meta-defined, tier-derived |
| **RCS** | Agent QPS | Google RBM |
| **All** | Your per-profile quota — whatever you actually sell | Your billing layer |

Bill against the Sender Profile, not the tenant — a tenant with three brands gets three meters.

## Channel-Specific Idempotency

Outbound message sends should be idempotent on the tuple `(sender profile, channel, client_message_id)`. Persist the intent to send *before* the upstream call — if the channel API succeeds but your write fails, a retry would otherwise duplicate.

Inbound delivery events are idempotent on different natural keys per channel — coalesce accordingly:

| Channel | Inbound event coalesces on |
|---|---|
| SMS | `(carrier_message_id, status)` |
| WhatsApp | `(wamid, status)` |
| RCS | `(messageId, status)` |

## State Reconciliation (per channel)

Don't rely on webhooks alone. Every channel can silently drift:

- **TCR / SMS** — campaign vetting score updates and carrier-level filtering changes do not always fire webhooks. Reconcile against TCR + carrier APIs on a schedule (daily for healthy campaigns, hourly when state was recently changing).
- **WhatsApp** — phone-number quality rating and messaging tier change without webhooks. Re-fetch every few hours; alert on transitions.
- **RCS** — agent launch state and carrier rollout status update silently. Re-fetch daily for `launched` agents and more often during initial verification rollout.

Track when each channel was last reconciled so dashboards can show how stale each profile is.

## Channel-Specific Anti-Patterns

- **WhatsApp** — Sharing one Meta System User token across multiple Sender Profiles. Token revocation now disables every profile.
- **SMS** — Reusing a TCR campaign across tenants. The campaign vetting score follows whoever the brand says it is — share at your peril.
- **RCS** — Hardcoding the RBM agent into the application instead of attaching it to a Sender Profile. Multi-region or multi-brand tenants will need multiple agents and the code path forks.
- **All** — Synchronous webhook processing. Throughput dies and the platforms retry aggressively.
- **All** — Claiming "data residency" by application-level filtering when the legal commitment is storage-level isolation.

## Tenant Offboarding

When a tenant churns, run the per-channel teardown — not just a state flag:

- **SMS** — deactivate the TCR campaign(s), release the phone number(s) per Sent's release flow.
- **WhatsApp** — unsubscribe your app from the WABA, revoke the System User token.
- **RCS** — unlaunch / suspend the RBM agent.

Then mark the Sender Profile archived. Schedule message-content deletion per your retention policy.
