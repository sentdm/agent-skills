# RCS Fallback Patterns — Reference

Supporting reference for `rcs-agent-onboarding`. Covers when SMS fallback fires from an RBM send, how to declare channel arrays on Sent, content-trimming considerations, lower-environment testing, and the webhook signals that confirm fallback occurred. The RBM error semantics themselves are documented at [Google's RBM error reference](https://developers.google.com/business-communications/rcs-business-messaging/reference/rest) — this doc covers Sent's wrapping behavior.

## When Fallback Fires

Sent's fallback engine triggers an alternate channel send when **any** of the following happens on the RCS attempt:

1. **Capability mismatch.** RBM responds with a `CAPABILITY_DENIED` (or equivalent) because the recipient's handset doesn't support a capability the message requires (e.g., carousel sent to a device that only renders text RCS).
2. **Agent unverified for recipient's carrier.** The agent is `launched` overall but the recipient's carrier is still `PENDING`. RBM accepts the send but it never delivers; Sent's per-carrier reconciliation flags it as fallback-eligible.
3. **Recipient device doesn't render RCS at all.** Older Android handsets, certain MVNO SIMs, or iOS devices on releases predating RCS support. RBM's capability endpoint returns `NOT_RCS_CAPABLE`.
4. **Soft RBM outage.** Rare, but if RBM is unreachable beyond Sent's retry budget, the fallback channel is attempted as a last resort. Configurable per Sender Profile.

Important: fallback is **per recipient per send**, not per Sender Profile. The same Sender Profile may deliver RCS to one recipient and SMS to another on the same campaign.

## Declaring Channels on Sent

Channels are declared on the send request as an ordered array. First channel listed is preferred; later channels are fallback targets.

```
channels: ["rcs", "sms"]
```

| Array | Behavior |
|---|---|
| `["rcs"]` | RCS-only. RBM errors surface to the application; nothing else attempted. |
| `["rcs", "sms"]` | Default for transactional/notification traffic. SMS attempted if RCS can't deliver. |
| `["rcs", "whatsapp", "sms"]` | RCS → WhatsApp → SMS waterfall. Requires the Sender Profile to have all three senders attached and the WhatsApp template pre-approved. |
| `["sms"]` | SMS-only. Used during agent provisioning before RCS is live. |

The Sender Profile's `fallback_policy` (`sms`, `none`, `application-routed`) acts as the **default** for sends that don't pass an explicit `channels` array. An explicit array on the send request always wins.

## Content Trimming on Fallback

When a message authored for RCS falls back to SMS, the rich elements have to go somewhere or get dropped. Sent's default trimming behavior:

| RCS element | What happens on SMS fallback |
|---|---|
| Plain text body | Carried through; counted toward segment limits |
| Suggested reply chips | Dropped silently (no SMS equivalent) |
| Suggested action: open URL | URL appended to body if not already present |
| Suggested action: dial / location / calendar | Dropped (or substituted with text URL where possible) |
| Rich card (text + media + actions) | Card text rendered as message body; media link appended if media is web-accessible; actions dropped or appended as URL |
| Rich card carousel | First card only — rest dropped |
| Attachments | Replaced with a short URL to the asset if it's hosted publicly; otherwise dropped |

Implications worth surfacing to tenants:

- **Segment cost.** An RCS message under 1000 chars is one billable RCS message. After trimming, the SMS fallback may span 3-7 SMS segments, billed per segment.
- **Link loss.** Suggested actions that aren't URLs (dial, location) silently disappear. If the action is load-bearing, write the SMS variant explicitly rather than relying on auto-trim.
- **Brand erosion.** Recipients see a rich card from your brand on RCS and a plain text block on SMS. Use a deliberate SMS-side template rather than auto-trim when brand consistency matters.

For tenants where this matters, the cleanest pattern is to author both variants explicitly and let Sent pick based on channel — see `template-builder-ui` for the authoring surface.

## Testing Fallback in Lower Environments

Sent provides three knobs in non-prod:

1. **Forced fallback flag** on the send request (`force_fallback: "capability_mismatch"`) — Sent skips the RCS attempt and goes straight to the next channel. Use to verify SMS-side behavior end to end.
2. **Test recipient registry** — pre-register specific phone numbers as "RCS-incapable" in lower envs. RBM probes for these numbers return `NOT_RCS_CAPABLE` in Sent's test stubs.
3. **Per-carrier launch state override** — toggle a specific carrier to `PENDING` on the RCS sender record in lower envs to exercise the per-carrier-pending fallback path.

Never use force-fallback flags in production. They're rejected at the API layer.

## Instrumentation — Confirming Fallback Occurred

Sent emits the following webhook events around fallback (see [Sent webhook docs](https://docs.sent.dm/webhooks) for the full schema):

| Event | Meaning |
|---|---|
| `message.channel_selected` | Fires when Sent decides which channel to use first. `channel` field carries the choice. |
| `message.fallback_triggered` | Fires when the primary channel fails and Sent moves to the next. `reason` carries the trigger (`capability_mismatch`, `carrier_pending`, `not_rcs_capable`, `rbm_unreachable`). |
| `message.delivered` | Fires when *any* channel successfully delivers. `channel` field tells you which one won. |
| `message.failed` | Fires only when **all** channels in the array failed. |

To confirm a specific message fell back from RCS to SMS, join `fallback_triggered` and `delivered` events on `message_id` and inspect `channel` on each.

For aggregate reporting, the MDR layer carries an `attempted_channels` array and a `delivered_channel` string per message. The `messaging-performance-analyzer` skill walks through reading these.

## Anti-Patterns

- Authoring a single rich-card message and assuming auto-trim makes the SMS variant acceptable
- Hardcoding `channels: ["rcs"]` on the send and treating the failure as a generic error (no fallback ever fires)
- Treating the per-carrier `PENDING` window as a Sent bug — it's expected, plan fallback around it
- Putting `whatsapp` in the fallback array without a pre-approved utility template (fallback will fail at template-resolution time)
- Using `force_fallback` in production traffic
