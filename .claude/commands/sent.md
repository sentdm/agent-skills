---
description: Sent meta dispatcher — list the SMS / WhatsApp / RCS skills available and route to the right one based on the user's intent
---

You are about to help with a messaging task on Sent (SMS, WhatsApp, RCS). The following skills are available in this plugin:

- **sent-skills:sms-10dlc-registration** — registering a brand + campaign with The Campaign Registry for A2P SMS
- **sent-skills:waba-template-author** — authoring and classifying WhatsApp templates (utility / marketing / authentication)
- **sent-skills:waba-embedded-signup** — Meta Embedded Signup integration end-to-end
- **sent-skills:rcs-agent-onboarding** — creating + verifying an RBM agent with Google for RCS sending
- **sent-skills:messaging-performance-analyzer** — analyzing Message Delivery Reports across any channel
- **sent-skills:sender-profile-architect** — multi-tenant architecture around Sent's Sender Profile (cross-channel)
- **sent-skills:template-builder-ui** — building the tenant-facing WhatsApp template submission UI

Look at the user's followup message. If it matches a skill's `Use when` triggers, invoke that skill directly. If it spans multiple skills, name the primary one and mention the others. If it's ambiguous, ask one clarifying question — never more.

Do not paraphrase the skill content here. Always invoke the skill itself.
