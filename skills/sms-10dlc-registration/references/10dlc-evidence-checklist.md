# 10DLC Evidence Checklist — Sent Compliance Form

Supporting reference for `sms-10dlc-registration`. This is the definitive list of fields a tenant must supply on Sent's 10DLC compliance form before Sent files the TCR brand + campaign on their behalf. Each row maps a tenant-facing input to the TCR payload field it populates, the format expected, and the most common reasons a submission gets bounced back for revision.

Use this alongside `references/tcr-use-cases.md` when authoring the form, validating an incoming packet, or debugging why a customer's submission failed pre-flight checks. Run `scripts/validate_10dlc_packet.py` against a JSON dump of the packet for the mechanical checks.

## Required fields

### 1. Legal business name

- **Format:** Exact name as registered with the state or IRS. Including the suffix (`LLC`, `Inc.`, `Corp.`, `LLP`).
- **Maps to:** TCR `Brand.entityName`.
- **Common mistakes:**
  - Submitting a DBA, marketing brand, or trade name instead of the legal entity. Sent will reject if the EIN-to-name match fails at the IRS lookup step.
  - Trailing punctuation (`Acme, Inc.,`) — strip the trailing comma.
  - Mismatched capitalization vs IRS records. Lookups are case-insensitive but the audit trail flags drift.
- **Sent tip:** If the customer uses a different consumer-facing brand, that goes in the campaign sample-message `{Brand Name}` token, not here.

### 2. EIN (Employer Identification Number)

- **Format:** US federal tax ID. Nine digits, with or without the standard hyphen: `12-3456789` or `123456789`. Regex: `^\d{2}-?\d{7}$`.
- **Maps to:** TCR `Brand.einIssuingCountry = US` plus `Brand.ein`.
- **Common mistakes:**
  - Confusing EIN with SSN (sole proprietors). Sole props with no EIN should pick the sole-proprietor brand flow — see `references/tcr-use-cases.md`.
  - Submitting a state tax ID instead of the federal EIN.
  - Typos in the first two digits (the IRS prefix). These fail the IRS match every time.
- **Non-US tenants:** Use DUNS, GIIN, or LEI instead — the form accepts one strong identifier.

### 3. Business address

- **Format:** Street, city, state (US two-letter), postal code, country. PO boxes are not accepted by TCR for primary brand address.
- **Maps to:** TCR `Brand.street`, `Brand.city`, `Brand.state`, `Brand.postalCode`, `Brand.country`.
- **Common mistakes:**
  - Using a mail-forwarding or virtual-office address that doesn't match the address on file with the IRS for the EIN.
  - Country code mismatches (`USA` vs `US`). TCR wants ISO 3166-1 alpha-2 (`US`).

### 4. Live website URL

- **Format:** Full URL with scheme. `https://example.com` or `https://acme.example.com/`. Must resolve at the time of submission.
- **Maps to:** TCR `Brand.website`.
- **Common mistakes:**
  - Staging or Vercel preview URLs that go down or 401.
  - Domains without TLS — TCR vetting downgrades non-HTTPS sites.
  - Coming-soon pages with no description of the business. Reviewers expect to see the brand's actual product / service.

### 5. Privacy policy URL

- **Format:** Direct URL to a public privacy policy that mentions SMS data handling.
- **Maps to:** TCR `Campaign.privacyPolicyLink`.
- **Common mistakes:**
  - Pointing at the homepage instead of the policy page.
  - Privacy policy doesn't mention SMS, message frequency, data sharing, or carrier disclaimers. Carriers spot-check this.
  - 404 or auth-walled URL.

### 6. Opt-in mechanism URL

- **Format:** Public URL showing the exact form, checkbox, or flow where end users consent to receive SMS. A screenshot is acceptable as a fallback (hosted publicly) but a live URL is strongly preferred.
- **Maps to:** TCR `Campaign.subscriberOptIn` (boolean + description) and the campaign attachments.
- **Common mistakes:**
  - Linking to a checkout flow without showing the SMS-consent checkbox.
  - Consent language that bundles SMS with marketing email — TCR wants SMS-specific consent.
  - Pre-checked consent boxes (forbidden under most state laws and TCR policy).

### 7. Use-case description

- **Format:** 1-3 sentences explaining what messages the tenant sends, to whom, and when.
- **Maps to:** TCR `Campaign.description`.
- **Common mistakes:**
  - Generic descriptions ("transactional messages"). Reviewers want specifics: "Shipping and delivery updates for orders placed on acme.example.com."
  - Description doesn't match the TCR use-case code (e.g. describing promotional content under `ACCOUNT_NOTIFICATION`).

### 8. Sample messages (≥ 1 per use case)

- **Format:** Plain-text examples of actual production messages, with `{Variable}` placeholders. Must include the brand name and an opt-out instruction.
- **Maps to:** TCR `Campaign.sample1`, `sample2`, ... `sample5`.
- **Common mistakes:**
  - Under 20 characters. Reviewers flag these as too generic.
  - Missing `Reply STOP to opt out.` (or carrier-compliant variant).
  - Including a URL shortener that isn't on the brand's verified-domains list.
  - Sample doesn't match the declared use case (promo content in a `2FA` sample).

### 9. Opt-out instruction text

- **Format:** Plain text the tenant commits to including in their auto-reply when a user texts `STOP`. Must reference the brand name.
- **Maps to:** TCR `Campaign.optOutMessage`.
- **Common mistakes:**
  - Text doesn't actually contain `STOP`.
  - No brand name in the confirmation ("You're unsubscribed." vs "Acme: You're unsubscribed from order updates.").

### 10. Support contact

- **Format:** Email, phone, or URL for end-user support.
- **Maps to:** TCR `Brand.email` and `Campaign.helpMessage`.
- **Common mistakes:**
  - Pointing at a no-reply or unmonitored inbox. Reviewers test it.
  - Mismatched between brand support contact and the `HELP` auto-reply.

## After the form is submitted

Sent's pre-flight runs `scripts/validate_10dlc_packet.py` against the JSON dump of these answers. Issues at this stage are cheap to fix — once filed with TCR a rejection costs days of round-trip. See `references/10dlc-rejection-remediation.md` for what to do when TCR or a carrier bounces a submission that passed pre-flight.
