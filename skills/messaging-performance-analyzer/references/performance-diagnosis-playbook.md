# Performance Diagnosis Playbook

Supporting reference for `messaging-performance-analyzer`. The SKILL.md tells you *what* a clean funnel analysis looks like; this doc tells you *which signal to pull next* and *when to hand off to another skill*.

## 1. Decision Tree — Which Signal First?

Most production performance complaints arrive as one of three vague shapes. Resist running every query — pick the entry point that matches the shape, then narrow.

```
"Messages aren't going through" / "delivery is bad"
   │
   ├─ Is it scoped to one tenant / Sender Profile? ──── Yes ──▶  Check sender-profile state
   │                                                              (registration, quality rating,
   │                                                               capability) BEFORE pulling MDRs.
   │
   ├─ Is it scoped to one channel?    ──── Yes ──▶  Pull the channel-appropriate funnel only.
   │                                                  Don't blend.
   │
   ├─ Is it scoped to one template / campaign / agent? ── Yes ▶  Pull MDR funnel filtered to that ID;
   │                                                              compare to the tenant's other
   │                                                              template / campaign baseline.
   │
   └─ Is it everywhere?               ──── Yes ──▶  Webhook ingestion check first
                                                    (see "Webhook drop" below).
```

The rule: **state checks are free, funnel queries are expensive.** Always rule out a degraded Sender Profile, expired access token, or paused TCR campaign before grinding through MDR aggregations.

### Investigate-First Order

1. **Sender Profile state** — registration complete, tokens valid, quality ratings green, capability flags fresh.
2. **Webhook drop** — is Sent actually receiving status updates? If MDR rows stop appearing for a window but the API still accepts sends, the problem is webhook delivery, not message delivery. Check Sent's [delivery webhooks](https://docs.sent.dm) docs.
3. **Per-channel funnel** — compute counts per stage for the cohort.
4. **MDR error codes** — only after a broken stage is identified. See `mdr-status-codes.md`.

## 2. Channel-Specific Diagnostic Patterns

### SMS — Carrier Filtering Signs

The carrier silently dropped your message when:

- Funnel shows `sent` → `delivered` cliff (>30% drop) **scoped to one carrier**. Aggregate by carrier first.
- The same content lands on Verizon but is filtered by T-Mobile (or vice versa).
- DLRs return `CARRIER_REJECT_*` with no opt-out / invalid-number signal.
- Drop coincides with a recent campaign content change, a new keyword, or a URL shortener swap.

Likely root causes: TCR campaign use-case mismatch, low vetting score, shared short-code reputation, unregistered link, or carrier-specific content filter on a keyword (loans, crypto, supplements). Hand off to `sent-skills:sms-10dlc-registration` for TCR-side fixes.

### WhatsApp — Template Issues

Symptoms that point at the template, not the funnel:

- `132000` (template paused) or `132001` (template missing) dominates `failed` for one template ID.
- `131048` (spam rate limit) rises after a template content change.
- Read rate collapses on one template only — usually a CTA-or-content regression, not a delivery issue.
- `131047` (re-engagement) dominates a marketing flow — the 24-hour window expired between session and send.

Hand off to `sent-skills:waba-template-author` to re-author or re-categorize the template.

### RCS — Fallback Chain Breaks

The RCS funnel is *two* funnels stitched together; breaks usually live in the seam:

- `NOT_RCS_CAPABLE` dominates → most of the audience never enters the RCS funnel; it's an audience-targeting issue, not RCS delivery.
- `AGENT_NOT_LAUNCHED` scoped to one carrier → the RBM agent isn't approved for that carrier yet. Hand off to `sent-skills:rcs-agent-onboarding`.
- Capability-check passes, send accepted, but no delivery DLR → carrier didn't surface a DLR; treat as "sent, unknown" and pull a sample to inspect.
- Fallback fired but the SMS leg also failed → the Sender Profile's fallback SMS sender is in a different state (e.g. paused campaign). Check both legs in `sent-skills:sender-profile-architect`.

## 3. When Symptoms Cross Skills — Handoff Matrix

| Symptom in the MDR | Likely root cause | Hand off to |
|---|---|---|
| `131005`, `133006` (WhatsApp auth / register) | Sender Profile registration drifted | `sent-skills:sender-profile-architect`, then `sent-skills:waba-embedded-signup` if re-auth needed |
| `133016` (WA tier exhausted) on a growing tenant | Tier upgrade overdue | `sent-skills:sender-profile-architect` (capacity planning) |
| `131048` rising across all templates | Account quality dropped — likely content / frequency | `sent-skills:waba-template-author` (review template mix), then sender-profile rate-limit policy |
| `132000` / `132001` on one template | Template lifecycle problem | `sent-skills:waba-template-author` |
| SMS `CAMPAIGN_SUSPENDED`, `BRAND_REJECTED` | TCR-side action | `sent-skills:sms-10dlc-registration` |
| SMS carrier-filter cliff on new content | Content / use-case mismatch | `sent-skills:sms-10dlc-registration` |
| RCS `AGENT_NOT_LAUNCHED` for one carrier | Per-carrier approval pending | `sent-skills:rcs-agent-onboarding` |
| RCS `NOT_RCS_CAPABLE` dominates | Audience targeting / fallback policy | `sent-skills:sender-profile-architect` (review fallback policy) |
| Funnel rows missing entirely for a window | Webhook ingestion problem on Sent's side | Escalate to Sent support (see below) |
| Cross-channel state drift (one Sender Profile, channels disagree) | Sender Profile composition issue | `sent-skills:sender-profile-architect` |

## 4. When to Escalate to Sent Support vs Investigate Yourself

Investigate yourself first when:

- The symptom is scoped to one tenant, one template, one campaign, or one cohort.
- MDR rows exist and an error code is present — the code is your lead.
- The state checks (Sender Profile, TCR campaign, WABA token, RBM agent) are all green.
- The fix is in tenant configuration (template content, campaign vetting, audience targeting).

Escalate to Sent support when:

- MDR rows stop appearing for a window across multiple tenants (webhook ingestion regression on Sent's side).
- Multiple Sender Profiles flip to a degraded state at the same time without a tenant-side change.
- An upstream provider returned an error code that isn't in `mdr-status-codes.md` — Sent normalization may need to be updated.
- A delivery anomaly correlates with a Sent platform deploy time window.
- You see `failed` rows with no error code populated — normalization is broken.

When escalating, include: tenant ID, Sender Profile ID, channel, cohort definition, time window, the broken stage with absolute counts, top error codes, and a sample of message IDs to inspect. Don't escalate with "delivery looks bad" — escalate with the cohort and the codes.

## 5. Diagnostic Loop

Repeat until the symptom is explained or scoped:

1. Narrow the cohort (channel × template/campaign × country × tenant × window).
2. Compute the funnel; identify the broken stage.
3. Pull the top error codes at that stage; map via `mdr-status-codes.md`.
4. If a code points to a sender-profile / template / campaign issue, hand off via §3.
5. If the codes are unfamiliar or rows are missing, escalate to Sent support per §4.
6. Record the diagnosis with quantified evidence — never "looks better now" without a recomputed funnel.
