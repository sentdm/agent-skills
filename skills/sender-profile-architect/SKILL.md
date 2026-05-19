---
name: sender-profile-architect
description: Designs Sent Sender Profile architecture for multi-tenant, multi-brand, or multi-channel messaging systems, including profile boundaries, profile-scoped credentials, webhooks, compliance inheritance, and channel readiness. Use when a user says sender profile, x-sender-id, profile setup, multi-tenant messaging, brand isolation, department sender, webhook routing, tenant offboarding, or asks how to model SMS, WhatsApp, and RCS senders in Sent.
---

<!--
Verified against Sent sources:
- https://docs.sent.dm/start/quickstart/dashboard-walkthrough
- https://docs.sent.dm/start/quickstart/channel-setup
- https://docs.sent.dm/reference/api
- Sent v3 OpenAPI: /v3/profiles, /v3/profiles/{profileId}, /v3/profiles/{profileId}/complete, /v3/brands, /v3/brands/{brandId}/campaigns, /v3/webhooks, /v3/webhooks/{id}/events, /v3/webhooks/{id}/test, /v3/webhooks/{id}/rotate-secret

Review notes:
- Sent dashboard docs verify Sender Profiles, display name, brand description, x-sender-id, and channel configuration status.
- Sent v3 OpenAPI verifies profile CRUD and profile completion. It does not prove a strict one-API-key-per-profile model, so this skill uses “profile-scoped credentials” rather than stronger claims.
- Treat routing-key tables, tenant state machines, and webhook correlation strategies as application architecture guidance unless a field is present in Sent responses/events.
-->

# Sender profile architect

## Overview

Use this skill to decide how a customer should map brands, tenants, departments, and channels onto Sent Sender Profiles. A Sender Profile is the durable boundary for sender identity and channel configuration. The Sent dashboard shows each profile with display name, brand description, `x-sender-id`, and SMS/WhatsApp configuration status. The v3 API exposes profile creation, listing, retrieval, update, deletion, and completion.

Good profile architecture prevents three recurring failures: messages sent from the wrong brand, compliance resources shared across incompatible use cases, and webhook/event data that cannot be routed back to the correct tenant.

## When to use

Use this skill when the user asks how to create Sender Profiles, split one customer into multiple senders, model a marketplace or ISV, isolate brands, route webhooks, handle profile-scoped API credentials, complete profile setup, or safely offboard a tenant. Use it whenever the request mentions `x-sender-id`, Sender Profile, profile completion, multi-tenant messaging, brand hierarchy, SMS/WhatsApp/RCS sender setup, or webhook routing.

Do not use this skill to decide 10DLC use cases in detail, write WhatsApp template copy, onboard RCS approval, or analyze delivery failures. Hand those to the related skills once the profile boundary is clear.

## Profile boundary principle

Create a separate Sender Profile when the sender identity, compliance evidence, webhook routing, operational ownership, or channel readiness must be isolated. Reuse a profile when the same legal/brand identity sends the same class of traffic and should share compliance posture and operational controls.

| Split signal | Create separate profiles when | Reuse a profile when |
|---|---|---|
| Brand identity | The recipient sees different brand names or support contacts. | The recipient sees one brand across all messages. |
| Compliance | 10DLC brand/campaign, opt-in source, or use case differs materially. | Compliance evidence and use case are the same. |
| Channel configuration | SMS, WhatsApp, or RCS resources belong to different brands or regions. | Channels represent one sender identity. |
| Webhook routing | Events must land in different tenant queues or data stores. | One team owns all events and reconciliation. |
| Lifecycle | One sender may be paused, restricted, or offboarded independently. | Senders always launch, pause, and retire together. |

## Process

### 1. Draw the recipient-visible sender model

Start with what the recipient sees, not with internal account hierarchy. Ask: “Would the recipient reasonably think these messages came from the same sender?” If the answer is no, use separate profiles.

