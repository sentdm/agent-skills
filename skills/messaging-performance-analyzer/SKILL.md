---
name: messaging-performance-analyzer
description: Analyzes WhatsApp Business API Message Delivery Reports (MDRs) to surface failure patterns and bottlenecks across a sales or notification funnel. Use when a user mentions "MDR", "delivery report", "why are my messages failing", "delivered vs read rate", "drop in delivery", or wants to find where leads drop off in a sequence. Use when investigating a sudden change in delivery rate, a specific status-code spike, or a tenant complaining their messages "aren't going through". Provides a funnel framing, status-code triage, and segmentation guidance.
---

# Messaging Performance Analyzer

## Overview

A Message Delivery Report (MDR) is the per-message status webhook Meta sends as a message moves through `sent → delivered → read → replied` — and the failure path with specific error codes when things go wrong. Raw MDRs are noisy; the value is in the funnel shape and where it breaks. This skill is the analyst's playbook: frame the funnel, slice the data, triage status codes, and produce an actionable diagnosis instead of vibes.

## When to Use

Use when:
- A user complains "delivery is bad" or "messages aren't going through"
- A specific template or tenant has a sudden delivery drop
- A sales sequence is underperforming and the team wants to know which step is leaking
- You see a spike in a particular WABA error code and need to interpret it
- You need to compare delivery health across tenants, countries, or templates

Do **not** use for:
- Writing or classifying templates — use `waba-template-author`
- Provisioning new senders — use `sender-profile-architect`
- Authoring the dashboard UI itself — that's product work, not analysis

## The Funnel Frame

Every WABA messaging analysis starts here:

```
Submitted   → message accepted by Cloud API
   │
Sent        → Meta has handed it off toward WhatsApp's network
   │
Delivered   → recipient's device acknowledged receipt
   │
Read        → recipient opened the message (only if read receipts are on)
   │
Replied / CTA → recipient took the desired action
```

A healthy WABA template typically sees ≥95% sent→delivered, 60-85% delivered→read (heavy regional variance), and single-digit-to-low-double-digit read→reply for cold sequences.

**Common funnel shapes and what they mean:**
- Sent high, delivered low → capability or recipient-quality issue (errors 131005, 131026, 131047)
- Delivered high, read low → opt-in friction, send-time mismatch, or template fatigue (per-recipient)
- Read high, replied low → CTA problem, message length, or wrong audience — content issue not delivery issue

## Workflow

1. **Pin the question.** "Why did delivery drop today?" is answerable. "How are our messages doing?" isn't. Push the user toward a comparable cohort (template × tenant × country × day).
2. **Define the window and the cohort.** Same template, same country, last 7 days vs prior 7 days. Avoid mixing templates with different categories — utility and marketing have different baselines.
3. **Compute the funnel per stage.** For each cohort, count distinct `wamid` at each status. Use the *latest* status per message; don't double-count a message that went sent→delivered→failed.
4. **Find the broken stage.** The biggest absolute drop between adjacent stages — relative to the baseline — is the bottleneck.
5. **Triage the error codes at that stage.** Group failed messages by `errors[0].code`. The top 1-2 codes usually explain ≥80% of failures. Map each code to a root cause using `references/mdr-status-codes.md`.
6. **Segment if needed.** If a status code dominates only for one country or one phone number ID, the fix is scoped to that segment (recipient quality, sender health, or template per-country issue). If it's across the board, look at template/account-level causes (paused template, account flagged, tier downgrade).
7. **Report:** broken stage, top status codes, hypothesis, suggested fix or follow-up data pull. Quantify (`12% drop, ~4,200 messages, 87% explained by error 131047`), don't qualify.

## Status-Code Triage (top offenders)

| Code | Meaning | Typical root cause |
|---|---|---|
| `131005` | Access denied / capability error | App permission revoked, BSP revoked the phone number |
| `131026` | Recipient cannot receive | Number not on WhatsApp, blocked, or wrong country format |
| `131047` | Re-engagement required | 24-hour window expired and template not sent — send a template to re-open |
| `131051` | Unsupported message type | Sending a media type the recipient's app can't render |
| `131056` | Pair rate-limit (sender↔recipient) | Too many messages to same recipient in a short window |
| `132000` | Template paused / disabled | Template was paused due to quality rating; revise or use a backup |
| `133000` | Account restriction | Account-level limit hit; usually a tier or messaging-limit issue |

The full enum lives in `references/mdr-status-codes.md`.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "Delivery dropped, so the problem is delivery." | The MDR `failed` status often masks a content or account-level cause. Always look at the error code, not just the status. |
| "Read rates are low — the template is broken." | Read receipts are off by default in many regions. Compare like-for-like and check whether the read-rate is structurally lower for that country. |
| "All these failures are 131026, so they're bad numbers — nothing we can do." | High 131026 usually means the contact list isn't being validated upstream. The fix is in onboarding, not messaging. |
| "Let me look at all templates in one chart." | Aggregating across categories hides regressions. Always slice by template first. |
| "Sample size is fine, I'll trust the rate." | A 90% delivery rate on 50 messages tells you nothing. Require ≥1,000 per cohort before drawing conclusions on small deltas. |

## Red Flags

- An analysis without a defined cohort (template × country × time window)
- Comparing yesterday vs today without a baseline week
- Quoting percentages without absolute counts
- Conflating "failed" and "not delivered yet" — failed has an `errors[]` array; pending doesn't
- A report that names a problem but no specific message IDs / examples to inspect
- "It's broken" without a top error code

## Verification

A good MDR analysis ends with:
- [ ] Cohort defined explicitly (template, country, window, tenant)
- [ ] Funnel computed at each stage with both rates and absolute counts
- [ ] Broken stage identified with the magnitude of the drop
- [ ] Top error codes named with their root-cause mapping
- [ ] One concrete next step (fix, deeper pull, or escalation to BSP / Meta support)
- [ ] Reproducible query / script — not a hand-computed number

## Related Skills

- `waba-template-author` — if the diagnosis is "template content" or "wrong category"
- `sender-profile-architect` — if the diagnosis is account-tier or sender-quality
