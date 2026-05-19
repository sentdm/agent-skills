# Sent Glossary

Shared terminology across the Sent skills. When in doubt, link to a term here
rather than redefining it in a skill.

## Sent-specific Terms

**Sent** — The WhatsApp Business platform these skills are written for.

**Sender Profile (SPS)** — Sent's per-tenant abstraction over a WhatsApp
Business Account (WABA). One SPS owns one WABA, one or more phone numbers, and
the Meta access token. SPS is the unit of webhook routing, rate-limit
accounting, and tenant isolation. See `sender-profile-architect`.

**Tenant** — A customer of Sent. A tenant may own multiple SPSes (e.g. one
per brand or per region).

**Tenant template** — A WhatsApp template that a tenant has authored and
submitted through Sent's template-builder UI. See `template-builder-ui`.

## Meta / WhatsApp Terms

**WABA (WhatsApp Business Account)** — The Meta object that owns one or more
phone numbers and templates. Created during Embedded Signup.

**Phone Number ID** — Meta's stable ID for a registered phone number. The key
used to route inbound webhooks back to the right SPS. *Not* the same as the
human-readable `display_phone_number`.

**Cloud API** — Meta's hosted WhatsApp Business API (the recommended one).
Endpoints live at `graph.facebook.com/v{version}/...`. Distinct from the older
On-Premises API.

**Template / Message Template** — A pre-approved message structure with
optional variables. Required to initiate conversations outside the 24-hour
customer-service window.

**Conversation** — Meta's billing primitive: a 24-hour window between a
business and a recipient. Different categories (utility, marketing,
authentication) bill differently.

**24-hour window / Customer service window** — The period after a recipient
sends an inbound message during which the business may send freeform replies.
After expiry, only templates work.

**MDR (Message Delivery Report)** — The webhook stream of per-message status
updates Meta sends as messages move through sent → delivered → read → replied.
See `messaging-performance-analyzer`.

**`wamid`** — Meta's globally unique ID for an individual message. The join
key for all message-status webhooks.

**Embedded Signup** — Meta's flow for tenants to connect their WABA to a
Tech Provider's app via Facebook Login for Business. See `waba-embedded-signup`.

**FBL (Facebook Login for Business)** — The OAuth product Embedded Signup is
built on. Has its own configuration (`config_id`) per app.

**System User** — A non-human Meta user that owns long-lived tokens for
production use. Tokens scoped via the System User do not expire on a real
user's password change.

**Tech Provider / Solution Partner** — Meta's BSP-equivalent tiers. Required
for revenue-share, hosted billing, and Embedded Signup.

**Template Categories** — Utility, Marketing, Authentication. Determine
pricing and review path. See `waba-template-author`.

**Messaging Limit Tier** — Per-phone-number cap on business-initiated
conversations per 24h. Tiers: 250 / 1k / 10k / 100k / unlimited.

**Quality Rating** — Per-phone-number signal (GREEN / YELLOW / RED) tracked
by Meta. Drops trigger throttling and tier downgrades.

**Granular Scope** — Meta's per-resource OAuth scope. Embedded Signup uses
`whatsapp_business_management` and `whatsapp_business_messaging` granular
scopes, each scoped to specific WABA IDs.

**X-Hub-Signature-256** — The HMAC-SHA256 header Meta uses to sign webhook
payloads. Computed with your app secret. Always verify.
