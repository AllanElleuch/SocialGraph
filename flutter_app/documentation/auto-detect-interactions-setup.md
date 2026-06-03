# Auto-detecting interactions — setup guide

How interaction auto-detection is wired, and the exact steps **you** need to do
to finish the two cloud sources (Google Calendar + Gmail). The device sources
already work out of the box.

All four sources funnel through one tested pipeline:

```
native/cloud payload → map to a record → applyDetectedInteractions() → contacts
                                          (match by contactId→email→phone, dedup by id)
```

---

## Status at a glance

| # | Source | Status | Needs you to… |
|---|--------|--------|----------------|
| 1 | Outbound return-prompt | ✅ Done & wired | nothing |
| 2 | Device Calendar (EventKit) | ✅ Done & wired | grant calendar permission on first run |
| 3 | Google Calendar (cloud) | 🔧 Logic built & tested | OAuth wiring (below) |
| 4 | Gmail (cloud) | 🔧 Logic built & tested | OAuth wiring + security review (below) |

Sources 3 & 4 have fully-tested logic (`GoogleCalendarSyncService`,
`GmailSyncService`, parsers). Only the **auth + one wiring line each** remain.

---

## 1 & 2 — Already done

- **Return-prompt:** after you tap Call/Text/Email and come back from the
  external app, a *“Logged a call with Ada · Remove”* SnackBar lets you undo.
  Nothing to configure.
- **Device Calendar:** runs on launch (`_syncCalendar()` in `main.dart`).
  iOS will ask for calendar access the first time — the prompt text is already
  in `ios/Runner/Info.plist` (`NSCalendarsUsageDescription` /
  `NSCalendarsFullAccessUsageDescription`).

> Do **#3 (Google Calendar) before #4 (Gmail)** — Calendar uses a *sensitive*
> OAuth scope (standard verification), while Gmail uses a *restricted* scope
> that needs a yearly third-party security (CASA) assessment to ship publicly.

---

## 3 — Google Calendar (cloud)

### Step 1 — Create OAuth credentials

