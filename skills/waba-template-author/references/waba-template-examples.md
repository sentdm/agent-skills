# WABA Template Examples — Reference

Worked, copy-pasteable WhatsApp template payloads grouped by Meta category.
Companion to `waba-template-categories.md`. Every example is a complete request
body in the shape Sent forwards to the Cloud API's `POST /v23.0/{waba_id}/message_templates`
endpoint. Variable placeholders use `{{1}}`, `{{2}}` and a matching `example`
block; if you copy these, change the names and IDs to placeholders that match
your tenant's actual data, but keep the structure.

> Synthetic values only — no real WABA IDs, brand names, or customer data.

## Utility

### 1. Order confirmation

Triggered by checkout. About that order. Single URL CTA bound to the order.

```json
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
      "text": "Hi {{1}}, your order #{{2}} is confirmed. We will let you know when it ships.",
      "example": { "body_text": [["Jordan", "A1029"]] }
    },
    {
      "type": "FOOTER",
      "text": "Reply STOP to opt out."
    },
    {
      "type": "BUTTONS",
      "buttons": [
        {
          "type": "URL",
          "text": "View order",
          "url": "https://example.com/orders/{{1}}",
          "example": ["https://example.com/orders/A1029"]
        }
      ]
    }
  ]
}
```

Why this is approved as utility: every component refers to the order, the CTA
deep-links to that order, no promotional language, no cross-sell.

### 2. Shipping update

Triggered by carrier scan. Variables are numbered 1..3 sequentially.

```json
{
  "name": "shipping_update_v2",
  "language": "en_US",
  "category": "UTILITY",
  "components": [
    {
      "type": "BODY",
      "text": "Hi {{1}}, package #{{2}} is out for delivery and should arrive by {{3}}.",
      "example": { "body_text": [["Jordan", "A1029", "6 PM today"]] }
    },
    {
      "type": "BUTTONS",
      "buttons": [
        {
          "type": "URL",
          "text": "Track package",
          "url": "https://example.com/track/{{1}}",
          "example": ["https://example.com/track/A1029"]
        }
      ]
    }
  ]
}
```

Why approved: status-only language, sample values are neutral, CTA points to the
tracking page for that specific package.

### 3. Appointment reminder

Triggered by user-booked appointment. Quick-reply buttons stay within the same
appointment — confirm or reschedule, no upsell.

```json
{
  "name": "appointment_reminder_v1",
  "language": "en_US",
  "category": "UTILITY",
  "components": [
    {
      "type": "BODY",
      "text": "Hi {{1}}, this is a reminder of your appointment with {{2}} on {{3}} at {{4}}.",
      "example": { "body_text": [["Jordan", "Dr. Patel", "Mon May 18", "10:30 AM"]] }
    },
    {
      "type": "FOOTER",
      "text": "Reply STOP to opt out."
    },
    {
      "type": "BUTTONS",
      "buttons": [
        { "type": "QUICK_REPLY", "text": "Confirm" },
        { "type": "QUICK_REPLY", "text": "Reschedule" }
      ]
    }
  ]
}
```

Why approved: every button action is tied to the appointment itself; no
"Book another visit" or other cross-sell.

## Marketing

### 1. Promo announcement

Business-initiated, discount code in the body. Unambiguously marketing.

```json
{
  "name": "spring_promo_v1",
  "language": "en_US",
  "category": "MARKETING",
  "components": [
    {
      "type": "BODY",
      "text": "Hi {{1}}, our spring sale is on — use code {{2}} for 20% off through Sunday.",
      "example": { "body_text": [["Jordan", "SPRING20"]] }
    },
    {
      "type": "FOOTER",
      "text": "Reply STOP to opt out."
    },
    {
      "type": "BUTTONS",
      "buttons": [
        {
          "type": "URL",
          "text": "Shop now",
          "url": "https://example.com/sale",
          "example": ["https://example.com/sale"]
        }
      ]
    }
  ]
}
```

### 2. Re-engagement (win-back)

```json
{
  "name": "winback_30d_v1",
  "language": "en_US",
  "category": "MARKETING",
  "components": [
    {
      "type": "BODY",
      "text": "Hi {{1}}, we miss you! Here is 15% off your next order with code {{2}}.",
      "example": { "body_text": [["Jordan", "COMEBACK15"]] }
    },
    {
      "type": "BUTTONS",
      "buttons": [
        { "type": "QUICK_REPLY", "text": "Shop deals" },
        { "type": "QUICK_REPLY", "text": "Browse new" }
      ]
    }
  ]
}
```

### 3. Seasonal announcement

```json
{
  "name": "holiday_drop_v1",
  "language": "en_US",
  "category": "MARKETING",
  "components": [
    {
      "type": "HEADER",
      "format": "IMAGE",
      "example": { "header_handle": ["4::aW1hZ2Uvc2FtcGxl"] }
    },
    {
      "type": "BODY",
      "text": "Hi {{1}}, our holiday collection just dropped. Take a look before it sells out.",
      "example": { "body_text": [["Jordan"]] }
    },
    {
      "type": "BUTTONS",
      "buttons": [
        {
          "type": "URL",
          "text": "See collection",
          "url": "https://example.com/holiday",
          "example": ["https://example.com/holiday"]
        }
      ]
    }
  ]
}
```

## Authentication

Authentication templates use the dedicated authentication type, not a body
variable masquerading as a code.

### 1. One-time code with copy button

```json
{
  "name": "login_otp_v1",
  "language": "en_US",
  "category": "AUTHENTICATION",
  "components": [
    {
      "type": "BODY",
      "add_security_recommendation": true
    },
    {
      "type": "FOOTER",
      "code_expiration_minutes": 10
    },
    {
      "type": "BUTTONS",
      "buttons": [
        { "type": "OTP", "otp_type": "COPY_CODE", "text": "Copy code" }
      ]
    }
  ]
}
```

Why approved: uses the AUTHENTICATION template type, the body uses the
managed code variable (not a freeform `{{1}}`), and the button is the
auth-only `COPY_CODE` action.

### 2. Password reset confirmation

Confirming a completed reset — UTILITY-shaped behaviorally but submitted under
AUTHENTICATION when the platform groups the flow under auth events.

```json
{
  "name": "password_reset_confirm_v1",
  "language": "en_US",
  "category": "AUTHENTICATION",
  "components": [
    {
      "type": "BODY",
      "add_security_recommendation": true
    },
    {
      "type": "FOOTER",
      "code_expiration_minutes": 5
    },
    {
      "type": "BUTTONS",
      "buttons": [
        { "type": "OTP", "otp_type": "COPY_CODE", "text": "Copy code" }
      ]
    }
  ]
}
```

If you only want a plain confirmation (no code), submit it as UTILITY instead:

```json
{
  "name": "password_changed_v1",
  "language": "en_US",
  "category": "UTILITY",
  "components": [
    {
      "type": "BODY",
      "text": "Your account password was changed on {{1}}. If this was not you, contact support.",
      "example": { "body_text": [["Mon May 18, 10:32 AM"]] }
    }
  ]
}
```

## Things to copy

- Variable numbering is always `{{1}}, {{2}}, {{3}}` in order of first appearance.
- `example.body_text` is an array-of-arrays — each inner array is one full row of samples.
- URL CTA examples must be the fully-resolved URL, not the template.
- Footers cannot contain variables — keep compliance-only language there.
