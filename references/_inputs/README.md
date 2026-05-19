# `_inputs/` — Ground-truth source material

This directory holds canonical Sent docs and API specs used to ground reference content in `skills/*/references/`. Files here are **inputs to skill content**, not skill content themselves.

When a skill reference cites Sent behavior (status enums, error codes, endpoint paths, webhook payload shapes, etc.), it should be grounded against a snapshot here so the claim is defensible.

## Contents

- `sent-docs-v3-2026-05-19.md` — Snapshot of docs.sent.dm: dashboard walkthrough, quickstarts (first message, first template, channel setup, account setup, try Sent), glossary, API reference (authentication, rate limits, idempotency, sandbox mode, errors, error catalog, data models). Captured 2026-05-19.
- `sent-openapi-v3-url.txt` — URL of the live OpenAPI 3 spec (`https://api-dev.sent.dm/swagger/v3/swagger.json`). Fetch on demand rather than committing the JSON (it changes).

## Workflow

When updating a reference doc:
1. Read the relevant section of `sent-docs-v3-*.md` for the canonical claim.
2. Cite the source in the reference using a comment block at top: `<!-- Grounded against references/_inputs/sent-docs-v3-2026-05-19.md (dashboard-walkthrough section) -->`.
3. If the OpenAPI spec is the source, fetch it fresh and paste the relevant operation block into your commit message.

When a snapshot is older than ~3 months, refresh it from docs.sent.dm and commit the new file with a new date.
