---
name: messaging-performance-analyzer
description: Analyzes Sent's unified Message Delivery Reports (MDRs) across SMS, WhatsApp, and RCS to surface failure patterns and bottlenecks in a sales or notification funnel. Use when a user mentions "MDR", "delivery report", "why are my messages failing", "delivered vs read rate", "drop in delivery", or wants to find where leads drop off in a sequence. Use when investigating a sudden delivery-rate change, a specific status-code spike (carrier reject, Meta error code, RBM capability failure), or a tenant complaining their messages "aren't going through". Use when comparing channel performance (SMS vs WhatsApp vs RCS with fallback) for the same audience. Provides a channel-aware funnel framing, per-channel status-code triage, and segmentation guidance.
---

# Messaging Performance Analyzer

## Overview

A Message Delivery Report (MDR) is Sent's unified per-message status stream — what each channel pushes back as a message moves through `sent → delivered → read → replied` and what each channel pushes when something fails. Each upstream provider speaks its own dialect (carriers for SMS, Meta for WhatsApp, Google RBM for RCS), and Sent normalizes them; this skill is the analyst's playbook for reading the normalized stream, slicing it, and producing an actionable diagnosis instead of vibes.

The skill is channel-aware because the meaningful funnel stages and the failure modes differ by channel. Don't analyze SMS and WhatsApp on the same axes.

## When to Use

Use when:
- A user complains "delivery is bad" or "messages aren't going through" on any channel
- A specific template / campaign / agent or tenant has a sudden delivery drop
- A sales sequence is underperforming and the team wants to know which step is leaking
- You see a spike in a particular status / error code (carrier reject, Meta 131xxx, RBM capability failure) and need to interpret it
- A tenant is using RCS-with-SMS-fallback and you need to know how much of the volume actually landed on RCS vs fell back
- You need to compare delivery health across tenants, countries, channels, or templates

Do **not** use for:
- Writing or classifying WhatsApp templates — use `waba-template-author`
- Provisioning new senders — use `sender-profile-architect`, `sms-10dlc-registration`, `waba-embedded-signup`, or `rcs-agent-onboarding`
- Authoring the dashboard UI itself — that's product work, not analysis

## The Funnel Frame (channel-aware)

Every analysis starts here, but the *stages that matter* depend on the channel.

### SMS funnel

```
Submitted   → message accepted by Sent
   │
Sent        → handed off to the carrier
   │
Delivered   → carrier acknowledged delivery to the handset
   │
Replied     → recipient responded (if any)
```

- No native "read" signal on SMS — `read` doesn't exist.
- "Delivered" is *carrier-reported*; some carriers don't return granular delivery receipts (DLRs), so the funnel ends at "Sent" for them. Note the carrier when you cite a number.

### WhatsApp funnel

```
Submitted   → message accepted by Cloud API
   │
Sent        → Meta has dispatched toward WhatsApp's network
   │
Delivered   → recipient's device acknowledged receipt
   │
Read        → recipient opened (only if read receipts are on)
   │
Replied / CTA → recipient took the desired action
```

Read receipts can be turned off by the recipient regardless of region; treat read-rate as advisory.

### RCS funnel

```
Capability  → recipient handset confirmed RCS-capable
   │  (no  → fallback path; counts as a different funnel)
   │
Submitted   → Sent accepted the message for RCS
   │
Sent        → handed to Google RBM
   │
Delivered   → carrier confirmed delivery
   │
Read        → recipient opened
   │
Reply / Action → recipient tapped a suggested action or replied
```

- The **capability check** is the unique RCS stage. Most RCS funnel leakage shows up here, *not* in delivery.
- If the Sender Profile's fallback policy is "SMS", treat the SMS leg as a separate funnel and combine for tenant-facing rollups only.

## Workflow

1. **Pin the question.** "Why did delivery drop today?" is answerable. "How are our messages doing?" isn't. Push the user toward a comparable cohort (channel × template-or-campaign × country × time window × tenant).
2. **Pick the channel-appropriate funnel.** SMS, WhatsApp, and RCS each have different meaningful stages; never blend them on one chart.
3. **Define the window and the cohort.** Same channel, same template/campaign, same country, last 7 days vs prior 7 days. For WhatsApp, never mix template categories — utility and marketing have different baselines.
4. **Compute the funnel per stage.** Count distinct message IDs at each status (`carrier_message_id` for SMS, `wamid` for WhatsApp, `messageId` for RCS). Use the *latest* status per message; don't double-count a `sent → delivered → failed` trajectory.
5. **Find the broken stage.** The biggest absolute drop between adjacent stages — relative to the baseline — is the bottleneck.
6. **Triage status codes at that stage.** Group failed messages by the channel's error field. The top 1-2 codes usually explain ≥80% of failures. Map each code to a root cause using the channel section in `references/mdr-status-codes.md`.
7. **Segment if needed.** If a code dominates only for one country, one carrier (SMS), one phone-number-id (WhatsApp), or one capability profile (RCS), the fix is scoped to that segment. If it's across the board, look at template / account / agent-level causes.
8. **Report:** broken stage, top status codes, hypothesis, suggested fix or follow-up data pull. Quantify (`12% drop, ~4,200 messages, 87% explained by carrier filter X` or `error 131047`), don't qualify.

