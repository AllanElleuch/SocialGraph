# Blueprint: Add & Edit Contact Feature

**Objective:** Build full Add/Edit contact management with rich form UX (tag badges, address autocomplete, current location, dark theme).

**Created:** 2026-03-24
**Status:** REVIEWED (RFC pipeline pass complete)
**Branch strategy:** Single integration branch `feat/contact-crud` — all work done directly
**Estimated steps:** 7 (3 parallel groups)

---

## RFC Review Summary

| # | Severity | Finding | Resolution |
|---|----------|---------|------------|
| 1 | CRITICAL | `geocoding` has no autocomplete — only returns single result for full address | Use Nominatim (OSM) HTTP API for autocomplete (free, no key) |
| 2 | CRITICAL | Steps 1+2 both touch pubspec.yaml/lock — merge conflict if truly parallel | Make Step 2 sequential after Step 1 |
| 3 | HIGH | Missing `network.client` entitlement — HTTP requests may fail silently | Add network.client to both entitlements in Step 1 |
| 4 | HIGH | Step 3 (TagInput) falsely depends on Step 1 — it's pure Flutter | Step 3 depends on nothing, parallelize with Step 1 |
| 5 | MEDIUM | geolocator needs NSLocationWhenInUseUsageDescription in Info.plist | Add to Step 2 tasks |
| 6 | MEDIUM | addContact throws when server is down — no offline fallback | Add local-only mode in Step 6 |
| 7 | LOW | GraphNode.name not explicitly called out in model migration | Clarified in Step 1 |

---

## Revised Dependency Graph

```
Step 1 (Model + Backend + Entitlements) ──► Step 2 (Location Service)  ──┐
                                                                         ├──► Step 5 (Contact Form) ──► Step 6 (Wire into App) ──► Step 7 (Polish)
Step 3 (Tag Input Widget) ───────────────────────────────────────────────┤
                                                                         │
Step 4 (Address Autocomplete) ──── depends on Step 2 ───────────────────┘
```

**Parallel groups:**
- **Wave 1:** Steps 1 + 3 in parallel (zero shared files)
- **Wave 2:** Steps 2 + 4 (Step 2 after 1; Step 4 after 2; but 4 can start once 2 finishes, overlapping with remaining Wave 1 work)
- **Wave 3:** Step 5 (depends on 1, 2, 3, 4)
- **Wave 4:** Step 6 → Step 7 (sequential)

**Critical path:** 1 → 2 → 4 → 5 → 6 → 7

---

## Step 1: Update Contact Model + Backend API + Entitlements

**Risk level:** Tier 2 (multi-file behavior change)
**Depends on:** none
**Files touched:**
- `flutter_app/lib/models/contact.dart`
- `flutter_app/lib/models/graph_node.dart`
- `flutter_app/lib/services/contact_service.dart`
- `flutter_app/macos/Runner/DebugProfile.entitlements`
- `flutter_app/macos/Runner/Release.entitlements`
- `server.ts`
- All files referencing `contact.name`: main.dart, contact_card.dart, graph_painter.dart, timeline_view.dart, graph_view.dart, map_painter.dart

### Context Brief
The Contact model has a single `name` field. Split into `firstName` + `lastName`, add `workplace` and `homeAddress` fields. Add `displayName` getter for backward compat. Update every consumer. Fix network entitlements so HTTP actually works on macOS. Add PUT/DELETE to backend.

### Tasks
1. Update `Contact` class:
   - Replace `name` with `firstName` (String) and `lastName` (String)
   - Add `workplace` (String, default `''`)
   - Add `homeAddress` (String, default `''`)
   - Add getter: `String get displayName => '$firstName $lastName'.trim();`
   - `fromJson`: support BOTH old `name` field (split on first space) and new `firstName`/`lastName`
   - `toJson`: emit `firstName`, `lastName`, `workplace`, `homeAddress` AND `name` (for backward compat with server)

2. Update `GraphNode` class:
   - Change constructor usage: wherever `name: c.name` is used, change to `name: c.displayName`

3. Fix macOS entitlements (BOTH files):
   - Add `com.apple.security.network.client` → `true` (enables HTTP requests)
   - Keep existing keys

