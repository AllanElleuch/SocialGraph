# RFC-001 — Search + Tap-to-Call / Text / Email

**Tier:** P0 (table stakes) · **Priority:** 1 · **Depends on:** `U0-model-foundation`

## Summary

Close the most-felt usability gaps: make a contact reachable in one tap (call / SMS /
email) and make search actually find people by phone, email, and workplace — not just
name and tags. Today `Contact` has no phone/email fields and the only actions are
edit/close.

## Pipeline Stages

1. **RFC intake** — this document.
2. **DAG decomposition** — units below.
3. **Unit assignment** — `flutter-architect` (model/search), `flutter-ui` (card actions),
   `flutter-integrations` (`url_launcher`).
4. **Unit implementation → validation → merge queue → verification.**

## Work Units

### U1.1 — Extend search to phone/email/workplace
- **id:** `U1.1-search-fields`
- **depends_on:** [`U0-model-foundation`]
- **scope:** Update `_filteredContacts` in `main.dart` to match `phone`, `email`,
  `workplace`, and `locationMet` (case-insensitive, substring). Extract the predicate into
  a testable `contactMatchesQuery(Contact, String)` pure function in a new
  `lib/services/contact_search.dart`.
- **acceptance_tests:** query "stripe" matches Alice (workplace); query partial phone digits
  matches; empty query returns all; matching is case-insensitive.
- **risk_level:** Tier 1.
- **rollback_plan:** revert `contact_search.dart` + the one call site in `main.dart`.

### U1.2 — Quick-action launcher service
- **id:** `U1.2-launcher-service`
- **depends_on:** [`U0-model-foundation`]
- **scope:** Add `url_launcher` dep. Create `lib/services/quick_actions_service.dart`
  with `call(phone)`, `sms(phone)`, `email(address)` building `tel:` / `sms:` / `mailto:`
  URIs and launching via `launchUrl`. Sanitize phone (strip spaces/dashes). Return a bool
  success; never throw to UI.
- **acceptance_tests:** URI builders produce `tel:+15551234567` from `"+1 (555) 123-4567"`;
  `mailto:` from a valid email; methods are no-ops (return false) on empty input.
- **risk_level:** Tier 2 (adds a plugin + platform URL schemes).
- **rollback_plan:** remove service + dep; no model/UI coupling beyond the card buttons.

### U1.3 — Quick-action buttons on ContactCard
- **id:** `U1.3-card-actions`
- **depends_on:** [`U0-model-foundation`, `U1.2-launcher-service`]
- **scope:** Add a Call / Text / Email action row to `contact_card.dart`, shown only when
  the respective field is non-empty. Display phone/email rows in the card body.
- **acceptance_tests:** buttons render only for populated fields; tapping invokes the
  matching launcher method (verified via injected fake in widget test).
- **risk_level:** Tier 1.
- **rollback_plan:** revert `contact_card.dart`.

### U1.4 — Surface phone/email in ContactForm
- **id:** `U1.4-form-fields`
- **depends_on:** [`U0-model-foundation`]
- **scope:** Add phone + email text fields to `contact_form.dart` with light validation
  (email format, phone digits). Map device `email` in `contacts_import_service.dart`.
- **acceptance_tests:** saving a contact persists phone+email; invalid email shows inline
  error; imported device contacts carry their email.
- **risk_level:** Tier 1.
- **rollback_plan:** revert form + import-service field mapping.

## Quality Pipeline Notes
- Plugin platform setup: iOS `LSApplicationQueriesSchemes` for `tel`/`sms`/`mailto` if needed.
- Tests: pure-function unit tests for U1.1/U1.2; widget test with a fake launcher for U1.3.

## Risks / Integration
- `url_launcher` on macOS desktop has limited `tel:` support — acceptable (mobile-first).
- Disjoint from RFC-002/003/004 except shared model (U0) and `contact_card.dart` (also
  touched by RFC-003) → sequence card edits after RFC-003 or merge carefully.

## Outputs
- `contact_search.dart`, `quick_actions_service.dart`, updated card/form, unit + widget tests.
