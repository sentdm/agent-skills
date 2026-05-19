# MDR Status & Error Codes — Reference

Supporting reference for `messaging-performance-analyzer`. The full WhatsApp
Cloud API error code list lives at
[Cloud API Error Codes](https://developers.facebook.com/docs/whatsapp/cloud-api/support/error-codes).
This doc captures the codes you actually see in delivery-report (MDR) analysis,
grouped by root cause.

## Message Status Lifecycle

The `messages` webhook delivers status updates with one of these values:

| Status | Meaning |
|---|---|
| `accepted` | (legacy) Meta accepted the API call; rare in current Cloud API |
| `sent` | Meta has dispatched the message toward the WhatsApp network |
| `delivered` | The recipient's device has acknowledged receipt |
| `read` | The recipient opened the message (only if they have read receipts on) |
| `failed` | Terminal failure; check `errors[]` for the code |
| `deleted` | The sender deleted the message (Cloud API delete) |

Only the **latest** status per `wamid` is meaningful when computing funnel
counts. A message can go `sent → delivered → failed` (e.g. read-only conversation
ran out before user replied) and should be counted as `failed`.

## Top Error Codes by Root Cause

### Authorization & Capability
| Code | Meaning | What it usually means |
|---|---|---|
| `131000` | Generic | Something went wrong; check the `error_data.details` text |
| `131005` | Access denied | App lost permission to the phone number; re-auth needed |
| `131008` | Required parameter missing | Malformed request — usually a client bug, not a runtime issue |
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
| `130429` | Rate limit hit (HTTP-style) | Too many requests in a short window; back off |
| `131056` | Pair rate-limit | Too many messages to the same recipient in a short window |
| `133016` | Account daily messaging limit reached | Tier exhausted for the 24h period |

### Template / Content
| Code | Meaning | What it usually means |
|---|---|---|
| `131051` | Unsupported message type | Recipient's app version can't render this type (e.g. an unsupported sticker) |
| `132000` | Template paused | Template exceeded the quality threshold; choose another |
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

## Interpreting the Funnel Through Codes

A common production diagnosis flow:

1. Compute funnel for a cohort (template × country × tenant × week).
2. Identify the broken stage.
3. Pull the top error codes at that stage:
   - `131026` dominant → contact-list quality problem (fix in onboarding, not messaging)
   - `131047` dominant → conversation-window expiry; users not replying within 24h, send a re-engagement template
   - `131048` dominant → quality rating dropped; investigate template content or send-frequency
   - `132000` / `132001` → template lifecycle issue (paused or deleted); fix in template management
   - `133016` → tier exhausted; either upgrade tier or re-pace sends
   - `131005` / `133005` / `133006` → SPS state issue (re-auth or re-register)

## Counting Rules

- **Always use distinct `wamid`s** when computing rates; the same `wamid` can have
  multiple webhook events.
- **Use the latest status** (`max(timestamp)`) — a `failed` after `delivered` means
  failed; a `read` after `delivered` means read.
- **Exclude pending** (no `delivered` and no `failed` after the analysis window
  closes) from rate denominators — they're indeterminate.
- **Require ≥1,000 messages per cohort** before drawing conclusions about rate
  shifts under 5 percentage points. Below that, the noise dominates.