## Status-Code Triage Pointers (by channel)

| Channel | What you're triaging | Common top offenders |
|---|---|---|
| **SMS** | Carrier rejection, opt-out, invalid number | Carrier filter (T-Mobile / AT&T / Verizon), TCR campaign throttle, STOP keyword, landline / invalid number |
| **WhatsApp** | Meta error code in `errors[0].code` | `131005`, `131026`, `131047`, `131048`, `131056`, `132000`, `133016`, `133006` |
| **RCS** | Capability mismatch, agent state, fallback engagement | Recipient not RCS-capable, agent not launched in that carrier, suggested-action timeout, fallback fired |

The full enums (per channel) live in `references/mdr-status-codes.md`.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "Delivery dropped, so the problem is delivery." | The `failed` status usually masks a content, capability, or account-level cause. Always look at the channel's error code, not just the status. |
| "Read rates are low — the template is broken." | WhatsApp read receipts are off in many regions; RCS read varies by handset. Compare like-for-like and check whether the read-rate is structurally lower in that segment. |
| "All these failures are 131026, so they're bad numbers — nothing we can do." | High 131026 (WhatsApp "not on WhatsApp") usually means the contact list isn't being validated upstream. The fix is in onboarding, not messaging. |
| "Let me look at all channels in one chart." | Blending SMS, WhatsApp, and RCS on one funnel hides everything important. Always slice by channel first. |
| "RCS fallback to SMS is the same as RCS delivery." | The fallback is a *different funnel*. Counting fallback as RCS delivery inflates RCS performance and hides the capability problem. |
| "Sample size is fine, I'll trust the rate." | A 90% delivery rate on 50 messages tells you nothing. Require a meaningful absolute count before drawing conclusions on small deltas — Sent's internal heuristic is ≥1,000 per cohort. |

## Red Flags

- An analysis without a defined cohort (channel × template-or-campaign × country × time window)
- Comparing yesterday vs today without a baseline week
- Quoting percentages without absolute counts
- Conflating "failed" and "not delivered yet" — failed has an error field; pending doesn't
- A report that names a problem but no specific message IDs / examples to inspect
- "It's broken" without a top error code per channel
- RCS delivery numbers that don't separately call out SMS-fallback volume

## Verification

A good analysis ends with:
- [ ] Channel named explicitly
- [ ] Cohort defined explicitly (template/campaign, country, window, tenant, channel)
- [ ] Funnel computed at each stage with both rates and absolute counts
- [ ] Broken stage identified with the magnitude of the drop
- [ ] Top error codes named with their root-cause mapping (channel-appropriate)
- [ ] For RCS, fallback volume reported separately
- [ ] One concrete next step (fix, deeper pull, or escalation to the relevant carrier / Meta / Google support)
- [ ] Reproducible query / script — not a hand-computed number

## Bundled references and scripts

| Path | Status | What it gives you |
|---|---|---|
| `references/mdr-status-codes.md` | shipped | Per-channel normalized status enum + Meta / carrier / RBM error-code triage tables. |
| `references/performance-diagnosis-playbook.md` | shipped | Decision tree for which signal to investigate first, channel-specific diagnostic patterns, cross-skill handoff matrix, and escalation criteria. |
| `scripts/analyze_mdr_funnel.py` | shipped | Reads an MDR export (CSV or JSON), prints per-stage counts and drop-off percentages, exits non-zero on anomalies. Run: `python skills/messaging-performance-analyzer/scripts/analyze_mdr_funnel.py path/to/mdr.csv` (use `--threshold N` to tune; default 20). |

## Related Skills

- `sent-skills:waba-template-author` — if the diagnosis is "WhatsApp template content" or "wrong category"
- `sent-skills:sms-10dlc-registration` — if the diagnosis is TCR vetting score / campaign throttle / brand mis-classification
- `sent-skills:rcs-agent-onboarding` — if the diagnosis is "agent not launched in that carrier" or capability mismatch
- `sent-skills:sender-profile-architect` — if the diagnosis is account-tier / sender-quality / multi-channel state drift
- See the top-level `sent-glossary` (`../../references/sent-glossary`) for shared Sent terminology.
