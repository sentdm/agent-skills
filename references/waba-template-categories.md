# WABA Template Categories — Reference

Supporting reference for `waba-template-author`. Excerpts from Meta's template
policy plus practical mappings to common use cases. Authoritative source:
[WhatsApp Business Platform > Message Templates](https://developers.facebook.com/docs/whatsapp/message-templates).

> The Meta policy evolves frequently — verify the current rules in the official
> docs before relying on edge cases. This reference captures stable patterns and
> the boundaries that have been consistent through 2024–2026.

## The Three Categories

### Utility
Triggered by a user action or a recurring event the user already opted into. The
message is *about that event*. Lowest-priced category.

**Eligible use cases (non-exhaustive):**
- Order placed / shipped / delivered
- Appointment confirmation, reminder, change
- Booking confirmation
- Account balance, statement, invoice
- Password change confirmation (note: *not* the OTP itself — that's authentication)
- Service status: outage, restoration, maintenance window
- Payment received / failed / overdue notice
- Recurring statement or subscription renewal notice
- Form / application status update

**Disqualifiers — if any of these are true, Meta will reclassify to marketing:**
- The message cross-sells, upsells, or invites the user back
- The CTA button leads anywhere other than the entity the message is about
  (an order-confirmation button must link to that order, not the homepage)
- Promotional language ("hurry", "limited", "exclusive", "sale", "deal")
- Discount codes, percentages off, or "use code X" content
- Promotional imagery in a media header

### Marketing
Business-initiated outreach with the intent to drive a new action — purchase,
visit, signup, re-engagement. Highest-priced category.

**Eligible use cases:**
- Promo / sale announcement
- Abandoned cart recovery
- Welcome-back / win-back
- Newsletter / content drop
- Product launch
- Event invitation (when the event is promotional, not transactional)
- Survey or feedback request (when not tied to a specific transaction)

There is no penalty for marketing templates; the penalty is for *labeling*
them as utility. When in doubt, ship as marketing.

### Authentication
A separate template type, not just a category. Used for one-time codes, login
verification, account-recovery codes.

**Distinct rules:**
- Body is constrained: "{{1}} is your verification code." plus optional security
  disclaimer ("For your security, do not share this code.")
- Buttons collapse to a single button: "Copy code" or "Autofill" (one-tap, mobile only)
- Supports `code_expiration_minutes` field
- Cannot include marketing or utility content
- Lower per-message cost; some regions price authentication separately

## Component Rules

### Header (optional)
- Type: `TEXT` | `IMAGE` | `VIDEO` | `DOCUMENT` | `LOCATION`
- Text: max 60 chars, max 1 variable
- Media: provide a sample URL or media handle at submission
- Location: lat/long pair for sample, structured location at send time

### Body (required)
- Max 1024 chars
- Supports `{{1}}`, `{{2}}`, … placeholders
- Variables must be sequential (no gaps); every variable needs a sample
- No URLs in body (link via CTA buttons instead) for most categories; exceptions exist

### Footer (optional)
- Max 60 chars
- No variables
- Common use: compliance text, opt-out instructions

### Buttons (optional)
- *Either* quick replies *or* CTA buttons, never both
- Quick replies: up to 3, max 25 chars per label
- CTAs: up to 2, types: `URL` or `PHONE_NUMBER`
  - URL CTAs may include one trailing variable: `https://sent.example/orders/{{1}}`
  - URL CTAs require an example URL for submission

## Submission Payload Shape (Cloud API)

```json
POST /v20.0/{waba_id}/message_templates
{
  "name": "order_confirmation_v1",
  "language": "en_US",
  "category": "UTILITY",
  "components": [
    {
      "type": "HEADER",
      "format": "TEXT",
      "text": "Order #{{1}} confirmed",
      "example": { "header_text": ["A1029"] }
    },
    {
      "type": "BODY",
      "text": "Hi {{1}}, your order #{{2}} has been confirmed and will ship soon. Track it any time below.",
      "example": { "body_text": [["John", "A1029"]] }
    },
    {
      "type": "FOOTER",
      "text": "Reply STOP to unsubscribe."
    },
    {
      "type": "BUTTONS",
      "buttons": [
        {
          "type": "URL",
          "text": "Track order",
          "url": "https://sent.example/orders/{{1}}",
          "example": ["https://sent.example/orders/A1029"]
        }
      ]
    }
  ]
}
```

## Common Rejection Reasons (from Meta's API)

| Code / phrase | Meaning | Fix |
|---|---|---|
| `INVALID_FORMAT` | Component schema broken | Re-validate against the component rules above |
| `TAG_CONTENT_MISMATCH` | Variable count differs from samples | Provide a sample for every `{{n}}` |
| `META_POLICY_VIOLATION` | Content violates content policy | Remove promotional content, slurs, or restricted-category content |
| `INVALID_LANGUAGE` | Language code unsupported | Use BCP-47 (`en_US`, not `en`) and one from Meta's supported list |
| Silent reclassification | Approved but category changed | Body/buttons/header read promotional even if the use case is utility |

## Worked Examples — Decision Tree in Action

**"Your order #1029 has shipped. Track it here."**
- Triggered by purchase? Yes. About the purchase? Yes. CTA is order-specific? Yes.
- → **UTILITY**, single URL CTA.

**"Your order #1029 has shipped. Check out our new arrivals!"**
- Triggered by purchase? Yes. About the purchase? No — second sentence is a promo.
- → **MARKETING** (or split into two templates).

**"Your account password was changed."**
- Triggered by user action? Yes (they changed it). About that action? Yes.
- → **UTILITY**. (The OTP that authorized the change is **AUTHENTICATION**, separate template.)

**"We miss you — here's 20% off your next order."**
- Business-initiated, re-engagement, discount.
- → **MARKETING**, unambiguously.

**"Your code is 729451. For your security, do not share this code."**
- One-time code for login.
- → **AUTHENTICATION** template type. Not a utility template with a code in the body.