1. Go to <https://console.cloud.google.com/> → create/select a project.
2. **APIs & Services → Library** → enable **Google Calendar API**
   (and **Gmail API** if you'll do #4).
3. **APIs & Services → OAuth consent screen**:
   - User type: **External**, fill app name / support email.
   - **Scopes** → add `.../auth/calendar.readonly`.
   - Add yourself under **Test users** (so you can use it before verification).
4. **APIs & Services → Credentials → Create credentials → OAuth client ID**:
   - Create an **iOS** client (bundle id = your app's, e.g. `com.you.socialGraph`).
   - Note the **iOS client ID** and its **reversed client ID**
     (`com.googleusercontent.apps.XXXX`).

### Step 2 — Add the sign-in dependency

```yaml
# pubspec.yaml → dependencies
google_sign_in: ^6.2.1
```

```bash
flutter pub get
```

### Step 3 — iOS native config

Add the reversed client ID as a URL scheme so the OAuth redirect returns to the
app. In `ios/Runner/Info.plist` (inside the top-level `<dict>`):

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <!-- your REVERSED iOS client ID -->
      <string>com.googleusercontent.apps.XXXXXXXX-XXXXXXXX</string>
    </array>
  </dict>
</array>
```

### Step 4 — Implement a token provider

The sync services depend only on this tiny interface
(`lib/services/google_sync_service.dart` already defines `GoogleTokenProvider`).
Create `lib/services/google_signin_token_provider.dart`:

```dart
import 'package:google_sign_in/google_sign_in.dart';
import 'google_sync_service.dart';

/// Bridges google_sign_in to the GoogleTokenProvider the sync services expect.
class GoogleSignInTokenProvider implements GoogleTokenProvider {
  GoogleSignInTokenProvider({required List<String> scopes})
      : _signIn = GoogleSignIn(scopes: scopes);

  final GoogleSignIn _signIn;

  /// Call once from a "Connect Google" button.
  Future<bool> connect() async {
    final account = await _signIn.signIn();
    return account != null;
  }

  Future<void> disconnect() => _signIn.disconnect();

  @override
  Future<String?> accessToken() async {
    final account = _signIn.currentUser ?? await _signIn.signInSilently();
    if (account == null) return null;
    final auth = await account.authentication;
    return auth.accessToken;
  }
}
```

Scopes to pass:

- Calendar only: `['https://www.googleapis.com/auth/calendar.readonly']`
- Calendar + Gmail: add `'https://www.googleapis.com/auth/gmail.metadata'`

### Step 5 — Wire it into the load cycle

In `lib/main.dart`, mirror the existing `_syncCalendar()`:

```dart
// field
final _googleTokens = GoogleSignInTokenProvider(
  scopes: const ['https://www.googleapis.com/auth/calendar.readonly'],
);
late final _googleCalendar = GoogleCalendarSyncService(_googleTokens);

// in _loadContacts(), after _syncCalendar():
await _syncGoogleCalendar();

// new method
Future<void> _syncGoogleCalendar() async {
  final selfEmail = _signedIn ? _auth.currentUser?.email : null;
  final updated = await _googleCalendar.sync(
    _contacts,
    selfEmails: {if (selfEmail != null) selfEmail},
  );
  if (!identical(updated, _contacts)) {
    if (mounted) setState(() => _contacts = updated);
    await _repository.save(_contacts);
  }
}
```

`accessToken()` returns `null` until the user connects, so `sync()` is a safe
no-op before then. Add a **“Connect Google Calendar”** button (e.g. in Settings)
that calls `_googleTokens.connect()`.

### Step 6 — Verify

```bash
flutter analyze
flutter test
flutter run        # connect, then check meetings appear as interactions
```

---

## 4 — Gmail (cloud)

Same auth as #3, plus the Gmail scope and one extra service.

### Step 1 — Scope & service

- Add `'https://www.googleapis.com/auth/gmail.metadata'` to the sign-in scopes
  (Step 4 above).
- Wire `GmailSyncService` like the calendar one:

```dart
late final _gmail = GmailSyncService(_googleTokens);

Future<void> _syncGmail() async {
  final selfEmail = _auth.currentUser?.email;
  if (selfEmail == null) return; // need to know "you" to find the other party
  final updated = await _gmail.sync(_contacts, selfEmails: {selfEmail});
  if (!identical(updated, _contacts)) {
    if (mounted) setState(() => _contacts = updated);
    await _repository.save(_contacts);
  }
}
```

Call `await _syncGmail();` in `_loadContacts()` after the calendar syncs.

### Step 2 — ⚠️ Security assessment before public release

`gmail.metadata` / `gmail.readonly` are **restricted** scopes. To publish on the
App Store with them, Google requires an **annual third-party CASA security
assessment** (time + cost). Until then it works for **Test users** only.

Options:
- Keep Gmail **off by default**, opt-in, and stay in testing while evaluating.
- Ship **Calendar only** (no CASA needed) and add Gmail later.

### Step 3 — Verify

Same as #3 (`flutter analyze` / `test` / `run`). The mapping is already covered
by `test/email_interaction_merge_test.dart` and `test/google_sync_service_test.dart`.

---

## How matching works (reference)

- **Match order:** explicit `contactId` → email (case-insensitive) →
  phone (last 9 digits, so `+1 (415) 555-0100` == `415-555-0100`).
- **Dedup:** every record carries a deterministic id
  (`calendar-<eventId>-<email>`, `gmail-<msgId>-<email>`), so re-syncing never
  creates duplicates — safe to run on every launch.
- **Confidence:** high-confidence sources auto-log (attended meetings, in-app
  actions). If you later add fuzzy sources (location visits), route them to a
  *“Suggested interactions”* inbox instead of silent logging.

## Files

| File | Role |
|------|------|
| `lib/services/interaction_match.dart` | generic match + dedup merge |
| `lib/services/calendar_meeting_merge.dart` | event → meeting (pure) |
| `lib/services/calendar_sync_service.dart` | device EventKit fetch (#2) |
| `lib/services/outbound_prompt.dart` | return-prompt logic (#1) |
| `lib/services/email_interaction_merge.dart` | email → interaction (pure) |
| `lib/services/google_parsers.dart` | Gmail/Calendar JSON parsers |
| `lib/services/google_sync_service.dart` | Google Calendar + Gmail REST (#3/#4) |
