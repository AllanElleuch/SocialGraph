# Contact Manager — Feature Analysis & Impact Prioritization

A complete catalog of features a phone contact manager *can* and *should* have,
prioritized by their impact on user value, retention, and differentiation.

> **Context:** SocialGraph positions itself as an **advanced contact manager** — it
> already ships a relationship **graph view**, **map view**, **timeline view**, **tags**,
> and **device contact import**. Features below are tagged with their status in this app:
> ✅ shipped · 🟡 partial · ⬜ not yet built.

---

## How features are prioritized

Each feature is scored on two axes and bucketed into a tier.

- **Impact** — how much it moves user value, retention, or word-of-mouth (1–5).
- **Effort** — relative build cost incl. platform permissions, sync, and edge cases (1–5).
- **Tier** — derived priority: do high-impact/low-effort first.

| Tier | Meaning | Rule of thumb |
|------|---------|---------------|
| **P0 — Table stakes** | Users expect it; absence = uninstall | Ship before launch |
| **P1 — High leverage** | Strong impact, reasonable effort | Next 1–2 releases |
| **P2 — Differentiators** | What makes an "advanced" manager stand out | Roadmap / paid tier |
| **P3 — Nice to have** | Polish, niche, or long-tail | Backlog |

---

## P0 — Table Stakes (must have)

These define a usable contact app. Missing any one is a dealbreaker.

| Feature | Impact | Effort | Status | Notes |
|---------|:------:|:------:|:------:|-------|
| **Create / edit / delete contacts (CRUD)** | 5 | 2 | ✅ | Core data ops; see `contact_form.dart`, `contact_service.dart` |
| **Store core fields** (name, phone, email, address, photo, company) | 5 | 2 | 🟡 | Confirm photo + multi-value fields are covered |
| **Multiple values per field** (2 phones, 3 emails, work/home) | 5 | 2 | 🟡 | Critical for real contacts; verify in model |
| **Search by name / number / email** | 5 | 2 | ⬜ | Fastest path to a contact; fuzzy match strongly preferred |
| **Alphabetical list + scroll index** | 4 | 1 | ⬜ | Default browse view with A–Z jump bar |
| **Import device contacts** | 5 | 3 | ✅ | `contacts_import_service.dart` + iOS permission |
| **Tap-to-call / text / email** | 5 | 1 | ⬜ | Deep links to dialer, SMS, mail — high daily use |
| **Permissions handled gracefully** | 4 | 2 | 🟡 | Pre-prompt + denied-state UX; iOS contacts/location set |
| **Persistent local storage** | 5 | 2 | ✅ | Data must survive restart; `contacts.json` / service layer |
| **Avatar / initials fallback** | 3 | 1 | 🟡 | Visual scan-ability when no photo |

**Why P0:** these are the operations every user performs the first minute. They
generate no differentiation but their *absence* guarantees churn.

---

## P1 — High Leverage (strong ROI)

Big retention and "feels modern" wins at moderate cost.

| Feature | Impact | Effort | Status | Notes |
|---------|:------:|:------:|:------:|-------|
| **Cloud sync & backup** | 5 | 4 | ⬜ | #1 trust feature — "I won't lose my contacts." Drives multi-device + reinstall survival |
| **Duplicate detection & merge** | 5 | 3 | ⬜ | Every imported list has dupes; auto-suggest merges |
| **Tags / labels / groups** | 4 | 2 | ✅ | `tag_input.dart` — segment family/work/leads |
| **Favorites / pinned contacts** | 4 | 1 | ⬜ | Fast access to the ~10 people that matter |
| **Recent / frequent contacts** | 4 | 2 | ⬜ | Surface who you actually interact with |
| **Notes per contact** | 4 | 1 | ⬜ | "Met at conf", "allergic to nuts" — the memory layer |
| **Contact detail screen** (rich profile) | 4 | 2 | 🟡 | One screen with all fields + quick actions |
| **Share contact** (vCard / link / QR) | 4 | 2 | ⬜ | QR exchange is a delightful in-person flow |
| **Bulk actions** (multi-select delete/tag/export) | 3 | 2 | ⬜ | Power-user cleanup |
| **Export** (vCard / CSV) | 4 | 2 | 🟡 | Data portability + user trust; reduces lock-in fear |
| **Dark mode / theming** | 3 | 1 | ⬜ | Baseline polish expectation |
| **Reminders to reach out** ("stay in touch") | 5 | 3 | ⬜ | Killer retention loop for a *relationship* manager |

**Why P1:** cloud sync and dedupe are the highest-impact items in the whole app —
they convert a "phone book" into something users *rely on*. The "stay in touch"
reminder is the strongest hook for SocialGraph's relationship-centric positioning.

---

## P2 — Differentiators ("advanced" contact manager)

These justify the "advanced" label and a paid tier. SocialGraph's identity lives here.

