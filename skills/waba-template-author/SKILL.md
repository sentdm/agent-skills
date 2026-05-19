---
name: waba-template-author
description: Authors WhatsApp Business API message templates and classifies them as utility, marketing, or authentication per Meta's policy. Use when a user mentions "WABA template", "WhatsApp template", "template category", or asks how to write a template for a specific use case (OTP, shipping update, promo, abandoned cart, appointment reminder). Use when classification is ambiguous and the user needs Meta-policy guidance to avoid the marketing surcharge. Use when a template was rejected and they need to revise it.
---

# WABA Template Author

## Overview

Meta classifies every WhatsApp Business template into one of three categories — **utility**, **marketing**, or **authentication** — and prices conversations differently based on that category. Misclassifying a marketing template as utility gets it re-categorized (often silently), inflates billing, and risks template pausing. This skill walks through authoring a template, classifying it correctly, and minimizing rejection risk.

## When to Use

Use when the user is:
- Drafting a new template and needs help with category, components, or variables
- Unsure whether their use case is utility or marketing
- Investigating a rejected template or a template that was re-categorized by Meta
- Building or extending a template library across multiple use cases

Do **not** use this skill for:
- The submission UI itself — use `template-builder-ui`
- Template *performance* analysis (open rate, delivery) — use `messaging-performance-analyzer`

## Classification Decision Tree

```
What triggers the message?
├── User just requested a code or login → AUTHENTICATION
│   (use authentication template type, not a regular template with a code in the body)
│
├── User-initiated event/transaction (purchase, booking, payment, password change,
│   account update, shipping status, appointment, recurring statement) → UTILITY
│   ├── Is the message about THAT event? → UTILITY
│   └── Does it cross-sell, promote, or invite back? → MARKETING
│
└── Business-initiated outreach (announcement, promo, win-back, newsletter,
    abandoned cart, lead nurture, product launch) → MARKETING
```

Heuristics that flip a draft from utility → marketing in Meta's review:
- Discount codes, "shop now", "buy", emojis like 🎉🛍️ in body
- Calls to action that aren't tied to the triggering event
- Re-engagement language ("we miss you", "come back")
- Promotional imagery in the header

## Authoring Workflow

1. **Capture the use case in one sentence.** "After a customer pays, confirm the order and link to the receipt." If you can't write this, the template isn't ready.
2. **Pick the category** using the decision tree. If ambiguous, default to marketing — Meta will too.
3. **Pick the language code.** Use the exact BCP-47 code (`en_US`, `pt_BR`, not `en`). Each language is a separate template.
4. **Design components in order:**
   - **Header** (optional): text (60 char max, 1 variable max) OR media (image/video/document) OR location.
   - **Body** (required): 1024 char max, supports `{{1}}`, `{{2}}`, … placeholders. Every variable needs a sample value at submission.
   - **Footer** (optional): 60 char max, no variables. Use for compliance text ("Reply STOP to opt out").
   - **Buttons** (optional): up to 3 quick replies OR up to 2 call-to-action (URL or phone). Cannot mix quick reply + CTA in the same template.
5. **Insert variables with samples.** Submit `{{1}}` with sample `John`, `{{2}}` with `#A1029`, etc. Meta rejects submissions whose sample text *looks* promotional even if the template wording is neutral.
6. **Name the template** in `snake_case`, prefixed by use case: `order_confirmation_v3`, not `template1`. The name is permanent per (name, language).
7. **Submit and watch the status webhook.** Statuses: `PENDING` → `APPROVED` | `REJECTED` | `PAUSED`. Re-categorization shows up as a status update with a new `category` field.

For component rules, character limits, and the exact Cloud API request shape, see `references/waba-template-categories.md`. For copy-pasteable payloads across all three categories, see `references/waba-template-examples.md`. For revising a rejected or re-categorized template, see `references/template-rejection-playbook.md`.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "It's clearly utility, I'll mark it utility and save money." | Meta's classifier reviews wording, buttons, and intent. Aggressive classification gets templates re-categorized within hours of first send. |
| "I'll put the discount in the footer so it stays utility." | Promotional content anywhere in the template — body, footer, header media, button labels — flips it to marketing. |
| "The header image is just branding." | A promotional header image (sale banner, product collage) re-categorizes the template. Use neutral imagery or skip the header. |
| "Variables let me reuse one template for promos and receipts." | Re-categorization is per-template, not per-message. One promotional send paused for that template hurts every other use case sharing it. |
| "Auth templates work like utility templates with an OTP variable." | Authentication templates are a distinct template type with their own component schema, button rules, and validity-period support. Don't put OTPs in regular templates. |

## Red Flags

- The draft's body would feel natural in an email newsletter → marketing, not utility
- The CTA button leads to a homepage or category page → marketing
- The same template is being asked to cover "confirmation AND upsell" → split into two templates
- Sample variable values include offer codes, discounts, or product lists → reclassify to marketing before submitting
- The template name contains `promo`, `offer`, `winback`, or `cross_sell` but the category is utility

## Verification

Before submitting, confirm:
- [ ] Use case fits in one sentence and the category follows the decision tree
- [ ] Every variable has a non-promotional sample value
- [ ] Buttons are either all quick replies OR all CTAs, not mixed
- [ ] Header text/footer text are within character limits (60 each)
- [ ] Body is ≤ 1024 chars and reads as if it could be sent without any promotional intent
- [ ] Language code is BCP-47 (`en_US`, not `en`)
- [ ] Name is `snake_case` and includes a version suffix (`_v1`, `_v2`)

After submission, confirm:
- [ ] Status webhook fired with `APPROVED` (not `PENDING` indefinitely — that often means review failure)
- [ ] Category in the approval matches what you submitted; if Meta re-categorized, revise wording and resubmit under a new version

## Bundled references and scripts

| Path | What it is |
|---|---|
| `references/waba-template-categories.md` | Meta category boundaries, component rules, Cloud API submission shape |
| `references/waba-template-examples.md` | Worked, copy-pasteable payloads for all three categories |
| `references/template-rejection-playbook.md` | Rejection-reason field guide and resubmission etiquette |
| `scripts/lint_waba_template.py` | Stdlib lint for a template JSON payload (placeholder numbering, samples, category checks) |
| `scripts/fixtures/utility_good.json` | Passing fixture for the linter |
| `scripts/fixtures/utility_bad.json` | Failing fixture (wrong placeholder order, promo phrasing in utility) |

Run: `python skills/waba-template-author/scripts/lint_waba_template.py template.json`

## Related skills

- `template-builder-ui` — the tenant-facing form that produces submissions following these rules
- `messaging-performance-analyzer` — post-send analysis of how the approved template performs
- See top-level `references/sent-glossary.md` for shared Sent terminology.
