---
description: Sent meta dispatcher — list the WABA skills available and route to the right one based on the user's intent
---

You are about to help with a WhatsApp Business API task on Sent. The following skills are available in this plugin:

- **sent-skills:waba-template-author** — authoring and classifying WABA templates (utility / marketing / authentication)
- **sent-skills:messaging-performance-analyzer** — analyzing Message Delivery Reports across a sales funnel
- **sent-skills:sender-profile-architect** — multi-tenant architecture around Sent's Sender Profiles (SPS)
- **sent-skills:template-builder-ui** — building the tenant-facing template submission UI
- **sent-skills:waba-embedded-signup** — Meta Embedded Signup integration end-to-end

Look at the user's followup message. If it matches a skill's `Use when` triggers, invoke that skill directly. If it spans multiple skills, name the primary one and mention the others. If it's ambiguous, ask one clarifying question — never more.

Do not paraphrase the skill content here. Always invoke the skill itself.
