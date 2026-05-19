---
description: Plan multi-tenant architecture around Sent's Sender Profiles (SPS) — data model, webhook routing, rate limits, lifecycle
---

Invoke the sent-skills:sender-profile-architect skill.

Begin by asking:
1. Tenant scale — current and 12-month projection (10? 1,000? 100,000?)
2. Isolation requirements — any regulated tenants (PHI, government, data-residency)?
3. Existing stack — DB, queue, cache, language/framework
4. The specific design question — data model, webhook routing, rate limits, or lifecycle?

Then walk the SPS framing and produce a concrete schema / sequence / state-machine sketch tailored to the answers. Recommend pooled by default; recommend silos only when the answers justify them.