4. Update `server.ts`:
   - Seed data: `firstName`/`lastName`/`workplace`/`homeAddress` fields
   - Add `PUT /api/contacts/:id` endpoint
   - Add `DELETE /api/contacts/:id` endpoint
   - Keep backward compat: if request has `name` but not `firstName`, split it

5. Update `ContactService`:
   - Add `updateContact(Contact)` → PUT `/api/contacts/:id`
   - Add `deleteContact(String id)` → DELETE `/api/contacts/:id`
   - Update `_seedData` to new format

6. Update ALL consumers of `contact.name` / `node.name`:
   - `main.dart`: search filter → `c.displayName`
   - `contact_card.dart`: display → `c.displayName`
   - `graph_painter.dart`: label → `node.name` (already via GraphNode)
   - `graph_view.dart`: GraphNode construction → `name: c.displayName`
   - `timeline_view.dart`: display → `contact.displayName`
   - `map_painter.dart`: label → `contact.displayName`

### Acceptance Tests
```bash
cd flutter_app && flutter analyze  # Zero errors
flutter test                        # Passes
# Manual: app displays "Alice Johnson" not broken
```

### Rollback
Revert all changes. Delete `contacts.json` to re-seed.

---

## Step 2: Location Service (GPS + Reverse Geocode + Nominatim)

**Risk level:** Tier 1 (new files only, no existing code modified except pubspec)
**Depends on:** Step 1 (pubspec.yaml/lock conflict avoidance)
**Files touched:**
- `flutter_app/pubspec.yaml`
- `flutter_app/lib/services/location_service.dart` (NEW)
- `flutter_app/lib/models/address_suggestion.dart` (NEW)
- `flutter_app/macos/Runner/Info.plist`

### Context Brief
Service to get GPS coordinates, reverse geocode to address, and search addresses via Nominatim (OpenStreetMap) for autocomplete. Nominatim is free, no API key, 1 req/sec rate limit. The `geocoding` package is NOT used for autocomplete — only `geolocator` for GPS + direct HTTP to Nominatim for search.

### Tasks
1. Add to `pubspec.yaml`:
   - `geolocator: ^13.0.0`
   - `geolocator_apple: ^2.3.0` (explicit macOS support)

2. Add to `macos/Runner/Info.plist`:
   - `NSLocationWhenInUseUsageDescription` key with description string

3. Create `lib/models/address_suggestion.dart`:
   ```dart
   class AddressSuggestion {
     final String displayName;
     final double lat;
     final double lng;
     const AddressSuggestion({required this.displayName, required this.lat, required this.lng});
   }
   ```

4. Create `lib/services/location_service.dart`:
   - `getCurrentPosition()` → uses Geolocator, checks permissions, returns `({double lat, double lng})`
   - `reverseGeocode(double lat, double lng)` → HTTP GET to Nominatim reverse endpoint, returns address string
   - `searchAddress(String query)` → HTTP GET to `https://nominatim.openstreetmap.org/search?q={query}&format=json&limit=5`, returns `List<AddressSuggestion>`
   - Rate limiting: debounce handled by caller, but service adds `User-Agent` header (Nominatim requires it)
   - Error handling: return empty list on failure, never throw

### Acceptance Tests
```bash
cd flutter_app && flutter pub get && flutter analyze  # Zero errors
```

### Rollback
Remove dependency, delete new files, revert Info.plist.

---

## Step 3: Tag Input Widget

**Risk level:** Tier 1 (single new file, no dependencies)
**Depends on:** none
**Files touched:**
- `flutter_app/lib/widgets/tag_input.dart` (NEW)

### Context Brief
Pure Flutter widget — no model imports needed. Takes `List<String>` in, emits `List<String>` out. Self-contained.

### Tasks
1. Create `lib/widgets/tag_input.dart`:
   - `TagInput` StatefulWidget:
     - Props: `List<String> initialTags`, `ValueChanged<List<String>> onTagsChanged`
   - TextField behavior:
     - `onSubmitted` (Enter): create tag
     - `onChanged`: detect comma → create tag, clear field
     - Trim whitespace, skip empty/duplicate
   - Tag display: `Wrap` widget with colored badge containers
   - Color palette (8 dark-friendly colors):
     ```
     indigo(0xFF6366f1), emerald(0xFF10b981), amber(0xFFF59E0B),
     rose(0xFFF43F5E), cyan(0xFF06B6D4), violet(0xFF8B5CF6),
     orange(0xFFF97316), teal(0xFF14B8A6)
     ```
   - Color selection: `palette[tag.hashCode.abs() % palette.length]`
   - Each badge: colored background at 15% opacity, colored border at 30%, white text, X icon button
   - X button calls remove + `onTagsChanged`
   - Dark theme: field background `Color(0xFF111111)`, border `Color(0xFF333333)`

