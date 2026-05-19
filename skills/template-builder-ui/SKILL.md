---
name: template-builder-ui
description: Designs and implements the tenant-facing UI for drafting and submitting WhatsApp templates to Sent. Use when building a template editor, variable picker, component editor (header/body/footer/buttons), live WhatsApp-style preview, category selector, or submission form. Use when a user mentions "template builder", "template editor UI", "tenant template submission", or "make it easy for tenants to build templates". Use when porting Meta's submission rules into client-side validation. Cross-references waba-template-author for the underlying policy. Do not use for generic templating engines (Jinja, Handlebars, Mustache, email/HTML templates) or non-Sent template systems.
---

# Template Builder UI

## Overview

Tenants don't read Meta's template policy — they expect the UI to keep them on the rails. A good template builder catches every Meta rejection reason *before* the user clicks submit, renders a faithful WhatsApp preview as they type, and converts "I want to send a notification" into a valid Cloud API submission payload. This skill is the WhatsApp-specific UX playbook — the parts where Meta's rules force decisions a generic form builder won't make on its own.

## When to Use

Use when:
- Building or refactoring a tenant template editor
- Implementing the live WhatsApp preview pane
- Adding a category picker that explains utility vs marketing vs authentication
- Mirroring Meta's component, character, and button rules in client-side validation
- Designing the submission feedback loop (status webhook → UI state)

Do **not** use for:
- The category decision logic itself — that lives in `waba-template-author`
- Backend submission to Meta's API — that's an integration concern, not UI
- SMS or RCS template editors — those are a separate UX problem (no live preview equivalent, no category, no header/body/footer split)

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

- Enforce `^[a-z][a-z0-9_]{0,511}$` on name; auto-`snake_case` what the user types.
- Surface the rule that `(name, language)` is permanent — show a `_v1` suffix suggestion to make versioning ergonomic.
- Language picker: BCP-47 from Meta's supported list, not a free-form input. Show the locale name plus the code (`en_US — English (US)`).

### Component Editor (Step 3)

The WhatsApp-specific rules the editor must enforce:

- **Header**: radio for type (none / text / image / video / document / location). Only show the corresponding sub-form. Text header is 60 chars and one variable.
- **Body**: when the user types `{{`, autocomplete the next available index. Show running char count vs 1024. Variables must be inserted *in order* (`{{1}}` before `{{2}}`) — gaps are a silent Meta rejection reason.
- **Footer**: single-line input, 60 chars, no variables.
- **Buttons**: a button-type radio at the top — *no buttons* / *quick replies* / *CTAs*. The radio is what prevents the "mixed buttons" rejection — never offer per-button type selection.
  - Quick replies: up to 3, 25 char labels.
  - CTAs: up to 2, mixable across URL and phone-number. URL CTAs may take one trailing variable (e.g. `https://example.com/orders/{{1}}`).

### Variable Sample Editor (Step 5)

Pin a sticky panel at the bottom or right edge. As the user inserts variables, add a labeled row: `{{1}} — sample: [ John ]`. Submission to Meta requires non-empty samples; an empty input here should block the submit button.

Critical, and WhatsApp-specific: **warn the user when sample values look promotional**. A simple word check (`off`, `sale`, `discount`, `deal`, `free`, `now`, …) on samples should flash a "samples should be neutral" warning. Most surprise re-categorizations trace back to promotional samples.

### Live Preview (right pane)

Render the template as a WhatsApp chat bubble (green-on-cream for outgoing). Substitute samples in real time. If samples are empty, show `{{1}}` literally and dim it to signal "this will fail submission". Render media headers as placeholders until uploaded.

### Submission Feedback (Step 6)

- On submit, send to your backend, which POSTs to Meta. Show an optimistic `PENDING` row in the template list immediately.
- Subscribe the UI to template-status webhooks via your existing realtime channel. On `APPROVED` / `REJECTED` / `PAUSED`, update the row.
- On `REJECTED`, show Meta's `reason` plus a human-friendly remediation hint mapped from the rejection-code dictionary. Don't show the raw Meta JSON.
- **On silent re-categorization** (status stays APPROVED but `category` changes), surface a banner — this is otherwise invisible to tenants and they get billed for marketing without realizing it.

## Validation Strategy

Express Meta's rule set as a single source-of-truth schema and reuse it on the client, in the submission handler, and right before forwarding to Meta. Mirror, don't duplicate — the rules in the three layers must agree exactly.

See `references/template-validation-matrix.md` for the per-channel rule table (SMS / WhatsApp / RCS) and how each failure should surface in the UI. See `references/template-ui-wireflows.md` for the full set of UX flows the builder must support (create-from-scratch, clone, Meta import, JSON paste, edit, submit, reject-recover). See `references/template-status-handling.md` for the lifecycle states, webhook-vs-polling tradeoff, and resubmission flow.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll show all 3 category options and let Meta sort it out." | Submissions take 1-30 min to review; tenants hate the cycle. Catch the policy issue in the UI. |
| "Sample values are an afterthought." | They're the #1 cause of re-categorization. The UI must make them prominent, not optional. |
| "Button type is just three checkboxes." | Quick replies and CTAs cannot coexist; expose the choice as a radio at the top, not per-button. |
| "Re-categorization is rare — I don't need a banner." | It's silent and billed. Tenants assume APPROVED means stable. The banner is the only way they'll know. |

## Red Flags

- A category picker that's a dropdown buried in step 4
- Variable inserts without an autocomplete index — tenants will type `{{3}}` before `{{1}}` and not realize Meta rejects it
- No client-side variable-sample input — the user discovers it on submit
- Buttons UI that allows mixing quick replies with CTAs
- Rejection feedback that shows raw Meta JSON
- No realtime update — tenant has to refresh to see APPROVED
- No banner when Meta silently re-categorizes a template

## Verification

The editor is done when:
- [ ] Meta's component rules are encoded in one schema reused across client, submission handler, and Meta-forwarding code
- [ ] Category selection happens first and reshapes the editor when switching to authentication
- [ ] Variable samples are required, with a promotional-language warning
- [ ] Mixed button types are impossible to construct in the UI
- [ ] Status webhook events update the template row in realtime
- [ ] Silent re-categorization surfaces as a visible tenant-facing banner

## Related Skills

- `waba-template-author` — the category decision tree and policy details the UI enforces
- `messaging-performance-analyzer` — once templates are live, this is how you measure them
- See top-level `references/sent-glossary.md` for shared Sent terminology.
