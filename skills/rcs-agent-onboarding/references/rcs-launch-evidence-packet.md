# RCS Launch Evidence Packet — Reference

Supporting reference for `rcs-agent-onboarding`. Describes the evidence Sent needs from a tenant before initiating the carrier handoff for an RBM agent's launch review. Authoritative source for review criteria is [Google's RBM launch documentation](https://developers.google.com/business-communications/rcs-business-messaging/guides/learn/launch) — this doc describes only what Sent collects and how to organize it.

## Why a Packet

Once Google verifies brand identity, the agent moves to `launch_review`. Google's reviewers — and each carrier signing off after — look at the *content* of what the agent intends to send. Reviewers don't see your runtime; they see whatever sample artifacts you submit. A well-organized packet shortens review time from weeks to days and is the single biggest lever a tenant has on launch latency.

The packet is also what Sent's onboarding team uses to sanity-check the agent before pushing it forward. Missing or vague evidence is the most common reason an agent sits in `launch_review` past the typical 5-10 business day window.

## Required Evidence

### 1. Brand verification artifact

- Letter of authorization (LOA) signed by an officer of the brand confirming the tenant is authorized to operate this agent
- A link to the brand's public site whose domain is on the agent's `verifiedDomains` list
- For franchises / resellers: documentation of the licensing arrangement

### 2. Business use case description

A 2-4 sentence plain-English description of:
- What the agent is for (transactional notifications? two-way support? OTP?)
- Who initiates the conversation (recipient action vs. business-initiated)
- How recipients opt in
- Roughly the volume profile (a few per recipient per week, daily, etc.)

This must align with the RBM use case declared on the agent (see `references/rbm-agent-spec.md`). A `TRANSACTIONAL` agent whose description reads "weekly newsletters" gets bounced back.

### 3. Sample message gallery

For **every** capability the agent declares, include at least one realistic sample showing it in use:

- Plain text message
- Suggested replies (chips)
- Suggested actions (open URL, dial, view location, calendar event)
- Rich card (standalone) — with media, title, description, action
- Rich card carousel — with at least 3 cards
- Each attachment type the agent will send (image, video, file)

Samples must use real brand assets (logo, color, copy voice) — placeholders are a kickback reason. Don't include capabilities you don't intend to use; declaring then never sending is harmless, but submitting a sample that exercises an undeclared capability is a contradiction.

### 4. Opt-in flow screenshots

Screenshots of the surfaces where recipients opt in:
- Web form, mobile app screen, in-store flow, or other consent capture
- The exact disclosure text shown to the recipient
- For OTP/transactional flows where consent is implied by the recipient's action: screenshots of that action surface

### 5. Fallback policy doc

A one-paragraph statement of what happens when the recipient isn't RCS-capable. Maps directly to `fallback_policy` on the Sender Profile. See `references/rcs-fallback-patterns.md` for the option set.

### 6. End-user support contact

A phone number, email, or in-product support URL recipients can reach if they have questions about the messages they receive. Must be reachable — Google and carriers both probe this during review.

## Pre-Handoff Checklist

Before Sent initiates the carrier handoff, confirm:

- [ ] Brand verification artifact attached, signed, dated within last 12 months
- [ ] Use case description matches the agent's declared RBM use case
- [ ] At least one sample per declared capability, using real brand assets
- [ ] Opt-in screenshot for every audience segment the agent will message
- [ ] Disclosure text in opt-in screenshot mentions RCS, the brand name, and message frequency
- [ ] Fallback policy doc is consistent with `fallback_policy` on the Sender Profile
- [ ] Support contact is live and answers within stated SLA
- [ ] `verifiedDomains` list covers every URL that appears in any sample
- [ ] No sample exercises an undeclared capability

## Per-Carrier Nuance

Each US carrier (T-Mobile, AT&T, Verizon, plus regional MVNOs) reviews independently after Google approves. The criteria are broadly similar but the specifics shift over time — treat carrier-specific copy requirements as external. Always check [Google's per-carrier guidance](https://developers.google.com/business-communications/rcs-business-messaging/guides/learn/launch) for the current rules.

The high-level pattern that holds across carriers:
- Promotional / marketing use cases get scrutinized harder than transactional
- Carriers may require additional opt-in disclosure language beyond Google's
- Some carriers stage rollout by recipient volume — expect throttling in the first weeks even after `ENABLED`

## Common Rejection Reasons

| Reason | Remediation |
|---|---|
| Brand assets in sample don't match the agent identity | Re-render samples with the actual logo, color, display name on the agent record |
| Use case description and declared use case disagree | Either change the declared use case or rewrite the description; resubmit |
| Opt-in screenshot missing channel disclosure | Update the opt-in surface to name RCS (or "text messages including RCS") and re-screenshot |
| Verified domain missing for a URL in a sample | Add the domain to the agent's `verifiedDomains` list, wait for re-verification, resubmit |
| Sample exercises an undeclared capability | Either declare the capability and stay in review, or remove the sample |
| Support contact unreachable | Wire up the contact and confirm before resubmitting |
| Same packet recycled across multiple agents with different brands | Each agent needs its own packet — Google catches this |

## After Submission

- Track the per-carrier launch state on the RCS sender record (see the lifecycle diagram in the parent SKILL.md).
- A carrier moving to `changes_requested` will come with a short reason — feed that back to the tenant and update the relevant packet artifact before resubmitting.
- Some carriers stay in `PENDING` for weeks even after Google approves — that's expected, not a packet problem.
