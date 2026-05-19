---
name: messaging-performance-analyzer
description: Analyzes Sent message delivery, webhook, and activity data to explain funnel drop-offs, delivery failures, read-rate gaps, channel fallback, and suspicious performance changes. Use when a user says MDR, delivery report, message activity, webhook event, failed messages, low delivery rate, RCS fallback, WhatsApp read rate, SMS filtering, campaign performance, or asks why messages did not arrive.
---

<!--
Verified against Sent sources:
- https://docs.sent.dm/start/quickstart/first-message
- https://docs.sent.dm/reference/api
- Sent v3 OpenAPI: POST /v3/messages, GET /v3/messages/{id}, GET /v3/messages/{id}/activities, /v3/webhooks, /v3/webhooks/event-types, /v3/webhooks/{id}/events, /v3/webhooks/{id}/test

Review notes:
- Sent docs verify the lifecycle QUEUED → ROUTED → SENT → DELIVERED, with READ for WhatsApp and RCS.
- Treat provider-level error-code dictionaries and MDR-normalized buckets as reference material unless the specific field appears in Sent message, activity, webhook, or exported log data.
-->

# Messaging performance analyzer

## Overview

Use this skill to turn raw Sent message evidence into a concise diagnosis of what changed, where the funnel leaks, and what to fix first. Anchor every analysis to **Sent message IDs**, **message status**, **message activities**, and **webhook events** before interpreting carrier, WhatsApp, or RCS provider codes.

Sent’s v3 send endpoint accepts a template-based request and returns per-recipient `message_id` values for asynchronous tracking. Status is retrieved with `GET /v3/messages/{id}`, and detailed lifecycle evidence is retrieved with `GET /v3/messages/{id}/activities`. Webhook endpoints support event ingestion, event-type discovery, event history, test delivery, and secret rotation.

## When to use

Use this skill when the user asks why messages failed, why delivery or read rate dropped, whether fallback is working, whether a provider is filtering traffic, or how a campaign performed. Trigger on words such as “MDR,” “delivery report,” “webhook event,” “activities,” “status,” “failed,” “undelivered,” “read rate,” “fallback,” “filtering,” “throttling,” or “carrier reject.”

Do not use this skill to register 10DLC, design a Sender Profile, onboard RCS, or author WhatsApp templates. Hand those workflows to the related skills after the performance symptom is isolated.

## Evidence hierarchy

Start with Sent-owned evidence, then enrich it with provider context. This prevents overfitting to a carrier code that may be missing, stale, or normalized differently across channels.

| Evidence | Sent-verified path | Use it for |
|---|---|---|
| Send response | `POST /v3/messages` | Identify request ID, accepted recipients, channel fan-out, and Sent `message_id` values. |
| Current status | `GET /v3/messages/{id}` | Confirm the latest known lifecycle status and any error details exposed by the API. |
| Activity timeline | `GET /v3/messages/{id}/activities` | Reconstruct acceptance, routing, sending, delivery, read, and error transitions. |
| Webhook configuration | `GET /v3/webhooks`, `GET /v3/webhooks/event-types` | Confirm whether the customer subscribed to the events needed for analysis. |
| Webhook event history | `GET /v3/webhooks/{id}/events` | Compare delivered events against API status and customer ingestion logs. |
| Webhook connectivity | `POST /v3/webhooks/{id}/test` | Verify endpoint reachability before blaming delivery infrastructure. |

## Process

### 1. Pin the question before slicing the funnel

Restate the user’s exact question as a measurable comparison. “WhatsApp is bad” becomes “Did WhatsApp `DELIVERED` rate fall for order templates sent from profile A between Monday and Wednesday?” A precise question keeps the cohort stable and prevents mixed-channel averages from hiding the failure mode.

Capture these dimensions before calculating anything: profile or sender identity, template ID/name, channel, country, send window, recipient segment, and whether fallback or multi-channel broadcast was requested.

**Example.** If a user says “RCS fallback stopped working,” define the cohort as messages sent with `channel: ["rcs", "sms"]` during the affected window, then compare RCS statuses, SMS fallback statuses, and duplicate recipient/channel pairs separately.

### 2. Build cohorts from Sent message IDs

Use Sent `message_id` as the primary unit. A v3 send can create separate messages for each recipient and channel pair when multiple channels are specified. Count each Sent message once at its latest status, then add recipient-level or campaign-level rollups only after deduplication.

Do not use provider IDs such as WhatsApp `wamid`, SMS carrier IDs, or RCS message IDs as the primary join key unless the exported evidence lacks Sent IDs. Provider IDs are useful for escalation, but the Sent API and dashboard track status by Sent message ID.

### 3. Normalize lifecycle stages to Sent’s documented statuses

Use Sent’s documented lifecycle as the first-pass funnel: `QUEUED`, `ROUTED`, `SENT`, `DELIVERED`, and `READ` for WhatsApp and RCS. Keep failed and error states in a separate terminal bucket using the exact status/error fields present in the evidence.

| Stage | Interpretation | Common diagnostic question |
|---|---|---|
| `QUEUED` | Sent accepted the request for processing. | Is the backlog growing or did the request never route? |
| `ROUTED` | Sent selected a channel/provider path. | Did routing choose the expected channel or fallback path? |
| `SENT` | The message left Sent/provider processing toward the destination network. | Are provider accepts high but downstream delivery low? |
| `DELIVERED` | Delivery was confirmed where supported. | Did the destination network confirm receipt? |
| `READ` | WhatsApp/RCS read receipt was observed where available. | Did users open the message after delivery? |
| Error/failure | A terminal or recoverable error occurred. | Is the root cause compliance, payload, throughput, opt-out, or provider outage? |