### Acceptance Tests
```bash
cd flutter_app && flutter analyze  # Zero errors
```

### Rollback
Delete file.

---

## Step 4: Address Autocomplete Widget

**Risk level:** Tier 2 (depends on LocationService, manages overlay lifecycle)
**Depends on:** Step 2 (imports LocationService and AddressSuggestion)
**Files touched:**
- `flutter_app/lib/widgets/address_field.dart` (NEW)

### Context Brief
Text field with debounced Nominatim autocomplete dropdown and optional "Use Current Location" button. Uses `LocationService` from Step 2.

### Tasks
1. Create `lib/widgets/address_field.dart`:
   - `AddressField` StatefulWidget:
     - Props: `String label`, `String? initialValue`, `ValueChanged<AddressResult> onChanged`, `bool showCurrentLocationButton`
   - `AddressResult` class: `{ String address, double? lat, double? lng }`
   - Text field with debounce timer (500ms)
   - On text change (after debounce): call `LocationService().searchAddress(query)`
   - Dropdown: `OverlayEntry` positioned below text field (use `LayerLink` + `CompositedTransformFollower`)
   - Max 5 suggestions shown
   - Tap suggestion → fill field, set lat/lng, dismiss dropdown, call `onChanged`
   - Tap outside → dismiss dropdown
   - "Use Current Location" button (trailing icon `my_location`):
     - Shows `CircularProgressIndicator` while loading
     - Calls `LocationService().getCurrentPosition()` then `reverseGeocode()`
     - Fills text field with address, calls `onChanged` with lat/lng
     - On error: show inline error text, allow manual entry
   - Manual text entry without selecting suggestion: call `onChanged` with address only (lat/lng null)
   - Dark theme styling matching app

### Acceptance Tests
```bash
cd flutter_app && flutter analyze  # Zero errors
```

### Rollback
Delete file.

---

## Step 5: Contact Form Screen

**Risk level:** Tier 2 (composes multiple widgets, form validation)
**Depends on:** Steps 1, 2, 3, 4
**Files touched:**
- `flutter_app/lib/widgets/contact_form.dart` (NEW)

### Context Brief
Single form widget for both Add and Edit. Uses TagInput (Step 3) and AddressField (Step 4). Constructs Contact objects using updated model (Step 1).

### Tasks
1. Create `lib/widgets/contact_form.dart`:
   - `ContactForm` StatefulWidget:
     - Props: `Contact? existingContact`, `List<Contact> allContacts`, `ValueChanged<Contact> onSave`, `VoidCallback onCancel`
   - Mode: `existingContact == null` → Add, else Edit
   - Form with `GlobalKey<FormState>`:
     - **First Name** — TextFormField, required validator, autofocus in add mode
     - **Last Name** — TextFormField, required validator
     - **Tags** — TagInput widget (initial: existing tags or empty)
     - **Location Met** — AddressField (showCurrentLocationButton: true)
     - **Workplace** — TextFormField (optional)
     - **Home Address** — AddressField (showCurrentLocationButton: false)
     - **Date Met** — GestureDetector showing formatted date, tap opens `showDatePicker` (dark theme)
     - **Connections** — Wrap of FilterChip from allContacts (exclude self), multi-select
   - Layout: full-height panel from right side (like ContactCard), scrollable
   - Header: "ADD CONTACT" / "EDIT CONTACT" + close X button
   - Footer: Row with Cancel (outlined) + Save (filled indigo) buttons
   - Save: validate form → construct Contact → call onSave
   - Edit pre-population: fill all controllers and state from existingContact
   - Generate new ID for add mode: `DateTime.now().millisecondsSinceEpoch.toString()`
   - Styling: Color(0xFF1a1a1a) background, 16px rounded corners, consistent spacing

