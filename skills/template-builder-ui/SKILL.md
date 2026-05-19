---
name: template-builder-ui
description: Designs and implements the tenant-facing UI for drafting and submitting WhatsApp templates to Sent. Use when building a template editor, variable picker, component editor (header/body/footer/buttons), live WhatsApp-style preview, category selector, or submission form. Use when a user mentions "template builder", "template editor UI", "tenant template submission", or "make it easy for tenants to build templates". Use when porting Meta's submission rules into client-side validation. Cross-references waba-template-author for the underlying policy.
---

# Template Builder UI

## Overview

Tenants don't read Meta's template policy — they expect the UI to keep them on the rails. A good template builder catches every Meta rejection reason *before* the user clicks submit, renders a faithful WhatsApp preview as they type, and converts "I want to send a notification" into a valid Cloud API submission payload. This skill is the UX + implementation playbook.

## When to Use

Use when:
- Building or refactoring a tenant template editor
- Implementing the live preview pane
- Adding a category picker that explains utility vs marketing vs authentication
- Mirroring Meta's component, character, and button rules in client-side validation
- Designing the submission feedback loop (status webhook → UI state)

Do **not** use for:
- The category decision logic itself — that lives in `waba-template-author`
- Backend submission to Meta's API — that's an integration concern, not UI

## The Editor Anatomy (build in this order)

```
┌─────────────────────────────────────────────────────┐
│ 1. Category picker     (utility / marketing / auth) │  ← affects every field below
│ 2. Name + language     (snake_case + BCP-47)        │  ← immutable after first save
├─────────────────────────────────────────────────────┤
│ 3. Components (live-validated)        │  4. Preview │
│    ├── Header (optional)              │   ┌───────┐ │
│    │   ├── type: text / image / video │   │       │ │
│    │   └── max 1 variable             │   │ chat  │ │
│    ├── Body (required)                │   │bubble │ │
│    │   ├── 1024 char max              │   │       │ │
│    │   └── variables with samples     │   └───────┘ │
│    ├── Footer (optional, 60 char)     │             │
│    └── Buttons (quick reply OR CTA)   │             │
├─────────────────────────────────────────────────────┤
│ 5. Variable sample editor (sticky)                  │
│ 6. Submit + rejection-feedback panel                │
└─────────────────────────────────────────────────────┘
```

### Category Picker (Step 1)

Show all three categories with one-line definitions and an example. Make this the **first** field; everything downstream depends on it.

- **Utility** — Triggered by a user action (order placed, appointment booked, password reset). Example: "Your order #1029 has shipped."
- **Marketing** — Business-initiated promo or outreach. Example: "Black Friday 50% off — shop now."
- **Authentication** — OTPs and login codes. Uses a separate template type with special button rules.

Selecting **authentication** swaps the entire component editor to the auth-template shape — the body is read-only ("Your code is {{1}}. For your security, do not share this code."), buttons collapse to a single "Copy code" or "One-tap" choice, and a `code_expiration_minutes` field appears.

### Name + Language (Step 2)

- Enforce `^[a-z][a-z0-9_]{0,511}$` on name; auto-`snake_case` what the user types
- Surface the rule that `(name, language)` is permanent — show a `_v1` suffix suggestion to make versioning ergonomic
- Language picker: BCP-47 from Meta's supported list, not a free-form input. Show the locale name plus the code (`en_US — English (US)`).

### Component Editor (Step 3)

- **Header**: radio for type (none / text / image / video / document / location). Only show the corresponding sub-form. Text header is 60 chars and one variable. Media headers want a sample URL or upload — pre-validate by HEADing the URL on blur.
- **Body**: contenteditable or textarea, with inline variable chips. When the user types `{{`, autocomplete the next available index. Show running char count vs 1024. Variables must be inserted in order (`{{1}}` before `{{2}}`); detecting gaps is one of Meta's silent rejection reasons.
- **Footer**: single-line input, 60 chars, no variables. Show character counter.
- **Buttons**: a button-type radio at the top — *no buttons* / *quick replies* / *CTAs*. Disabling the third option once the user has chosen one of the first two prevents the "mixed buttons" rejection.
  - Quick replies: up to 3, 25 char labels.
  - CTAs: up to 2, mixable across URL and phone-number. URL CTAs may take one trailing variable (`https://sent.example/orders/{{1}}`).

