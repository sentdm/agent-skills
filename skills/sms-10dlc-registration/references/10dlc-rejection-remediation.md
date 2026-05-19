# 10DLC Rejection Remediation — Reference

Supporting reference for `sms-10dlc-registration`. When TCR or a US carrier rejects a brand or campaign, the rejection code is often opaque. This doc maps the rejections Sent sees most often to detection signals, concrete fix steps, and re-submission etiquette so the next round of review goes through cleanly.

Pair with `references/10dlc-evidence-checklist.md` (what should be in the packet) and `references/tcr-use-cases.md` (taxonomy). Run `scripts/validate_10dlc_packet.py` against the corrected packet before re-submitting.

## Rejection taxonomy

Rejections come in two layers:

1. **TCR-side** — the brand or campaign was rejected before it ever reached carriers. Faster turnaround. Most often: missing data, EIN-name mismatch, content that violates TCR policy.
2. **Carrier-side** — TCR approved the campaign, but one or more of T-Mobile, AT&T, Verizon, or an MVNO declined. The campaign's per-carrier state will show `DECLINED` or `SUSPENDED`. Carrier decisions are slower to reverse and require evidence updates before re-submission.

Always identify the layer first — the fix path is different.

## 1. Brand verification failure (`UNVERIFIED`, `VETTING_FAILED`)

- **Detect:** TCR brand status moves to `UNVERIFIED` or external vetting returns `FAILED`. Sent surfaces this as `brand.status != VERIFIED` on the Sender Profile.
- **Root causes:**
  - EIN doesn't match the IRS record for the supplied legal name.
  - Brand address doesn't match the IRS or state filing.
  - Submitted entity type (`PRIVATE_PROFIT` vs `NON_PROFIT`) contradicts the IRS record.
- **Fix steps:**
  1. Re-pull the tenant's IRS EIN confirmation letter (Form CP-575) and reconcile name, address, and entity type field-by-field.
  2. Correct the brand record in TCR. Resubmit for vetting (costs another vet fee).
  3. If the legal name has genuinely changed, the tenant needs an IRS Form 147C confirming the current name before re-vetting.
- **Re-submission etiquette:** Don't re-submit the same data hoping for a different reviewer. Re-vetting with unchanged data is logged as a duplicate and may slow the next legitimate re-vet.

## 2. EIN-to-legal-name mismatch

- **Detect:** Pre-flight (`validate_10dlc_packet.py`) catches format issues; TCR catches semantic mismatch with `EIN_NAME_MISMATCH`.
- **Root causes:**
  - Tenant submitted a DBA instead of legal entity name.
  - Recent legal name change not yet reflected with the IRS.
  - Typo in EIN.
- **Fix steps:**
  1. Confirm the EIN against the IRS confirmation letter — not the tenant's accounting system.
  2. Update legal name to match exactly (including suffix).
  3. If a legitimate name change has occurred, request Form 147C from IRS before re-filing.
- **Re-submission etiquette:** Note the changed fields in the resubmission cover letter. Reviewers approve corrections faster when the delta is explicit.

## 3. Campaign content does not match declared use case

- **Detect:** TCR returns `USE_CASE_MISMATCH` or carriers return `CONTENT_VIOLATION`. Often surfaces as a `2FA` campaign getting downgraded after a sample promo message slips in.
- **Root causes:**
  - Promotional language in samples for `ACCOUNT_NOTIFICATION`, `2FA`, or `CUSTOMER_CARE`.
  - Samples mention a discount, sale, or call-to-buy.
  - Sample uses a transactional voice but the declared use case is `MARKETING`.
- **Fix steps:**
  1. Re-classify: if any sample is genuinely promotional, split into two campaigns rather than reclassifying everything as `MIXED` (see `references/tcr-use-cases.md`).
  2. Rewrite samples to mirror only the traffic that belongs in the declared use case.
  3. For ambiguous samples, lead with the trigger event (`Your order #1029 has shipped`) — reviewers parse the first sentence hardest.
- **Re-submission etiquette:** Resubmit with the trimmed samples. If splitting into two campaigns, file them sequentially, not in parallel, so the first one's vetting score informs the second.

## 4. Opt-in evidence insufficient

- **Detect:** TCR returns `OPTIN_INSUFFICIENT` or the opt-in URL gets flagged in manual review.
- **Root causes:**
  - URL points at a homepage rather than the specific consent form.
  - Consent language bundles SMS with email or push.
  - Pre-checked consent box.
  - Consent is buried in terms of service rather than at the point of phone-number capture.
- **Fix steps:**
  1. Update the live opt-in surface so the SMS checkbox is unchecked by default and the consent text is SMS-specific.
  2. Take a fresh screenshot with timestamp and host it publicly.
  3. Re-file with the new URL or screenshot as the opt-in evidence.
- **Re-submission etiquette:** Don't paste a URL that requires login. If the consent flow is behind auth, host a public mock that mirrors the production UX.

## 5. Sample messages too generic

- **Detect:** TCR returns `SAMPLE_TOO_GENERIC` or carriers downgrade vetting after launch.
- **Root causes:**
  - Samples under 20 characters or under 3 sentences.
  - Missing brand name, recipient context, or opt-out language.
  - Samples are paraphrases instead of literal production sends.
- **Fix steps:**
  1. Pull 5 real sends (with PII redacted) from staging.
  2. Replace generic samples with the redacted real sends, keeping brand name and `Reply STOP` intact.
  3. Make sure samples cover the variety the campaign will actually send.
- **Re-submission etiquette:** Number the samples in the cover note so a reviewer can confirm each one passes their content scan.

## 6. Missing opt-out language

- **Detect:** TCR returns `MISSING_OPTOUT` or carriers flag at the content-filter layer post-launch.
- **Root causes:**
  - One or more sample messages omit the `STOP` instruction.
  - The opt-out auto-reply doesn't actually contain `STOP`.
  - Brand name missing from the opt-out confirmation.
- **Fix steps:**
  1. Add `Reply STOP to unsubscribe.` to every sample.
  2. Verify the auto-reply text references the brand and the word `STOP`.
  3. Run `validate_10dlc_packet.py` — it enforces the `STOP` check on `opt_out_text`.
- **Re-submission etiquette:** Note in the cover that samples and the auto-reply were both updated together.

## 7. Prohibited content category

- **Detect:** TCR returns `PROHIBITED_CONTENT` or `SHAFT_VIOLATION` (sex, hate, alcohol, firearms, tobacco). Some carriers extend this list (cannabis, payday loans, debt collection).
- **Root causes:**
  - Campaign content falls into an outright prohibited category for US carriers.
  - Age-gated category declared but no age-verification at opt-in.
  - Affiliate marketing without disclosure.
- **Fix steps:**
  1. If outright prohibited (e.g. cannabis on Verizon), 10DLC is not the right channel. Surface this back to the tenant; the registration cannot succeed.
  2. If age-gated, add age verification at opt-in, set `Campaign.ageGated = true`, and update samples to reference the gate.
  3. If affiliate marketing, declare it honestly and add disclosure in the message body.
- **Re-submission etiquette:** Don't shop the same prohibited campaign to different reviewers. Address the category restriction or recommend an alternative channel (e.g. WhatsApp, RCS, email).

## General re-submission etiquette

- Fix one class of issue at a time. Bundling unrelated changes into a single re-submission makes it hard for reviewers to confirm each fix.
- Include a short cover note listing what changed since the last submission.
- Re-run `scripts/validate_10dlc_packet.py` before every re-submission. Mechanical failures are free to catch and expensive to re-file for.
- Track rejection codes on the Sender Profile so repeat rejections trigger a manual review before another re-file.
