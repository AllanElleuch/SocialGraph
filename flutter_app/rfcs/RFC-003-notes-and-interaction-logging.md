# RFC-003 — Notes + Interaction Logging

**Tier:** P1/P2 · **Priority:** 3 · **Depends on:** `U0-model-foundation`

## Summary

The memory layer that makes the graph/timeline meaningful: free-text notes per contact and
a log of interactions (call, text, meeting, email, note) with timestamps. Feeds RFC-005
reminders and RFC-006 strength scoring, and drives `lastInteraction` automatically.

## Work Units

### U3.1 — InteractionEvent model + Contact wiring
- **id:** `U3.1-interaction-model`
- **depends_on:** [`U0-model-foundation`]
- **scope:** Finalize `InteractionEvent { id, date, type (enum), note }` (introduced in U0),
  add `Contact.logInteraction(event)` helper returning a new Contact via `copyWith` with the
  event prepended and `lastInteraction` updated to `max(existing, event.date)`.
- **acceptance_tests:** logging updates `lastInteraction`; events stored newest-first;
  round-trips through JSON.
- **risk_level:** Tier 1.
- **rollback_plan:** revert helper; field already additive from U0.

### U3.2 — Notes editor
- **id:** `U3.2-notes-ui`
- **depends_on:** [`U0-model-foundation`]
- **scope:** Notes section in `contact_card.dart` (read) + a multiline field in
  `contact_form.dart` (edit). Autosaves on form save.
- **acceptance_tests:** entering notes persists and renders on the card; empty notes show
  a muted placeholder.
- **risk_level:** Tier 1.
- **rollback_plan:** revert card + form note sections.

### U3.3 — Interaction log UI + quick-log
- **id:** `U3.3-log-ui`
- **depends_on:** [`U3.1-interaction-model`]
- **scope:** On the card, a "Log interaction" action (type picker + optional note) and a
  recent-interactions list. Auto-log a `call`/`text`/`email` event when the RFC-001
  quick-actions fire (integration point).
- **acceptance_tests:** logging an interaction adds it to the list and updates the card's
  Last Interaction; tapping Call (RFC-001) appends a `call` event.
- **risk_level:** Tier 2 (touches card shared with RFC-001).
- **rollback_plan:** revert card log section; auto-log hook guarded behind a null check.

### U3.4 — Timeline integration
- **id:** `U3.4-timeline`
- **depends_on:** [`U3.1-interaction-model`]
- **scope:** Extend `timeline_view.dart` to optionally order by most-recent interaction and
  show interaction count per contact.
- **acceptance_tests:** contacts with recent interactions sort correctly; count matches log.
- **risk_level:** Tier 1.
- **rollback_plan:** revert timeline changes; falls back to dateMet ordering.

## Risks / Integration
- Shares `contact_card.dart` with RFC-001 → integrate U3.3 after RFC-001 U1.3 or coordinate.
- Provides the data backbone for RFC-005 and RFC-006; merge before them.

## Outputs
- Interaction model + helpers, notes UI, interaction log UI, timeline ordering, unit tests.