### Variable Sample Editor (Step 5)

Pin a sticky panel at the bottom or right edge. As the user inserts variables, add a labeled row: `{{1}} — sample: [ John ]`. Submission to Meta requires non-empty samples; an empty input here should block the submit button.

Critical: warn the user when sample values look promotional. Run a simple regex check (`/\b(off|sale|discount|deal|free|now)\b/i`) on samples and flash a "samples should be neutral" warning. Most surprise re-categorizations trace back to promotional samples.

### Live Preview (right pane)

- Render the template as a WhatsApp chat bubble (green-on-cream for outgoing). Use a fixed-width 320px column to match a phone.
- Substitute samples in real time. If samples are empty, show `{{1}}` literally and dim it to signal "this will fail".
- Render media headers as placeholders if no upload yet. Don't load remote URLs in the preview — proxy or sandbox them; tenants can paste hostile URLs.

### Submission Feedback (Step 6)

- On submit, send to your backend, which POSTs to Meta. Show an optimistic `PENDING` row in the template list immediately.
- Subscribe the UI to template-status webhooks via your existing realtime channel. On `APPROVED` / `REJECTED` / `PAUSED`, update the row.
- On `REJECTED`, show Meta's `reason` plus a human-friendly remediation hint mapped from the rejection-code dictionary. Don't show the raw Meta JSON.
- On silent re-categorization (status stays APPROVED but `category` changes), surface a banner — this is otherwise invisible to tenants and they get billed for marketing.

## Validation Strategy

Validate at three layers, mirror the same rules in each:
1. **Inline** (as-you-type): char counts, variable order, button-type-mixed.
2. **Pre-submit**: full schema check, sample completeness, media URL HEAD check.
3. **Server-side**: re-validate before forwarding to Meta — clients lie.

Express the rule set as a single source-of-truth schema (Zod, JSON Schema, etc.) and reuse it across the three layers.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll show all 3 category options and let Meta sort it out." | Submissions take 1-30 min to review; tenants hate the cycle. Catch the policy issue in the UI. |
| "Live preview can render media headers from any URL." | Tenant-controlled URLs in the preview iframe = XSS / SSRF surface. Proxy or sandbox. |
| "Sample values are an afterthought." | They're the #1 cause of re-categorization. The UI must make them prominent, not optional. |
| "Button type is just three checkboxes." | Quick replies and CTAs cannot coexist; expose the choice as a radio at the top, not per-button. |
| "Re-categorization is rare — I don't need a banner." | It's silent and billed. Tenants assume APPROVED means stable. The banner is the only way they'll know. |

## Red Flags

- A category picker that's a dropdown buried in step 4
- Variable inserts without an autocomplete index
- A preview that loads remote URLs directly into the page
- No client-side variable-sample input — the user discovers it on submit
- Buttons UI that allows mixing quick replies with CTAs
- Rejection feedback that shows raw Meta JSON
- No realtime update — tenant has to refresh to see APPROVED

## Verification

The editor is done when:
- [ ] All Meta component rules are encoded in a single validation schema, reused inline + pre-submit + server-side
- [ ] Category selection happens first and reshapes the editor when switching to authentication
- [ ] Preview renders within 200ms of keystroke and never fetches remote URLs directly
- [ ] Variable samples are required, with a promotional-language warning
- [ ] Mixed button types are impossible to construct in the UI
- [ ] Status webhook events update the template row in realtime
- [ ] Silent re-categorization surfaces as a visible tenant-facing banner
- [ ] Accessibility: full keyboard navigation, ARIA labels on component editors, color contrast ≥4.5:1 on the preview

## Related Skills

- `waba-template-author` — the category decision tree and policy details the UI enforces
- `messaging-performance-analyzer` — once templates are live, this is how you measure them