**Example.** A healthcare ISV serves three clinic chains. Each chain has its own patient-facing brand, privacy policy, and support phone. Create one profile per clinic chain. Do not put all clinics behind a single ISV profile just because the same platform sends the messages.

### 2. Map each profile to channel readiness

For each proposed profile, list SMS, WhatsApp, and RCS readiness separately. Sent’s channel setup guidance covers production setup for all three channels and recommends using the same phone number across SMS, WhatsApp, and RCS where possible. That recommendation does not override compliance or brand isolation.

| Channel | Profile-level questions | Follow-up skill |
|---|---|---|
| SMS | Is US A2P involved? Which brand/campaign and opt-in evidence apply? | `sms-10dlc-registration` |
| WhatsApp | Which WABA/phone number identity maps to this brand? Are templates approved? | `waba-embedded-signup`, `waba-template-author` |
| RCS | Has Sent initiated setup and carrier approval for this profile? Is SMS fallback ready? | `rcs-agent-onboarding` |

### 3. Create or update the Sent profile

Use Sent’s profile API where API access is appropriate, or the dashboard when the user is operating manually. The verified v3 API includes:

| Operation | Endpoint | Use |
|---|---|---|
| Create profile | `POST /v3/profiles` | Create a sender boundary for a brand, department, tenant, or use case. |
| List profiles | `GET /v3/profiles` | Audit existing profile boundaries before creating duplicates. |
| Retrieve profile | `GET /v3/profiles/{profileId}` | Inspect detailed profile configuration. |
| Update profile | `PATCH /v3/profiles/{profileId}` | Change profile configuration/settings. |
| Delete profile | `DELETE /v3/profiles/{profileId}` | Soft-delete a profile after traffic, webhooks, and credentials are drained. |
| Complete setup | `POST /v3/profiles/{profileId}/complete` | Validate prerequisites and start the profile completion workflow. |

Use idempotency keys on create/update/complete calls when the integration might retry. The OpenAPI exposes an optional `Idempotency-Key` header for those operations.

### 4. Attach compliance and channel prerequisites before completion

The profile completion endpoint validates prerequisites such as profile data, brand, campaigns, and channel connections. For US A2P SMS, create or attach Sent brand and campaign resources before completing the profile. The verified brand/campaign endpoints are `/v3/brands` and `/v3/brands/{brandId}/campaigns`.

Do not invent field names such as `tcr_brand_id` or `waba_phone_id` unless the actual API response includes them. Store Sent IDs returned by the API and any returned provider identifiers separately, with clear names.

**Example data model.**

```text
sender_profiles
- sent_profile_id
- x_sender_id
- display_name
- brand_description
- status_app_level
- sms_ready_app_level
- whatsapp_ready_app_level
- rcs_ready_app_level

sender_profile_resources
- sent_profile_id
- channel
- sent_resource_id
- provider_resource_type
- provider_resource_id
- status_last_seen_at
```

### 5. Design webhook routing around Sent event evidence

Sent’s v3 webhook API supports creating/listing webhooks, retrieving event types, viewing webhook events, testing a webhook, toggling status, and rotating signing secrets. Use those endpoints to verify configuration and delivery before blaming channel infrastructure.

Route inbound events by stable identifiers present in the Sent payload. If the exact event payload fields are not documented for the customer’s account, log full events in a secure staging environment and derive the routing map from observed Sent fields rather than assumed provider keys.

**Example.** If a marketplace needs tenant-specific queues, route first by Sent profile or sender identifier if present in the event. Fall back to a mapping table from Sent message ID to tenant/profile created at send time. Avoid making provider IDs the only routing key.

### 6. Model profile lifecycle as an application state machine

Sent exposes profile APIs and completion behavior, but your application may need richer internal states. Label them as application states so future agents do not mistake them for Sent enums.

