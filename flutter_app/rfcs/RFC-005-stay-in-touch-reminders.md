# RFC-005 — Stay-in-Touch Reminders

**Tier:** P2 (differentiator) · **Priority:** 5
**Depends on:** `U0-model-foundation`, RFC-003 (interactions), RFC-006 (strength, optional)

## Summary

The retention engine and the clearest expression of "advanced relationship manager":
per-contact reach-out cadence and a surfaced list of contacts you're overdue to contact.
Uses interaction recency (RFC-003) and, when available, relationship strength (RFC-006) to
prioritize who to nudge.

## Work Units

### U5.1 — Cadence model + due calculation
- **id:** `U5.1-cadence`
- **depends_on:** [`U0-model-foundation`, `U3.1-interaction-model`]
- **scope:** Use `reminderCadenceDays` (from U0). Pure function
  `reachOutStatus(Contact, now) → {dueInDays, isOverdue}` from `lastInteraction +
  cadence`. Sensible default cadence by tag (e.g. "Family" 30d) when unset.
- **acceptance_tests:** a contact 100 days since last interaction with 90d cadence is
  overdue; null cadence uses tag default; future-due contacts are not overdue.
- **risk_level:** Tier 1 (pure logic).
- **rollback_plan:** delete the service; no callers depend on it yet.

### U5.2 — "Needs attention" surface
- **id:** `U5.2-attention-list`
- **depends_on:** [`U5.1-cadence`]
- **scope:** A view/sheet listing overdue contacts sorted by overdue-ness × strength
  (RFC-006 if present, else recency). Each row offers a quick-log / quick-action
  (RFC-001/003 integration) and "snooze".
- **acceptance_tests:** overdue contacts appear sorted; logging an interaction removes the
  contact from the list; snooze pushes the due date out.
- **risk_level:** Tier 2.
- **rollback_plan:** revert the view + its entry point.

### U5.3 — Cadence editor
- **id:** `U5.3-cadence-ui`
- **depends_on:** [`U5.1-cadence`]
- **scope:** Per-contact cadence picker in `contact_card.dart` / form (e.g. weekly /
  monthly / quarterly / custom / off).
- **acceptance_tests:** setting a cadence persists and changes the due calculation.
- **risk_level:** Tier 1.
- **rollback_plan:** revert the picker.

### U5.4 — Local notifications *(optional / flagged)*
- **id:** `U5.4-notifications`
- **depends_on:** [`U5.1-cadence`]
- **scope:** Optional `flutter_local_notifications` daily check for overdue contacts.
  Behind a feature flag; in-app surface (U5.2) is the primary deliverable.
- **acceptance_tests:** scheduling fires for an overdue contact (manual/device test).
- **risk_level:** Tier 2 (platform permissions).
- **rollback_plan:** flag off; remove dep.

## Risks / Integration
- Hard-depends on RFC-003 interaction data; soft-depends on RFC-006 for prioritization.
- Notifications add iOS permission surface — keep optional for this pass.

## Outputs
- `reach_out_service.dart`, needs-attention view, cadence editor, unit tests for due logic.
