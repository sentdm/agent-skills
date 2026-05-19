# Template Status Handling

The lifecycle states a Sent template moves through, which fields are editable in each, how the UI gets notified of upstream changes, and how to handle resubmission. The builder UI tracks every template against the state machine below.

## Status enum

Sent normalizes template status into four states the UI renders, regardless of underlying channel:

| State | Meaning | Source |
|---|---|---|
| `Draft` | Authored locally, not yet submitted | Sent-internal |
| `Pending` | Submitted, awaiting review (WhatsApp = Meta review; RCS = Google review; SMS skips this state) | Set by Sent on submit, cleared by upstream callback |
| `Approved` | Live and sendable | Set by Sent on upstream approval |
| `Rejected` | Upstream rejected the submission | Set by Sent on upstream rejection, carries a `rejection_reason` payload |

**Note on Meta `PAUSED`:** Meta sometimes flags an Approved WhatsApp template as `PAUSED` due to deliverability quality issues. Sent surfaces this as `Approved` + a `paused` badge on the same row — it is *not* a separate top-level state because the template remains in the catalog and resumes automatically once quality recovers. Do not bucket PAUSED templates as Rejected.

Other upstream states (Meta `DISABLED`, `IN_APPEAL`, etc.) collapse into Sent's enum per the Sent template-status API docs at https://docs.sent.dm.

## Editable fields by state

| Field | Draft | Pending | Approved | Rejected |
|---|:-:|:-:|:-:|:-:|
| Name | edit | locked | locked | locked |
| Language | edit | locked | locked | locked |
| Category | edit | locked | locked (Meta may silently change it — see below) | locked |
| Channel | edit | locked | locked | locked |
| Body | edit | locked | edit (creates v2) | edit |
| Header type | edit | locked | locked | edit |
| Header text/media | edit | locked | edit | edit |
| Footer | edit | locked | edit | edit |
| Button types (radio) | edit | locked | locked | edit |
| Button labels | edit | locked | edit | edit |
| Variable samples | edit | locked | edit | edit |

Editing an **Approved** template's editable fields does not mutate the live template — it creates a new version on submit, while the prior version continues to send until the new one is approved. Make this obvious in the editor footer ("Submitting creates v2; v1 keeps sending until v2 is approved").

In **Pending**, surface a "Withdraw and edit" affordance — it calls the Sent withdraw endpoint and moves the template back to Draft.

## Webhook vs polling

Sent emits a `template.status_changed` webhook event whenever a template transitions states. See https://docs.sent.dm for the full event schema and subscription setup.

Two reasonable UI approaches:

- **Webhook + realtime fanout** (preferred). The backend receives the Sent webhook, fans out to the relevant tenant's realtime channel (Pusher / Ably / Supabase Realtime / WebSocket), and the list row updates in place. Lowest latency, no client polling load. Use when you already have a realtime layer for other reasons.
- **Short polling** (acceptable fallback). The list view polls `GET /templates?status=pending` every 5–10s while any row is in Pending; stops polling when none remain. Simpler to ship; more network load. Use when you don't yet have realtime infrastructure.

Do *not* poll per-row — always poll the list filter — and do not poll forever. Cap at e.g. 30 min after submit; beyond that, the tenant must refresh.

## Rejection reason display: Meta vs Sent

Two distinct rejection sources, and the UI should render them differently:

- **Meta-surfaced rejection.** The `rejection_reason` Sent forwards from Meta's `template.message_template_status_update` event. Render this as a sticky banner with the human-readable reason on top, the raw Meta enum (e.g. `INVALID_FORMAT`, `ABUSIVE_CONTENT`, `INCORRECT_CATEGORY`) collapsed by default, and a Sent-maintained remediation hint mapped from the enum.
- **Sent-surfaced rejection.** When Sent's own pre-submission validation (the server-side mirror of the matrix) rejects the payload before forwarding to Meta. Render with a different icon and label ("Caught by Sent before submission") so tenants don't think Meta reviewed the template.

Never show the raw Meta JSON — it's noisy and changes shape. Always go through the Sent-normalized rejection-reason API.

## Resubmission flow

After editing a Rejected template:

1. The Submit button triggers a *new submission attempt* against the existing template record. The template ID stays stable; only the `attempt_id` increments.
2. The list row transitions Rejected → Pending in place; do not create a duplicate row.
3. The rejection-reason banner is dismissed automatically when the new attempt enters Pending.
4. On Approval, the row turns green and the banner stays gone. On a fresh Rejection, render the new reason — and add a "previous reasons" disclosure showing the prior failures so tenants can see they're not regressing.

For Approved templates, "resubmit" is really "submit a new version" — covered above in Editable fields.

## Silent re-categorization

Meta may re-categorize an Approved template (most commonly Utility → Marketing) without changing its status. Sent surfaces this as a `template.recategorized` event with the old and new categories. The list-row UI should render a one-time dismissible banner ("Meta moved this template to Marketing — it will now bill at marketing rates"). Tenants who miss this end up surprised by billing. See the `template-builder-ui` SKILL.md for the editor-side treatment.
