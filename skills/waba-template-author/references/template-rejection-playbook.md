# Template Rejection Playbook — Reference

What to do when Meta rejects a WhatsApp template, silently re-categorizes it,
or pauses it after delivery starts. Companion to `waba-template-categories.md`
and `waba-template-examples.md`. Authoritative source for codes is the official
[Cloud API template docs](https://developers.facebook.com/docs/whatsapp/message-templates).

Every entry: what triggers it, how to detect it from the rejection / status
payload, and what to change before resubmitting.

## Category mismatch (utility classified, marketing content)

**What it looks like:** Template is `APPROVED` but the returned `category` is
`MARKETING` even though you submitted `UTILITY`. Or, after first send, the
status moves to `PENDING` → `APPROVED` again with a flipped category.

**How to detect:** Compare submitted `category` to the post-approval `category`
on the webhook. Re-categorization is the most common silent failure.

**Revise:**
- Strip any sentence that does not refer to the triggering event.
- Replace generic CTAs ("Shop now", "Browse more") with event-specific ones
  ("View order", "Track package").
- Remove second-person calls to action that are not the entity in the message.
- Resubmit under a new version suffix (`_v2`) — the old name is locked.

## Promotional content in utility category

**Banned in utility body, footer, header, button labels:**

- "buy now", "shop now", "order today"
- "limited time", "exclusive", "hurry", "ends soon"
- "special offer", "best deal", "lowest price"
- "discount", "% off", "sale", "free shipping"
- Discount codes like `SAVE20`, even as a variable sample
- Promotional emojis in body or header text (🎉 🛍️ 💸 🔥)

**Revise:** strip the phrase; if the use case genuinely includes a promo,
flip to `MARKETING` rather than masking the wording.

## Missing variable samples

**What it looks like:** Submission fails with `TAG_CONTENT_MISMATCH` or the
template is rejected with "variable example missing".

**Sent's required shape:**

```json
{
  "type": "BODY",
  "text": "Hi {{1}}, your order #{{2}} has shipped.",
  "example": { "body_text": [["Jordan", "A1029"]] }
}
```

`body_text` is an array of arrays — the outer array is "one row per
variable group", and the inner array has one sample per `{{n}}`. Forgetting
the outer array is the single most common cause.

For URL CTAs:

```json
{ "type": "URL", "text": "Track", "url": "https://example.com/orders/{{1}}",
  "example": ["https://example.com/orders/A1029"] }
```

`example` is a flat array here (not nested).

## Authentication template with code formatting error

**What it looks like:** Submission fails with "invalid component" on an
authentication template, or the OTP button does not appear in the rendered
template preview.

**Revise:**
- Use `category: "AUTHENTICATION"` and the dedicated auth component shape, not
  a UTILITY template with a `{{1}}` for the code.
- The body component must use `add_security_recommendation: true` or include
  the platform-managed security recommendation; no freeform `{{1}}` for the code.
- The button component must be `OTP` with `otp_type` of `COPY_CODE` or `AUTOFILL`.
- `code_expiration_minutes` belongs on the FOOTER component, not the body.

See `waba-template-examples.md` for two valid AUTH payloads.

## Button URL doesn't match domain

**What it looks like:** Rejection with "URL does not match business domain"
or the template is approved but later paused for the same reason.

**Revise:**
- Confirm the WABA's verified business domain matches the CTA URL host.
- Subdomains often need to be added separately if Meta's domain check is
  strict — `app.example.com` and `example.com` are not interchangeable.
- For URL CTAs with a variable, the example URL must resolve to the same
  registered domain.
- If you're a multi-tenant platform on Sent, the WABA in question must own
  the domain — you cannot deep-link to a tenant subdomain not registered
  under that WABA.

## Language code mismatch

**What it looks like:** Rejection with `INVALID_LANGUAGE`, or two templates
under the same conceptual name behave inconsistently across recipients.

**Revise:**
- Use BCP-47 codes with the underscore separator: `en_US`, `pt_BR`, `es_MX`.
- Not `en`, not `en-US`, not `en_us`.
- Each language is a *separate template* with its own approval. You cannot
  submit one template and have it cover several locales.

## Generic placeholders (template too generic)

**What it looks like:** Rejection with a content reason ("does not meet
template quality standards") even though the wording is neutral.

**Triggers:**
- Bodies like "{{1}}, here is an update for you" — Meta cannot tell what
  category the template is for, so they default to reject.
- Sample values like `Test`, `Sample`, `XYZ` — these read as if the template
  was never going to be used in production.

**Revise:** add at least one variable that proves the use case (an order ID,
an appointment time, an account-event timestamp) and use realistic sample
values that match.

## Resubmission etiquette and timing

- **One change per resubmission.** If you change wording *and* category *and*
  variables, you cannot tell which change unblocked the template.
- **Use a new version suffix.** `_v1` → `_v2`. Submitting under the same
  `(name, language)` will fail with name-conflict if the prior template is
  still in any state other than `DELETED`.
- **Wait for review before re-resubmitting.** Spamming submissions of the
  same template body slows the queue for the WABA.
- **For PAUSED templates,** revise the content (don't just wait) — Meta
  paused for a reason and an untouched resubmission lands in the same place.
- **For silent re-categorization,** resubmit the *strictest* version of the
  wording even if you intend to send marketing content from it — once the
  category is set, marketing-priced sends still work fine under a stricter
  template.

## Quick triage table

| Symptom | Most likely cause | First fix |
|---|---|---|
| Approved but category flipped | Promotional language Meta detected | Strip wording, resubmit as `_v2` |
| `INVALID_FORMAT` | Component schema typo | Re-check component types and required fields |
| `TAG_CONTENT_MISMATCH` | Variables vs. samples count mismatch | Provide one sample per `{{n}}` in the right shape |
| `META_POLICY_VIOLATION` | Restricted content (alcohol, finance, etc.) | Check Meta's restricted-content policy for the WABA's vertical |
| `INVALID_LANGUAGE` | Bad locale code | Use BCP-47 with underscore |
| Approved then PAUSED | Quality rating dropped post-send | Revise wording, slow down sends, address opt-out rate |
