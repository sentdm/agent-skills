# Sent Glossary

Shared terminology across the Sent skills. When in doubt, link to a term here rather than redefining it in a skill.

## Sent Concepts

**Sent** — The unified messaging platform these skills are written for. Supports SMS, WhatsApp, and RCS through a single API.

**Sender Profile** — A tenant's sending identity on Sent. One profile unifies the SMS sender (with TCR brand + campaign), the WhatsApp sender (WABA + phone numbers + access token), and the RCS sender (RBM agent + fallback policy) into one record with one API key. The unit of webhook routing, rate-limit accounting, and tenant isolation. See `sender-profile-architect`.

**Tenant / Customer** — A customer of Sent. A tenant may own multiple Sender Profiles (e.g. one per brand or per region).

**Tenant template** — A WhatsApp template that a tenant has authored and submitted through Sent's template-builder UI. See `template-builder-ui`.

**Channel** — A delivery method: SMS, WhatsApp, or RCS. The same Sender Profile can send across any combination of these.

**Brand** — An organizational entity associated with a Sender Profile, used to structure SMS campaign vetting (the TCR Brand) and to group templates and contacts.

**Messaging Profile** — Sent's term for an SMS-provider configuration on a Sender Profile, including webhook URLs and delivery settings. Distinct from "Sender Profile" — Messaging Profile is SMS-only and lives *inside* a Sender Profile.

## Cross-channel Terms

**MDR (Message Delivery Report)** — Sent's name for the unified per-message status webhook stream across SMS, WhatsApp, and RCS. Each channel's upstream provider (carrier, Meta, Google RBM) uses its own terminology; MDR normalizes them. See `messaging-performance-analyzer`.

**Conversation** — Meta's billing primitive for WhatsApp: a 24-hour window between a business and a recipient. Different categories (utility, marketing, authentication) bill differently. SMS and RCS are billed per-segment / per-message, not by conversation.

**24-hour window / Customer service window** — WhatsApp-only. The period after a recipient sends an inbound message during which the business may send freeform replies. After expiry, only templates work.

## SMS / 10DLC Terms

**10DLC (10-digit long code)** — The standard provisioned A2P SMS sender format in the US. Subject to TCR registration and per-carrier filtering.

**TCR (The Campaign Registry)** — The US carrier-mandated registry where businesses register brands and campaigns to send A2P SMS. Vetting score and approval determine campaign throughput.

**Brand (TCR)** — The legal entity registered with TCR. Distinct from the marketing concept of a brand.

**Campaign (TCR)** — The specific use case (e.g. "order notifications", "2FA codes") registered against a TCR Brand. Carriers assign throughput and filtering rules per campaign.

**Vetting / Vetting Score** — TCR's external verification of a Brand. Higher scores unlock more throughput.

## WhatsApp / Meta Terms

**WABA (WhatsApp Business Account)** — The Meta object that owns one or more phone numbers and templates. Created during Embedded Signup.

**Phone Number ID** — Meta's stable ID for a registered WhatsApp business phone number. The key used to route inbound WhatsApp webhooks back to the right Sender Profile. *Not* the same as the human-readable `display_phone_number`.

**Cloud API** — Meta's hosted WhatsApp Business API (the recommended one). Endpoints live at `graph.facebook.com/v{version}/...`. Distinct from the older On-Premises API.

**Template / Message Template** — A pre-approved message structure with optional variables. Required to initiate WhatsApp conversations outside the 24-hour customer-service window.

**`wamid`** — Meta's globally unique ID for an individual WhatsApp message. The join key for all WhatsApp message-status webhooks.

**Embedded Signup** — Meta's flow for tenants to connect their WABA to a Tech Provider's app via Facebook Login for Business. See `waba-embedded-signup`.

**FBL (Facebook Login for Business)** — The OAuth product Embedded Signup is built on. Has its own configuration (`config_id`) per app.

**System User** — A non-human Meta user that owns long-lived tokens for production use. Tokens scoped via the System User do not expire on a real user's password change.

**Tech Provider / Solution Partner** — Meta's BSP-equivalent tiers. Required for revenue-share, hosted billing, and Embedded Signup.

**Template Categories** — Utility, Marketing, Authentication. Determine WhatsApp pricing and review path. See `waba-template-author`.

**Messaging Limit Tier** — Per-WhatsApp-phone-number cap on business-initiated conversations per 24h. Tiers: 250 / 1k / 10k / 100k / unlimited.

**Quality Rating** — Per-WhatsApp-phone-number signal (GREEN / YELLOW / RED) tracked by Meta. Drops trigger throttling and tier downgrades.

**Granular Scope** — Meta's per-resource OAuth scope. Embedded Signup uses `whatsapp_business_management` and `whatsapp_business_messaging` granular scopes, each scoped to specific WABA IDs.

**X-Hub-Signature-256** — The HMAC-SHA256 header Meta uses to sign webhook payloads. Computed with your app secret. Always verify.

## RCS / Google RBM Terms

**RCS (Rich Communication Services)** — The carrier-native successor to SMS, supporting rich media, suggested replies, and verified sender branding on Android.

**RBM (RCS Business Messaging)** — Google's API and back-office for businesses sending RCS via their agents.

**Agent (RBM Agent)** — The RCS sender identity, owned by Google RBM. The `agentId` is the routing key for inbound RCS webhooks.

**Launch / Launched Agent** — The state of an RBM agent that has passed Google's review and is rolling out across carriers. Until launched, an agent only reaches test devices.

**Fallback Policy** — How a Sender Profile behaves when a recipient lacks RCS capability. Common choices: fall back to SMS, fall back to nothing, surface to the application for routing.

**Capabilities** — The set of RCS features (rich cards, carousels, suggested actions) that an agent has been approved for. Subset of what RCS supports.
