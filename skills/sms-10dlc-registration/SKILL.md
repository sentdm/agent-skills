---
name: sms-10dlc-registration
description: Registers a brand and one or more campaigns with The Campaign Registry (TCR) so a tenant can send A2P SMS on US carriers via Sent. Use when a user mentions "10DLC", "TCR", "campaign registry", "brand registration", "campaign registration", "vetting score", "carrier filtering", "T-Mobile / AT&T / Verizon SMS filter", or asks why their SMS messages are throttled or blocked. Use when onboarding a new SMS-sending tenant, classifying a campaign use case, debugging a TCR rejection, or improving a vetting score. Covers the brand identity decision, campaign use-case selection, sample-message authoring, and the most common reasons a campaign gets rejected or filtered.
---

# SMS 10DLC Registration

## Overview

US carriers require Application-to-Person (A2P) SMS senders to register with [The Campaign Registry (TCR)](https://www.campaignregistry.com/) before they can reliably deliver messages on 10-digit long codes. Registration has two parts: a **Brand** (the legal entity that's sending) and one or more **Campaigns** (the specific use cases — order updates, 2FA, marketing). Carriers assign throughput and apply filtering based on the campaign vetting score; misregistration causes silent filtering, throttling, or outright blocks. This skill walks through registering correctly the first time, classifying campaigns truthfully, and debugging rejections.

## When to Use

Use when:
- Onboarding a tenant who needs to send A2P SMS in the US
- A tenant's SMS messages are being filtered or throttled on a specific carrier
- A TCR campaign was rejected or its vetting score is too low for the desired throughput
- Picking a campaign use case (transactional / mixed / marketing / 2FA) for a new flow
- Auditing an existing brand+campaign for accuracy after a tenant's legal/business details changed

Do **not** use for:
- Non-US SMS — TCR is US-specific
- Short codes or toll-free numbers — different registration regimes
- The Sender Profile data model that *holds* the campaign IDs — use `sender-profile-architect`
- Delivery-rate analysis once registered — use `messaging-performance-analyzer`

## The Two Registrations

```
Brand (TCR)                         ← the legal entity, registered once per tenant
  ├── EIN / DUNS / GIIN / LEI       ← external verification anchors
  ├── Brand name, website, vertical
  └── Vetting score (External Vet)  ← unlocks higher throughput

  └── Campaign(s) (TCR)             ← one per distinct use case
       ├── Use case (TCR taxonomy)
       ├── Sample messages
       ├── Phone numbers attached
       ├── Carrier approvals (per-carrier)
       └── TPS (throughput, per carrier)
```

A Sender Profile on Sent attaches its SMS sender to one Brand and (usually) one Campaign. Splitting one tenant's traffic across multiple campaigns is appropriate when use cases genuinely differ (e.g. 2FA + marketing).

## Brand Registration Workflow

1. **Pick the brand entity correctly.** The legal entity that sends the SMS — usually the customer's parent company, *not* a marketing-department name. Mismatches between Brand name and the From-name in the message body cause vetting downgrades.
2. **Provide the strongest external identifier.** Order of preference: EIN (US), DUNS, GIIN, LEI. Brands without any verifiable identifier cap out at low vetting scores and throughput.
3. **Set entity type honestly.** `PRIVATE_PROFIT`, `PUBLIC_PROFIT`, `NON_PROFIT`, `GOVERNMENT`, `SOLE_PROPRIETOR`. Sole-proprietor brands are subject to additional restrictions; don't pretend otherwise.
4. **Submit for External Vetting.** Optional but recommended — raises the per-campaign throughput cap.
5. **Persist `tcr_brand_id` on the Sender Profile.** The Brand is a long-lived object; campaigns are what change.

## Campaign Registration Workflow

1. **Pick the smallest accurate use case.** TCR has ~20 use cases (`2FA`, `ACCOUNT_NOTIFICATION`, `MARKETING`, `MIXED`, `LOW_VOLUME`, etc.). The most common mistake is choosing `MIXED` when a more specific use case applies — `MIXED` raises vetting bar without raising throughput.
2. **Author sample messages that mirror production.** Minimum 2, usually 3-5. They must reflect the *actual* traffic. Including a promo CTA in a campaign you classified as `ACCOUNT_NOTIFICATION` is the #1 rejection reason.
3. **Declare attributes truthfully.** Subscriber opt-in mechanism, opt-out keywords (`STOP`, `UNSUBSCRIBE`), help keywords (`HELP`), embedded link policy (yes/no), embedded phone policy (yes/no), affiliate marketing (yes/no), age-gated content (yes/no). Lying gets caught at the carrier-filter level even if TCR approves.
4. **Attach phone numbers.** A phone number can only be on one campaign at a time. Moving numbers between campaigns triggers re-vetting.
5. **Wait for carrier approvals.** TCR approves the campaign as a whole; each carrier (T-Mobile, AT&T, Verizon) decides independently whether to allow it. A "TCR approved" campaign can still be blocked on one carrier.
6. **Persist `tcr_campaign_id` plus per-carrier approval state on the SMS sender.**

## Use-Case Picking Cheat Sheet

| Traffic | TCR use case | Rationale |
|---|---|---|
| OTP / login code | `2FA` | Highest per-message limit and best carrier approval rate when used cleanly |
| Shipping / order / appointment updates | `ACCOUNT_NOTIFICATION` | Transactional, no promo content allowed |
| Account alerts (low balance, security) | `ACCOUNT_NOTIFICATION` | Same |
| Customer support replies | `CUSTOMER_CARE` | Inbound-driven; outbound limited |
| Promo / marketing / win-back | `MARKETING` | Higher review bar; opt-in must be very clear |
| Mix of transactional + marketing | `MIXED` | Last resort. Higher bar, no extra throughput |
| Polls / surveys (no marketing) | `POLLING_VOTING` | Niche; only use if the entire campaign is this |

When in doubt: split into two campaigns rather than choosing `MIXED`.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll register as the parent company even though we send under a sub-brand." | Carrier filters compare the From-name in the SMS body to the Brand name. Mismatch → filtered as suspicious. |
| "I'll skip External Vetting — it costs money." | Without it, your per-campaign TPS caps low. The throughput math usually pays back the vetting cost in days for a serious sender. |
| "I'll pick `MIXED` to be safe." | `MIXED` raises the review bar without raising throughput. Pick the most specific accurate use case. |
| "I'll add a promo CTA to a 2FA campaign — it's just one line." | 2FA campaigns are required to be code-only. Any promo content gets the campaign downgraded or paused. |
| "The campaign is TCR-approved, so we're fine on every carrier." | Each carrier filters independently. T-Mobile is the most aggressive; test there first. |
| "I'll reuse one campaign across all tenants." | Vetting and filtering follow the Brand and the Campaign. Sharing a campaign across tenants means one bad actor degrades everyone. |

## Red Flags

- Brand name doesn't appear in the message body's From-name
- `MIXED` use case picked because the registrant wasn't sure
- Sample messages don't include the opt-out keyword sentence (`Reply STOP to unsubscribe.`)
- Phone number attached to two campaigns simultaneously
- Campaign IDs hardcoded in application code instead of attached to a Sender Profile
- No reconciliation job watching per-carrier approval state — silent T-Mobile blocks discovered only via delivery analysis
- Promotional content in a campaign classified as `ACCOUNT_NOTIFICATION` or `2FA`

## Verification

A correctly registered tenant has:
- [ ] One TCR Brand with the right external identifier and entity type
- [ ] External Vetting submitted (unless the tenant truly is low-volume)
- [ ] One Campaign per distinct use case — no over-broad `MIXED`
- [ ] Sample messages that match actual production sends and include opt-out language
- [ ] Subscriber opt-in mechanism documented in the campaign attributes
- [ ] Phone numbers attached and not shared across campaigns
- [ ] Per-carrier approval state stored and reconciled on a schedule
- [ ] Sender Profile holds `tcr_brand_id` + `tcr_campaign_id`; nothing in application code is hardcoded

## Related Skills

- `sender-profile-architect` — where the TCR identifiers attach in the data model
- `messaging-performance-analyzer` — diagnosing per-carrier filtering after the campaign is live
