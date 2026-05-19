<!-- Grounded against references/_inputs/sent-docs-v3-2026-05-19.md (Glossary section). When this file diverges from the snapshot, the snapshot wins. -->

# Sent Glossary

Shared terminology across the Sent skills. When in doubt, link to a term here rather than redefining it in a skill.

Organized alphabetically (A–W). Where a term is owned by an upstream provider (Meta, Google RBM, TCR), that's called out so it's clear which side of the integration the truth lives on.

## Numerals

**10DLC (10-digit long code)** — The standard provisioned A2P SMS sender format in the US. Subject to TCR registration and per-carrier filtering. See `sms-10dlc-registration`.

**24-hour window / Customer service window** — WhatsApp-only. The period after a recipient sends an inbound message during which the business may send freeform replies. After expiry, only templates work.

## A

**Agent (RBM Agent)** — The RCS sender identity, owned by Google RBM. The `agentId` is the routing key for inbound RCS webhooks. See `rcs-agent-onboarding`.

**API Key** — A single UUID passed via the `x-api-key` HTTP header. In v3 the API key alone identifies the account; there is no separate `x-sender-id` header (that's v2 legacy). See `sent`.

**Authentication Message** — A WhatsApp template categorized `AUTHENTICATION` (OTP / one-time-passcode use cases). Has the strictest content rules and the lowest per-conversation price. See `waba-template-author`.

**Available Channels** — Field on the Contact model (`available_channels`), stored as a comma-separated string of channel names (e.g., `sms,whatsapp`). Drives which channels the contact can be reached on. `BUSINESS_007` is returned if you target a channel not listed here.

## B

**Balance (CustomerBalance)** — A customer's prepaid account balance plus its transaction history. `BUSINESS_003` (`Insufficient account balance`) is returned when a send would exceed it.

**Brand** — An organizational entity associated with a Sender Profile, used to structure SMS campaign vetting (the TCR Brand) and to group templates and contacts.

**Brand (TCR)** — The legal entity registered with The Campaign Registry. Distinct from the marketing concept of a brand. See `sms-10dlc-registration`.

**Branded Sender** — An RCS sender that has passed Google's review and shows the verified business name + logo on Android. See `rcs-agent-onboarding`.

**Business Account (WABA)** — Meta's `WhatsApp Business Account` identifier. The Meta object that owns one or more WhatsApp phone numbers and templates. Created during Embedded Signup. See `waba-embedded-signup`.

## C

**Campaign (TCR)** — The specific use case (e.g. "order notifications", "2FA codes") registered against a TCR Brand. Carriers assign throughput and filtering rules per campaign. See `sms-10dlc-registration`.

**Capabilities** — The set of RCS features (rich cards, carousels, suggested actions) that an agent has been approved for. Subset of what RCS supports.

**Carousel Card** — RCS rich content built from up to 10 Rich Cards arranged horizontally. See `rcs-agent-onboarding`.

**Channel** — A delivery method: `sms`, `whatsapp`, or `rcs`. The same Sender Profile can send across any combination of these. Selected per-send via the `channel` array on `POST /v3/messages`; omitting it triggers Unified Messaging Intelligence.

**Channel Provider** — An internal Sent abstraction representing the upstream provider for a channel (e.g., `WhatsappChannelProvider`, `SmsProvider`). Customers don't address providers directly — they target channels and let Sent route.

**Cloud API** — Meta's hosted WhatsApp Business API (the recommended one). Endpoints live at `graph.facebook.com/v{version}/...`. Distinct from the older On-Premises API.

**Contact** — A recipient (phone-number-keyed) belonging to a Customer. Exposes derived fields like `format_e164`, `format_international`, `format_national`, `format_rfc`, `country_code`, `region_code`, `available_channels`, `default_channel`, and `opt_out`.

**Contact ID** — UUID identifier for a Contact.

**Conversation** — Meta's billing primitive for WhatsApp: a 24-hour window between a business and a recipient. Different categories (utility, marketing, authentication) bill differently. SMS and RCS are billed per-segment / per-message, not by conversation.

**Customer / Customer ID** — The primary tenant entity on Sent (a Sent account). Identified by a UUID. A Customer may own multiple Sender Profiles (e.g. one per brand or per region). Sometimes called "Tenant" in skill prose.

## D

**Default Channel** — Per-contact field (`default_channel`) selecting which channel a contact should be reached on when a sender omits the `channel` array. Typically `sms` or `whatsapp`.

**Delivery Status** — The unified per-message status enum: `QUEUED` → `ROUTED` → `SENT` → `DELIVERED` → `READ`, plus `FAILED` (any stage) and `RECEIVED` (inbound). `READ` is WhatsApp + RCS only — SMS has no equivalent. There is no `PAUSED` delivery status; `PAUSED` exists Meta-side for templates but is not surfaced.

## E

**E.164 Format** — International phone number format (`+CCNNNNNNNNNN`, e.g., `+14155552671`). Required for the `to` array on `POST /v3/messages`. `VALIDATION_002` is returned when a number is not in E.164.

**Embedded Signup** — Meta's flow for tenants to connect their WABA to a Tech Provider's app via Facebook Login for Business. See `waba-embedded-signup`.

**Endpoint** — An HTTP entry point on the v3 API (e.g., `POST /v3/messages`, `GET /v3/templates`). Rate limits, idempotency support, and sandbox support are documented per endpoint.

## F

**Fallback Policy** — How a send behaves when a recipient lacks the requested channel. For RCS this usually means falling back to SMS — expressed explicitly as `"channel": ["rcs", "sms"]`.

**FastEndpoints** — The .NET endpoint framework Sent's API is built on. Implementation detail; surfaces in stack traces but not in the public API contract.

**FBL (Facebook Login for Business)** — The OAuth product Embedded Signup is built on. Has its own configuration (`config_id`) per app.

**Formatting (phone number)** — Sent returns each Contact in four formats: `format_e164` (`+1234567890`), `format_international` (`+1 234-567-890`), `format_national` (`(234) 567-890`), and `format_rfc` (`tel:+1-234-567-890`, RFC 3966).

## G

**Granular Scope** — Meta's per-resource OAuth scope. Embedded Signup uses `whatsapp_business_management` and `whatsapp_business_messaging` granular scopes, each scoped to specific WABA IDs.

## I

**InstantiatedPhones** — Sent's internal representation of phone numbers that have been resolved against a customer's provisioned senders (used to determine which sender will originate a message).

## K

**KYC (Know Your Customer)** — Sent's identity-verification gate before a customer can send live traffic. Drives the onboarding state machine (`SIGNED_UP` → `KYC_STARTED` → `WHITELISTED`/`KYC_RESUBMISSION_REQUESTED` → `ONBOARDING_STARTED` → `KYC_COMPLETED` → `MESSAGE_COMPLIANCE_COMPLETED` → activated). Failures surface as `AUTH_006` (KYC not complete) or `AUTH_007` (KYC done, no channel configured).

## L

**Launch / Launched Agent** — The state of an RBM agent that has passed Google's review and is rolling out across carriers. Until launched, an agent only reaches test devices.

## M

**Marketing Message** — A WhatsApp template categorized `MARKETING`. Priced higher than utility and authentication; subject to user-initiated frequency controls.

**MDR (Message Delivery Report)** — Sent's name for the unified per-message status webhook stream across SMS, WhatsApp, and RCS. Each channel's upstream provider (carrier, Meta, Google RBM) uses its own terminology; MDR normalizes them to the Delivery Status enum above. See `messaging-performance-analyzer`.

**Message Activity** — A row in the per-message activity log returned by `GET /v3/messages/{id}/activities`. Each transition (QUEUED → ROUTED → SENT → …) and each FAILED reason is one activity.

**Message Body** — The text content field of a template's body component. SMS body limit: 160 chars/segment (longer splits into segments). WhatsApp body: 1028 chars. RCS body: 1028 chars.

**Message Template** — See **Template**.

**Messaging Limit Tier** — Per-WhatsApp-phone-number cap on business-initiated conversations per 24h. Tiers: 250 / 1k / 10k / 100k / unlimited.

**Messaging Profile** — Sent's term for an SMS-provider configuration on a Sender Profile, including webhook URLs and delivery settings. Distinct from "Sender Profile" — Messaging Profile is SMS-only and lives *inside* a Sender Profile.

## P

**Pagination** — Standard list endpoints return paginated results. Use `limit` and the provided cursor / page params per endpoint to traverse. Default and max page sizes vary by resource.

**Phone Number ID** — Meta's stable ID for a registered WhatsApp business phone number. The key used to route inbound WhatsApp webhooks back to the right Sender Profile. *Not* the same as the human-readable `display_phone_number`.

**Phone Number Validation** — Sent normalizes every contact phone number to E.164, derives the other format variants, and surfaces `VALIDATION_002` on inputs that can't be parsed.

**Pricing** — Sent charges per-message, with WhatsApp also subject to Meta's per-Conversation pricing tiers (utility / marketing / authentication). SMS and RCS are billed per-segment / per-message, not by conversation.

## Q

**Quality Rating** — Per-WhatsApp-phone-number signal (GREEN / YELLOW / RED) tracked by Meta. Drops trigger throttling and tier downgrades.

## R

**RBM (RCS Business Messaging)** — Google's API and back-office for businesses sending RCS via their agents.

**RCS (Rich Communication Services)** — The carrier-native successor to SMS, supporting rich media, suggested replies, and verified sender branding on Android. On Sent, RCS is not self-service — requires a one-time carrier approval initiated via `support@sent.dm`. Once approved, the RCS Agent appears in the dashboard.

**RCS Agent** — See **Agent (RBM Agent)**. Sent's customer-facing name for the RCS sender after Google approval.

**Region Code** — The ISO 3166-1 alpha-2 country code for a contact (`US`, `CA`, `GB`, …). Exposed as `region_code` on the Contact model.

**Rich Card** — A single rich content unit in RCS (image/title/description/suggestions). Multiple Rich Cards combine into a Carousel Card.

## S

**Sandbox** — Setting `"sandbox": true` on any mutation request validates the request and returns a realistic fake response with no side effects (no provider call, no DB write, no charge). Responses include the `X-Sandbox: true` header. Stacks with `Idempotency-Key`.

**Sender ID** — A per-customer identifier exposed in the dashboard. In v3 API auth, you do **not** send it as a header — `x-api-key` alone identifies the account. The legacy v2 API used `x-sender-id`; v3 does not.

**Sender Profile** — A tenant's sending identity on Sent. One profile unifies the SMS sender (with TCR brand + campaign), the WhatsApp sender (WABA + phone numbers + access token), and the RCS sender (RBM agent + fallback policy) into one record with one API key. The unit of webhook routing, rate-limit accounting, and tenant isolation. Setup statuses: `incomplete`, `pending_review`, `approved`, `rejected`. See `sender-profile-architect`.

**Sent** — The unified messaging platform these skills are written for. Supports SMS, WhatsApp, and RCS through a single API. Base URL: `https://api.sent.dm`.

**SMS (Short Message Service)** — Carrier-delivered text messaging. On Sent in the US it requires 10DLC + TCR registration. Body limit: 160 chars/segment, longer messages split into segments.

**Suggestion Chip** — An RCS interactive element rendered below a message body — quick reply, open URL, or dial number.

**System User** — A non-human Meta user that owns long-lived tokens for production use. Tokens scoped via the System User do not expire on a real user's password change.

**System User Access Token** — The long-lived access token issued to a System User and used to call WhatsApp Cloud API on a WABA's behalf. Sent stores and rotates these on the customer's behalf when a WABA is connected via Embedded Signup.

## T

**TCR (The Campaign Registry)** — The US carrier-mandated registry where businesses register brands and campaigns to send A2P SMS. Vetting score and approval determine campaign throughput. See `sms-10dlc-registration`.

**Tech Provider / Solution Partner** — Meta's BSP-equivalent tiers. Required for revenue-share, hosted billing, and Embedded Signup.

**Template / Message Template** — A pre-approved message structure with optional variables. Required to initiate WhatsApp conversations outside the 24-hour customer-service window. Component support: SMS = body only; RCS + WhatsApp = header, body, footer, buttons.

**Template Category** — One of `AUTHENTICATION`, `MARKETING`, `UTILITY`. Meta's three categories — no others. Determines WhatsApp pricing and review path. See `waba-template-author`.

**Template Status** — One of `PENDING`, `APPROVED`, `REJECTED`. Sent does **not** surface a `PAUSED` status; `PAUSED` exists Meta-side but isn't exposed in v3. `BUSINESS_005` is returned when a send targets a non-`APPROVED` template.

**Tenant** — Informal synonym for **Customer**. See **Customer / Customer ID**.

**Tenant template** — A WhatsApp template that a tenant has authored and submitted through Sent's template-builder UI. See `template-builder-ui`.

**Transaction** — One row in the CustomerBalance ledger (a credit or a debit). Each billable message produces a transaction.

## U

**Unified Messaging Intelligence** — Sent's automatic channel selection: when `POST /v3/messages` is sent without a `channel` array, Sent chooses the optimal channel(s) for each recipient based on `available_channels`, `default_channel`, and cost.

**Utility Message** — A WhatsApp template categorized `UTILITY` (order updates, account notifications, etc.). Priced between authentication (cheapest) and marketing (most expensive). See `waba-template-author`.

**UUID** — RFC 4122 universally unique identifier. The primary key format for every Sent resource (Customer, Contact, Sender Profile, Template, Message, Webhook, User). `VALIDATION_003` is returned when one is malformed.

## V

**Validation** — Synchronous request validation. Failures return `VALIDATION_00x` codes; `error.details` is `{field: [messages]}`.

**Variable Substitution** — Placeholders in a template body / header that are filled at send time. Sent supports both positional (`{{1}}`, `{{2}}`) and named (`{{name}}`, `{{orderNumber}}`) styles. Values come from the `template.parameters` object on `POST /v3/messages`. `ERR_TEMPLATE_PARAMS_INVALID` is returned per-message when required variables are missing or fail regex validation.

**Vetting / Vetting Score** — TCR's external verification of a Brand. Higher scores unlock more throughput. See `sms-10dlc-registration`.

## W

**WABA** — See **Business Account (WABA)**.

**`wamid`** — Meta's globally unique ID for an individual WhatsApp message. The join key for all WhatsApp message-status webhooks.

**Webhook** — A customer-registered HTTP endpoint Sent posts events to. Configured per-event-type (`message`, `templates`, …) with optional `event_filters` to narrow sub-types (e.g., `{"message": ["delivered", "failed"]}`). Has a `signing_secret` for signature verification, configurable `retry_count` (1–5) and `timeout_seconds` (5–120), and tracked health fields (`consecutive_failures`, `last_successful_delivery_at`). Sub-types follow `<field>.<event>` (e.g., `message.delivered`, `message.failed`, `message.read`).

**WhatsApp Business API** — Meta's API surface for businesses to send WhatsApp messages. Sent integrates via the **Cloud API** flavor (`graph.facebook.com/v{version}/...`).

**WhatsApp Template** — A WhatsApp **Template** in particular (i.e., one whose channel set includes `whatsapp`). Subject to Meta's category review and the Sent template lifecycle (`PENDING` → `APPROVED` / `REJECTED`).

## X

**X-Hub-Signature-256** — The HMAC-SHA256 header Meta uses to sign webhook payloads. Computed with your app secret. Always verify.
