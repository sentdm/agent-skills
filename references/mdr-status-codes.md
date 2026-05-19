# MDR Status & Error Codes — Reference

Supporting reference for `messaging-performance-analyzer`. Sent normalizes inbound delivery events from all three channels into a single MDR stream. This doc captures the codes you actually see in production analysis, grouped by channel and root cause.

Authoritative upstream sources:
- WhatsApp: [Cloud API Error Codes](https://developers.facebook.com/docs/whatsapp/cloud-api/support/error-codes)
- SMS: TCR + carrier-specific reject reasons (T-Mobile, AT&T, Verizon — each carrier publishes its own list)
- RCS: [RBM API errors](https://developers.google.com/business-communications/rcs-business-messaging/reference/rest)

## Message Status Lifecycle (normalized)

Sent's MDR uses normalized status values across channels:

| Status | Meaning | Channels |
|---|---|---|
| `submitted` | Sent accepted the API call | all |
| `sent` | Handed off to the upstream provider | all |
| `delivered` | Recipient device acknowledged receipt | SMS (when DLR available), WhatsApp, RCS |
| `read` | Recipient opened the message | WhatsApp (if read receipts on), RCS |
| `failed` | Terminal failure; check the channel's error code | all |
| `replied` | Recipient sent an inbound message in response | all |

Only the **latest** status per message ID is meaningful when computing funnel counts. A message can go `sent → delivered → failed` (e.g. expired window on WhatsApp, capability lost on RCS) and should be counted as `failed`.

## SMS — Carrier Reject Reasons

Carriers don't have a single shared error enum; each publishes its own. Sent normalizes the high-signal ones. The categories you'll see most:

| Category | Typical Sent-normalized code or label | What it means |
|---|---|---|
| Carrier filter | `CARRIER_REJECT_T_MOBILE`, `CARRIER_REJECT_ATT`, etc. | The carrier blocked the message — usually a content / campaign-mismatch issue |
| Throughput throttle | `THROUGHPUT_EXCEEDED` | TCR campaign TPS exceeded; pace sends |
| Invalid destination | `INVALID_NUMBER`, `LANDLINE`, `UNKNOWN_SUBSCRIBER` | Number is not SMS-reachable |
| Opt-out (STOP) | `OPT_OUT` | Recipient texted STOP; do not re-send |
| Campaign suspended | `CAMPAIGN_SUSPENDED`, `BRAND_REJECTED` | TCR action on the campaign / brand; fix in onboarding |
| No DLR | `NO_DELIVERY_RECEIPT` | Carrier didn't return a DLR; treat as "sent, unknown" |

When triaging SMS:
- Aggregate by carrier first — same content can pass on one network and fail on another.
- Then aggregate by category. Carrier-filter spikes mean the campaign needs vetting work; opt-out spikes mean list hygiene.

## WhatsApp — Meta Error Codes

The full enum is on Meta's site; what follows is the working set you triage against in real analyses.

### Authorization & Capability
| Code | Meaning | What it usually means |
|---|---|---|
| `131000` | Generic | Check the `error_data.details` text |
| `131005` | Access denied | App lost permission to the phone number; re-auth needed |
| `131008` | Required parameter missing | Malformed request — client bug |
| `131009` | Parameter value invalid | Phone number format, locale code, or template name wrong |
| `131016` | Service unavailable | Meta-side outage; retry with backoff |
| `131021` | Recipient cannot be sender | Don't message yourself |

### Recipient Quality
| Code | Meaning | What it usually means |
|---|---|---|
| `131026` | Message undeliverable | Recipient is not on WhatsApp, blocked your number, or the number is invalid |
| `131047` | Re-engagement message | 24-hour customer service window expired; must send a template to reopen |
| `131048` | Spam rate limit | Per-recipient or per-account quality has dropped; messages throttled |

### Rate Limit / Throughput
| Code | Meaning | What it usually means |
|---|---|---|
| `130429` | Rate limit hit | Too many requests in a short window; back off |
| `131056` | Pair rate-limit | Too many messages to the same recipient in a short window |
| `133016` | Account daily messaging limit reached | Tier exhausted for the 24h period |

### Template / Content
| Code | Meaning | What it usually means |
|---|---|---|
| `131051` | Unsupported message type | Recipient's app version can't render this type |
| `132000` | Template paused | Template exceeded the quality threshold |
| `132001` | Template does not exist | Wrong template name or language combination |
| `132005` | Template hydrated text too long | Body after variable substitution exceeded the 1024-char cap |
| `132007` | Translated text too long | Same as above for a specific language variant |

### Account Restriction
| Code | Meaning | What it usually means |
|---|---|---|
| `133000` | Account is incomplete | Business not yet verified |
| `133004` | Server temporarily unavailable | Meta-side; retry |
| `133005` | Two-step PIN required | Phone number registration PIN missing or wrong |
| `133006` | Phone number not registered | Step 7 of Embedded Signup (`/register`) was skipped or failed |
| `133008` | Too many 2FA verification attempts | Rotate the PIN and re-register |
| `133009` | Phone number deletion failed | Cleanup-time error; not delivery-related |

## RCS — RBM Reject Reasons

RCS funnel breakage tends to be more about capability than delivery. Common normalized buckets:

| Category | Typical Sent-normalized code or label | What it means |
|---|---|---|
| Capability mismatch | `NOT_RCS_CAPABLE`, `CAPABILITY_REVOKED` | Handset isn't RCS-reachable; usually fall back to SMS |
| Agent state | `AGENT_NOT_LAUNCHED`, `AGENT_SUSPENDED` | The RBM agent isn't approved in this carrier or has been suspended; sender-side fix |
| Quota | `RCS_QPS_EXCEEDED` | Pace sends |
| Content rejected | `RICH_CARD_INVALID`, `SUGGESTION_INVALID` | Payload didn't meet RBM schema; client bug |
| Suggestion timeout | `SUGGESTION_TIMEOUT` | User didn't tap within the suggestion lifetime; usually a UX signal, not a failure |
| No DLR | `NO_DELIVERY_RECEIPT` | Carrier didn't surface delivery; treat as "sent, unknown" |

When triaging RCS:
- Always separate the capability check from delivery. Most "RCS is broken" reports are really "the audience isn't RCS-capable."
- If a Sender Profile uses SMS fallback, report the fallback volume next to the RCS funnel — never inside it.

## Interpreting the Funnel Through Codes

A common production diagnosis flow:

1. Compute funnel for a cohort (channel × template-or-campaign × country × tenant × week).
2. Identify the broken stage.
3. Pull the top error codes at that stage:
   - **SMS** carrier-filter spike → campaign content / vetting score; fix at TCR level
   - **SMS** invalid-number dominance → contact-list hygiene problem
   - **WhatsApp** `131026` dominant → contact-list quality problem (fix in onboarding)
   - **WhatsApp** `131047` dominant → conversation-window expiry; send a re-engagement template
   - **WhatsApp** `131048` dominant → quality rating dropped; investigate template content or send-frequency
   - **WhatsApp** `132000` / `132001` → template lifecycle issue (paused or deleted)
   - **WhatsApp** `133016` → tier exhausted; either upgrade tier or re-pace sends
   - **WhatsApp** `131005` / `133005` / `133006` → Sender Profile state issue (re-auth or re-register)
   - **RCS** `NOT_RCS_CAPABLE` dominant → audience targeting; consider SMS-first for this segment
   - **RCS** `AGENT_NOT_LAUNCHED` in one carrier → re-engage Google verification for that carrier

## Counting Rules

- **Use distinct message IDs** (`carrier_message_id` for SMS, `wamid` for WhatsApp, `messageId` for RCS) when computing rates; the same ID can have multiple webhook events.
- **Use the latest status** (`max(timestamp)`) — a `failed` after `delivered` means failed; a `read` after `delivered` means read.
- **Exclude pending** (no `delivered` and no `failed` after the analysis window closes) from rate denominators — they're indeterminate.
- **Honor a minimum cohort size** before drawing conclusions about rate shifts under a few percentage points. Sent's internal heuristic is ≥1,000 messages per cohort; below that, the noise dominates.
- **Separate RCS fallback volume.** If a Sender Profile falls back to SMS, the SMS messages it generated are *not* RCS delivery; account for them in the SMS funnel.
