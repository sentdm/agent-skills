# Multi-Tenancy Patterns for WABA Apps — Reference

Supporting reference for `sender-profile-architect`. Patterns for isolation,
data modeling, and operational concerns specific to WhatsApp Business API
platforms.

## Three Models

### Pooled

One database, one set of services. Every tenant-scoped row carries `tenant_id`
and `sps_id`. Queries are gated by an app-layer or DB-layer policy (RLS, view,
or middleware) that enforces the tenant boundary.

**Strengths**
- Low per-tenant cost (good for SaaS economics)
- Instant onboarding — new tenant is a row, not infra
- Single migration / deploy / monitoring story

**Weaknesses**
- Blast radius: a bad query or a leaked key affects all tenants
- Noisy neighbor: one tenant's traffic burst impacts everyone
- Data residency / compliance is harder to claim

**When to choose:** default. Especially for SMB and mid-market tenants.

### Siloed

Per-tenant database or schema, possibly per-tenant compute. The tenant boundary
is the database boundary.

**Strengths**
- Strong isolation; data residency / compliance is easy to claim
- Noisy neighbor mitigated
- Per-tenant migrations possible (rare upside in practice)

**Weaknesses**
- High operational cost — N databases to back up, patch, upgrade
- Onboarding requires provisioning
- Cross-tenant analytics is now a pipeline problem

**When to choose:** enterprise tenants who are paying for it, or regulated
verticals (healthcare, government) where you've committed to data isolation.

### Hybrid (recommended for most platforms)

Pooled compute, pooled SPS metadata, **siloed message-content storage** for
tenants that pay for it or where the data is sensitive. The SPS table is the
join point — `sps.storage_partition` points at the right storage backend.

**Strengths**
- Cheap default with an upsell path for isolation
- Compliance story is plausible without N databases
- Single application, multiple storage backends — possible if abstracted early

**Cost:** the abstraction. You must commit to a storage interface that
supports both partitions on day one. Retrofitting is painful.

## The SPS Schema (sketch)

```sql
CREATE TABLE tenants (
  id           uuid PRIMARY KEY,
  name         text NOT NULL,
  plan         text NOT NULL,
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE sender_profiles (
  id                  uuid PRIMARY KEY,
  tenant_id           uuid NOT NULL REFERENCES tenants(id),
  display_name        text NOT NULL,
  meta_business_id    text,
  waba_id             text UNIQUE,            -- one WABA per SPS
  access_token        bytea,                  -- encrypted
  state               text NOT NULL,          -- enum: provisioned, connecting, ...
  state_updated_at    timestamptz NOT NULL DEFAULT now(),
  last_meta_sync_at   timestamptz,
  storage_partition   text NOT NULL DEFAULT 'default',
  created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE phone_numbers (
  id                    uuid PRIMARY KEY,
  sps_id                uuid NOT NULL REFERENCES sender_profiles(id),
  phone_number_id       text UNIQUE NOT NULL,   -- Meta's ID, the webhook key
  display_phone_number  text NOT NULL,
  verified_name         text,
  quality_rating        text,
  messaging_limit_tier  text,
  registration_pin      bytea,                  -- encrypted
  created_at            timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_phone_numbers_phone_number_id ON phone_numbers (phone_number_id);
CREATE INDEX idx_sender_profiles_tenant ON sender_profiles (tenant_id);
```

Notes:
- `waba_id` is unique — one SPS per WABA. Multiple phone numbers per WABA are
  the `phone_numbers` table.
- `phone_number_id` is the lookup key for webhook routing.
- Tokens and PINs are encrypted at rest, ideally with envelope encryption
  (per-tenant DEK wrapped by a KMS-managed KEK).

## Webhook Routing (the hot path)

```
1. POST /webhooks/whatsapp
2. Verify X-Hub-Signature-256 against app secret
3. Parse payload → extract entry[0].changes[0].value.metadata.phone_number_id
4. Lookup: SELECT sps_id, tenant_id FROM phone_numbers WHERE phone_number_id = $1
   (or Redis cache)
5. Enqueue: queue.publish(`sps.${sps_id}`, payload)
6. Return 200 within ~1s
```

Two failure modes to design out:
- **Cold lookup**: a webhook arrives for a `phone_number_id` you've never seen
  (e.g. tenant added a number in Meta Business Manager, not via your UI). Log,
  return 200, alert ops — don't drop.
- **Slow lookup**: DB latency spikes block ACK. Always have a Redis or
  in-process LRU cache backed by the DB.

## Rate-Limit Accounting

| Layer | What's metered | Where to enforce |
|---|---|---|
| Meta phone-number tier (1k/10k/100k/unlimited per 24h) | Business-initiated conversations | Read from Meta API; persist on `phone_numbers.messaging_limit_tier`; alert at 80% |
| Meta throughput (CPS) | Messages per second per phone | Token bucket per `phone_number_id`, sized to the tier |
| Your per-tenant or per-SPS quota | Whatever you sell (messages/month, AI calls, etc.) | Token bucket per `sps_id`, persisted in Redis with periodic snapshot |

Bill per SPS, not per tenant. A tenant with two SPSes has two meters.

## Idempotency

Outbound message sends should be idempotent on `(sps_id, client_message_id)`.
Persist this row before calling Meta — if the Meta call succeeds and your DB
write fails, the next send retry would otherwise duplicate.

Inbound webhook events are idempotent on `wamid + status` — the same status
event can arrive multiple times due to Meta retries. Use an upsert keyed on
`(wamid, status)` for the message-events table.

## Operational Patterns

- **State reconciliation job** — every N minutes, sample SPSes whose
  `last_meta_sync_at` is stale and refresh state from Meta. Don't rely on
  webhooks alone.
- **Token rotation** — for System User tokens, rotate on a schedule (90 days)
  via the Meta API. Persist the new token before discarding the old one.
- **Tenant offboarding** — when a tenant churns, set their SPSes to a
  `archived` state, unsubscribe the app from their WABA, and schedule
  data deletion per your retention policy.

## Anti-Patterns to Avoid

- Keying messages by `tenant_id` only (lose the SPS dimension)
- Storing tokens unencrypted because "it's just an internal DB"
- Synchronous webhook processing (kills throughput at scale)
- Sharing one System User token across SPSes (revocation now affects all of them)
- Computing tenant data residency by application-level filtering when the
  legal commitment is database-level isolation
