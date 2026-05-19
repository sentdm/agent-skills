---
name: sent
description: Sent meta dispatcher — routes to the right SMS/WhatsApp/RCS skill (sender profile, 10DLC registration, WABA signup, template authoring, RCS onboarding, MDR analysis, template UI). Use when the user mentions Sent broadly without naming a specific channel workflow, asks "what can you help with on Sent", or describes a problem that could span multiple Sent skills. Use when the request is ambiguous about channel (SMS vs WhatsApp vs RCS) or surface (compliance, integration, debugging, UI) and a clarifying question is needed before invoking a vertical skill. Use when the user says "help me with Sent", "I want to send messages", "set up messaging", or pastes a Sent dashboard / API URL without further context.
---

# Sent Meta Dispatcher

## Overview

This skill is a router, not a worker. It exists so that when a user mentions Sent without naming a specific channel or workflow, Claude inspects the request, asks the smallest number of clarifying questions needed to pick a lane, and then invokes the correct vertical skill — instead of guessing, doing partial work in the wrong vertical, or paraphrasing skill content here.

Sent is a unified messaging platform spanning SMS (10DLC / TCR in the US), WhatsApp (WABA via Meta), and RCS (RBM via Google). Each channel has its own onboarding, compliance, content rules, and failure modes; conflating them produces bad advice. The seven vertical skills in this plugin each own one slice of that surface area. This skill's only job is to put the user in front of the right one quickly.

## When to Use

Use when:
- The user mentions "Sent" broadly without naming a channel ("help me with Sent", "I want to use Sent for messaging")
- The user asks an open-ended question like "what can you help with on Sent?" or "where do I start?"
- The request could plausibly span multiple vertical skills (e.g., "messaging isn't working" — could be 10DLC vetting, WABA template rejection, RBM capability, or MDR funnel)
- The channel is ambiguous (SMS vs WhatsApp vs RCS not stated; geography matters because 10DLC is US-only)
- The surface is ambiguous (API integration vs dashboard UX vs compliance paperwork)
- The user pastes a Sent dashboard URL or API path without further context

Do **not** use when:
- The user has already named the channel **and** the workflow — invoke the matching vertical skill directly.
- The question is purely about Sent product, billing, or pricing — those aren't in scope for any skill in this plugin; point the user at `https://docs.sent.dm` or Sent support.

## Routing rules

| User intent | Target skill |
|---|---|
| SMS compliance, 10DLC, brand/campaign registration, TCR vetting, carrier rejects | `sent-skills:sms-10dlc-registration` |
| Authoring a WhatsApp template; classifying utility vs marketing vs authentication; fixing a Meta template rejection | `sent-skills:waba-template-author` |
| Connecting a WhatsApp Business Account; Meta Embedded Signup flow; `config_id`, callbacks, token exchange | `sent-skills:waba-embedded-signup` |
| Launching RCS; creating + verifying an RBM agent with Google; capability + fallback decisions | `sent-skills:rcs-agent-onboarding` |
| Multi-tenant architecture, data model around Sender Profile, cross-channel routing, rate limits | `sent-skills:sender-profile-architect` |
| Delivery debugging, MDR funnel analysis, "why are my messages failing", status-code triage across channels | `sent-skills:messaging-performance-analyzer` |
| Building / specifying the tenant-facing WhatsApp template submission UI in the Sent dashboard | `sent-skills:template-builder-ui` |

If the request matches one row cleanly, invoke that skill and stop. If it spans two or more rows, name the primary one, mention the others, and let the user steer.

## Clarifying questions to ask before routing

Ask only what's needed to pick a lane. Stop as soon as the channel + workflow are unambiguous.

1. **Channel** — SMS, WhatsApp, RCS, or unsure?
2. **Workflow stage** — fresh setup, in the middle of integration, or debugging something that was working?
3. **Geography** — US only, international, or both? (Matters for SMS — 10DLC / TCR is US-only.)
4. **Surface** — API / backend integration, dashboard UX work, or compliance paperwork (TCR brand, WABA verification, RBM launch evidence)?
5. **Audience** — are you an end-tenant of Sent, or are you building the multi-tenant Sent platform itself? (Sender Profile vs single-tenant onboarding.)
6. **Symptom** (if debugging) — error code, rejection reason, low vetting score, or pure delivery-rate drop?
7. **Artifact in hand** — do you have a template draft, an RBM agent ID, an MDR export, a `config_id`, or nothing yet?

One question per turn is fine; never fire all seven at once.

## When to handle without routing

This skill is not a fallback for general questions. If the user asks about:
- **Sent product, billing, plans, pricing, or account access** — direct them to `https://docs.sent.dm` or Sent support, not a skill.
- **Generic engineering** (how to do retries, queueing, observability in general) — those aren't in this plugin's scope; answer normally without invoking a Sent skill.
- **Meta / Google / TCR carrier policy details that aren't yet operationalized in a skill** — link the upstream docs directly rather than paraphrasing them here.

If after the clarifying questions the request still doesn't fit any vertical skill, say so plainly. Don't force a route.

## Related skills

- `sent-skills:sms-10dlc-registration` — register a brand + campaign with The Campaign Registry for A2P SMS.
- `sent-skills:waba-template-author` — author and classify WhatsApp templates (utility / marketing / authentication).
- `sent-skills:waba-embedded-signup` — implement Meta's Embedded Signup flow end-to-end.
- `sent-skills:rcs-agent-onboarding` — create + verify an RBM agent with Google for RCS sending.
- `sent-skills:messaging-performance-analyzer` — analyze MDRs across any channel to find funnel leaks.
- `sent-skills:sender-profile-architect` — multi-tenant architecture around Sent's Sender Profile.
- `sent-skills:template-builder-ui` — design the tenant-facing WhatsApp template submission UI.
- See top-level `references/sent-glossary.md` for shared Sent terminology (Sender Profile, MDR, WABA, RBM, 10DLC, TCR, config_id).