| Feature | Impact | Effort | Status | Notes |
|---------|:------:|:------:|:------:|-------|
| **Relationship graph / network view** | 5 | 4 | ✅ | `graph_view.dart`, `force_simulation.dart` — signature feature |
| **Map of contacts by location** | 4 | 4 | ✅ | `map_view.dart` — "who's near me / in this city" |
| **Interaction timeline / history** | 5 | 3 | ✅ | `timeline_view.dart` — relationship log over time |
| **Relationship strength / scoring** | 4 | 3 | ⬜ | Rank closeness; powers nudges + graph weighting |
| **"How we're connected" paths** | 4 | 3 | 🟡 | Shortest-path intros across the graph |
| **Interaction logging** (calls/meetings/notes auto + manual) | 5 | 4 | ⬜ | Feeds timeline, strength, and reminders |
| **Smart reminders by cadence** ("haven't talked in 90d") | 5 | 3 | ⬜ | Relationship CRM staple |
| **Custom fields** (birthday, spouse, how-met, lead status) | 4 | 2 | ⬜ | Lets it flex into light personal CRM |
| **Birthday / anniversary reminders** | 4 | 2 | ⬜ | High emotional payoff, low effort |
| **Enrichment** (auto-fill company/role/social from email) | 4 | 4 | ⬜ | "Magic" first-run wow; privacy-sensitive |
| **Calendar / email integration** | 4 | 4 | ⬜ | Auto-log meetings; pull next interactions |
| **Geofencing / "near a contact"** | 3 | 4 | ⬜ | Builds on existing location service |
| **AI summary of a relationship** | 4 | 3 | ⬜ | "Last 5 interactions, suggested follow-up" |
| **Segments & saved filters** | 3 | 2 | ⬜ | Combine tags + location + recency |

**Why P2:** the graph, map, and timeline already exist — the highest next-impact
moves are **interaction logging → relationship strength → cadence reminders**, because
together they form the loop that makes an advanced manager *useful daily* rather than
*visually impressive once*.

---

## P3 — Nice to Have (polish & long-tail)

| Feature | Impact | Effort | Status | Notes |
|---------|:------:|:------:|:------:|-------|
| **Business card / OCR scan** | 3 | 4 | ⬜ | Fast add at events; camera + OCR |
| **Voice add / search** | 2 | 3 | ⬜ | Hands-free capture |
| **Widgets** (home-screen favorites) | 3 | 3 | ⬜ | Daily-glance access |
| **Apple/Google Contacts two-way sync** | 4 | 5 | ⬜ | High value but high maintenance |
| **Multi-account / workspaces** | 2 | 4 | ⬜ | Separate personal vs work graphs |
| **Privacy vault / locked contacts** | 3 | 3 | ⬜ | Biometric-gated sensitive contacts |
| **Custom ringtone / per-contact settings** | 2 | 2 | ⬜ | Legacy expectation |
| **Localization / i18n** | 3 | 3 | ⬜ | Expand addressable market |
| **Accessibility** (VoiceOver, dynamic type) | 4 | 2 | 🟡 | Should be P1-grade hygiene; audit needed |
| **Undo / trash bin** | 3 | 2 | ⬜ | Safety net for accidental deletes |
| **Activity / audit log** | 2 | 2 | ⬜ | "What changed" history |
| **Themed graph layouts / clustering** | 2 | 3 | ⬜ | Visual polish on existing graph |

---

## Cross-cutting concerns (apply to every tier)

These aren't "features" users ask for by name, but they gate trust and ratings.

- **Privacy & data handling** — contacts are among the most sensitive data on a phone.
  Clear permission rationale, local-first option, transparent sync, easy export/delete.
- **Performance at scale** — many users have 1,000–5,000+ contacts. List virtualization,
  indexed search, and graph layout must stay smooth.
- **Offline-first** — must fully work with no network; sync reconciles later.
- **Conflict resolution** — when sync + device + edits collide, resolve deterministically.
- **Onboarding** — import + first-value (graph populated) within the first 60 seconds.
- **App Store compliance** — permission strings, encryption declaration (already configured).

---

## Recommended build order for SocialGraph

Given what's already shipped (graph, map, timeline, tags, import), the highest-impact
next steps in order:

1. **Search + tap-to-call/text/email** *(P0 gaps)* — close basic usability holes.
2. **Duplicate detection & merge** *(P1)* — imported lists are messy; this is felt immediately.
3. **Notes + interaction logging** *(P1/P2)* — the data that makes graph/timeline meaningful.
4. **Cloud sync & backup** *(P1)* — the #1 trust feature; unlocks multi-device.
5. **Cadence-based "stay in touch" reminders** *(P2)* — the retention engine and the
   clearest expression of the "advanced relationship manager" promise.
6. **Relationship strength scoring** *(P2)* — ties logging, reminders, and graph weight together.

> **Strategic note:** SocialGraph's defensible edge is the **relationship intelligence loop**
> (*log interactions → score strength → nudge you to reconnect → visualize the network*).
> Plain CRUD/search/sync are necessary to retain users, but the loop above is what turns
> a contact list into a product people pay for and recommend.

---

## Impact vs. Effort map (quick reference)

```
 IMPACT
   5 |  TapToCall   Search   Dedupe    CloudSync   InteractionLog
     |  CRUD        Reminders          Graph✅
   4 |  Favorites   Notes    Share     Strength    Enrichment
     |  Tags✅      Map✅     Export    Birthdays   Calendar
   3 |  DarkMode    Bulk     Widgets   OCR         Geofence
     |  Avatars     Undo
   2 |  Ringtone    Voice    Workspaces
     +--------------------------------------------------------
        1     2          3            4            5    EFFORT
        (do first)                         (plan / paid tier)
```

*Top-left = do now. Bottom-right = schedule deliberately.*