| Application state | Meaning | Exit condition |
|---|---|---|
| `draft` | Profile data is being collected. | Required identity and owner fields are present. |
| `compliance_pending` | Brand/campaign/channel evidence is being prepared. | Required compliance resources exist or have been submitted. |
| `completion_started` | `/v3/profiles/{profileId}/complete` returned accepted/started behavior. | Webhook/callback or follow-up status indicates completion result. |
| `active` | Profile is approved for intended channels. | Traffic is allowed and test sends pass. |
| `restricted` | One or more channels is blocked, paused, or missing approval. | Root cause resolved and profile retested. |
| `retiring` | Sends are drained and webhooks/credentials are being removed. | No active sends, subscriptions, or credentials remain. |

### 7. Plan tenant offboarding before the first send

Offboarding is easiest when profile boundaries are clean. To retire a profile, stop new sends, drain in-flight messages, export relevant message/activity evidence, disable or reroute webhooks, revoke or rotate credentials, delete/soft-delete the profile when safe, and retain compliance records according to the customer’s policy.

## Common rationalizations to avoid

Do not use one profile for every tenant just because it is easy. Over-splitting creates unnecessary compliance and operational work.

Do not use one shared profile for distinct recipient-visible brands. Under-splitting creates wrong-sender and compliance-contamination failures.

Do not treat internal tenant ID as a substitute for Sender Profile ID. The application can map tenant ID to profile ID, but outbound sends and webhook reconciliation need Sent identifiers.

Do not hardcode provider identifiers as routing keys before verifying Sent webhook payloads. Sent’s event shape is the integration contract.

Do not rotate webhook secrets casually. Secret rotation immediately invalidates the old secret, so coordinate with the receiving endpoint.

## Verification checklist

- [ ] Each proposed profile has a recipient-visible rationale.
- [ ] SMS, WhatsApp, and RCS readiness are tracked separately per profile.
- [ ] US A2P SMS profiles have brand/campaign work routed to compliance before completion.
- [ ] The implementation stores Sent profile IDs and any provider IDs as separate fields.
- [ ] Profile creation/update/complete calls use idempotency keys where retries are possible.
- [ ] Webhook routing is based on Sent event fields or a send-time Sent message ID mapping.
- [ ] Application lifecycle states are not presented as Sent API enum values.
- [ ] Offboarding drains sends, webhooks, credentials, and retained evidence.

## Related skills

Use `sent-skills:sms-10dlc-registration` when a profile needs US A2P SMS brand/campaign registration, opt-in review, or 10DLC troubleshooting.

Use `sent-skills:waba-embedded-signup` when the architecture includes WhatsApp WABA/phone-number connection or Embedded Signup.

Use `sent-skills:rcs-agent-onboarding` when the profile needs RCS approval, launch evidence, or fallback design.

Use `sent-skills:template-builder-ui` when the architecture decision depends on reusable cross-channel template lifecycle.

Use `sent-skills:messaging-performance-analyzer` after launch when webhook, delivery, or activity evidence shows a performance issue.

See the top-level `references/sent-glossary.md` for shared Sent terminology.

## Suggested bundled references and scripts

| File | Type | Purpose |
|---|---|---|
| `references/multi-tenancy-patterns.md` | Architecture reference | Keep detailed routing, rate-limit, idempotency, and offboarding patterns outside the skill body. |
| `references/sender-profile-data-model.md` | Schema reference | Provide recommended application tables and mapping fields for Sent profile integrations. |
| `references/profile-boundary-examples.md` | Worked examples | Show ISV, marketplace, multi-brand enterprise, and department-level profile splits. |
| `scripts/audit_sender_profiles.py` | Validation script | Compare expected tenant/profile/channel mappings against exported Sent profile and webhook data. |

## Unverified claims to confirm or remove

- A strict one-API-key-per-profile model was not verified; use “profile-scoped credentials” unless confirmed.
- Exact Sent webhook event payload routing fields were not verified in the extracted OpenAPI details.
- Profile states such as `partially_active`, `restricted`, or `restoring` are application-level labels unless Sent returns them.
- Provider-specific routing keys for WhatsApp/RCS/SMS should not be required unless observed in Sent event payloads or docs.