### 4. Check webhook health before diagnosing delivery

A drop in dashboard activity or customer-side events can be a webhook ingestion problem, not a delivery problem. Confirm webhook existence, active status, event subscriptions, recent event history, and test delivery. Rotate secrets only when the user explicitly asks or when a credential compromise is suspected, because rotation immediately invalidates the old secret.

**Example.** If Sent status shows `DELIVERED` but the customer database shows “no delivery callbacks,” inspect `/v3/webhooks/{id}/events` and the customer’s endpoint logs. If Sent has events but the endpoint returned failures, the fix is webhook handling, not campaign routing.

### 5. Split by channel before naming a root cause

SMS, WhatsApp, and RCS fail differently. Do not average them together unless the user explicitly asked for a blended KPI. Compare each channel’s funnel and then compare the aggregate.

| Channel | First cuts | Typical next evidence |
|---|---|---|
| SMS | Country, sender/profile, 10DLC campaign, opt-out, carrier family | Compliance status, brand/campaign readiness, opt-out logs, throughput patterns. |
| WhatsApp | Template, language, category, recipient country, quality/tier symptoms | Template status, read receipts, conversation window, Meta-side errors if present. |
| RCS | Agent readiness, fallback behavior, capability gaps, rich content rendering | Sent RCS setup status, fallback SMS results, capability/error details if present. |

### 6. Quantify impact before recommending fixes

Report raw counts and rates together. A 40% failure rate over 15 messages is a different decision than a 4% failure rate over 150,000 messages. Include exclusions such as pending messages, test traffic, sandbox sends, retries, and duplicate channel fan-out.

A practical analysis table should include: sent count, latest status distribution, failure count, failure-rate delta versus baseline, top exact error strings/codes, first observed timestamp, affected templates, affected countries, and affected profiles.

### 7. Convert the diagnosis into the next action

End with one primary diagnosis, one confidence level, and the next verification step. Avoid long lists of generic fixes. Tie every recommendation to observed evidence.

**Example.** “The largest leak is after `ROUTED` for SMS traffic on profile `support-us`, starting at 14:10 UTC. WhatsApp and RCS cohorts are stable. The affected traffic uses the same order-update template and a US A2P route. Verify the Sent brand/campaign status and opt-out handling next; if compliant, escalate the exact message IDs and activity timestamps.”

## Common rationalizations to avoid

Do not infer delivery failure from missing customer-side webhooks until Sent webhook event history and endpoint responses are checked. Webhook ingestion failures often mimic delivery failures.

Do not label a campaign “carrier filtered” from a small sample without comparing baseline, country, sender/profile, and template. Filtering is a conclusion after cohort isolation, not a synonym for “failed.”

Do not treat `READ` as a universal stage. Sent documents read receipts for WhatsApp and RCS; SMS generally does not support read receipts.

Do not collapse RCS fallback into SMS delivery. For `channel: ["rcs", "sms"]`, count RCS attempts and SMS attempts separately, then report recipient-level success if the user asks for it.

## Verification checklist

- [ ] The analysis uses Sent `message_id` values as the primary unit.
- [ ] The cohort is pinned by time window, profile/sender identity, template, channel, and recipient segment.
- [ ] Status math uses the latest known status per Sent message ID.
- [ ] Pending or in-flight messages are either excluded or reported separately.
- [ ] Webhook configuration, event history, and endpoint test results are checked when the symptom is missing callbacks.
- [ ] Channel-specific failures are split before aggregate rates are reported.
- [ ] Provider or carrier codes are quoted exactly as observed and not invented from a lookup table.
- [ ] The final recommendation names one next verification step and the evidence that justifies it.

## Related skills

Use `sent-skills:sms-10dlc-registration` when the leak points to US A2P SMS compliance, brand registration, campaign registration, or opt-in/opt-out evidence.

Use `sent-skills:rcs-agent-onboarding` when the symptom points to RCS agent approval, launch readiness, capability gaps, or fallback design rather than live delivery analytics.

Use `sent-skills:sender-profile-architect` when the issue is tenant/profile isolation, webhook routing, credential scoping, or multi-brand sender design.

Use `sent-skills:waba-template-author` or `sent-skills:template-builder-ui` when the root cause is WhatsApp template category, review status, template payload structure, or authoring workflow.

## Suggested bundled references and scripts

| File | Type | Purpose |
|---|---|---|
| `references/mdr-status-codes.md` | Lookup table | Normalize observed SMS, WhatsApp, and RCS provider errors without putting long code dictionaries in the skill body. |
| `references/performance-diagnosis-playbook.md` | Worked examples | Show full examples for SMS compliance failure, WhatsApp template rejection, RCS fallback, and webhook ingestion failure. |
| `scripts/analyze_sent_message_funnel.py` | Validation script | Load exported message/activity/webhook CSV or JSON, deduplicate by Sent `message_id`, and output stage counts by channel/profile/template. |
| `scripts/compare_webhook_events.py` | Validation script | Compare Sent webhook event exports against customer ingestion logs to distinguish delivery failures from callback failures. |

## Unverified claims to confirm or remove

- The term “MDR” as a public Sent v3 API object or endpoint was not verified in the extracted Sent v3 API reference.
- Exact normalized provider error buckets such as `CARRIER_REJECT_*`, `RCS_QPS_EXCEEDED`, or WhatsApp numeric-code groupings are reference/internal taxonomy unless those exact fields appear in the customer’s Sent activity or webhook payloads.
- Any fixed cohort-size threshold such as “1,000 messages minimum” is an analysis heuristic, not a documented Sent API rule.
- Provider identifiers such as carrier message IDs, `wamid`, or RCS message IDs should not be required unless Sent activity/webhook payloads expose them for the relevant account.
