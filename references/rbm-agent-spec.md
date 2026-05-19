# RBM Agent Spec — Reference

Supporting reference for `rcs-agent-onboarding`. The fields, capabilities, and lifecycle details for an RCS Business Messaging agent on Google's RBM platform. Canonical source: [Google RBM docs](https://developers.google.com/business-communications/rcs-business-messaging).

## Agent Identity Fields

| Field | Notes |
|---|---|
| `displayName` | Shown on every RCS bubble. Match the tenant's public-facing brand exactly. |
| `description` | Short blurb shown in the agent's "about" panel. Recipients see it. |
| `logoUri` | Square brand mark. Specific dimensions in the RBM docs; under-spec leads to verification kickback. |
| `heroUri` | Optional banner shown in the agent profile. |
| `color` | Brand color used for outline and accents in the messaging UI. |
| `contactInfo.url` | The tenant's public website. Domain must be in `agent.verifiedDomains`. |
| `contactInfo.email` | Support contact. Used by Google during verification. |
| `contactInfo.phone` | Support phone. Used by Google during verification. |
| `verifiedDomains[]` | Every URL domain the agent will link to. Add at creation; later changes re-trigger review. |
| `phoneNumbers[]` | Optional. Numbers the agent can be reached at (for click-to-call). |

## Capabilities

Agents declare which RCS features they need. Declaring more than needed is harmless; declaring less than needed causes runtime errors.

| Capability | What it enables |
|---|---|
| Suggested replies | Tap-to-send chips below the message |
| Suggested actions | Tap-to-open URLs, dial, view location, add to calendar |
| Rich card (standalone) | A single card with media + title + description + actions |
| Rich card carousel | Multiple cards swiped horizontally |
| File attachments | PDF, etc. |
| Image attachments | JPG / PNG |
| Video attachments | MP4 |
| Audio attachments | MP3 / OGG |

## Use Cases

Use cases on RBM mirror TCR in spirit — pick the narrowest accurate one.

| Use case | When to pick |
|---|---|
| `TRANSACTIONAL` | Order, shipping, appointment, payment notifications. Triggered by recipient action. |
| `OTP` | One-time codes only. Lowest review bar, highest reach. |
| `PROMOTIONAL` | Marketing campaigns. Highest review bar. |
| `CUSTOMER_CARE` | Two-way support. |
| `MULTI_USE` | Last resort. Raises the bar without practical gain. |

## Verification

Google reviews:
1. Brand identity — display name, logo, color match the tenant's public brand
2. Domain control — each `verifiedDomains` entry must respond to a verification probe (DNS or file)
3. Contact info validity — email and phone must work
4. Use-case fit — sample messages line up with the declared use case

Typical turnaround: 1-7 business days. Rejection reasons usually surface in the agent's review state with a short explanation.

## Launch Review

After verification, the agent goes into `launch_review`. This is where:

- Google reviews the actual content / capabilities the agent will use.
- Each carrier (T-Mobile, AT&T, Verizon, plus regional MVNOs) independently signs off.

The agent state goes to `launched` when Google approves; individual carriers may still be rolling out for weeks afterward. Track per-carrier state explicitly:

```
launch_status per carrier:
  T-Mobile:  ENABLED
  AT&T:      PENDING
  Verizon:   ENABLED
  US Cellular: PENDING
```

Until a carrier is `ENABLED`, recipients on that carrier will not receive RCS from this agent. They'll fall through to whatever fallback policy is configured.

## Capability Detection at Send Time

Before sending, you can call:

```
GET https://rcsbusinessmessaging.googleapis.com/v1/users/{phoneNumber}:capabilities?agentId={agentId}
```

The response indicates whether the recipient handset is RCS-capable for this agent. If not, the application (or Sent's fallback policy) decides what to do.

In high-volume flows, prefer batch capability resolution or cached lookups (capabilities change rarely but are not stable forever — re-check periodically).

## Fallback Policy Patterns

| Policy | Behavior | When to use |
|---|---|---|
| `sms` (Sent built-in) | If RBM rejects with capability error, Sent routes the same message via the Sender Profile's SMS sender | Default for transactional / 2FA-style traffic |
| `none` | RBM rejection surfaces to the application as an error | When the application needs to choose a different message for SMS |
| `application-routed` | Same as `none` — the application catches the error and routes | Same |

## Anti-Patterns

- One RBM agent shared across multiple tenants — recipients see the wrong brand
- Capabilities declared as a strict subset of what the application sends — runtime errors at scale
- Adding `verifiedDomains` after launch — forces full re-review
- Sending the same payload to RCS and SMS without re-formatting — SMS has no rich cards, no suggested replies
- Hardcoding `agentId` in application code instead of attaching it to a Sender Profile
- Ignoring per-carrier rollout state — silent gaps in coverage for weeks