### Acceptance Tests
```bash
cd flutter_app && flutter analyze  # Zero errors
```

### Rollback
Delete file.

---

## Step 6: Wire Add/Edit into App

**Risk level:** Tier 2 (modifies core app wiring)
**Depends on:** Step 5
**Files touched:**
- `flutter_app/lib/main.dart`
- `flutter_app/lib/widgets/contact_card.dart`

### Context Brief
Connect ContactForm to the app shell. "+" button opens Add form. Contact card gets Edit button. Save persists via ContactService (with offline fallback). Refresh list after save.

### Tasks
1. `main.dart` (`_HomePageState`):
   - Add state: `bool _showForm = false`, `Contact? _editingContact`
   - Add `_openAddForm()`: sets `_showForm = true`, `_editingContact = null`, `_selectedContact = null`
   - Add `_openEditForm(Contact c)`: sets `_showForm = true`, `_editingContact = c`, `_selectedContact = null`
   - Add `_onFormSave(Contact contact)` method:
     - If editing: try `_service.updateContact(contact)`, catch → add to local `_contacts` list
     - If adding: try `_service.addContact(contact)`, catch → add to local `_contacts` with generated ID
     - On error: show SnackBar "Saved locally (server unavailable)"
     - Refresh: `_fetchContacts()` on success, or just `setState` with local update on failure
     - Close form
   - Add `_closeForm()`: sets `_showForm = false`, `_editingContact = null`
   - Wire "+" button: `onAddContact: _openAddForm`
   - Add `ContactForm` to Stack (conditionally rendered when `_showForm`)
   - Contact form positioned like ContactCard (right panel, animated)

2. `contact_card.dart`:
   - Add `VoidCallback? onEdit` parameter
   - Add edit icon button (pencil) next to close button in header
   - Wire to `onEdit` callback

3. `main.dart` ContactCard usage:
   - Pass `onEdit: () => _openEditForm(_selectedContact!)`

### Acceptance Tests
```bash
cd flutter_app && flutter analyze
flutter run -d macos
# Test: tap "+" → form opens → fill name → save → contact appears in graph
# Test: tap contact → card → edit → form prefilled → change name → save → updated
# Test: stop server → add contact → "saved locally" snackbar
```

### Rollback
Revert main.dart and contact_card.dart.

---

## Step 7: Polish, Edge Cases & Tests

**Risk level:** Tier 1 (minor tweaks + tests)
**Depends on:** Step 6
**Files touched:**
- Various widget files (minor)
- `flutter_app/test/contact_model_test.dart` (NEW)
- `flutter_app/test/tag_input_test.dart` (NEW)
- `flutter_app/test/widget_test.dart` (update)

### Tasks
1. Edge cases:
   - Empty form save attempt → validation errors shown
   - Very long tag text → ellipsis in badge
   - Network error on save → SnackBar with retry option
   - Location permission denied → "Permission denied" inline, allow manual entry
   - Cancel during form edit → discard changes (no confirmation for MVP)

2. Animation polish:
   - ContactForm slides in from right (AnimatedPositioned, matching ContactCard)
   - ContactCard slides out when form opens

3. Tests:
   - `contact_model_test.dart`: fromJson with old `name` field, fromJson with new fields, toJson, displayName getter
   - `tag_input_test.dart`: add tag via Enter, add via comma, remove tag, duplicate prevention
   - Update `widget_test.dart` for new model

### Acceptance Tests
```bash
cd flutter_app && flutter analyze && flutter test  # All pass
```

### Rollback
Revert branch.

---

## Invariants (verified after every step)

- [ ] `flutter analyze` reports zero errors
- [ ] `flutter test` passes
- [ ] App launches on macOS without crash
- [ ] Existing Mutuals/Location/Timeline views still work
- [ ] Seed data loads correctly (backward compat)

## Anti-patterns to avoid

- **Do NOT use Google Maps/Places API** — use Nominatim (free, no key)
- **Do NOT use state management library** — keep setState pattern
- **Do NOT break existing JSON format** — fromJson must handle both old `name` and new `firstName`/`lastName`
- **Do NOT create separate Add/Edit screens** — one ContactForm widget with mode param
- **Do NOT use `geocoding` package for autocomplete** — it returns single results, not suggestions
