---
name: New skill proposal
about: Propose a Sent-domain skill (SMS / WhatsApp / RCS) before opening an implementation PR
title: "[Skill Proposal]: "
labels: enhancement
assignees: ""
---

## Proposed Name

Use kebab case, for example `sms-shortcode-provisioning` or `waba-policy-reviewer`.

## One-Line Description

Draft the actual `description` field, including what the skill does and at least one `Use when` trigger.

```yaml
description:
```

## Trigger Phrases

List the words users would naturally type when this skill should activate.

## Existing Skill It Complements

Which current skill is closest, and why is this not just an edit to that skill?

## Why This Is Sent-Domain (SMS / WhatsApp / RCS)

Explain why this belongs in `sent-skills` (a messaging-platform-domain skill collection) instead of a generic engineering lifecycle collection. Name the channel(s) it covers.

## Workflow Sketch

Outline the process the skill should make the agent follow.

## References

Link source docs, internal examples, or representative transcripts that justify the workflow.
