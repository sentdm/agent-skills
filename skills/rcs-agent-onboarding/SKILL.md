---
name: rcs-agent-onboarding
description: Creates and verifies an RCS Business Messaging (RBM) agent with Google so a tenant can send rich messages on RCS via Sent. Use when a user mentions "RCS", "RBM", "RCS Business Messaging", "RCS agent", "verified sender", "rich card", "suggested action", "RCS fallback to SMS", or asks how to launch an RCS sender. Use when onboarding a tenant for RCS, defining the agent's capabilities (rich cards, carousels, suggested actions), setting the SMS fallback policy, or debugging an agent that isn't reaching a particular carrier. Covers agent creation, verification, capability declaration, launch review, and the fallback decision.
---

# RCS Agent Onboarding

## Overview

RCS Business Messaging (RBM) is Google's API for branded, rich messaging on the Android default messaging app. Unlike SMS, RCS requires a per-tenant **Agent** that's been verified by Google and approved by each mobile carrier the agent wants to reach. The agent declares its capabilities (rich cards, carousels, suggested replies, suggested actions), its verified domains, and what to do when the recipient isn't RCS-capable. This skill walks through agent creation, the verification + launch review, and the decisions that affect deliverability across carriers.

RCS is *not* SMS-with-features. Provisioning, billing, and delivery semantics all differ — treat it as its own channel.

## When to Use

Use when:
- A tenant wants to send RCS via Sent for the first time
- An agent is stuck in `pending_verification` or `launch_review`
- A tenant's RCS messages aren't reaching one specific carrier despite delivering on others
- Defining or changing the agent's capabilities or fallback policy
- Auditing an existing agent for missed capability declarations after a feature change

Do **not** use for:
- The Sender Profile data model that holds `agent_id` — use `sender-profile-architect`
- Investigating delivery rates once the agent is live — use `messaging-performance-analyzer`
- Authoring rich-card payloads at runtime — that's regular RBM API work, not onboarding

## Agent Lifecycle

```
created ──► pending_verification ──► verified ──► launch_review ──► launched
   │                │                                  │              │
   ▼                ▼                                  ▼              ▼
deleted        rejected                          changes_requested  suspended
                                                       │              │
                                                       └──► launch_review ──► launched
```

States that matter:

- **created** — Agent record exists in RBM; not visible to recipients yet.
- **pending_verification** — Google is verifying the brand identity, domains, and contact information.
- **verified** — Brand approved. Now you can submit for launch review.
- **launch_review** — Google reviews the agent's content, capabilities, and use cases. Each carrier also signs off here.
- **launched** — Agent is live in production. Carriers may still roll out at their own pace.
- **suspended** — Google or a carrier has paused the agent; sending is blocked.

Persist this state on the Sender Profile's RCS sender record. Don't infer it from the RBM API on every send.

## Onboarding Workflow

1. **Decide brand identity.** Agent display name, brand logo, brand color, description. The brand presented to the recipient is the agent — recipients see it on every RCS bubble. Mismatches with the company's public branding are the most common reason verification gets bounced back.

2. **Pick the use case.** RBM has explicit use cases — `CUSTOMER_CARE`, `TRANSACTIONAL`, `OTP`, `MULTI_USE`, etc. Same principle as TCR: pick the narrowest accurate one. `MULTI_USE` raises the review bar.

3. **List verified domains.** Every URL the agent will link to must be on a domain Google has verified you control. Add them all *at creation*; adding domains later forces re-review.

4. **Declare capabilities you actually need.** Subset of:
   - Suggested replies (chips below the message)
   - Suggested actions (open URL, dial, view location, calendar event)
   - Rich cards (single or carousel)
   - File / image / video attachments
   Declaring capabilities you don't use is harmless. Declaring less than you use causes runtime errors.

5. **Define the SMS fallback policy.** When a recipient isn't RCS-capable, RBM rejects the send with a capability error. Decide up-front:
   - **Fall back to SMS** — Sent's `fallback_policy = 'sms'` will route through the same Sender Profile's SMS sender. Requires the SMS sender to be 10DLC-registered. Bills as SMS.
   - **No fallback** — Sent surfaces the error to the application. Pick this if you want to control fallback semantically (different template, different timing).
   - **Application-routed** — Same as no fallback; the application decides.

6. **Submit for verification.** Google checks brand identity, domain control, contact details. Typically 1-7 business days.

7. **Submit for launch review.** Once verified, each agent goes through a content / capability review. Each carrier (T-Mobile, AT&T, Verizon, regional MVNOs) approves independently. Expect uneven rollout — an agent can be `launched` overall but unreachable on a single carrier for weeks after.

8. **Persist `agent_id` and per-carrier rollout state on the RCS sender record.** Per-carrier state is what tells you why a specific recipient on T-Mobile isn't getting your messages even though Verizon recipients are.

## Capability vs Fallback — Common Mistakes

| Question | Answer |
|---|---|
| Recipient on iOS — RCS or SMS? | iOS supports RCS as of recent releases, but capability is per-handset. Always check the capability endpoint, don't assume. |
| Recipient on Android with no Google Messages? | Not RCS-capable. Fall back. |
| Carousel rendered on T-Mobile but not AT&T? | Carrier hasn't rolled out the carousel capability for this agent yet. Either wait or downgrade the payload for that carrier. |
| Suggested-action URL doesn't open? | URL domain isn't on the agent's verified-domains list. Add and re-review. |

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll skip the fallback policy — RCS will figure it out." | RBM rejects non-capable recipients with an error; without an explicit fallback, the tenant's user just gets nothing. |
| "We can edit verified domains later." | Each change re-triggers Google review. Front-load domain registration. |
| "`MULTI_USE` is the safe choice." | It raises the review bar. Pick the narrowest accurate use case. |
| "Once Google verified us, we're live on every carrier." | Google verification is brand identity. Each carrier still has to approve the agent separately. Expect weeks of staggered rollout. |
| "We can share one agent across tenants." | An agent represents a brand. Sharing across tenants means recipients see the wrong brand in their messages. One agent per tenant per brand. |
| "I'll fall back to SMS using a different sender." | Sent routes fallback through the *same* Sender Profile's SMS sender by design — keeps the recipient experience consistent. Setting up a separate sender is an anti-pattern. |

## Red Flags

- Agent display name or logo doesn't match the tenant's public-facing brand
- Verified-domains list is shorter than the URLs the agent actually sends
- Capabilities declared are a superset of what's used (harmless) *or* a subset (causes runtime errors)
- No per-carrier rollout state tracked — silent failures on one carrier
- Fallback policy not declared explicitly on the Sender Profile
- Application code hardcodes `agent_id` instead of reading it from the Sender Profile

## Verification

A correctly onboarded RCS sender has:
- [ ] One RBM Agent per tenant brand, with consistent display name, logo, and colors
- [ ] Use case narrower than `MULTI_USE` unless genuinely multi-purpose
- [ ] Verified-domains list covers every URL the agent will link to
- [ ] Capabilities declared match the actual payloads sent
- [ ] Fallback policy explicitly set on the Sender Profile (`sms`, `none`, or application-routed)
- [ ] Per-carrier rollout state stored and reconciled on a schedule
- [ ] Sender Profile holds `agent_id`; nothing in application code is hardcoded

## Related Skills

- `sender-profile-architect` — where `agent_id` and fallback policy attach in the data model
- `sms-10dlc-registration` — the SMS sender that backs an RCS fallback policy
- `messaging-performance-analyzer` — for diagnosing capability-mismatch and per-carrier rollout issues after launch
